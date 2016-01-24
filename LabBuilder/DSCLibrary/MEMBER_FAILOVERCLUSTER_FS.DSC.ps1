<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FAILOVERCLUSTER_FS
.Desription
    Builds a Network failover clustering node for use as a File Server.
    It also starts the iSCSI Initiator and connects to any specified iSCSI Targets.
.Parameters:    
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    PSDscAllowDomainUser = $True
    ServerTargetName = 'sa-foc-target'
    TargetPortalAddress = '192.168.129.24'
    InitiatorPortalAddress = '192.168.129.28'
#########################################################################################################################################>
Configuration MEMBER_FAILOVERCLUSTER_FS
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration' -ModuleVersion 1.1
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName ciSCSI
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        # Install the RSAT PowerShell Module which is required by the xWaitForResource
        WindowsFeature RSATADPowerShell
        { 
            Ensure = "Present" 
            Name = "RSAT-AD-PowerShell" 
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

        # Wait for the Domain to be available so we can join it.
        xWaitForADDomain DscDomainWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $DomainAdminCredential 
            RetryCount = 100 
            RetryIntervalSec = 10 
            DependsOn = "[WindowsFeature]RSATADPowerShell" 
        }

        # Join this Server to the Domain so that it can be an Enterprise CA.
        xComputer JoinDomain 
        { 
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential 
            DependsOn = "[xWaitForADDomain]DscDomainWait" 
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
