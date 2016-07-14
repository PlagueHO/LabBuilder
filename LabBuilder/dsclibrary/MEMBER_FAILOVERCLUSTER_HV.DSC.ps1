<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FAILOVERCLUSTER_HV
.Desription
    Builds a Network failover clustering node Hyper-V.
    It also optionally starts the iSCSI Initiator and connects to any specified iSCSI Targets.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
    ISCSIServerName = 'SA-FS1'
    ServerTargetName = 'sa-foc-target'
    TargetPortalAddress = '192.168.129.24'
    InitiatorPortalAddress = '192.168.129.28'
###################################################################################################>

Configuration MEMBER_FAILOVERCLUSTER_HV
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature FailoverClusteringInstall
        {
            Ensure = "Present" 
            Name = "Failover-Clustering" 
        }

        WindowsFeature FailoverClusteringPSInstall
        {
            Ensure = "Present" 
            Name = "RSAT-Clustering-PowerShell" 
        }

        WindowsFeature InstallHyperV
        {
            Ensure = "Present" 
            Name = "Hyper-V" 
        }

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
        ResourceName      = '[xADDomain]PrimaryDC'
        NodeName          = $Node.DCname
        RetryIntervalSec  = 15
        RetryCount        = 60
        }
        
        # Join this Server to the Domain so that it can be an Enterprise CA.
        xComputer JoinDomain 
        { 
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential 
            DependsOn = "[WaitForAll]DC" 
        }

        if ($Node.ServerTargetName)
        {
            # Ensure the iSCSI Initiator service is running
            Service iSCSIService 
            { 
                Name = 'MSiSCSI'
                StartupType = 'Automatic'
                State = 'Running'
            }

            # Wait for the iSCSI Server Target to become available
            WaitForAny WaitForiSCSIServerTarget
            {
                ResourceName = "[ciSCSIServerTarget]ClusterServerTarget"
                NodeName = $Node.ServerName
                RetryIntervalSec = 30
                RetryCount = 30
                DependsOn = "[Service]iSCSIService"
            }

            # Connect the Initiator
            ciSCSIInitiator iSCSIInitiator
            {
                Ensure = 'Present'
                NodeAddress = "iqn.1991-05.com.microsoft:$($Node.ServerTargetName)"
                TargetPortalAddress = $Node.TargetPortalAddress
                InitiatorPortalAddress = $Node.InitiatorPortalAddress
                IsPersistent = $true 
                DependsOn = "[WaitForAny]WaitForiSCSIServerTarget" 
            } # End of ciSCSITarget Resource

            # Enable iSCSI FireWall rules so that the Initiator can be added to iSNS
            xFirewall iSCSIFirewallIn
            {
                Name = "MsiScsi-In-TCP"
                Ensure = 'Present'
                Enabled = 'True'
            }
            xFirewall iSCSIFirewallOut
            {
                Name = "MsiScsi-Out-TCP"
                Ensure = 'Present'
                Enabled = 'True'
            }
        }
    }
}
