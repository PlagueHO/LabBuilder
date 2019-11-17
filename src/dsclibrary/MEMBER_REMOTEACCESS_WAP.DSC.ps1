<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_REMOTEACCESS_WAP
.Desription
    Builds a Server that is joined to a domain and then contains Remote Access and
    Web Application Proxy components.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
###################################################################################################>

Configuration MEMBER_REMOTEACCESS_WAP
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0

    Node $AllNodes.NodeName {
        # Assemble the  Admin Credentials
        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature DirectAccessVPNInstall
        {
            Ensure = 'Present'
            Name   = 'DirectAccess-VPN'
        }

        WindowsFeature RoutingInstall
        {
            Ensure    = 'Present'
            Name      = 'Routing'
            DependsOn = '[WindowsFeature]DirectAccessVPNInstall'
        }

        WindowsFeature WebApplicationProxyInstall
        {
            Ensure    = 'Present'
            Name      = 'Web-Application-Proxy'
            DependsOn = '[WindowsFeature]RoutingInstall'
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
    }
}
