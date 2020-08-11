<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_SUBCA
.Desription
    Builds a Enterprise Subordinate\Issuing CA.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    InstallRSATTools = $true
    CACommonName = 'LABBUILDER.COM Issuing CA'
    CADistinguishedNameSuffix = 'DC=LABBUILDER,DC=COM'
    CRLPublicationURLs = '65:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n79:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n6:http://pki.labbuilder.com/CertEnroll/%3%8%9.crl'
    CACertPublicationURLs = '1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n2:http://pki.labbuilder.com/CertEnroll/%1_%3%4.crt'
    RootCAName = 'SS_ROOTCA'
    RootCACommonName = 'LABBUILDER.COM Root CA'
###################################################################################################>

Configuration MEMBER_SUBCA
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName ActiveDirectoryCSDsc
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName NetworkingDsc

    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword)
        {
            $LocalAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ('Administrator', (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }

        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        # Install the CA Service
        WindowsFeature ADCSCA
        {
            Name   = 'ADCS-Cert-Authority'
            Ensure = 'Present'
        }

        # Install the Web Enrollment Service
        WindowsFeature WebEnrollmentCA
        {
            Name      = 'ADCS-Web-Enrollment'
            Ensure    = 'Present'
            DependsOn = '[WindowsFeature]ADCSCA'
        }

        WindowsFeature InstallWebMgmtService
        {
            Ensure    = 'Present'
            Name      = 'Web-Mgmt-Service'
            DependsOn = '[WindowsFeature]ADCSWebEnrollment'
        }

        if ($InstallRSATTools)
        {
            WindowsFeature RSAT-ManagementTools
            {
                Ensure    = 'Present'
                Name      = 'RSAT-AD-Tools'
                DependsOn = '[WindowsFeature]ADCSCA'
            }
        }

        if ($Node.InstallOnlineResponder)
        {
            # Install the Online Responder Service
            WindowsFeature OnlineResponderCA
            {
                Name      = 'ADCS-Online-Cert'
                Ensure    = 'Present'
                DependsOn = '[WindowsFeature]ADCSCA'
            }
        }

        if ($Node.InstallEnrollmentWebService)
        {
            # Install the Enrollment Web Service/Enrollment Policy Web Service
            WindowsFeature EnrollmentWebSvc
            {
                Name      = 'ADCS-Enroll-Web-Svc'
                Ensure    = 'Present'
                DependsOn = '[WindowsFeature]ADCSCA'
            }

            WindowsFeature EnrollmentWebPol
            {
                Name      = 'ADCS-Enroll-Web-Pol'
                Ensure    = 'Present'
                DependsOn = '[WindowsFeature]WebEnrollmentCA'
            }
        }

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        # Join this Server to the Domain
        Computer JoinDomain
        {
            Name       = $Node.NodeName
            DomainName = $Node.DomainName
            Credential = $DomainAdminCredential
            DependsOn  = '[WaitForAll]DC'
        }

        # Create the CAPolicy.inf file that sets basic parameters for certificate issuance for this CA.
        File CAPolicy
        {
            Ensure          = 'Present'
            DestinationPath = 'C:\Windows\CAPolicy.inf'
            Contents        = "[Version]`r`n Signature= `"$Windows NT$`"`r`n[Certsrv_Server]`r`n RenewalKeyLength=4096`r`n RenewalValidityPeriod=Years`r`n RenewalValidityPeriodUnits=10`r`n AlternateSignatureAlgorithm=1`r`n CNGHashAlgorithm=SHA256`r`n LoadDefaultTemplates=0`r`n"
            Type            = 'File'
            DependsOn       = '[Computer]JoinDomain'
        }

        <#
            Make a CertEnroll folder to put the Root CA certificate into.
            The CA Web Enrollment server would also create this but we need it now.
        #>
        File CertEnrollFolder
        {
            Ensure          = 'Present'
            DestinationPath = 'C:\Windows\System32\CertSrv\CertEnroll'
            Type            = 'Directory'
            DependsOn       = '[File]CAPolicy'
        }

        <#
            Wait for the RootCA Web Enrollment to complete so we can grab the Root CA
            certificate file.
        #>
        WaitForAny RootCA
        {
            ResourceName     = '[ADCSWebEnrollment]ConfigWebEnrollment'
            NodeName         = $Node.RootCAName
            RetryIntervalSec = 30
            RetryCount       = 30
            DependsOn        = '[File]CertEnrollFolder'
        }

        # Download the Root CA certificate file.
        xRemoteFile DownloadRootCACRTFile
        {
            DestinationPath = "C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCAName)_$($Node.RootCACommonName).crt"
            Uri             = "http://$($Node.RootCAName)/CertEnroll/$($Node.RootCAName)_$($Node.RootCACommonName).crt"
            DependsOn       = '[WaitForAny]RootCA'
        }

        # Download the Root CA certificate revocation list.
        xRemoteFile DownloadRootCACRLFile
        {
            DestinationPath = "C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCACommonName).crl"
            Uri             = "http://$($Node.RootCAName)/CertEnroll/$($Node.RootCACommonName).crl"
            DependsOn       = '[xRemoteFile]DownloadRootCACRTFile'
        }

        # Install the Root CA Certificate to the LocalMachine Root Store and DS
        Script InstallRootCACert
        {
            PSDSCRunAsCredential = $DomainAdminCredential
            SetScript            = {
                Write-Verbose -Message "Registering the Root CA Certificate C:\Windows\System32\CertSrv\CertEnroll\$($Using:Node.RootCAName)_$($Using:Node.RootCACommonName).crt in DS..."
                & "$($ENV:SystemRoot)\system32\certutil.exe" -f -dspublish "C:\Windows\System32\CertSrv\CertEnroll\$($Using:Node.RootCAName)_$($Using:Node.RootCACommonName).crt" RootCA
                Write-Verbose -Message "Registering the Root CA CRL C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCACommonName).crl in DS..."
                & "$($ENV:SystemRoot)\system32\certutil.exe" -f -dspublish "C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCACommonName).crl" "$($Using:Node.RootCAName)"
                Write-Verbose -Message "Installing the Root CA Certificate C:\Windows\System32\CertSrv\CertEnroll\$($Using:Node.RootCAName)_$($Using:Node.RootCACommonName).crt..."
                & "$($ENV:SystemRoot)\system32\certutil.exe" -addstore -f root "C:\Windows\System32\CertSrv\CertEnroll\$($Using:Node.RootCAName)_$($Using:Node.RootCACommonName).crt"
                Write-Verbose -Message "Installing the Root CA CRL C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCACommonName).crl..."
                & "$($ENV:SystemRoot)\system32\certutil.exe" -addstore -f root "C:\Windows\System32\CertSrv\CertEnroll\$($Node.RootCACommonName).crl"
            }
            GetScript            = {
                return @{
                    Installed = ((Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object -FilterScript { ($_.Subject -Like "CN=$($Using:Node.RootCACommonName),*") -and ($_.Issuer -Like "CN=$($Using:Node.RootCACommonName),*") } ).Count -EQ 0)
                }
            }
            TestScript           = {
                if ((Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object -FilterScript { ($_.Subject -Like "CN=$($Using:Node.RootCACommonName),*") -and ($_.Issuer -Like "CN=$($Using:Node.RootCACommonName),*") } ).Count -EQ 0)
                {
                    Write-Verbose -Message 'Root CA Certificate Needs to be installed...'
                    return $false
                }
                return $true
            }
            DependsOn            = '[xRemoteFile]DownloadRootCACRTFile'
        }

        <#
            Configure the Sub CA which will create the Certificate REQ file that Root CA will use
            to issue a certificate for this Sub CA.
        #>
        ADCSCertificationAuthority ConfigCA
        {
            Ensure                    = 'Present'
            IsSingleInstance          = 'Yes'
            Credential                = $DomainAdminCredential
            CAType                    = 'EnterpriseSubordinateCA'
            CACommonName              = $Node.CACommonName
            CADistinguishedNameSuffix = $Node.CADistinguishedNameSuffix
            OverwriteExistingCAinDS   = $true
            OutputCertRequestFile     = "c:\windows\system32\certsrv\certenroll\$($Node.NodeName).req"
            CryptoProviderName        = 'RSA#Microsoft Software Key Storage Provider'
            HashAlgorithmName         = 'SHA256'
            KeyLength                 = 2048
            DependsOn                 = '[Script]InstallRootCACert'
        }

        # Configure the Web Enrollment Feature
        ADCSWebEnrollment ConfigWebEnrollment
        {
            Ensure           = 'Present'
            IsSingleInstance = 'Yes'
            Credential       = $LocalAdminCredential
            DependsOn        = '[ADCSCertificationAuthority]ConfigCA'
        }

        # Set the IIS Mime Type to allow the REQ request to be downloaded by the Root CA
        Script SetREQMimeType
        {
            SetScript  = {
                Add-WebConfigurationProperty -PSPath IIS:\ -Filter //staticContent -Name "." -Value @{fileExtension = '.req'; mimeType = 'application/pkcs10' }
            }
            GetScript  = {
                return @{
                    'MimeType' = ((Get-WebConfigurationProperty -Filter "//staticContent/mimeMap[@fileExtension='.req']" -PSPath IIS:\ -Name *).mimeType);
                }
            }
            TestScript = {
                if (-not (Get-WebConfigurationProperty -Filter "//staticContent/mimeMap[@fileExtension='.req']" -PSPath IIS:\ -Name *))
                {
                    # Mime type is not set
                    return $false
                }
                # Mime Type is already set
                return $true
            }
            DependsOn  = '[ADCSWebEnrollment]ConfigWebEnrollment'
        }

        # Wait for the Root CA to have completed issuance of the certificate for this SubCA.
        WaitForAny SubCACer
        {
            ResourceName     = "[Script]IssueCert_$($Node.NodeName)"
            NodeName         = $Node.RootCAName
            RetryIntervalSec = 30
            RetryCount       = 30
            DependsOn        = '[Script]SetREQMimeType'
        }

        # Download the Certificate for this SubCA but rename it so that it'll match the name expected by the CA
        xRemoteFile DownloadSubCACERFile
        {
            DestinationPath = "C:\Windows\System32\CertSrv\CertEnroll\$($Node.NodeName)_$($Node.CACommonName).crt"
            Uri             = "http://$($Node.RootCAName)/CertEnroll/$($Node.NodeName).crt"
            DependsOn       = '[WaitForAny]SubCACer'
        }

        # Register the Sub CA Certificate with the Certification Authority
        Script RegisterSubCA
        {
            PSDSCRunAsCredential = $DomainAdminCredential
            SetScript            = {
                Write-Verbose -Message "Registering the Sub CA Certificate with the Certification Authority C:\Windows\System32\CertSrv\CertEnroll\$($Using:Node.NodeName)_$($Using:Node.CACommonName).crt..."
                & "$($ENV:SystemRoot)\system32\certutil.exe" -installCert "C:\Windows\System32\CertSrv\CertEnroll\$($Using:Node.NodeName)_$($Using:Node.CACommonName).crt"
            }
            GetScript            = {
                return @{
                }
            }
            TestScript           = {
                if (-not (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertHash'))
                {
                    Write-Verbose -Message 'Sub CA Certificate needs to be registered with the Certification Authority...'
                    return $false
                }
                return $true
            }
            DependsOn            = '[xRemoteFile]DownloadSubCACERFile'
        }

        <#
            Perform final configuration of the CA which will cause the CA service to startup
            It should be able to start up once the SubCA certificate has been installed.
        #>
        Script ADCSAdvConfig
        {
            SetScript  = {
                if ($Using:Node.CADistinguishedNameSuffix)
                {
                    & "$($ENV:SystemRoot)\system32\certutil.exe" -setreg CA\DSConfigDN "CN=Configuration,$($Using:Node.CADistinguishedNameSuffix)"
                    & "$($ENV:SystemRoot)\system32\certutil.exe" -setreg CA\DSDomainDN "$($Using:Node.CADistinguishedNameSuffix)"
                }

                if ($Using:Node.CRLPublicationURLs)
                {
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CRLPublicationURLs $($Using:Node.CRLPublicationURLs)
                }

                if ($Using:Node.CACertPublicationURLs)
                {
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CACertPublicationURLs $($Using:Node.CACertPublicationURLs)
                }

                Restart-Service -Name CertSvc
                New-Item -Path 'c:\windows\setup\scripts\' -ItemType Directory -ErrorAction SilentlyContinue
                Add-Content -Path 'c:\windows\setup\scripts\certutil.log' -Value 'Certificate Service Restarted ...'
            }

            GetScript  = {
                return @{
                    'DSConfigDN'            = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN');
                    'DSDomainDN'            = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSDomainDN');
                    'CRLPublicationURLs'    = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs');
                    'CACertPublicationURLs' = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs')
                }
            }

            TestScript = {
                if (((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN') -ne "CN=Configuration,$($Using:Node.CADistinguishedNameSuffix)"))
                {
                    return $false
                }

                if (((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSDomainDN') -ne "$($Using:Node.CADistinguishedNameSuffix)"))
                {
                    return $false
                }

                if (($Using:Node.CRLPublicationURLs) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs') -ne $Using:Node.CRLPublicationURLs))
                {
                    return $false
                }

                if (($Using:Node.CACertPublicationURLs) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs') -ne $Using:Node.CACertPublicationURLs))
                {
                    return $false
                }

                return $true
            }

            DependsOn  = '[Script]RegisterSubCA'
        }

        if ($Node.InstallOnlineResponder)
        {
            # Configure the Online Responder Feature
            ADCSOnlineResponder ConfigOnlineResponder
            {
                Ensure           = 'Present'
                IsSingleInstance = 'Yes'
                Credential       = $LocalAdminCredential
                DependsOn        = '[Script]ADCSAdvConfig'
            }

            # Enable Online Responder FireWall rules so we can remote manage Online Responder
            Firewall OnlineResponderFirewall1
            {
                Name      = 'Microsoft-Windows-OnlineRevocationServices-OcspSvc-DCOM-In'
                Enabled   = 'True'
                DependsOn = '[ADCSOnlineResponder]ConfigOnlineResponder'
            }

            Firewall OnlineResponderirewall2
            {
                Name      = 'Microsoft-Windows-CertificateServices-OcspSvc-RPC-TCP-In'
                Enabled   = 'True'
                DependsOn = '[ADCSOnlineResponder]ConfigOnlineResponder'
            }

            Firewall OnlineResponderFirewall3
            {
                Name      = 'Microsoft-Windows-OnlineRevocationServices-OcspSvc-TCP-Out'
                Enabled   = 'True'
                DependsOn = '[ADCSOnlineResponder]ConfigOnlineResponder'
            }
        }
    }
}
