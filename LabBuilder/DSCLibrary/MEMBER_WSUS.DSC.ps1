<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_WSUS
.Desription
	Builds a Server that is joined to a domain and then installs WSUS components.
	Requires cMicrosoftUpdate resource from https://github.com/fabiendibot/cMicrosoftUpdate
.Parameters:          
	DomainName = "LABBUILDER.COM"
	DomainAdminPassword = "P@ssword!1"
#########################################################################################################################################>

Configuration MEMBER_WSUS
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration' -ModuleVersion 1.1
    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.9.0.0 # Current as of 8 Feb 2016
	Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.4.0.0 # Current as of 8 Feb 2016
	Import-DscResource -ModuleName xWindowsUpdate -ModuleVersion 2.3.0.0 # Current as of 28 Feb 2016
	Import-DscResource -ModuleName xStorage -ModuleVersion 2.4.0.0  # Current as of 8 Feb 2016
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

		WindowsFeature RSATADPowerShell
        { 
            Ensure = "Present" 
            Name = "RSAT-AD-PowerShell" 
			DependsOn = "[WindowsFeature]UpdateServicesServicesInstall" 
        } 

        xWaitForADDomain DscDomainWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $DomainAdminCredential 
            RetryCount = 100 
            RetryIntervalSec = 10 
			DependsOn = "[WindowsFeature]RSATADPowerShell" 
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
