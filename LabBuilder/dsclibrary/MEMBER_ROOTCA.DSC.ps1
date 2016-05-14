<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_ROOTCA
.Desription
    Builds an Enterprise Root CA.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
    InstallRSATTools = $True
    CACommonName = "LABBUILDER.COM Root CA"
    CADistinguishedNameSuffix = "DC=LABBUILDER,DC=COM"
    CRLPublicationURLs = "65:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n79:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n6:http://pki.labbuilder.com/CertEnroll/%3%8%9.crl"
    CACertPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n2:http://pki.labbuilder.com/CertEnroll/%1_%3%4.crt"
    CRLPeriodUnits = 52
    CRLPeriod = 'Weeks'
    CRLOverlapUnits = 12
    CRLOverlapPeriod = 'Hours'
    ValidityPeriodUnits = 10
    ValidityPeriod = 'Years'
    AuditFilter = 127
###################################################################################################>

Configuration MEMBER_ROOTCA
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xAdcsDeployment
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName xNetworking
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
        WindowsFeature ADCSWebEnrollment {
            Name = 'ADCS-Web-Enrollment'
            Ensure = 'Present'
            DependsOn = "[WindowsFeature]ADCSCA"
        }

        WindowsFeature InstallWebMgmtService
        {
            Ensure = "Present" 
            Name = "Web-Mgmt-Service" 
            DependsOn = '[WindowsFeature]ADCSWebEnrollment'
        }

        if ($InstallRSATTools)
        {
            WindowsFeature RSAT-ManagementTools
            {
                Ensure    = "Present"
                Name      = "RSAT-AD-Tools"
                DependsOn = "[WindowsFeature]ADCSCA"
            }
        }

        if ($Node.InstallOnlineResponder) {
            # Install the Online Responder Service
            WindowsFeature OnlineResponderCA {
                Name = 'ADCS-Online-Cert'
                Ensure = 'Present'
                DependsOn = "[WindowsFeature]ADCSCA"
            }
        }

        if ($Node.InstallEnrollmentWebService) {
            # Install the Enrollment Web Service/Enrollment Policy Web Service
            WindowsFeature EnrollmentWebSvc {
                Name = 'ADCS-Enroll-Web-Svc'
                Ensure = 'Present'
                DependsOn = "[WindowsFeature]ADCSCA"
            }

            WindowsFeature EnrollmentWebPol {
                Name = 'ADCS-Enroll-Web-Pol'
                Ensure = 'Present'
                DependsOn = "[WindowsFeature]ADCSCA"
            }
        }

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
        ResourceName      = '[xADDomain]PrimaryDC'
        NodeName          = $Node.DCname
        RetryIntervalSec  = 15
        RetryCount        = 60
        }
        
        # Join this Server to the Domain
        xComputer JoinDomain 
        { 
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential 
            DependsOn = "[WaitForAll]DC" 
        }
            
        # Create the CAPolicy.inf file that sets basic parameters for certificate issuance for this CA.
        File CAPolicy
        {
            Ensure = 'Present'
            DestinationPath = 'C:\Windows\CAPolicy.inf'
            Contents = "[Version]`r`n Signature= `"$Windows NT$`"`r`n[Certsrv_Server]`r`n DiscreteSignatureAlgorithm=1`r`n HashAlgorithm=RSASHA256`r`n RenewalKeyLength=4096`r`n RenewalValidityPeriod=Years`r`n RenewalValidityPeriodUnits=20`r`n CRLDeltaPeriod=Days`r`n CRLDeltaPeriodUnits=0`r`n[CRLDistributionPoint]`r`n[AuthorityInformationAccess]`r`n"
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

        # Configure the Root CA which will create the Certificate REQ file that Root CA will use
        # to issue a certificate for this Sub CA.
        xADCSCertificationAuthority ConfigCA
        {
            Ensure = 'Present'
            Credential = $DomainAdminCredential
            CAType = 'EnterpriseRootCA'
            CACommonName = $Node.CACommonName
            CADistinguishedNameSuffix = $Node.CADistinguishedNameSuffix
            OverwriteExistingCAinDS  = $True
            CryptoProviderName = 'RSA#Microsoft Software Key Storage Provider'
            HashAlgorithmName = 'SHA256'
            KeyLength = 4096
            DependsOn = '[File]CertEnrollFolder'
        }
        
        # Configure the Web Enrollment Feature
        xADCSWebEnrollment ConfigWebEnrollment {
            Ensure = 'Present'
            Name = 'ConfigWebEnrollment'
            Credential = $LocalAdminCredential
            DependsOn = '[xADCSCertificationAuthority]ConfigCA'
        }

        # Perform final configuration of the CA which will cause the CA service to startup
        # Set the advanced CA properties
        Script ADCSAdvConfig
        {
            SetScript = {
                If ($Using:Node.CADistinguishedNameSuffix) {
                    & "$($ENV:SystemRoot)\system32\certutil.exe" -setreg CA\DSConfigDN "CN=Configuration,$($Using:Node.CADistinguishedNameSuffix)"
                    & "$($ENV:SystemRoot)\system32\certutil.exe" -setreg CA\DSDomainDN "$($Using:Node.CADistinguishedNameSuffix)"
                }
                If ($Using:Node.CRLPublicationURLs) {
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CRLPublicationURLs $($Using:Node.CRLPublicationURLs)
                }
                If ($Using:Node.CACertPublicationURLs) {
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CACertPublicationURLs $($Using:Node.CACertPublicationURLs)
                }
                If ($Using:Node.CRLPeriodUnits) {
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CRLPeriodUnits $($Using:Node.CRLPeriodUnits)
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CRLPeriod "$($Using:Node.CRLPeriod)"
                }
                If ($Using:Node.CRLOverlapUnits) {
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CRLOverlapUnits $($Using:Node.CRLOverlapUnits)
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CRLOverlapPeriod "$($Using:Node.CRLOverlapPeriod)"
                }
                If ($Using:Node.ValidityPeriodUnits) {
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\ValidityPeriodUnits $($Using:Node.ValidityPeriodUnits)
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\ValidityPeriod "$($Using:Node.ValidityPeriod)"
                }
                If ($Using:Node.AuditFilter) {
                    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\AuditFilter $($Using:Node.AuditFilter)
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
                    'CRLPeriodUnits'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPeriodUnits')
                    'CRLPeriod'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPeriod')
                    'CRLOverlapUnits'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLOverlapUnits')
                    'CRLOverlapPeriod'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLOverlapPeriod')
                    'ValidityPeriodUnits'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('ValidityPeriodUnits')
                    'ValidityPeriod'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('ValidityPeriod')
                    'AuditFilter'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('AuditFilter')
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
                If (($Using:Node.CRLPeriodUnits) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPeriodUnits') -ne $Using:Node.CRLPeriodUnits)) {
                    Return $False
                }
                If (($Using:Node.CRLPeriod) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPeriod') -ne $Using:Node.CRLPeriod)) {
                    Return $False
                }
                If (($Using:Node.CRLOverlapUnits) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLOverlapUnits') -ne $Using:Node.CRLOverlapUnits)) {
                    Return $False
                }
                If (($Using:Node.CRLOverlapPeriod) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLOverlapPeriod') -ne $Using:Node.CRLOverlapPeriod)) {
                    Return $False
                }
                If (($Using:Node.ValidityPeriodUnits) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('ValidityPeriodUnits') -ne $Using:Node.ValidityPeriodUnits)) {
                    Return $False
                }
                If (($Using:Node.ValidityPeriod) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('ValidityPeriod') -ne $Using:Node.ValidityPeriod)) {
                    Return $False
                }
                If (($Using:Node.AuditFilter) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('AuditFilter') -ne $Using:Node.AuditFilter)) {
                    Return $False
                }
                Return $True
            }
            DependsOn = '[xADCSWebEnrollment]ConfigWebEnrollment'
        }
        
        if ($Node.InstallOnlineResponder) {
            # Configure the Online Responder Feature
            xADCSOnlineResponder ConfigOnlineResponder {
                Ensure = 'Present'
                IsSingleInstance  = 'Yes'
                Credential = $LocalAdminCredential
                DependsOn = '[Script]ADCSAdvConfig'
            }

            # Enable Online Responder FireWall rules so we can remote manage Online Responder
            xFirewall OnlineResponderFirewall1
            {
                Name = "Microsoft-Windows-OnlineRevocationServices-OcspSvc-DCOM-In"
                Enabled = "True"
                DependsOn = "[xADCSOnlineResponder]ConfigOnlineResponder" 
            }

            xFirewall OnlineResponderirewall2
            {
                Name = "Microsoft-Windows-CertificateServices-OcspSvc-RPC-TCP-In"
                Enabled = "True"
                DependsOn = "[xADCSOnlineResponder]ConfigOnlineResponder" 
            }

            xFirewall OnlineResponderFirewall3
            {
                Name = "Microsoft-Windows-OnlineRevocationServices-OcspSvc-TCP-Out"
                Enabled = "True"
                DependsOn = "[xADCSOnlineResponder]ConfigOnlineResponder" 
            }
        }
    }
}
