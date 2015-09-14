<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_SUBCA
.Desription
	Builds a Enterprise Subordinate\Issuing CA.
.Parameters:    
		  DomainName = "LABBUILDER.COM"
		  DomainAdminPassword = "P@ssword!1"
		  PSDscAllowDomainUser = $True
		  CACommonName = "LABBUILDER.COM Issuing CA"
		  CADistinguishedNameSuffix = "DC=LABBUILDER,DC=COM"
		  CRLPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n10:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n2:http://pki.labbuilder.com/CertEnroll/%3%8%9.crl"
		  CACertPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n2:http://pki.labbuilder.com/CertEnroll/%1_%3%4.crt"
          RootCAName = "SS_ROOTCA"
          RootCACommonName = "LABBUILDER.COM Root CA"
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

		# Install the RSAT PowerShell Module which is required by the xWaitForResource
		WindowsFeature RSATADPowerShell
		{ 
			Ensure = "Present" 
			Name = "RSAT-AD-PowerShell" 
		} 

		# Install the CA Service
		WindowsFeature ADCSCA {
			Name = 'ADCS-Cert-Authority'
			Ensure = 'Present'
			DependsOn = "[WindowsFeature]RSATADPowerShell" 
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
			DestinationPath = "C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCAName)_$($Node.RootCACommonName).crt"
			Uri = "http://$($Node.RootCAName)/CertEnroll/$($Node.RootCAName)_$($Node.RootCACommonName).crt"
			DependsOn = '[WaitForAny]RootCA'
		}

		# Download the Root CA certificate revocation list.
		xRemoteFile DownloadRootCACRLFile
		{
			DestinationPath = "C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCACommonName).crl"
			Uri = "http://$($Node.RootCAName)/CertEnroll/$($Node.RootCACommonName).crl"
			DependsOn = '[xRemoteFile]DownloadRootCACRTFile'
		}

		# Configure the Sub CA which will create the Certificate REQ file that Root CA will use
		# to issue a certificate for this Sub CA.
		xADCSCertificationAuthority ConfigCA
		{
			Ensure = 'Present'
			Credential = $DomainAdminCredential
			CAType = 'EnterpriseSubordinateCA'
			CACommonName = $Node.CACommonName
			CADistinguishedNameSuffix = $Node.CADistinguishedNameSuffix
			OverwriteExistingCAinDS  = $True
			OutputCertRequestFile = "c:\windows\system32\certsrv\certenroll\$($Node.NodeName).req"
			DependsOn = '[xRemoteFile]DownloadRootCACRLFile'
		}

		# Configure the Web Enrollment Feature
		xADCSWebEnrollment ConfigWebEnrollment {
			Ensure = 'Present'
			Name = 'ConfigWebEnrollment'
			Credential = $LocalAdminCredential
			DependsOn = '[xADCSCertificationAuthority]ConfigCA'
		}

		# Set the IIS Mime Type to allow the REQ request to be downloaded by the Root CA
		Script SetREQMimeType
		{
			SetScript = {
				Add-WebConfigurationProperty -PSPath IIS:\ -Filter //staticContent -Name "." -Value @{fileExtension='.req';mimeType='application/pkcs10'}
			}
			GetScript = {
				Return @{
					'MimeType' = ((Get-WebConfigurationProperty -Filter "//staticContent/mimeMap[@fileExtension='.req']" -PSPath IIS:\ -Name *).mimeType);
				}
			}
			TestScript = { 
				If (-not (Get-WebConfigurationProperty -Filter "//staticContent/mimeMap[@fileExtension='.req']" -PSPath IIS:\ -Name *)) {
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
			DependsOn = "[Script]SetREQMimeType"
		}

		# Download the Certificate for this SubCA but rename it so that it'll match the name expected by the CA
		xRemoteFile DownloadSubCACERFile
		{
			DestinationPath = "C:\Windows\System32\CertSrv\CertEnroll\$($Node.NodeName)_$($Node.CACommonName).crt"
			Uri = "http://$($Node.RootCAName)/CertEnroll/$($Node.NodeName).crt"
			DependsOn = '[WaitForAny]SubCACer'
		}

		# Install the Sub CA Certificate to the LocalMachine CA Store
		Script InstallSubCACert
		{
			SetScript = {
				Write-Verbose "Installing the Sub CA Certificate..."
				Import-Certificate -FilePath "C:\Windows\System32\CertSrv\CertEnroll\$($Node.NodeName)_$($Node.CACommonName).crt" -CertStoreLocation cert:\LocalMachine\CA\
			}
			GetScript = {
				Return @{
				}
			}
			TestScript = { 
				If ((Get-ChildItem -Path Cert:\LocalMachine\CA | Where-Object -FilterScript { ($_.Subject -Like "CN=$($Using:Node.CACommonName),*") -and ($_.Issuer -Like "CN=$($Using:Node.RootCACommonName),*") } ).Count -EQ 0) {
					Write-Verbose "Sub CA Certificate Needs to be installed..."
					Return $False
				}
				Return $True
			}
			DependsOn = '[xRemoteFile]DownloadSubCACERFile'
		}

		# Install the Root CA Certificate to the LocalMachine Root Store
		Script InstallRootCACert
		{
			SetScript = {
				Write-Verbose "Installing the Root CA Certificate..."
				Import-Certificate -FilePath "C:\Windows\System32\CertSrv\CertEnroll\$($Using:Node.RootCAName)_$($Using:Node.RootCACommonName).crt" -CertStoreLocation cert:\LocalMachine\Root\
			}
			GetScript = {
				Return @{
				}
			}
			TestScript = { 
				If ((Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object -FilterScript { ($_.Subject -Like "CN=$($Using:Node.RootCACommonName),*") -and ($_.Issuer -Like "CN=$($Using:Node.RootCACommonName),*") } ).Count -EQ 0) {
					Write-Verbose "Root CA Certificate Needs to be installed..."
					Return $False
				}
				Return $True
			}
			DependsOn = '[Script]InstallSubCACert'
		}

		# Register the Sub CA Certificate with the Certification Authority
		Script RegisterSubCA
		{
			SetScript = {
				Write-Verbose "Registering the Sub CA Certificate with the Certification Authority..."
				& "$($ENV:SystemRoot)\system32\certutil.exe" -installCert "C:\Windows\System32\CertSrv\CertEnroll\$($Node.NodeName)_$($Node.CACommonName).crt"
			}
			GetScript = {
				Return @{
				}
			}
			TestScript = { 
				If (-not (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertHash')) {
					Write-Verbose "Sub CA Certificate needs to be registered with the Certification Authority..."
					Return $False
				}
				Return $True
			}
			DependsOn = '[Script]InstallRootCACert'
		}

		# Perform final configuration of the CA which will cause the CA service to startup
		# It should be able to start up once the SubCA certificate has been installed.
		Script ADCSAdvConfig
		{
			SetScript = {
				If ($Using:Node.CADistinguishedNameSuffix) {
					& "$($ENV:SystemRoot)\system32\certutil.exe" -setreg CA\DSConfigDN "CN=Configuration,$($Using:Node.CADistinguishedNameSuffix)"
				}
				If ($Using:Node.CADistinguishedNameSuffix) {
					& "$($ENV:SystemRoot)\system32\certutil.exe" -setreg CA\DSDomainDN "$($Using:Node.CADistinguishedNameSuffix)"
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
					'DSDomainDN' = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSDomainDN');
					'CRLPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs');
					'CACertPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs')
				}
			}
			TestScript = { 
				If (((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN') -ne "CN=Configuration,$($Using:Node.CADistinguishedNameSuffix)")) {
					Return $False
				}
				If (((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSDomainDN') -ne "$($Using:Node.CADistinguishedNameSuffix)")) {
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
			DependsOn = '[Script]RegisterSubCA'
		}
		
		# Configure the Online Responder Feature
		xADCSOnlineResponder ConfigOnlineResponder {
			Ensure = 'Present'
			Name = 'ConfigOnlineResponder'
			Credential = $LocalAdminCredential
			DependsOn = '[Script]ADCSAdvConfig'
		}

	}
}
