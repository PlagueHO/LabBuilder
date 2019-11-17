<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FAILOVERCLUSTER_HV
.Desription
    Builds a Network failover clustering node Hyper-V.
    It also optionally starts the iSCSI Initiator and connects to any specified iSCSI Targets.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    ISCSIServerName = 'SA-FS1'
    ServerTargetName = 'sa-foc-target'
    TargetPortalAddress = '192.168.129.24'
    InitiatorPortalAddress = '192.168.129.28'
###################################################################################################>

Configuration MEMBER_FAILOVERCLUSTER_HV
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

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

        WindowsFeature FailoverClusteringInstall
        {
            Ensure = 'Present'
            Name   = 'Failover-Clustering'
        }

        WindowsFeature FailoverClusteringPSInstall
        {
            Ensure = 'Present'
            Name   = 'RSAT-Clustering-PowerShell'
        }

        WindowsFeature InstallHyperV
        {
            Ensure = 'Present'
            Name   = 'Hyper-V'
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
    }
}
