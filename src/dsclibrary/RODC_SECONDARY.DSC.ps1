<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    RODC_SECONDARY
.Desription
    Builds a Read Only Domain Controller and adds it to the existing domain provided in the Parameter DomainName.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    InstallRSATTools = $true
###################################################################################################>

Configuration RODC_SECONDARY
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion 4.1.0.0

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

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }


        ADDomainController SecondaryDC
        {
            DomainName                    = $Node.DomainName
            Credential                    = $DomainAdminCredential
            SafemodeAdministratorPassword = $LocalAdminCredential
            ReadOnlyReplica               = $true
            DependsOn                     = '[WaitForADDomain]DscDomainWait'
        }
    }
}
