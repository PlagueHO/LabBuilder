<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FILESERVER
.Desription
    Builds a Server that is joined to a domain and then made into a File Server.
.Parameters:          
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration MEMBER_FILESERVER
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xStorage
    Import-DscResource -ModuleName xNetworking
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
    }
}
