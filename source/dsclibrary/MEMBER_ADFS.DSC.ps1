<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_ADFS
.Desription
    Builds a Server that is joined to a domain and then made into an ADFS Server using WID.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
###################################################################################################>

Configuration MEMBER_ADFS
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0

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

        WindowsFeature WIDInstall
        {
            Ensure = 'Present'
            Name   = 'Windows-Internal-Database'
        }

        WindowsFeature ADFSInstall
        {
            Ensure    = 'Present'
            Name      = 'ADFS-Federation'
            DependsOn = '[WindowsFeature]WIDInstall'
        }

        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        Computer JoinDomain
        {
            Name       = $Node.NodeName
            DomainName = $Node.DomainName
            Credential = $DomainAdminCredential
            DependsOn  = '[WaitForAll]DC'
        }

        # Enable ADFS FireWall rules
        Firewall ADFSFirewall1
        {
            Name    = 'ADFSSrv-HTTP-In-TCP'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        Firewall ADFSFirewall2
        {
            Name    = 'ADFSSrv-HTTPS-In-TCP'
            Ensure  = 'Present'
            Enabled = 'True'
        }

        Firewall ADFSFirewall3
        {
            Name    = 'ADFSSrv-SmartcardAuthN-HTTPS-In-TCP'
            Ensure  = 'Present'
            Enabled = 'True'
        }
    }
}
