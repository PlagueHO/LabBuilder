<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    RODC_SECONDARY
.Desription
    Builds a Read Only Domain Controller and adds it to the existing domain provided in the Parameter DomainName.
    The RODC will not be installed at the moment because the xActiveDirectory DSC Resource does not support RODC.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
    InstallRSATTools = $True
###################################################################################################>

Configuration RODC_SECONDARY
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xActiveDirectory
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
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

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
            ResourceName     = '[xADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

<#
        xADDomainController SecondaryDC
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $DomainAdminCredential
            SafemodeAdministratorPassword = $LocalAdminCredential 
            DependsOn = "[xWaitForADDomain]DscDomainWait"
        }
#>
    }
}
