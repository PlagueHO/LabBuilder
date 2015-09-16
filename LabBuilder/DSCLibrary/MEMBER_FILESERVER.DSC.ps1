<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_FILESERVER
.Desription
	Builds a Server that is joined to a domain and then made into a File Server.
.Parameters:          
	DomainName = "LABBUILDER.COM"
	DomainAdminPassword = "P@ssword!1"
#########################################################################################################################################>

Configuration MEMBER_FILESERVER
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
	Import-DscResource -ModuleName xActiveDirectory
	Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xStorage
	Import-DSCResource -ModuleName xNetworking 
	Node $AllNodes.NodeName {
		# Assemble the Local Admin Credentials
		If ($Node.LocalAdminPassword) {
			[PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
		}
		If ($Node.DomainAdminPassword) {
			[PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
		}

		WindowsFeature FileServerInstall 
        { 
            Ensure = "Present" 
            Name = "FS-FileServer" 
        }

		WindowsFeature DataDedupInstall 
        { 
            Ensure = "Present" 
            Name = "FS-Data-Deduplication" 
			DependsOn = "[WindowsFeature]FileServerInstall" 
        }

		WindowsFeature DFSNameSpaceInstall 
        { 
            Ensure = "Present" 
            Name = "FS-DFS-Namespace" 
			DependsOn = "[WindowsFeature]DataDedupInstall" 
        }

		WindowsFeature DFSReplicationInstall 
        { 
            Ensure = "Present" 
            Name = "FS-DFS-Replication" 
			DependsOn = "[WindowsFeature]DFSNameSpaceInstall" 
        }

		WindowsFeature FSResourceManagerInstall 
        { 
            Ensure = "Present" 
            Name = "FS-Resource-Manager" 
			DependsOn = "[WindowsFeature]DFSReplicationInstall" 
        }

		WindowsFeature FSSyncShareInstall 
        { 
            Ensure = "Present" 
            Name = "FS-SyncShareService" 
			DependsOn = "[WindowsFeature]FSResourceManagerInstall" 
        }

		WindowsFeature StorageServicesInstall 
        { 
            Ensure = "Present" 
            Name = "Storage-Services" 
			DependsOn = "[WindowsFeature]FSSyncShareInstall" 
        }

		WindowsFeature RSATADPowerShell
        { 
            Ensure = "Present" 
            Name = "RSAT-AD-PowerShell" 
			DependsOn = "[WindowsFeature]StorageServicesInstall"
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

		# Enable FSRM FireWall rules so we can remote manage FSRM
		xFirewall FSRMFirewall1
        {
			Name = "FSRM-WMI-ASYNC-In-TCP"
			State = "Enabled"
			Access = "Allow"
			DependsOn = "[xComputer]JoinDomain" 
        }

		xFirewall FSRMFirewall2
        {
			Name = "FSRM-WMI-WINMGMT-In-TCP"
			State = "Enabled" 
			Access = "Allow"
			DependsOn = "[xComputer]JoinDomain" 
        }

		xFirewall FSRMFirewall3
        {
			Name = "FSRM-RemoteRegistry-In (RPC)"
			State = "Enabled" 
			Access = "Allow"
			DependsOn = "[xComputer]JoinDomain" 
        }
		
		xFirewall FSRMFirewall4
        {
			Name = "FSRM-Task-Scheduler-In (RPC)"
			State = "Enabled" 
			Access = "Allow"
			DependsOn = "[xComputer]JoinDomain" 
        }

		xFirewall FSRMFirewall5
        {
			Name = "FSRM-SrmReports-In (RPC)"
			State = "Enabled" 
			Access = "Allow"
			DependsOn = "[xComputer]JoinDomain" 
        }

		xFirewall FSRMFirewall6
        {
			Name = "FSRM-RpcSs-In (RPC-EPMAP)"
			State = "Enabled" 
			Access = "Allow"
			DependsOn = "[xComputer]JoinDomain" 
        }
		
		xFirewall FSRMFirewall7
        {
			Name = "FSRM-System-In (TCP-445)"
			State = "Enabled" 
			Access = "Allow"
			DependsOn = "[xComputer]JoinDomain" 
        }
		
		xFirewall FSRMFirewall8
        {
			Name = "FSRM-SrmSvc-In (RPC)"
			State = "Enabled"
			Access = "Allow"
			DependsOn = "[xComputer]JoinDomain" 
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
