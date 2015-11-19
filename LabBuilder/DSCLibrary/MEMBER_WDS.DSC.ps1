<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_WDS
.Desription
	Builds a Server that is joined to a domain and then installs WSUS components.
.Parameters:          
	DomainName = "LABBUILDER.COM"
	DomainAdminPassword = "P@ssword!1"
#########################################################################################################################################>

Configuration MEMBER_WDS
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
	Import-DscResource -ModuleName xActiveDirectory
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

		WindowsFeature RSATADPowerShellInstall
        { 
            Ensure = "Present" 
            Name = "RSAT-AD-PowerShell" 
			DependsOn = "[WindowsFeature]WDSTransportInstall" 
        } 

		WindowsFeature BitLockerNetworkUnlockInstall
        { 
            Ensure = "Present" 
            Name = "BitLocker-NetworkUnlock" 
			DependsOn = "[WindowsFeature]RSATADPowerShellInstall" 
        } 

        xWaitForADDomain DscDomainWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $DomainAdminCredential 
            RetryCount = 100 
            RetryIntervalSec = 10 
			DependsOn = "[WindowsFeature]BitLockerNetworkUnlockInstall" 
        }

		xComputer JoinDomain 
        { 
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential 
			DependsOn = "[xWaitForADDomain]DscDomainWait" 
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
