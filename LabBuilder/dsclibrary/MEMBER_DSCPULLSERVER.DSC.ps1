<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_DSCPULLSERVER
.Desription
    Builds a Server that is joined to a domain and then made into an DSC Pull Server.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
    Port = 8080
    PhysicalPath = "D:\inetpub\PSDSCPullServer"
    # Set to a valid certificate thumbprint to allow HTTP traffic
    CertificateThumbprint = 'AllowUnencryptedTraffic'
    RegistrationKey = '140a952b-b9d6-406b-b416-e0f759c9c0e4'
###################################################################################################>

Configuration MEMBER_DSCPULLSERVER
{
    Import-DSCResource -ModuleName xPSDesiredStateConfiguration

    Node $NodeName
    {
        WindowsFeature DSCServiceFeature
        {
            Ensure = 'Present'
            Name   = 'DSC-Service'
        }

        xDscWebService PSDSCPullServer
        {
            Ensure                  = 'Present'
            EndpointName            = 'PSDSCPullServer'
            Port                    = $Node.Port
            PhysicalPath            = $Node.PhysicalPath
            CertificateThumbPrint   = $Node.CertificateThumbprint
            ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
            State                   = 'Started'
            DependsOn               = '[WindowsFeature]DSCServiceFeature'
        }

        File RegistrationKeyFile
        {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }
    }
}
