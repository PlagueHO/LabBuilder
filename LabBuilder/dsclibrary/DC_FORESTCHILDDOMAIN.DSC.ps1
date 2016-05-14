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
    PSDscAllowDomainUser = $True
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

Configuration DC_FORESTCHILDDOMAIN
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
                Name      = "RSAT-AD-Tools","RSAT-DNS-Server"
                DependsOn = "[WindowsFeature]ADDSInstall"
            }
        }

        xWaitForADDomain DscDomainWait
        {
            DomainName           = $Node.ParentDomainName
            DomainUserCredential = $DomainAdminCredential
            RetryCount           = 100
            RetryIntervalSec     = 10
            DependsOn            = "[WindowsFeature]ADDSInstall"
        }
        
        xADDomain PrimaryDC 
        { 
            DomainName                    = $Node.DomainName
            ParentDomainName              = $Node.ParentDomainName
            DomainAdministratorCredential = $DomainAdminCredential
            SafemodeAdministratorPassword = $LocalAdminCredential
            DependsOn                     = "[xWaitForADDomain]DscDomainWait"
        }

        # DNS Server Settings
        if ($Node.Forwarders)
        {
            xDnsServerForwarder DNSForwarders
            {
                IsSingleInstance = 'Yes'
                IPAddresses      = $Node.Forwarders
                DependsOn        = "[xADDomain]PrimaryDC"
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
                DependsOn        = "[xADDomain]PrimaryDC"
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
                DependsOn     = "[xADDomain]PrimaryDC"
            }
        }
    }
}
