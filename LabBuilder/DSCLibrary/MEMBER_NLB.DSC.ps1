<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_NLB
.Desription
	Builds a Network Load Balancing cluster node.
.Parameters:    
		  DomainName = "LABBUILDER.COM"
		  DomainAdminPassword = "P@ssword!1"
		  PSDscAllowDomainUser = $True
#########################################################################################################################################>
Configuration MEMBER_NLB
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration' -ModuleVersion 1.1
    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.9.0.0 # Current as of 8 Feb 2016
	Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.4.0.0 # Current as of 8 Feb 2016
	Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 3.7.0.0 # Current as of 28 Feb 2016
	Node $AllNodes.NodeName {
		# Assemble the Local Admin Credentials
		If ($Node.LocalAdminPassword) {
			[PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
		}
		If ($Node.DomainAdminPassword) {
			[PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
		}

		# Install the RSAT PowerShell Module which is required by the xWaitForResource
		WindowsFeature RSATADPowerShell
		{ 
			Ensure = "Present" 
			Name = "RSAT-AD-PowerShell" 
		} 

		WindowsFeature InstallWebServer
		{ 
			Ensure = "Present" 
			Name = "Web-Server" 
		}

		WindowsFeature InstallWebMgmtService
		{ 
			Ensure = "Present" 
			Name = "Web-Mgmt-Service" 
		}

		WindowsFeature InstallNLB
		{ 
			Ensure = "Present" 
			Name = "NLB" 
		} 

		# Wait for the Domain to be available so we can join it.
		xWaitForADDomain DscDomainWait
		{
			DomainName = $Node.DomainName
			DomainUserCredential = $DomainAdminCredential 
			RetryCount = 100 
			RetryIntervalSec = 10 
			DependsOn = "[WindowsFeature]RSATADPowerShell" 
		}

		# Join this Server to the Domain so that it can be an Enterprise CA.
		xComputer JoinDomain 
		{ 
			Name          = $Node.NodeName
			DomainName    = $Node.DomainName
			Credential    = $DomainAdminCredential 
			DependsOn = "[xWaitForADDomain]DscDomainWait" 
		} 			
	}
}
