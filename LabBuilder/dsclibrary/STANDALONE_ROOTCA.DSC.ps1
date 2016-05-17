<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    STANDALONE_ROOTCA
.Desription
    Builds a Standalone Root CA and creates Issuing CA certificates for Sub CAs.
.Parameters:    
            CACommonName = "LABBUILDER.COM Root CA"
            CADistinguishedNameSuffix = "DC=LABBUILDER,DC=COM"
            CRLPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n10:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n2:http://pki.labbuilder.com/CertEnroll/%3%8%9.crl"
            CACertPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n2:http://pki.labbuilder.com/CertEnroll/%1_%3%4.crt"
            CRLPeriodUnits = 52
            CRLPeriod = 'Weeks'
            CRLOverlapUnits = 12
            CRLOverlapPeriod = 'Hours'
            ValidityPeriodUnits = 10
            ValidityPeriod = 'Years'
            AuditFilter = 127
            SubCAs = @('SA_SUBCA')
###################################################################################################>

Configuration STANDALONE_ROOTCA
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xAdcsDeployment
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }

        # Install the ADCS Certificate Authority
        WindowsFeature ADCSCA {
            Name = 'ADCS-Cert-Authority'
            Ensure = 'Present'
        }

        # Install ADCS Web Enrollment - only required because it creates the CertEnroll virtual folder
        # Which we use to pass certificates to the Issuing/Sub CAs       
        WindowsFeature ADCSWebEnrollment
        {
            Ensure = 'Present'
            Name = 'ADCS-Web-Enrollment'
            DependsOn = '[WindowsFeature]ADCSCA'
        }

        WindowsFeature InstallWebMgmtService
        {
            Ensure = "Present" 
            Name = "Web-Mgmt-Service" 
            DependsOn = '[WindowsFeature]ADCSWebEnrollment'
        }

        # Create the CAPolicy.inf file which defines basic properties about the ROOT CA certificate
        File CAPolicy
        {
            Ensure = 'Present'
            DestinationPath = 'C:\Windows\CAPolicy.inf'
            Contents = "[Version]`r`n Signature= `"$Windows NT$`"`r`n[Certsrv_Server]`r`n DiscreteSignatureAlgorithm=1`r`n HashAlgorithm=RSASHA256`r`n RenewalKeyLength=4096`r`n RenewalValidityPeriod=Years`r`n RenewalValidityPeriodUnits=20`r`n CRLDeltaPeriod=Days`r`n CRLDeltaPeriodUnits=0`r`n[CRLDistributionPoint]`r`n[AuthorityInformationAccess]`r`n"
            Type = 'File'
            DependsOn = '[WindowsFeature]ADCSCA'
        }

        # Configure the CA as Standalone Root CA
        xADCSCertificationAuthority ConfigCA
        {
            Ensure = 'Present'
            Credential = $LocalAdminCredential
            CAType = 'StandaloneRootCA'
            CACommonName = $Node.CACommonName
            CADistinguishedNameSuffix = $Node.CADistinguishedNameSuffix
            ValidityPeriod = 'Years'
            ValidityPeriodUnits = 20
            CryptoProviderName = 'RSA#Microsoft Software Key Storage Provider'
            HashAlgorithmName = 'SHA256'
            KeyLength = 4096
            DependsOn = '[File]CAPolicy'
        }

        # Configure the ADCS Web Enrollment
        xADCSWebEnrollment ConfigWebEnrollment {
            Ensure = 'Present'
            Name = 'ConfigWebEnrollment'
            Credential = $LocalAdminCredential
            DependsOn = '[xADCSCertificationAuthority]ConfigCA'
        }

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

        # Generate Issuing certificates for any SubCAs
        Foreach ($SubCA in $Node.SubCAs) {
            
            # Wait for SubCA to generate REQ
            WaitForAny "WaitForSubCA_$SubCA"
            {
                ResourceName = '[xADCSCertificationAuthority]ConfigCA'
                NodeName = $SubCA
                RetryIntervalSec = 30
                RetryCount = 30
                DependsOn = '[Script]ADCSAdvConfig'
            }

            # Download the REQ from the SubCA
            xRemoteFile "DownloadSubCA_$SubCA"
            {
                DestinationPath = "C:\Windows\System32\CertSrv\CertEnroll\$SubCA.req"
                Uri = "http://$SubCA/CertEnroll/$SubCA.req"
                DependsOn = "[WaitForAny]WaitForSubCA_$SubCA"
            }

            # Generate the Issuing Certificate from the REQ
            Script "IssueCert_$SubCA"
            {
                SetScript = {
                    Write-Verbose -Message "Submitting C:\Windows\System32\CertSrv\CertEnroll\$Using:SubCA.req to $($Using:Node.CACommonName)"
                    [String]$RequestResult = & "$($ENV:SystemRoot)\System32\Certreq.exe" -Config ".\$($Using:Node.CACommonName)" -Submit "C:\Windows\System32\CertSrv\CertEnroll\$Using:SubCA.req"
                    $Matches = [Regex]::Match($RequestResult, 'RequestId:\s([0-9]*)')
                    If ($Matches.Groups.Count -lt 2) {
                        Write-Verbose -Message "Error getting Request ID from SubCA certificate submission."
                        Throw "Error getting Request ID from SubCA certificate submission."
                    }
                    [int]$RequestId = $Matches.Groups[1].Value
                    Write-Verbose -Message "Issuing $RequestId in $($Using:Node.CACommonName)"
                    [String]$SubmitResult = & "$($ENV:SystemRoot)\System32\CertUtil.exe" -Resubmit $RequestId
                    If ($SubmitResult -notlike 'Certificate issued.*') {
                        Write-Verbose -Message "Unexpected result issuing SubCA request."
                        Throw "Unexpected result issuing SubCA request."
                    }
                    Write-Verbose -Message "Retrieving C:\Windows\System32\CertSrv\CertEnroll\$Using:SubCA.req from $($Using:Node.CACommonName)"
                    [String]$RetrieveResult = & "$($ENV:SystemRoot)\System32\Certreq.exe" -Config ".\$($Using:Node.CACommonName)" -Retrieve $RequestId "C:\Windows\System32\CertSrv\CertEnroll\$Using:SubCA.crt"
                }
                GetScript = {
                    Return @{
                        'Generated' = (Test-Path -Path "C:\Windows\System32\CertSrv\CertEnroll\$Using:SubCA.crt");
                    }
                }
                TestScript = { 
                    If (-not (Test-Path -Path "C:\Windows\System32\CertSrv\CertEnroll\$Using:SubCA.crt")) {
                        # SubCA Cert is not yet created
                        Return $False
                    }
                    # SubCA Cert has been created
                    Return $True
                }
                DependsOn = "[xRemoteFile]DownloadSubCA_$SubCA"
            }

            # Wait for SubCA to install the CA Certificate
            WaitForAny "WaitForComplete_$SubCA"
            {
                ResourceName = '[Script]InstallSubCACert'
                NodeName = $SubCA
                RetryIntervalSec = 30
                RetryCount = 30
                DependsOn = "[Script]IssueCert_$SubCA"
            }

            # Shutdown the Root CA - it is no longer needed because it has issued all SubCAs
            Script ShutdownRootCA
            {
                SetScript = {
                    Stop-Computer
                }
                GetScript = {
                    Return @{
                    }
                }
                TestScript = { 
                    # SubCA Cert is not yet created
                    Return $False
                }
                DependsOn = "[WaitForAny]WaitForComplete_$SubCA"
            }
        }
    }
}
