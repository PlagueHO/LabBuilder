<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FILESERVER_FSRMTEST
.Desription
    Builds a Server that is joined to a domain and then made into a File Server.
    Includes tests for FSRM Resources.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
###################################################################################################>

Configuration MEMBER_FILESERVER_FSRMTEST
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName FSRMDsc

    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword) {
            $LocalAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ('Administrator', (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }

        if ($Node.DomainAdminPassword) {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature FileServerInstall
        {
            Ensure = 'Present'
            Name = 'FS-FileServer'
        }

        WindowsFeature DataDedupInstall
        {
            Ensure = 'Present'
            Name = 'FS-Data-Deduplication'
            DependsOn = '[WindowsFeature]FileServerInstall'
        }

        WindowsFeature BranchCacheInstall
        {
            Ensure = 'Present'
            Name = 'FS-BranchCache'
            DependsOn = '[WindowsFeature]DataDedupInstall'
        }

        WindowsFeature DFSNameSpaceInstall
        {
            Ensure = 'Present'
            Name = 'FS-DFS-Namespace'
            DependsOn = '[WindowsFeature]BranchCacheInstall'
        }

        WindowsFeature DFSReplicationInstall
        {
            Ensure = 'Present'
            Name = 'FS-DFS-Replication'
            DependsOn = '[WindowsFeature]DFSNameSpaceInstall'
        }

        WindowsFeature FSResourceManagerInstall
        {
            Ensure = 'Present'
            Name = 'FS-Resource-Manager'
            DependsOn = '[WindowsFeature]DFSReplicationInstall'
        }

        WindowsFeature FSSyncShareInstall
        {
            Ensure = 'Present'
            Name = 'FS-SyncShareService'
            DependsOn = '[WindowsFeature]FSResourceManagerInstall'
        }

        WindowsFeature StorageServicesInstall
        {
            Ensure = 'Present'
            Name = 'Storage-Services'
            DependsOn = '[WindowsFeature]FSSyncShareInstall'
        }

        WindowsFeature ISCSITargetServerInstall
        {
            Ensure = 'Present'
            Name = 'FS-iSCSITarget-Server'
            DependsOn = '[WindowsFeature]StorageServicesInstall'
        }


        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
        ResourceName      = '[ADDomain]PrimaryDC'
        NodeName          = $Node.DCname
        RetryIntervalSec  = 15
        RetryCount        = 60
        }

        # Join this Server to the Domain
        Computer JoinDomain
        {
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential
            DependsOn = '[WaitForAll]DC'
        }

        # Enable FSRM FireWall rules so we can remote manage FSRM
        Firewall FSRMFirewall1
        {
            Name = 'FSRM-WMI-ASYNC-In-TCP'
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall2
        {
            Name = 'FSRM-WMI-WINMGMT-In-TCP'
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall3
        {
            Name = 'FSRM-RemoteRegistry-In (RPC)'
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall4
        {
            Name = 'FSRM-Task-Scheduler-In (RPC)'
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall5
        {
            Name = 'FSRM-SrmReports-In (RPC)'
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall6
        {
            Name = 'FSRM-RpcSs-In (RPC-EPMAP)'
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall7
        {
            Name = 'FSRM-System-In (TCP-445)'
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall8
        {
            Name = 'FSRM-SrmSvc-In (RPC)'
            Ensure = 'Present'
            Enabled = 'True'
        }

        WaitforDisk Disk2
        {
            DiskId = 1
            RetryIntervalSec = 60
            RetryCount = 60
            DependsOn = '[Computer]JoinDomain'
        }

        Disk DVolume
        {
            DiskId = 1
            DriveLetter = 'D'
            DependsOn = '[WaitforDisk]Disk2'
        }

        File UsersFolder
        {
            DestinationPath = 'd:\Users'
            Ensure = 'Present'
            Type = 'Directory'
            DependsOn = '[Disk]DVolume'
        }

        FSRMQuotaTemplate HardLimit5GB
        {
            Name = '5 GB Limit'
            Description = '5 GB Hard Limit'
            Ensure = 'Present'
            Size = 5GB
            SoftLimit = $false
            ThresholdPercentages = @( 85, 100 )
            DependsOn = '[File]UsersFolder'
        }

        FSRMQuotaTemplateAction HardLimit5GBEmail85
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
            DependsOn = '[FSRMQuotaTemplate]HardLimit5GB'
        } # End of FSRMQuotaTemplateAction Resource

        FSRMQuotaTemplateAction HardLimit5GBEvent85
        {
            Name = '5 GB Limit'
            Percentage = 85
            Ensure = 'Present'
            Type = 'Event'
            Body = 'User [Source Io Owner] has exceed the [Quota Threshold]% quota threshold for quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB and the current usage is [Quota Used MB] MB ([Quota Used Percent]% of limit).'
            EventType = 'Warning'
            DependsOn = '[FSRMQuotaTemplate]HardLimit5GB'
        } # End of FSRMQuotaTemplateAction Resource

        FSRMQuotaTemplateAction HardLimit5GBEmail100
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
            DependsOn = '[FSRMQuotaTemplate]HardLimit5GB'
        } # End of FSRMQuotaTemplateAction Resource

        FSRMQuota DUsersQuota
        {
            Path = 'd:\users'
            Description = '5 GB Hard Limit, YEAH!'
            Ensure = 'Present'
            Template = '5 GB Limit'
            MatchesTemplate = $true
            DependsOn = '[FSRMQuotaTemplateAction]HardLimit5GBEmail100'
        } # End of FSRMQuota Resource

        File SharedFolder
        {
            DestinationPath = 'd:\shared'
            Ensure = 'Present'
            Type = 'Directory'
            DependsOn = '[Disk]DVolume'
        }

        FSRMQuota DSharedQuota
        {
            Path = 'd:\shared'
            Description = '5 GB Hard Limit'
            Ensure = 'Present'
            Size = 5GB
            SoftLimit = $false
            ThresholdPercentages = @( 75, 100 )
            DependsOn = '[File]SharedFolder'
        } # End of FSRMQuota Resource

        FSRMQuotaAction DSharedEmail75
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
            DependsOn = '[FSRMQuota]DSharedQuota'
        } # End of FSRMQuotaAction Resource

        FSRMQuotaAction DSharedEmail100
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
            DependsOn = '[FSRMQuota]DSharedQuota'
        } # End of FSRMQuotaAction Resource

        File AutoFolder
        {
            DestinationPath = 'd:\auto'
            Ensure = 'Present'
            Type = 'Directory'
            DependsOn = '[Disk]DVolume'
        }

        FSRMAutoQuota DAutoQuota
        {
            Path = 'd:\auto'
            Ensure = 'Present'
            Template = '100 MB Limit'
            DependsOn = '[File]SharedFolder'
        } # End of FSRMQuota Resource

        FSRMFileGroup FSRMFileGroupPortableFiles
        {
            Name = 'Portable Document Files'
            Description = 'Files containing portable document formats'
            Ensure = 'Present'
            IncludePattern = '*.eps','*.pdf','*.xps'
        }

        FSRMFileScreenTemplate FileScreenSomeFiles
        {
            Name = 'Block Some Files'
            Description = 'File Screen for Blocking Some Files'
            Ensure = 'Present'
            Active = $true
            IncludeGroup = 'Audio and Video Files','Executable Files','Backup Files'
        } # End of FSRMFileScreenTemplate Resource

        FSRMFileScreenTemplateAction FileScreenSomeFilesEmail
        {
            Name = 'Block Some Files'
            Ensure = 'Present'
            Type = 'Email'
            Subject = 'Unauthorized file matching [Violated File Group] file group detected'
            Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
            MailBCC = ''
            MailCC = 'fileserveradmins@contoso.com'
            MailTo = '[Source Io Owner Email]'
            DependsOn = '[FSRMFileScreenTemplate]FileScreenSomeFiles'
        } # End of FSRMFileScreenTemplateAction Resource

        FSRMFileScreenTemplateAction FileScreenSomeFilesEvent
        {
            Name = 'Block Some Files'
            Ensure = 'Present'
            Type = 'Event'
            Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
            EventType = 'Warning'
            DependsOn = '[FSRMFileScreenTemplate]FileScreenSomeFiles'
        } # End of FSRMFileScreenTemplateAction Resource

        FSRMFileScreen DUsersFileScreen
        {
            Path = 'd:\users'
            Description = 'File Screen for Blocking Some Files'
            Ensure = 'Present'
            Active = $true
            IncludeGroup = 'Audio and Video Files','Executable Files','Backup Files'
        } # End of FSRMFileScreen Resource

        FSRMFileScreenAction DUsersFileScreenSomeFilesEmail
        {
            Path = 'd:\users'
            Ensure = 'Present'
            Type = 'Email'
            Subject = 'Unauthorized file matching [Violated File Group] file group detected'
            Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
            MailBCC = ''
            MailCC = 'fileserveradmins@contoso.com'
            MailTo = '[Source Io Owner Email]'
            DependsOn = '[FSRMFileScreen]DUsersFileScreen'
        } # End of FSRMFileScreenAction Resource

        FSRMFileScreenAction DUsersFileScreenSomeFilesEvent
        {
            Path = 'd:\users'
            Ensure = 'Present'
            Type = 'Event'
            Body = 'The system detected that user [Source Io Owner] attempted to save [Source File Path] on [File Screen Path] on server [Server]. This file matches the [Violated File Group] file group which is not permitted on the system.'
            EventType = 'Warning'
            DependsOn = '[FSRMFileScreen]DUsersFileScreen'
        } # End of FSRMFileScreenAction Resource

        FSRMFileScreenException DUsersFileScreenException
        {
            Path = 'd:\users'
            Description = 'File Screen Exclusion'
            Ensure = 'Present'
            IncludeGroup = 'E-mail Files'
        } # End of FSRMFileScreenException Resource

        FSRMClassificationProperty PrivacyClasificationProperty
        {
            Name = 'Privacy'
            DisplayName = 'File Privacy'
            Description = 'File Privacy Property'
            Ensure = 'Present'
            Type = 'SingleChoice'
            PossibleValue = 'Top Secret','Secret','Confidential','Public'
            Parameters = 'Parameter1=Value1','Parameter2=Value2'
        } # End of FSRMClassificationProperty Resource

        FSRMClassificationPropertyValue PublicClasificationPropertyValue
        {
            Name = 'Public'
            PropertyName = 'Privacy'
            Description = 'Publically accessible files.'
            Ensure = 'Present'
            DependsOn = '[FSRMClassificationProperty]PrivacyClasificationProperty'
        } # End of FSRMClassificationPropertyValue Resource

        FSRMClassificationPropertyValue SecretClasificationPropertyValue
        {
            Name = 'Secret'
            PropertyName = 'Privacy'
            Ensure = 'Present'
            DependsOn = '[FSRMClassificationProperty]PrivacyClasificationProperty'
        } # End of FSRMClassificationPropertyValue Resource
        FSRMClassification FSRMClassificationSettings
        {
            Id = 'Default'
            Continuous = $true
            ContinuousLog = $true
            ContinuousLogSize = 2048
            ScheduleWeekly = 'Monday','Tuesday','Wednesday'
            ScheduleRunDuration = 4
            ScheduleTime = '23:30'
        } # End of FSRMClassification Resource
        FSRMClassificationRule ConfidentialPrivacyClasificationRule
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
        } # End of FSRMClassificationRule Resource
    }
}
