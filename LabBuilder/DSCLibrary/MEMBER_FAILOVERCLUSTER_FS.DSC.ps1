<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FAILOVERCLUSTER_FS
.Desription
    Builds a Network failover clustering node for use as a File Server.
    It also starts the iSCSI Initiator and connects to any specified iSCSI Targets.
.Parameters:    
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
    ServerTargetName = 'sa-foc-target'
    TargetPortalAddress = '192.168.129.24'
    InitiatorPortalAddress = '192.168.129.28'
###################################################################################################>

Configuration MEMBER_FAILOVERCLUSTER_FS
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName ciscsi
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
            DependsOn = "[WindowsFeature]FailoverClusteringInstall" 
        } 

        WindowsFeature FileServerInstall 
        { 
            Ensure = "Present" 
            Name = "FS-FileServer" 
            DependsOn = "[WindowsFeature]FailoverClusteringPSInstall" 
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
                NodeName = $Node.ServerTargetName
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
        }    
    }
}
