<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_NPS
.Desription
    Builds a Server that is joined to a domain and then contains NPS/Radius components.
.Requires
    Windows Server 2012 R2 Full (Server core not supported).
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
###################################################################################################>

Configuration NPS
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration


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


}
