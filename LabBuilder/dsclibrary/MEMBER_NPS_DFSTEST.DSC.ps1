<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_NPS_SPECIAL
.Desription
    Builds a Server that is joined to a domain and then contains NPS/Radius components.

    ** This is a special version that is used for testing the cDFS resource because
    ** it requires a full server (not core) installation to work.
.Requires
    Windows Server 2012 R2 Full (Server core not supported).
.Parameters:          
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration MEMBER_NPS_DFSTEST
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName cDFS
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature NPASPolicyServerInstall 
        {
            Ensure = "Present" 
            Name = "NPAS-Policy-Server" 
        }

        WindowsFeature NPASHealthInstall 
        {
            Ensure = "Present" 
            Name = "NPAS-Health" 
            DependsOn = "[WindowsFeature]NPASPolicyServerInstall" 
        }

        WindowsFeature RSATNPAS
        {
            Ensure = "Present" 
            Name = "RSAT-NPAS" 
            DependsOn = "[WindowsFeature]NPASPolicyServerInstall" 
        }

        WindowsFeature RSATDFSMgmtConInstall 
        {
            Ensure = "Present" 
            Name = "RSAT-DFS-Mgmt-Con" 
            DependsOn = "[WindowsFeature]RSATNPAS" 
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
        
        cDFSRepGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'SA_FS1','SA_FS2'
            Folders = 'Software','Misc'
            Topology = 'Fullmesh'
            ContentPaths = 'd:\public\Software','d:\public\Misc'
            PSDSCRunAsCredential = $DomainAdminCredential
            DependsOn = '[xComputer]JoinDomain'
        } # End of RGPublic Resource
    }
}
