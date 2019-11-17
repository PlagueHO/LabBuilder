<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    DC_SECONDARY
.Desription
    Builds a Domain Controller and adds it to the existing domain provided in the Parameter
    DomainName.
    Setting optional parameters Forwarders, ADZones and PrimaryZones will allow additional
    configuration of the DNS Server.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    PSDscAllowDomainUser = $true
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

Configuration DC_SECONDARY
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
                -ArgumentName ('Administrator', (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }

        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentName ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
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

        WaitForADDomain DscDomainWait
        {
            DomainName   = $Node.DomainName
            Credential   = $DomainAdminCredential
            WaitTimeout  = 300
            RestartCount = 5
            DependsOn    = '[WindowsFeature]ADDSInstall'
        }

        ADDomainController SecondaryDC
        {
            DomainName                    = $Node.DomainName
            Credential                    = $DomainAdminCredential
            SafemodeAdministratorPassword = $LocalAdminCredential
            DependsOn                     = '[WaitForADDomain]DscDomainWait'
        }

        # DNS Server Settings
        if ($Node.Forwarders)
        {
            xDnsServerForwarder DNSForwarders
            {
                IsSingleInstance = 'Yes'
                IPAddresses      = $Node.Forwarders
                DependsOn        = '[ADDomainController]SecondaryDC'
            }
        }
        [System.Int32]$count = 0
        foreach ($ADZone in $Node.ADZones)
        {
            $count++
            xDnsServerADZone "ADZone$count"
            {
                Ensure           = 'Present'
                Name             = $ADZone.Name
                DynamicUpdate    = $ADZone.DynamicUpdate
                ReplicationScope = $ADZone.ReplicationScope
                DependsOn        = '[ADDomainController]SecondaryDC'
            }
        }
        [System.Int32]$count = 0
        foreach ($PrimaryZone in $Node.PrimaryZones)
        {
            $count++
            xDnsServerPrimaryZone "PrimaryZone$count"
            {
                Ensure        = 'Present'
                Name          = $PrimaryZone.Name
                ZoneFile      = $PrimaryZone.ZoneFile
                DynamicUpdate = $PrimaryZone.DynamicUpdate
                DependsOn     = '[ADDomainController]SecondaryDC'
            }
        }
    }
}
