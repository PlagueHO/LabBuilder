<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_DSCPULLSERVER
.Desription
    Builds a Server that is joined to a domain and then made into an DSC Pull Server.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    Port = 8080
    PhysicalPath = 'D:\inetpub\PSDSCPullServer'
    # Set to a valid certificate thumbprint to allow HTTP traffic
    CertificateThumbprint = 'AllowUnencryptedTraffic'
    RegistrationKey = '140a952b-b9d6-406b-b416-e0f759c9c0e4'
###################################################################################################>

Configuration MEMBER_DSCPULLSERVER
{
    Import-DSCResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName xWebAdministration

    Node $AllNodes.NodeName {
        # Assemble the Admin Credentials
        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature IISInstall
        {
            Ensure = 'Present'
            Name   = 'Web-Server'
        }

        WindowsFeature AspNet45Install
        {
            Ensure = 'Present'
            Name   = 'Web-Asp-Net45'
        }

        WindowsFeature WebMgmtServiceInstall
        {
            Ensure = 'Present'
            Name   = 'Web-Mgmt-Service'
        }

        WindowsFeature DSCServiceFeature
        {
            Ensure = 'Present'
            Name   = 'DSC-Service'
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

        xDscWebService PSDSCPullServer
        {
            Ensure                = 'Present'
            EndpointName          = 'PSDSCPullServer'
            Port                  = $Node.Port
            PhysicalPath          = $Node.PhysicalPath
            CertificateThumbPrint = $Node.CertificateThumbprint
            ModulePath            = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            ConfigurationPath     = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
            State                 = 'Started'
            DependsOn             = '[WindowsFeature]DSCServiceFeature'
        }

        File RegistrationKeyFile
        {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $Node.RegistrationKey
        }
    }
}
