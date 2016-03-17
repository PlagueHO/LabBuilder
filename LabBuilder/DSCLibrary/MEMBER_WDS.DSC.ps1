<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_WDS
.Desription
    Builds a Server that is joined to a domain and then installs WSUS components.
.Parameters:          
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration MEMBER_WDS
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xStorage
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature WDSDeploymentInstall 
        {
            Ensure = "Present" 
            Name = "WDS-Deployment" 
        }

        WindowsFeature WDSTransportInstall 
        {
            Ensure = "Present" 
            Name = "WDS-Transport" 
            DependsOn = "[WindowsFeature]WDSDeploymentInstall" 
        }

        WindowsFeature BitLockerNetworkUnlockInstall
        {
            Ensure = "Present" 
            Name = "BitLocker-NetworkUnlock" 
            DependsOn = "[WindowsFeature]RSATADPowerShellInstall" 
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
