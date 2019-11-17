<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FAILOVERCLUSTER_FS
.Desription
    Builds a Network failover clustering node for use as a File Server.
    It also optionally starts the iSCSI Initiator and connects to any specified iSCSI Targets.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    ServerName = 'SA-FS1'
    ServerTargetName = 'sa-fs1-sa-foc-target-target'
    TargetPortalAddress = '192.168.129.24'
    InitiatorPortalAddress = '192.168.129.28'
###################################################################################################>

Configuration MEMBER_FAILOVERCLUSTER_FS
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName ISCSIDsc

    Node $AllNodes.NodeName {
        # Assemble the Admin Credentials
        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature FailoverClusteringInstall
        {
            Ensure = 'Present'
            Name   = 'Failover-Clustering'
        }

        WindowsFeature FailoverClusteringPSInstall
        {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-PowerShell'
            DependsOn = '[WindowsFeature]FailoverClusteringInstall'
        }

        WindowsFeature FileServerInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-FileServer'
            DependsOn = '[WindowsFeature]FailoverClusteringPSInstall'
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

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        # Join this Server to the Domain so that it can be an Enterprise CA.
        Computer JoinDomain
        {
            Name       = $Node.NodeName
            DomainName = $Node.DomainName
            Credential = $DomainAdminCredential
            DependsOn  = '[WaitForAll]DC'
        }

        if ($Node.ServerTargetName)
        {
            # Ensure the iSCSI Initiator service is running
            Service iSCSIService
            {
                Name        = 'MSiSCSI'
                StartupType = 'Automatic'
                State       = 'Running'
            }

            # Wait for the iSCSI Server Target to become available
            WaitForAny WaitForiSCSIServerTarget
            {
                ResourceName     = '[ISCSIServerTarget]ClusterServerTarget'
                NodeName         = $Node.ServerName
                RetryIntervalSec = 30
                RetryCount       = 30
                DependsOn        = '[Service]iSCSIService'
            }

            # Connect the Initiator
            ISCSIInitiator iSCSIInitiator
            {
                Ensure                 = 'Present'
                NodeAddress            = "iqn.1991-05.com.microsoft:$($Node.ServerTargetName)"
                TargetPortalAddress    = $Node.TargetPortalAddress
                InitiatorPortalAddress = $Node.InitiatorPortalAddress
                IsPersistent           = $true
                DependsOn              = '[WaitForAny]WaitForiSCSIServerTarget'
            } # End of ISCSITarget Resource

            # Enable iSCSI FireWall rules so that the Initiator can be added to iSNS
            Firewall iSCSIFirewallIn
            {
                Name    = 'MsiScsi-In-TCP'
                Ensure  = 'Present'
                Enabled = 'True'
            }
            Firewall iSCSIFirewallOut
            {
                Name    = 'MsiScsi-Out-TCP'
                Ensure  = 'Present'
                Enabled = 'True'
            }
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
    }
}
