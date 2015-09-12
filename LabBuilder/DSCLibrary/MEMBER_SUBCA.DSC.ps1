<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_SUBCA
.Desription
	Builds a Member Subordinate CA.
.Parameters:    
          DomainName = "LABBUILDER.COM"
          DomainAdminPassword = "P@ssword!1"
          PSDscAllowDomainUser = $True
          CACommonName = "LABBUILDER.COM Issuing CA"
          CADistinguishedNameSuffix = "DC=LABBUILDER,DC=COM"
          DSConfigDN = "CN=Configuration,DC=LABBUILDER,DC=COM"
          CRLPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n10:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n2:http://pki.labbuilder.com/CertEnroll/%3%8%9.crl"
          CACertPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n2:http://pki.labbuilder.com/CertEnroll/%1_%3%4.crt"
          RootCAName = "SS_ROOTCA"
          RootCACRTName = "SS_ROOTCA_LABBUILDER.COM Root CA.crt"
#########################################################################################################################################>

Configuration MEMBER_SUBCA
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
	Import-DscResource -ModuleName xActiveDirectory
	Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xAdcsDeployment
	Import-DscResource -ModuleName xPSDesiredStateConfiguration
	Node $AllNodes.NodeName {
		# Assemble the Local Admin Credentials
		If ($Node.LocalAdminPassword) {
			[PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
		}
		If ($Node.DomainAdminPassword) {
			[PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
		}

		# Install the CA Service
		WindowsFeature ADCSCA {
			Name = 'ADCS-Cert-Authority'
			Ensure = 'Present'
		}

		# Install the Web Enrollment Service
		WindowsFeature WebEnrollmentCA {
			Name = 'ADCS-Web-Enrollment'
			Ensure = 'Present'
			DependsOn = "[WindowsFeature]ADCSCA"
		}

		# Install the Online Responder Service
		WindowsFeature OnlineResponderCA {
			Name = 'ADCS-Online-Cert'
			Ensure = 'Present'
			DependsOn = "[WindowsFeature]WebEnrollmentCA"
		}

        # Wait for the Domain to be available so we can join it.
		xWaitForADDomain DscDomainWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $DomainAdminCredential 
            RetryCount = 100 
            RetryIntervalSec = 10 
			DependsOn = "[WindowsFeature]OnlineResponderCA" 
        }

		# Join this Server to the Domain so that it can be an Enterprise CA.
		xComputer JoinDomain 
        { 
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential 
			DependsOn = "[xWaitForADDomain]DscDomainWait" 
        } 
			
		# Create the CAPolicy.inf file that sets basic parameters for certificate issuance for this CA.
		File CAPolicy
		{
			Ensure = 'Present'
			DestinationPath = 'C:\Windows\CAPolicy.inf'
			Contents = "[Version]`r`n Signature= `"$Windows NT$`"`r`n[Certsrv_Server]`r`n RenewalKeyLength=2048`r`n RenewalValidityPeriod=Years`r`n RenewalValidityPeriodUnits=10`r`n LoadDefaultTemplates=1`r`n AlternateSignatureAlgorithm=1`r`n"
			Type = 'File'
			DependsOn = '[xComputer]JoinDomain'
		}

		# Make a CertEnroll folder to put the Root CA certificate into.
		# The CA Web Enrollment server would also create this but we need it now.
		File CertEnrollFolder
		{
			Ensure = 'Present'
			DestinationPath = 'C:\Windows\System32\CertSrv\CertEnroll'
			Type = 'Directory'
			DependsOn = '[File]CAPolicy'
		}

        # Wait for the RootCA Web Enrollment to complete so we can grab the Root CA certificate
		# file.
		WaitForAny RootCA
        {
            ResourceName = '[xADCSWebEnrollment]ConfigWebEnrollment'
            NodeName = $Node.RootCAName
            RetryIntervalSec = 30
            RetryCount = 30
			DependsOn = "[File]CertEnrollFolder"
        }

		# Download the Root CA certificate file.
		xRemoteFile DownloadRootCACRTFile
		{
			DestinationPath = "C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCACRTName)"
			Uri = "http://$($Node.RootCAName)/CertEnroll/$($Node.RootCACRTName)"
			DependsOn = '[WaitForAny]RootCA'
		}

		# Configure the Sub CA which will create the Certificate CSR file that Root CA will use
		# to issue a certificate for this Sub CA.
		xADCSCertificationAuthority ConfigCA
        {
            Ensure = 'Present'
            Credential = $DomainAdminCredential
            CAType = 'EnterpriseSubordinateCA'
			CACommonName = $Node.CACommonName
			CADistinguishedNameSuffix = $Node.CADistinguishedNameSuffix
			OverwriteExistingCAinDS  = $True
			OutputCertRequestFile = "c:\windows\system32\certsrv\certenroll\$($Node.NodeName) Request.csr"
            DependsOn = '[xRemoteFile]DownloadRootCACRTFile'
        }

		# Configure the Web Enrollment Feature
		xADCSWebEnrollment ConfigWebEnrollment {
            Ensure = 'Present'
            Name = 'ConfigWebEnrollment'
            Credential = $LocalAdminCredential
            DependsOn = '[xADCSCertificationAuthority]ConfigCA'
        }

		# Set the IIS Mime Type to allow the CSR request to be downloaded by the Root CA
		Script SetCSRMimeType
		{
			SetScript = {
				Add-WebConfigurationProperty -PSPath IIS:\ -Filter //staticContent -Name "." -Value @{fileExtension='.csr';mimeType='application/pkcs10'}
			}
			GetScript = {
				Return @{
					'MimeType' = ((Get-WebConfigurationProperty -Filter "//staticContent/mimeMap[@fileExtension='.csr']" -PSPath IIS:\ -Name *).mimeType);
				}
			}
			TestScript = { 
				If (-not (Get-WebConfigurationProperty -Filter "//staticContent/mimeMap[@fileExtension='.csr']" -PSPath IIS:\ -Name *)) {
					# Mime type is not set
					Return $False
				}
				# Mime Type is already set
				Return $True
			}
			DependsOn = '[xADCSWebEnrollment]ConfigWebEnrollment'
		}

		# Wait for the Root CA to have completed issuance of the certificate for this SubCA.
		WaitForAny SubCACer
		{
			ResourceName = "[Script]IssueCert_$($Node.NodeName)"
			NodeName = $Node.RootCAName
			RetryIntervalSec = 30
			RetryCount = 30
			DependsOn = "[Script]SetCSRMimeType"
		}

		# Download the Certificate for this SubCA.
		xRemoteFile DownloadSubCACERFile
		{
			DestinationPath = "C:\Windows\System32\CertSrv\CertEnroll\$($Node.NodeName).cer"
			Uri = "http://$($Node.RootCAName)/CertEnroll/$($Node.NodeName).cer"
			DependsOn = '[WaitForAny]SubCACer'
		}

		# Install the Root CA and the SubCA Certificates into this machine.
		Script InstallSubCACert
		{
			SetScript = {
				Write-Verbose "Installing Certificates..."
				Import-Certificate -FilePath "C:\Windows\System32\CertSrv\CertEnroll\$($Node.NodeName).cer" -CertStoreLocation cert:\CA\
				Import-Certificate -FilePath "C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCACRTName).cer" -CertStoreLocation cert:\Root\
			}
			GetScript = {
				Return @{
				}
			}
			TestScript = { 
				If ((Get-ChildItem -Path Cert:\LocalMachine\CA | Where-Object -Property Subject -EQ "CN=$($Node.NodeName)").Count -EQ 0) {
					Return $False
				}
				Return $True
			}
			DependsOn = '[xRemoteFile]DownloadSubCACERFile'
		}

		# Perform final configuration of the CA which will cause the CA service to startup
		# It should be able to start up once the SubCA certificate has been installed.
		Script ADCSAdvConfig
		{
			SetScript = {
				If ($Using:Node.DSConifgDN) {
					& "$($ENV:SystemRoot)\system32\certutil.exe" -setreg CA\DSConfigDN $($Using:Node.DSConfigDN)
				}
				If ($Using:Node.CRLPublicationURLs) {
					& "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CRLPublicationURLs $($Using:Node.CRLPublicationURLs)
				}
				If ($Using:Node.CACertPublicationURLs) {
					& "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CACertPublicationURLs $($Using:Node.CACertPublicationURLs)
				}
				Restart-Service -Name CertSvc
				Add-Content -Path 'c:\windows\setup\scripts\certutil.log' -Value "Certificate Service Restarted ..."
			}
			GetScript = {
				Return @{
					'DSConfigDN' = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN');
					'CRLPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs');
					'CACertPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs')
				}
			}
			TestScript = { 
				If (($Using:Node.DSConfigDN) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN') -ne $Using:Node.DSConfigDN)) {
					Return $False
				}
				If (($Using:Node.CRLPublicationURLs) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs') -ne $Using:Node.CRLPublicationURLs)) {
					Return $False
				}
				If (($Using:Node.CACertPublicationURLs) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs') -ne $Using:Node.CACertPublicationURLs)) {
					Return $False
				}
				Return $True
			}
			DependsOn = '[Script]InstallSubCACert'
		}
	}
}
