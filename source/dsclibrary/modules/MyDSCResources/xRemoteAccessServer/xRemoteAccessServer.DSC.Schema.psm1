<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_EDGE
.Desription
    Builds a Server that is joined to a domain and then contains Remote Access components.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
###################################################################################################>

Configuration REMOTEACCESS
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration


        WindowsFeature DirectAccessVPNInstall
        {
            Ensure = "Present"
            Name = "DirectAccess-VPN"
        }

        WindowsFeature RoutingInstall
        {
            Ensure = "Present"
            Name = "Routing"
            DependsOn = "[WindowsFeature]DirectAccessVPNInstall"
        }


}
