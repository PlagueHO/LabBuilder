<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FAILOVERCLUSTER_HV
.Desription
    Builds a Network failover clustering node Hyper-V. It also starts the iSCSI Initiator and connects
    to any specified iSCSI Targets.
.Parameters:    
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    PSDscAllowDomainUser = $True
#########################################################################################################################################>
Configuration MEMBER_FAILOVERCLUSTER_HV
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration' -ModuleVersion 1.1
	Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.4.0.0 # Current as of 8 Feb 2016
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 3.7.0.0 # Current as of 28 Feb 2016
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
    }
}
