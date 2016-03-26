<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FILESERVER_FSRMTEST
.Desription
    Builds a Server that is joined to a domain and then made into a File Server.
    Includes tests for FSRM Resources.
.Parameters:          
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration MEMBER_FILESERVER_FSRMTEST
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xStorage
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName cFSRM
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

        WindowsFeature BranchCacheInstall 
        { 
            Ensure = "Present" 
            Name = "FS-BranchCache" 
            DependsOn = "[WindowsFeature]DataDedupInstall" 
        }

        WindowsFeature DFSNameSpaceInstall 
        {
            Ensure = "Present" 
            Name = "FS-DFS-Namespace" 
            DependsOn = "[WindowsFeature]BranchCacheInstall" 
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

        # Enable FSRM FireWall rules so we can remote manage FSRM
        xFirewall FSRMFirewall1
        {
            Name = "FSRM-WMI-ASYNC-In-TCP"
            Ensure = 'Present'
            Enabled = 'True'
        }

        xFirewall FSRMFirewall2
        {
            Name = "FSRM-WMI-WINMGMT-In-TCP"
            Ensure = 'Present'
            Enabled = 'True' 
        }

        xFirewall FSRMFirewall3
        {
            Name = "FSRM-RemoteRegistry-In (RPC)"
            Ensure = 'Present'
            Enabled = 'True' 
        }

        xFirewall FSRMFirewall4
        {
            Name = "FSRM-Task-Scheduler-In (RPC)"
            Ensure = 'Present'
            Enabled = 'True' 
        }

        xFirewall FSRMFirewall5
        {
            Name = "FSRM-SrmReports-In (RPC)"
            Ensure = 'Present'
            Enabled = 'True' 
        }

        xFirewall FSRMFirewall6
        {
            Name = "FSRM-RpcSs-In (RPC-EPMAP)"
            Ensure = 'Present'
            Enabled = 'True' 
        }
        
        xFirewall FSRMFirewall7
        {
            Name = "FSRM-System-In (TCP-445)"
            Ensure = 'Present'
            Enabled = 'True' 
        }
        
        xFirewall FSRMFirewall8
        {
            Name = "FSRM-SrmSvc-In (RPC)"
            Ensure = 'Present'
            Enabled = 'True'
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

        xFSRMQuotaTemplate HardLimit5GB
        {
            Name = '5 GB Limit'
            Description = '5 GB Hard Limit'
            Ensure = 'Present'
            Size = 5GB
            SoftLimit = $False
            ThresholdPercentages = @( 85, 100 )
            DependsOn = "[File]UsersFolder" 
        }

        xFSRMQuotaTemplateAction HardLimit5GBEmail85
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
            DependsOn = "[xFSRMQuotaTemplate]HardLimit5GB" 
        } # End of xFSRMQuotaTemplateAction Resource

        xFSRMQuotaTemplateAction HardLimit5GBEvent85
        {
            Name = '5 GB Limit'
            Percentage = 85
            Ensure = 'Present'
            Type = 'Event'
            Body = 'User [Source Io Owner] has exceed the [Quota Threshold]% quota threshold for quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB and the current usage is [Quota Used MB] MB ([Quota Used Percent]% of limit).'
            EventType = 'Warning'
            DependsOn = "[xFSRMQuotaTemplate]HardLimit5GB" 
        } # End of xFSRMQuotaTemplateAction Resource

        xFSRMQuotaTemplateAction HardLimit5GBEmail100
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
            DependsOn = "[xFSRMQuotaTemplate]HardLimit5GB" 
        } # End of xFSRMQuotaTemplateAction Resource

        xFSRMQuota DUsersQuota
        {
            Path = 'd:\users'
            Description = '5 GB Hard Limit, YEAH!'
            Ensure = 'Present'
            Template = '5 GB Limit'
            MatchesTemplate = $true
            DependsOn = "[xFSRMQuotaTemplateAction]HardLimit5GBEmail100" 
        } # End of xFSRMQuota Resource

        File SharedFolder
        {
            DestinationPath = 'd:\shared'
            Ensure = 'Present'
            Type = 'Directory'
            DependsOn = "[xDisk]DVolume" 
        }

        xFSRMQuota DSharedQuota
        {
            Path = 'd:\shared'
            Description = '5 GB Hard Limit'
            Ensure = 'Present'
            Size = 5GB
            SoftLimit = $False
            ThresholdPercentages = @( 75, 100 )
            DependsOn = "[File]SharedFolder" 
        } # End of xFSRMQuota Resource

        xFSRMQuotaAction DSharedEmail75
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
            DependsOn = "[xFSRMQuota]DSharedQuota" 
        } # End of xFSRMQuotaAction Resource

        xFSRMQuotaAction DSharedEmail100
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
            DependsOn = "[xFSRMQuota]DSharedQuota" 
        } # End of xFSRMQuotaAction Resource

        File AutoFolder
        {
            DestinationPath = 'd:\auto'
            Ensure = 'Present'
            Type = 'Directory'
            DependsOn = "[xDisk]DVolume" 
        }

        xFSRMAutoQuota DAutoQuota
        {
            Path = 'd:\auto'
            Ensure = 'Present'
            Template = '100 MB Limit'
            DependsOn = "[File]SharedFolder" 
        } # End of xFSRMQuota Resource

        xFSRMFileGroup FSRMFileGroupPortableFiles
        {
            Name = 'Portable Document Files'
            Description = 'Files containing portable document formats'
            Ensure = 'Present'
            IncludePattern = '*.eps','*.pdf','*.xps'
        }

        xFSRMFileScreenTemplate FileScreenSomeFiles
        {
            Name = 'Block Some Files'
            Description = 'File Screen for Blocking Some Files'
            Ensure = 'Present'
            Active = $true
            IncludeGroup = 'Audio and Video Files','Executable Files','Backup Files' 
        } # End of xFSRMFileScreenTemplate Resource

        xFSRMFileScreenTemplateAction FileScreenSomeFilesEmail
        {
            Name = 'Block Some Files'
            Ensure = 'Present'
            Type = 'Email'
            Subject = 'Unauthorized file matching [Violated File Group] file group detected'
            Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
            MailBCC = ''
            MailCC = 'fileserveradmins@contoso.com'
            MailTo = '[Source Io Owner Email]'           
            DependsOn = "[xFSRMFileScreenTemplate]FileScreenSomeFiles" 
        } # End of xFSRMFileScreenTemplateAction Resource

        xFSRMFileScreenTemplateAction FileScreenSomeFilesEvent
        {
            Name = 'Block Some Files'
            Ensure = 'Present'
            Type = 'Event'
            Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
            EventType = 'Warning'
            DependsOn = "[xFSRMFileScreenTemplate]FileScreenSomeFiles" 
        } # End of xFSRMFileScreenTemplateAction Resource

        xFSRMFileScreen DUsersFileScreen
        {
            Path = 'd:\users'
            Description = 'File Screen for Blocking Some Files'
            Ensure = 'Present'
            Active = $true
            IncludeGroup = 'Audio and Video Files','Executable Files','Backup Files' 
        } # End of xFSRMFileScreen Resource

        xFSRMFileScreenAction DUsersFileScreenSomeFilesEmail
        {
            Path = 'd:\users'
            Ensure = 'Present'
            Type = 'Email'
            Subject = 'Unauthorized file matching [Violated File Group] file group detected'
            Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
            MailBCC = ''
            MailCC = 'fileserveradmins@contoso.com'
            MailTo = '[Source Io Owner Email]'           
            DependsOn = "[xFSRMFileScreen]DUsersFileScreen" 
        } # End of xFSRMFileScreenAction Resource

        xFSRMFileScreenAction DUsersFileScreenSomeFilesEvent
        {
            Path = 'd:\users'
            Ensure = 'Present'
            Type = 'Event'
            Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
            EventType = 'Warning'
            DependsOn = "[xFSRMFileScreen]DUsersFileScreen" 
        } # End of xFSRMFileScreenAction Resource

        xFSRMFileScreenException DUsersFileScreenException
        {
            Path = 'd:\users'
            Description = 'File Screen Exclusion'
            Ensure = 'Present'
            IncludeGroup = 'E-mail Files' 
        } # End of xFSRMFileScreenException Resource

        xFSRMClassificationProperty PrivacyClasificationProperty
        {
            Name = 'Privacy'
            DisplayName = 'File Privacy'
            Description = 'File Privacy Property'
            Ensure = 'Present'
            Type = 'SingleChoice'
            PossibleValue = 'Top Secret','Secret','Confidential','Public'
            Parameters = 'Parameter1=Value1','Parameter2=Value2'
        } # End of xFSRMClassificationProperty Resource

        xFSRMClassificationPropertyValue PublicClasificationPropertyValue
        {
            Name = 'Public'
            PropertyName = 'Privacy'
            Description = 'Publically accessible files.'
            Ensure = 'Present'
            DependsOn = "[xFSRMClassificationProperty]PrivacyClasificationProperty" 
        } # End of xFSRMClassificationPropertyValue Resource

        xFSRMClassificationPropertyValue SecretClasificationPropertyValue
        {
            Name = 'Secret'
            PropertyName = 'Privacy'
            Ensure = 'Present'
            DependsOn = "[xFSRMClassificationProperty]PrivacyClasificationProperty" 
        } # End of xFSRMClassificationPropertyValue Resource
        xFSRMClassification FSRMClassificationSettings
        {
            Id = 'Default'
            Continuous = $True
            ContinuousLog = $True
            ContinuousLogSize = 2048
            ScheduleWeekly = 'Monday','Tuesday','Wednesday'
            ScheduleRunDuration = 4
            ScheduleTime = '23:30'
        } # End of xFSRMClassification Resource
        xFSRMClassificationRule ConfidentialPrivacyClasificationRule
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
        } # End of xFSRMClassificationRule Resource
    }
}
