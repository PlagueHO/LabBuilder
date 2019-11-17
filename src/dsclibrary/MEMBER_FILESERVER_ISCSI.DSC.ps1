<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FILESERVER_ISCSI
.Desription
    Builds a Server that is joined to a domain and then made into a File Server.
    Configures a iSCSI targets and virtual disks.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
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
###################################################################################################>

Configuration MEMBER_FILESERVER_ISCSI
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName ISCSI

    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword)
        {
            $LocalAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ('Administrator', (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }

        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature FileServerInstall
        {
            Ensure = 'Present'
            Name   = 'FS-FileServer'
        }

        WindowsFeature DataDedupInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-Data-Deduplication'
            DependsOn = '[WindowsFeature]FileServerInstall'
        }

        WindowsFeature BranchCacheInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-BranchCache'
            DependsOn = '[WindowsFeature]DataDedupInstall'
        }

        WindowsFeature DFSNameSpaceInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-DFS-Namespace'
            DependsOn = '[WindowsFeature]BranchCacheInstall'
        }

        WindowsFeature DFSReplicationInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-DFS-Replication'
            DependsOn = '[WindowsFeature]DFSNameSpaceInstall'
        }

        WindowsFeature FSResourceManagerInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-Resource-Manager'
            DependsOn = '[WindowsFeature]DFSReplicationInstall'
        }

        WindowsFeature FSSyncShareInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-SyncShareService'
            DependsOn = '[WindowsFeature]FSResourceManagerInstall'
        }

        WindowsFeature StorageServicesInstall
        {
            Ensure    = 'Present'
            Name      = 'Storage-Services'
            DependsOn = '[WindowsFeature]FSSyncShareInstall'
        }

        WindowsFeature ISCSITargetServerInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-iSCSITarget-Server'
            DependsOn = '[WindowsFeature]StorageServicesInstall'
        }

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        # Join this Server to the Domain
        Computer JoinDomain
        {
            Name       = $Node.NodeName
            DomainName = $Node.DomainName
            Credential = $DomainAdminCredential
            DependsOn  = '[WaitForAll]DC'
        }

        # Enable FSRM FireWall rules so we can remote manage FSRM
        Firewall FSRMFirewall1
        {
            Name    = 'FSRM-WMI-ASYNC-In-TCP'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall2
        {
            Name    = 'FSRM-WMI-WINMGMT-In-TCP'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall3
        {
            Name    = 'FSRM-RemoteRegistry-In (RPC)'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall4
        {
            Name    = 'FSRM-Task-Scheduler-In (RPC)'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall5
        {
            Name    = 'FSRM-SrmReports-In (RPC)'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall6
        {
            Name    = 'FSRM-RpcSs-In (RPC-EPMAP)'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall7
        {
            Name    = 'FSRM-System-In (TCP-445)'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        Firewall FSRMFirewall8
        {
            Name    = 'FSRM-SrmSvc-In (RPC)'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        WaitforDisk Disk2
        {
            DiskId           = 1
            RetryIntervalSec = 60
            RetryCount       = 60
            DependsOn        = '[Computer]JoinDomain'
        }

        Disk DVolume
        {
            DiskId      = 1
            DriveLetter = 'D'
            DependsOn   = '[WaitforDisk]Disk2'
        }

        File VirtualDisksFolder
        {
            Ensure          = 'Present'
            DestinationPath = 'D:\iSCSIVirtualDisks'
            Type            = 'Directory'
            DependsOn       = '[Disk]DVolume'
        }

        $DependsOn = '[File]VirtualDisksFolder'
        [System.Int32] $count = 0
        foreach ($VirtualDisk in $Node.VirtualDisks)
        {
            $count++
            $Name = "$($Node.TargetName)_Disk_$count"
            ISCSIVirtualDisk $Name
            {
                Ensure      = 'Present'
                Path        = $VirtualDisk.Path
                DiskType    = $VirtualDisk.DiskType
                SizeBytes   = $VirtualDisk.SizeBytes
                Description = $VirtualDisk.Description
                DependsOn   = $DependsOn
            }
            $DependsOn = "[ISCSIVirtualDisk]$Name"
        }

        ISCSIServerTarget ClusterServerTarget
        {
            Ensure       = 'Present'
            TargetName   = $Node.TargetName
            InitiatorIds = $Node.ClusterInitiatorIds
            Paths        = $Node.VirtualDisks.Path
            DependsOn    = $DependsOn
        }
    }
}
