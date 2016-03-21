<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_WSUS
.Desription
    Builds a Server that is joined to a domain and then installs WSUS components.
    Requires cMicrosoftUpdate resource from https://github.com/fabiendibot/cMicrosoftUpdate
.Parameters:          
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration MEMBER_WSUS
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName xStorage
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature UpdateServicesWIDDBInstall 
        {
            Ensure = "Present" 
            Name = "UpdateServices-WidDB" 
        }

        WindowsFeature UpdateServicesServicesInstall 
        {
            Ensure = "Present" 
            Name = "UpdateServices-Services" 
            DependsOn = "[WindowsFeature]UpdateServicesWIDDBInstall" 
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

        xWaitforDisk Disk2
        {
            DiskNumber = 1
            RetryIntervalSec = 60
            RetryCount = 60
            DependsOn = "[xComputer]JoinDomain" 
        }
        
        xDisk DVolume
        {
            DiskNumber = 1
            DriveLetter = 'D'
            DependsOn = "[xWaitforDisk]Disk2" 
        }
    }
}
