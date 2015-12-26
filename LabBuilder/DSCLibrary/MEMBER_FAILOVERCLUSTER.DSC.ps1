<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_FAILOVERCLUSTER
.Desription
	Builds a Network failover clustering node.
.Parameters:    
		  DomainName = "LABBUILDER.COM"
		  DomainAdminPassword = "P@ssword!1"
		  PSDscAllowDomainUser = $True
#########################################################################################################################################>
Configuration MEMBER_FAILOVERCLUSTER
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration' -ModuleVersion 1.1
	Import-DscResource -ModuleName xActiveDirectory
	Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xPSDesiredStateConfiguration
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

		WindowsFeature FailoverClusteringInstall
		{ 
			Ensure = "Present" 
			Name = "Failover-Clustering" 
		} 

		WindowsFeature FailoverClusteringPSInstall
		{ 
			Ensure = "Present" 
			Name = "RSAT-Clustering-PowerShell" 
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
