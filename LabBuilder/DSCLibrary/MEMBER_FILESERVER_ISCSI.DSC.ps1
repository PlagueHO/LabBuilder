<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_FILESERVER_ISCSI
.Desription
	Builds a Server that is joined to a domain and then made into a File Server.
	Configures a iSCSI targets and virtual disks.
.Parameters:          
	DomainName = "LABBUILDER.COM"
	DomainAdminPassword = "P@ssword!1"
	TargetName = 'sa-foc-target'
	VirtualDisks =  @(
		@{ Path = 'D:\iSCSIVirtualDisks\sa-foc-witness.vhdx';
			DiskType = 'Dynamic';
			SizeBytes = 500MB;
		},
		@{ Path = 'D:\iSCSIVirtualDisks\sa-foc-disk1.vhdx';
			DiskType = 'Dynamic';
			SizeBytes = 10GB;
		},
		@{ Path = 'D:\iSCSIVirtualDisks\sa-foc-disk2.vhdx';
			DiskType = 'Dynamic';
			SizeBytes = 10GB;
		},
		@{ Path = 'D:\iSCSIVirtualDisks\sa-foc-disk3.vhdx';
			DiskType = 'Dynamic';
			SizeBytes = 10GB;
		}
	)
	ClusterInitiatorIds = @(
		'Iqn:iqn.1991-05.com.microsoft:sa-foc1.labbuilder.com'
		'Iqn:iqn.1991-05.com.microsoft:sa-foc2.labbuilder.com'
		'Iqn:iqn.1991-05.com.microsoft:sa-foc3.labbuilder.com'
	)
#########################################################################################################################################>

Configuration MEMBER_FILESERVER_ISCSI
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration' -ModuleVersion 1.1
	Import-DscResource -ModuleName xActiveDirectory
	Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xStorage
	Import-DscResource -ModuleName xNetworking
	Import-DscResource -ModuleName ciSCSI
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

		WindowsFeature ISCSITargetServerInstall 
		{ 
			Ensure = "Present" 
			Name = "FS-iSCSITarget-Server" 
			DependsOn = "[WindowsFeature]StorageServicesInstall" 
		}

		WindowsFeature RSATADPowerShell
		{ 
			Ensure = "Present" 
			Name = "RSAT-AD-PowerShell" 
			DependsOn = "[WindowsFeature]ISCSITargetServerInstall"
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
			Ensure = 'Present'
			Enabled = 'True'
			DependsOn = "[xComputer]JoinDomain" 
		}

		xFirewall FSRMFirewall2
		{
			Name = "FSRM-WMI-WINMGMT-In-TCP"
			Ensure = 'Present'
			Enabled = 'True' 
			DependsOn = "[xComputer]JoinDomain" 
		}

		xFirewall FSRMFirewall3
		{
			Name = "FSRM-RemoteRegistry-In (RPC)"
			Ensure = 'Present'
			Enabled = 'True' 
			DependsOn = "[xComputer]JoinDomain" 
		}
		
		xFirewall FSRMFirewall4
		{
			Name = "FSRM-Task-Scheduler-In (RPC)"
			Ensure = 'Present'
			Enabled = 'True' 
			DependsOn = "[xComputer]JoinDomain" 
		}

		xFirewall FSRMFirewall5
		{
			Name = "FSRM-SrmReports-In (RPC)"
			Ensure = 'Present'
			Enabled = 'True' 
			DependsOn = "[xComputer]JoinDomain" 
		}

		xFirewall FSRMFirewall6
		{
			Name = "FSRM-RpcSs-In (RPC-EPMAP)"
			Ensure = 'Present'
			Enabled = 'True' 
			DependsOn = "[xComputer]JoinDomain" 
		}
		
		xFirewall FSRMFirewall7
		{
			Name = "FSRM-System-In (TCP-445)"
			Ensure = 'Present'
			Enabled = 'True' 
			DependsOn = "[xComputer]JoinDomain" 
		}
		
		xFirewall FSRMFirewall8
		{
			Name = "FSRM-SrmSvc-In (RPC)"
			Ensure = 'Present'
			Enabled = 'True'
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

		File VirtualDisksFolder
		{
			Ensure = 'Present'
			DestinationPath = 'D:\iSCSIVirtualDisks'
			Type = 'Directory'
			DependsOn = '[xDisk]DVolume'
		}

		[String[]] $DependsOn = @()
		[Int] $Count = 0
		foreach ($VirtualDisk in $Node.VirtualDisk)
		{
			$Count++ 
			$Name = "$($Node.TargetName)_Disk_$Count"
			$DependsOn += @( "[ciSCSIVirtualDisk]$Name" )
			ciSCSIVirtualDisk $Name
			{
				Ensure = 'Present'
				Path = $VirtualDisk.Path
				DiskType = $VirtualDisk.DiskType
				SizeBytes = $VirtualDisk.SizeBytes
				Description = $VirtualDisk.Description
				DependsOn = '[File]VirtualDisksFolder'
			}
		}

		ciSCSIServerTarget ClusterTarget01
		{
			Ensure = 'Present'
			TargetName = $Node.TargetName
			InitiatorIds = $Node.ClusterInitiatorIds
			Paths = $Node.VirtualDisks.Path
			DependsOn = $DependsOn
		}

	}
}
