<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    DC_FORESTCHILDDOMAIN
.Desription
    Builds a Domain Controller and creates it as the first DC in a new child domain within the
    existing forest specified in the DomainName parameter.
    Setting optional parameters Forwarders, ADZones and PrimaryZones will allow additional
    configuration of the DNS Server.
.Parameters:
    ParentDomainName = "LABBUILDER.COM"
    DomainName = "DEV"
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

Configuration DC_FORESTCHILDDOMAIN
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion 4.1.0.0
    Import-DscResource -ModuleName xDNSServer

    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword)
        {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        if ($Node.DomainAdminPassword)
        {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.ParentDomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
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
                Name      = "RSAT-AD-Tools", "RSAT-DNS-Server"
                DependsOn = "[WindowsFeature]ADDSInstall"
            }
        }

        WaitForADDomain DscDomainWait
        {
            DomainName           = $Node.ParentDomainName
            Credential           = $DomainAdminCredential
            WaitTimeout          = 300
            RestartCount         = 5
            DependsOn            = "[WindowsFeature]ADDSInstall"
        }

        ADDomain PrimaryDC
        {
            DomainName                    = $Node.DomainName
            ParentDomainName              = $Node.ParentDomainName
            Credential                    = $DomainAdminCredential
            SafemodeAdministratorPassword = $LocalAdminCredential
            DependsOn                     = "[WaitForADDomain]DscDomainWait"
        }

        # DNS Server Settings
        if ($Node.Forwarders)
        {
            xDnsServerForwarder DNSForwarders
            {
                IsSingleInstance = 'Yes'
                IPAddresses      = $Node.Forwarders
                DependsOn        = "[ADDomain]PrimaryDC"
            }
        }
        $Count=0
        foreach ($ADZone in $Node.ADZones)
        {
            $Count++
            xDnsServerADZone "ADZone$Count"
            {
                Ensure           = 'Present'
                Name             = $ADZone.Name
                DynamicUpdate    = $ADZone.DynamicUpdate
                ReplicationScope = $ADZone.ReplicationScope
                DependsOn        = "[ADDomain]PrimaryDC"
            }
        }
        $Count=0
        foreach ($PrimaryZone in $Node.PrimaryZones)
        {
            $Count++
            xDnsServerPrimaryZone "PrimaryZone$Count"
            {
                Ensure        = 'Present'
                Name          = $PrimaryZone.Name
                ZoneFile      = $PrimaryZone.ZoneFile
                DynamicUpdate = $PrimaryZone.DynamicUpdate
                DependsOn     = "[ADDomain]PrimaryDC"
            }
        }
    }
}
