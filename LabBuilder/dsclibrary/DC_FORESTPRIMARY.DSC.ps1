<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    DC_FORESTPRIMARY
.Desription
    Builds a Domain Controller as the first DC in a forest with the name of the Domain Name
    parameter passed.
    Setting optional parameters Forwarders, ADZones and PrimaryZones will allow additional
    configuration of the DNS Server.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    InstallRSATTools = $True
    Forwarders = @('8.8.8.8','8.8.4.4')
    ADZones = @(
        @{ Name = 'ALPHA.LOCAL';
           DynamicUpdate = 'Secure';
           ReplicationScope = 'Forest';
        }
    )
    PrimaryZones = @(
        @{ Name = 'BRAVO.LOCAL';
           ZoneFile = 'bravo.local.dns';
           DynamicUpdate = 'None';
        }
    )
###################################################################################################>

Configuration DC_FORESTPRIMARY
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xDNSServer
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature BackupInstall
        { 
            Ensure = "Present" 
            Name   = "Windows-Server-Backup" 
        } 

        WindowsFeature DNSInstall 
        {
            Ensure = "Present"
            Name   = "DNS"
        }

        WindowsFeature ADDSInstall
        {
            Ensure    = "Present"
            Name      = "AD-Domain-Services"
            DependsOn = "[WindowsFeature]DNSInstall"
        }
        
        WindowsFeature RSAT-AD-PowerShellInstall
        {
            Ensure    = "Present"
            Name      = "RSAT-AD-PowerShell"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        if ($InstallRSATTools)
        {
            WindowsFeature RSAT-ManagementTools
            {
                Ensure    = "Present"
                Name      = "RSAT-AD-Tools","RSAT-DNS-Server"
                DependsOn = "[WindowsFeature]ADDSInstall"
            }
        }

        xADDomain PrimaryDC
        {
            DomainName                    = $Node.DomainName 
            DomainAdministratorCredential = $DomainAdminCredential
            SafemodeAdministratorPassword = $LocalAdminCredential
            DependsOn                     = "[WindowsFeature]ADDSInstall"
        }

        xWaitForADDomain DscForestWait 
        {
            DomainName           = $Node.DomainName 
            DomainUserCredential = $DomainAdminCredential
            RetryCount           = 20
            RetryIntervalSec     = 30
            DependsOn            = "[xADDomain]PrimaryDC"
        }
        
        # Enable AD Recycle bin
        xADRecycleBin RecycleBin
        {
            EnterpriseAdministratorCredential = $DomainAdminCredential
            ForestFQDN                        = $Node.DomainName
            DependsOn                         = "[xWaitForADDomain]DscForestWait"
        }

        # Install a KDS Root Key so we can create MSA/gMSA accounts
        Script CreateKDSRootKey
        {
            SetScript = {
                Add-KDSRootKey -EffectiveTime ((Get-Date).AddHours(-10))            }
            GetScript = {
                Return @{
                    KDSRootKey = (Get-KDSRootKey)
                }
            }
            TestScript = { 
                If (-not (Get-KDSRootKey)) {
                    Write-Verbose -Message "KDS Root Key Needs to be installed..."
                    Return $False
                }
                Return $True
            }
            DependsOn = '[xWaitForADDomain]DscForestWait'
        }

        # DNS Server Settings
        if ($Node.Forwarders)
        {
            xDnsServerForwarder DNSForwarders
            {
                IsSingleInstance = 'Yes'
                IPAddresses      = $Node.Forwarders
                DependsOn        = "[xWaitForADDomain]DscForestWait"
            }
        }
        [Int]$Count=0
        Foreach ($ADZone in $Node.ADZones) {
            $Count++
            xDnsServerADZone "ADZone$Count"
            {
                Ensure           = 'Present'
                Name             = $ADZone.Name
                DynamicUpdate    = $ADZone.DynamicUpdate
                ReplicationScope = $ADZone.ReplicationScope
                DependsOn        = "[xWaitForADDomain]DscForestWait"
            }
        }
        [Int]$Count=0
        Foreach ($PrimaryZone in $Node.PrimaryZones) {
            $Count++
            xDnsServerPrimaryZone "PrimaryZone$Count"
            {
                Ensure        = 'Present'
                Name          = $PrimaryZone.Name
                ZoneFile      = $PrimaryZone.ZoneFile
                DynamicUpdate = $PrimaryZone.DynamicUpdate
                DependsOn        = "[xWaitForADDomain]DscForestWait"
            }
        }
<#
        # Create a Reverse Lookup Zone
        xDnsServerPrimaryZone GlobalNamesZone
        {
            Name = $Node.ReverseZone
            DynamicUpdate = 
            Ensure = 'Present'
            DependsOn = '[xWaitForADDomain]DscForestWait'
        }

        # Create a Global Names zone - can't do this until the resource supports it
        xDnsServerPrimaryZone GlobalNamesZone
        {
            Name = 'GlobalNames'
            DynamicUpdate = 
            Ensure = 'Present'
            DependsOn = '[xWaitForADDomain]DscForestWait'
        }

        # Enable GlobalNames in DNS Server
        Script InstallRootCACert
        {
            PSDSCRunAsCredential = $DomainAdminCredential
            SetScript = {
                Write-Verbose -Message "Enabling Global Name Zone..."
                Set-DNSServerGlobalNameZone -Enable
            }
            GetScript = {
                Return @{
                    Enable = (Get-DNSServerGlobalNameZone).Enable
                }
            }
            TestScript = { 
                If (-not (Get-DNSServerGlobalNameZone).Enable) {
                    Write-Verbose -Message "Global Name Zone needs to be enabled..."
                    Return $False
                }
                Return $True
            }
            DependsOn = '[xDnsServerPrimaryZone]GlobalNamesZone'
        }
#>
    }
}
