<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FILESERVER
.Desription
    Builds a Server that is joined to a domain and then made into a File Server.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    SpokeComputerName = @('Spoke1','Spoke2')
    ResourceGroupName = 'WebSite'
    ResourceGroupDescription = 'Files for web server'
    ResourceGroupFolderName = 'WebSiteFiles'
    ResourceGroupContentPath = 'd:\inetpub\wwwroot\WebSiteFiles'
###################################################################################################>

Configuration MEMBER_DFSHUB
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName DFSDsc
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName NetworkingDsc

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

        WindowsFeature DFSNameSpaceInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-DFS-Namespace'
            DependsOn = '[WindowsFeature]FileServerInstall'
        }

        WindowsFeature DFSReplicationInstall
        {
            Ensure    = 'Present'
            Name      = 'FS-DFS-Replication'
            DependsOn = '[WindowsFeature]DFSNameSpaceInstall'
        }

        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = 'Present'
            Name   = 'RSAT-DFS-Mgmt-Con'
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

        WaitForAll WaitForAllSpokes
        {
            ResourceName     = '[Disk]DVolume'
            NodeName         = $Node.SpokeComputerName
            RetryIntervalSec = 30
            RetryCount       = 30
            DependsOn        = '[Computer]JoinDomain'
        }

        # Configure the Replication Group
        DFSReplicationGroup RGWebSite
        {
            GroupName            = $Node.ResourceGroupName
            Description          = $Node.ResourceGroupDescription
            Ensure               = 'Present'
            DomainName           = $Node.DomainName
            Members              = @() + $Node.NodeName + $Node.SpokeComputerName
            Folders              = $Node.ResourceGroupFolderName
            PSDSCRunAsCredential = $DomainAdminCredential
            DependsOn            = '[Disk]DVolume'
        } # End of RGWebSite Resource

        DFSReplicationGroupFolder RGWebSiteFolder
        {
            GroupName            = $Node.ResourceGroupName
            FolderName           = $Node.ResourceGroupFolderName
            DomainName           = $Node.DomainName
            Description          = $Node.ResourceGroupDescription
            PSDSCRunAsCredential = $DomainAdminCredential
            DependsOn            = '[DFSReplicationGroup]RGWebSite'
        } # End of RGWebSiteFolder Resource

        DFSReplicationGroupMembership RGWebSiteMembershipHub
        {
            GroupName            = $Node.ResourceGroupName
            FolderName           = $Node.ResourceGroupFolderName
            DomainName           = $Node.DomainName
            ComputerName         = $Node.NodeName
            ContentPath          = $Node.ResourceGroupContentPath
            PrimaryMember        = $true
            PSDSCRunAsCredential = $DomainAdminCredential
            DependsOn            = '[DFSReplicationGroupFolder]RGWebSiteFolder'
        } # End of RGWebSiteMembershipHub Resource

        # Configure the connection and membership for each Spoke
        foreach ($spoke in $Node.SpokeComputerName)
        {
            DFSReplicationGroupConnection "RGWebSiteConnection$spoke"
            {
                GroupName               = $Node.ResourceGroupName
                DomainName              = $Node.DomainName
                Ensure                  = 'Present'
                SourceComputerName      = $Node.NodeName
                DestinationComputerName = $spoke
                PSDSCRunAsCredential    = $DomainAdminCredential
                DependsOn               = '[DFSReplicationGroupFolder]RGWebSiteFolder'
            } # End of RGWebSiteConnection$spoke Resource

            DFSReplicationGroupMembership "RGWebSiteMembership$spoke"
            {
                GroupName            = $Node.ResourceGroupName
                FolderName           = $Node.ResourceGroupFolderName
                DomainName           = $Node.DomainName
                ComputerName         = $spoke
                ContentPath          = $Node.ResourceGroupContentPath
                PSDSCRunAsCredential = $DomainAdminCredential
                DependsOn            = "[DFSReplicationGroupConnection]RGWebSiteConnection$spoke"
            } # End of RGWebSiteMembership$spoke Resource
        }
    }
}
