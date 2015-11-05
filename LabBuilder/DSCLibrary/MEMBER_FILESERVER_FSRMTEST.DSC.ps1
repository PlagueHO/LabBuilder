<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_FILESERVER_FSRMTEST
.Desription
	Builds a Server that is joined to a domain and then made into a File Server.
	Includes tests for FSRM Resources.
.Parameters:          
	DomainName = "LABBUILDER.COM"
	DomainAdminPassword = "P@ssword!1"
#########################################################################################################################################>

Configuration MEMBER_FILESERVER_FSRMTEST
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
	Import-DscResource -ModuleName xActiveDirectory
	Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xStorage
	Import-DscResource -ModuleName xNetworking
	Import-DscResource -ModuleName cFSRMQuotas
	Import-DscResource -ModuleName cFSRMFileScreens
	Import-DscResource -ModuleName cFSRMClassifications
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

		File UsersFolder
		{
			DestinationPath = 'd:\Users'
			Ensure = 'Present'
			Type = 'Directory'
			DependsOn = "[xDisk]DVolume" 
		}

		cFSRMQuotaTemplate HardLimit5GB
		{
			Name = '5 GB Limit'
			Description = '5 GB Hard Limit'
			Ensure = 'Present'
			Size = 5GB
			SoftLimit = $False
			ThresholdPercentages = @( 85, 100 )
			DependsOn = "[File]UsersFolder" 
		}

		cFSRMQuotaTemplateAction HardLimit5GBEmail85
		{
			Name = '5 GB Limit'
			Percentage = 85
			Ensure = 'Present'
			Type = 'Email'
			Subject = '[Quota Threshold]% quota threshold exceeded'
			Body = 'User [Source Io Owner] has exceed the [Quota Threshold]% quota threshold for quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB and the current usage is [Quota Used MB] MB ([Quota Used Percent]% of limit).'
			MailBCC = ''
			MailCC = 'fileserveradmins@contoso.com'
			MailTo = '[Source Io Owner Email]'           
			DependsOn = "[cFSRMQuotaTemplate]HardLimit5GB" 
		} # End of cFSRMQuotaTemplateAction Resource

		cFSRMQuotaTemplateAction HardLimit5GBEvent85
		{
			Name = '5 GB Limit'
			Percentage = 85
			Ensure = 'Present'
			Type = 'Event'
			Body = 'User [Source Io Owner] has exceed the [Quota Threshold]% quota threshold for quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB and the current usage is [Quota Used MB] MB ([Quota Used Percent]% of limit).'
			EventType = 'Warning'
			DependsOn = "[cFSRMQuotaTemplate]HardLimit5GB" 
		} # End of cFSRMQuotaTemplateAction Resource

		cFSRMQuotaTemplateAction HardLimit5GBEmail100
		{
			Name = '5 GB Limit'
			Percentage = 100
			Ensure = 'Present'
			Type = 'Email'
			Subject = '[Quota Threshold]% quota threshold exceeded'
			Body = 'User [Source Io Owner] has exceed the [Quota Threshold]% quota threshold for quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB and the current usage is [Quota Used MB] MB ([Quota Used Percent]% of limit).'
			MailBCC = ''
			MailCC = 'fileserveradmins@contoso.com'
			MailTo = '[Source Io Owner Email]'
			DependsOn = "[cFSRMQuotaTemplate]HardLimit5GB" 
		} # End of cFSRMQuotaTemplateAction Resource

		cFSRMQuota DUsersQuota
		{
			Path = 'd:\users'
			Description = '5 GB Hard Limit, YEAH!'
			Ensure = 'Present'
			Template = '5 GB Limit'
			MatchesTemplate = $true
			DependsOn = "[cFSRMQuotaTemplateAction]HardLimit5GBEmail100" 
		} # End of cFSRMQuota Resource

		File SharedFolder
		{
			DestinationPath = 'd:\shared'
			Ensure = 'Present'
			Type = 'Directory'
			DependsOn = "[xDisk]DVolume" 
		}

		cFSRMQuota DSharedQuota
		{
			Path = 'd:\shared'
			Description = '5 GB Hard Limit'
			Ensure = 'Present'
			Size = 5GB
			SoftLimit = $False
			ThresholdPercentages = @( 75, 100 )
			DependsOn = "[File]SharedFolder" 
		} # End of cFSRMQuota Resource

		cFSRMQuotaAction DSharedEmail75
		{
			Path = 'd:\shared'
			Percentage = 75
			Ensure = 'Present'
			Type = 'Email'
			Subject = '[Quota Threshold]% quota threshold exceeded'
			Body = 'User [Source Io Owner] has exceed the [Quota Threshold]% quota threshold for quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB and the current usage is [Quota Used MB] MB ([Quota Used Percent]% of limit).'
			MailBCC = ''
			MailCC = 'fileserveradmins@contoso.com'
			MailTo = '[Source Io Owner Email]'           
			DependsOn = "[cFSRMQuota]DSharedQuota" 
		} # End of cFSRMQuotaAction Resource

		cFSRMQuotaAction DSharedEmail100
		{
			Path = 'd:\shared'
			Percentage = 100
			Ensure = 'Present'
			Type = 'Email'
			Subject = '[Quota Threshold]% quota threshold exceeded'
			Body = 'User [Source Io Owner] has exceed the [Quota Threshold]% quota threshold for quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB and the current usage is [Quota Used MB] MB ([Quota Used Percent]% of limit).'
			MailBCC = ''
			MailCC = 'fileserveradmins@contoso.com'
			MailTo = '[Source Io Owner Email]'
			DependsOn = "[cFSRMQuota]DSharedQuota" 
		} # End of cFSRMQuotaAction Resource

		File AutoFolder
		{
			DestinationPath = 'd:\auto'
			Ensure = 'Present'
			Type = 'Directory'
			DependsOn = "[xDisk]DVolume" 
		}

		cFSRMAutoQuota DAutoQuota
		{
			Path = 'd:\auto'
			Ensure = 'Present'
			Template = '100 MB Limit'
			DependsOn = "[File]SharedFolder" 
		} # End of cFSRMQuota Resource

		cFSRMFileGroup FSRMFileGroupPortableFiles
		{
			Name = 'Portable Document Files'
			Description = 'Files containing portable document formats'
			Ensure = 'Present'
			IncludePattern = '*.eps','*.pdf','*.xps'
		}

		cFSRMFileScreenTemplate FileScreenSomeFiles
		{
			Name = 'Block Some Files'
			Description = 'File Screen for Blocking Some Files'
			Ensure = 'Present'
			Active = $true
			IncludeGroup = 'Audio and Video Files','Executable Files','Backup Files' 
		} # End of cFSRMFileScreenTemplate Resource

		cFSRMFileScreenTemplateAction FileScreenSomeFilesEmail
		{
			Name = 'Block Some Files'
			Ensure = 'Present'
			Type = 'Email'
			Subject = 'Unauthorized file matching [Violated File Group] file group detected'
			Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
			MailBCC = ''
			MailCC = 'fileserveradmins@contoso.com'
			MailTo = '[Source Io Owner Email]'           
			DependsOn = "[cFSRMFileScreenTemplate]FileScreenSomeFiles" 
		} # End of cFSRMFileScreenTemplateAction Resource

		cFSRMFileScreenTemplateAction FileScreenSomeFilesEvent
		{
			Name = 'Block Some Files'
			Ensure = 'Present'
			Type = 'Event'
			Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
			EventType = 'Warning'
			DependsOn = "[cFSRMFileScreenTemplate]FileScreenSomeFiles" 
		} # End of cFSRMFileScreenTemplateAction Resource

		cFSRMFileScreen DUsersFileScreen
		{
			Path = 'd:\users'
			Description = 'File Screen for Blocking Some Files'
			Ensure = 'Present'
			Active = $true
			IncludeGroup = 'Audio and Video Files','Executable Files','Backup Files' 
		} # End of cFSRMFileScreen Resource

		cFSRMFileScreenAction DUsersFileScreenSomeFilesEmail
		{
			Path = 'd:\users'
			Ensure = 'Present'
			Type = 'Email'
			Subject = 'Unauthorized file matching [Violated File Group] file group detected'
			Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
			MailBCC = ''
			MailCC = 'fileserveradmins@contoso.com'
			MailTo = '[Source Io Owner Email]'           
			DependsOn = "[cFSRMFileScreen]DUsersFileScreen" 
		} # End of cFSRMFileScreenAction Resource

		cFSRMFileScreenAction DUsersFileScreenSomeFilesEvent
		{
			Path = 'd:\users'
			Ensure = 'Present'
			Type = 'Event'
			Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
			EventType = 'Warning'
			DependsOn = "[cFSRMFileScreen]DUsersFileScreen" 
		} # End of cFSRMFileScreenAction Resource

		cFSRMFileScreenException DUsersFileScreenException
		{
			Path = 'd:\users'
			Description = 'File Screen Exclusion'
			Ensure = 'Present'
			IncludeGroup = 'E-mail Files' 
		} # End of cFSRMFileScreenException Resource

		cFSRMClassificationProperty PrivacyClasificationProperty
		{
			Name = 'Privacy'
			DisplayName = 'File Privacy'
			Description = 'File Privacy Property'
			Ensure = 'Present'
			Type = 'SingleChoice'
			PossibleValue = 'Top Secret','Secret','Confidential','Public'
			Parameters = 'Parameter1=Value1','Parameter2=Value2'
		} # End of cFSRMClassificationProperty Resource

		cFSRMClassificationPropertyValue PublicClasificationPropertyValue
		{
			Name = 'Public'
			PropertyName = 'Privacy'
			Description = 'Publically accessible files.'
			Ensure = 'Present'
			DependsOn = "[cFSRMClassificationProperty]PrivacyClasificationProperty" 
		} # End of cFSRMClassificationPropertyValue Resource

		cFSRMClassificationPropertyValue SecretClasificationPropertyValue
		{
			Name = 'Secret'
			PropertyName = 'Privacy'
			Ensure = 'Present'
			DependsOn = "[cFSRMClassificationProperty]PrivacyClasificationProperty" 
		} # End of cFSRMClassificationPropertyValue Resource
		cFSRMClassification FSRMClassificationSettings
		{
			Id = 'Default'
			Continuous = $True
			ContinuousLog = $True
			ContinuousLogSize = 2048
			ScheduleWeekly = 'Monday','Tuesday','Wednesday'
			ScheduleRunDuration = 4
			ScheduleTime = '23:30'
		} # End of cFSRMClassification Resource
		cFSRMClassificationRule ConfidentialPrivacyClasificationRule
		{
			Name = 'Confidential'
			Description = 'Set Confidential'
			Ensure = 'Present'
			Property = 'Privacy'
			PropertyValue = 'Confidential'
			ClassificationMechanism = 'Content Classifier'
			ContentString = 'Confidential'
			Namespace = '[FolderUsage_MS=User Files]','d:\Users'
			ReevaluateProperty = 'Overwrite'                
		} # End of cFSRMClassificationRule Resource
	}
}
