<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_WSUS
.Desription
    Builds a Server that is joined to a domain and then installs WSUS components.
    Requires cMicrosoftUpdate resource from https://github.com/fabiendibot/cMicrosoftUpdate
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
###################################################################################################>

Configuration MEMBER_WSUS
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName StorageDsc

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

        WindowsFeature UpdateServicesWIDDBInstall
        {
            Ensure = 'Present'
            Name   = 'UpdateServices-WidDB'
        }

        WindowsFeature UpdateServicesServicesInstall
        {
            Ensure    = 'Present'
            Name      = 'UpdateServices-Services'
            DependsOn = '[WindowsFeature]UpdateServicesWIDDBInstall'
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

        WaitforDisk Disk2
        {
            DiskId           = 1
            RetryIntervalSec = 60
            RetryCount       = 60
            DependsOn        = '[Computer]JoinDomain'
        }

        Disk DVolume
        {
            DiskId      = 1
            DriveLetter = 'D'
            DependsOn   = '[WaitforDisk]Disk2'
        }
    }
}
