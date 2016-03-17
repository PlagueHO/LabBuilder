<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_BRANCHCACHE_HOST
.Desription
    Builds a Server that is joined to a domain and then made into a BranchCache Hosted Mode Server.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration MEMBER_BRANCHCACHE_HOST
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

        WindowsFeature BranchCache 
        { 
            Ensure = "Present" 
            Name = "BranchCache" 
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

        # Enable BranchCache Hosted Mode Firewall Fules
        xFirewall FSRMFirewall1
        {
            Name = "Microsoft-Windows-PeerDist-HostedServer-In"
            Ensure = 'Present'
            Enabled = 'True'
        }

        xFirewall FSRMFirewall2
        {
            Name = "Microsoft-Windows-PeerDist-HostedServer-Out"
            Ensure = 'Present'
            Enabled = 'True' 
        }
    }
}
