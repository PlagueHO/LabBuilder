<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FILESERVER
.Desription
    Builds a Server that is joined to a domain and then made into a File Server.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
###################################################################################################>

Configuration FILESERVER
{

     Param
    (
        # Set the Domain Name
        [Parameter(Mandatory=$True,Position=1)]
        [System.String]
        $DomainName,

        # Local Administrator Credentials
        [Parameter(Mandatory=$True)]
        [System.String]
        $LocalAdminPassword,

        # Domain Administrator Credentials
        [Parameter(Mandatory=$True)]
        [ParameterType]
        $DomainAdminPassword,

        # Disks for File server use
        [Parameter(AttributeValues)]
        [hashtable]
        $Disks


    )

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName NetworkingDsc

        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        if ($Node.DomainAdminPassword) {
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


        # Enable FSRM FireWall rules so we can remote manage FSRM
        Firewall FSRMFirewall1
        {
            Name = "FSRM-WMI-ASYNC-In-TCP"
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall2
        {
            Name = "FSRM-WMI-WINMGMT-In-TCP"
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall3
        {
            Name = "FSRM-RemoteRegistry-In (RPC)"
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall4
        {
            Name = "FSRM-Task-Scheduler-In (RPC)"
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall5
        {
            Name = "FSRM-SrmReports-In (RPC)"
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall6
        {
            Name = "FSRM-RpcSs-In (RPC-EPMAP)"
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall7
        {
            Name = "FSRM-System-In (TCP-445)"
            Ensure = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall8
        {
            Name = "FSRM-SrmSvc-In (RPC)"
            Ensure = 'Present'
            Enabled = 'True'
        }

        [Int]$Count=0
        ForEach ($Disk in $Disks) {
        $Count++

        WaitforDisk Disk$Count
        {
            DiskNumber = $Disk.Number
            RetryIntervalSec = 60
            RetryCount = 60
        }

        Disk Volume$Count
        {
            DiskNumber = $Disk.Number
            DriveLetter = $Disk.Letter
            DependsOn = "[WaitforDisk]Disk$Count"
        }
      }
}
