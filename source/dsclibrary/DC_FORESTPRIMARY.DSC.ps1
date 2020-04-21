<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    DC_FORESTPRIMARY
.Desription
    Builds a Domain Controller as the first DC in a forest with the name of the Domain Name
    parameter passed.
    The optional parameter DomainNetBiosName can be used to set the NetBios name of the domain
    if it needs to be different from the DomainName.
    Setting optional parameters Forwarders, ADZones and PrimaryZones will allow additional
    configuration of the DNS Server.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainNetBiosName = 'LABBUILDER'
    DomainAdminPassword = 'P@ssword!1'
    InstallRSATTools = $true
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
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion 4.1.0.0
    Import-DscResource -ModuleName xDNSServer -ModuleVersion 1.16.0.0

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
                -ArgumentList ('Administrator', (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature BackupInstall
        {
            Ensure = 'Present'
            Name   = 'Windows-Server-Backup'
        }

        WindowsFeature DNSInstall
        {
            Ensure = 'Present'
            Name   = 'DNS'
        }

        WindowsFeature ADDSInstall
        {
            Ensure    = 'Present'
            Name      = 'AD-Domain-Services'
            DependsOn = '[WindowsFeature]DNSInstall'
        }

        WindowsFeature RSAT-AD-PowerShellInstall
        {
            Ensure    = 'Present'
            Name      = 'RSAT-AD-PowerShell'
            DependsOn = '[WindowsFeature]ADDSInstall'
        }

        if ($InstallRSATTools)
        {
            WindowsFeature RSAT-ManagementTools
            {
                Ensure    = 'Present'
                Name      = 'RSAT-AD-Tools', 'RSAT-DNS-Server'
                DependsOn = '[WindowsFeature]ADDSInstall'
            }
        }

        if ($Node.DomainNetBiosName)
        {
            ADDomain PrimaryDC
            {
                DomainName                    = $Node.DomainName
                DomainNetBiosName             = $Node.DomainNetBiosName
                Credential                    = $DomainAdminCredential
                SafemodeAdministratorPassword = $LocalAdminCredential
                DependsOn                     = '[WindowsFeature]ADDSInstall'
            }
        }
        else
        {
            ADDomain PrimaryDC
            {
                DomainName                    = $Node.DomainName
                Credential                    = $DomainAdminCredential
                SafemodeAdministratorPassword = $LocalAdminCredential
                DependsOn                     = '[WindowsFeature]ADDSInstall'
            }
        }

        WaitForADDomain DscDomainWait
        {
            DomainName   = $Node.DomainName
            Credential   = $DomainAdminCredential
            WaitTimeout  = 300
            RestartCount = 5
            DependsOn    = '[ADDomain]PrimaryDC'
        }

        # Enable AD Recycle bin
        ADOptionalFeature RecycleBin
        {
            FeatureName                       = 'Recycle Bin Feature'
            EnterpriseAdministratorCredential = $DomainAdminCredential
            ForestFQDN                        = $Node.DomainName
            DependsOn                         = '[WaitForADDomain]DscDomainWait'
        }

        # Install a KDS Root Key so we can create MSA/gMSA accounts
        Script CreateKDSRootKey
        {
            SetScript  = {
                Add-KDSRootKey -EffectiveTime ((Get-Date).AddHours(-10)) }
            GetScript  = {
                Return @{
                    KDSRootKey = (Get-KDSRootKey)
                }
            }
            TestScript = {
                if (-not (Get-KDSRootKey))
                {
                    Write-Verbose -Message 'KDS Root Key Needs to be installed...'
                    Return $false
                }
                Return $true
            }
            DependsOn  = '[WaitForADDomain]DscDomainWait'
        }

        # DNS Server Settings
        if ($Node.Forwarders)
        {
            xDnsServerForwarder DNSForwarders
            {
                IsSingleInstance = 'Yes'
                IPAddresses      = $Node.Forwarders
                DependsOn        = '[WaitForADDomain]DscDomainWait'
            }
        }

        $count = 0
        foreach ($ADZone in $Node.ADZones)
        {
            $count++
            xDnsServerADZone "ADZone$count"
            {
                Ensure           = 'Present'
                Name             = $ADZone.Name
                DynamicUpdate    = $ADZone.DynamicUpdate
                ReplicationScope = $ADZone.ReplicationScope
                DependsOn        = '[WaitForADDomain]DscDomainWait'
            }
        }

        $count = 0
        foreach ($PrimaryZone in $Node.PrimaryZones)
        {
            $count++
            xDnsServerPrimaryZone "PrimaryZone$count"
            {
                Ensure        = 'Present'
                Name          = $PrimaryZone.Name
                ZoneFile      = $PrimaryZone.ZoneFile
                DynamicUpdate = $PrimaryZone.DynamicUpdate
                DependsOn     = '[WaitForADDomain]DscDomainWait'
            }
        }

        <#
        # Create a Reverse Lookup Zone
        xDnsServerPrimaryZone GlobalNamesZone
        {
            Name = $Node.ReverseZone
            DynamicUpdate =
            Ensure = 'Present'
            DependsOn = '[WaitForADDomain]DscDomainWait'
        }

        # Create a Global Names zone - can't do this until the resource supports it
        xDnsServerPrimaryZone GlobalNamesZone
        {
            Name = 'GlobalNames'
            DynamicUpdate =
            Ensure = 'Present'
            DependsOn = '[WaitForADDomain]DscDomainWait'
        }

        # Enable GlobalNames in DNS Server
        Script InstallRootCACert
        {
            PSDSCRunAsCredential = $DomainAdminCredential
            SetScript = {
                Write-Verbose -Message 'Enabling Global Name Zone...'
                Set-DNSServerGlobalNameZone -Enable
            }
            GetScript = {
                Return @{
                    Enable = (Get-DNSServerGlobalNameZone).Enable
                }
            }
            TestScript = {
                if (-not (Get-DNSServerGlobalNameZone).Enable) {
                    Write-Verbose -Message 'Global Name Zone needs to be enabled...'
                    Return $false
                }
                Return $true
            }
            DependsOn = '[xDnsServerPrimaryZone]GlobalNamesZone'
        }
#>
    }
}
