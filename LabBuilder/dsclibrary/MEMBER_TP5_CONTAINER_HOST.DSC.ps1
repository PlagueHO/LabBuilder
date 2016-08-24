<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_TP5_CONTAINER_HOST
.Desription
    Builds a Server that is joined to a domain and then made into a Container Host with Docker.

    This should only be used on a Windows Server 2016 TP5 host.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration MEMBER_TP5_CONTAINER_HOST
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName xComputerManagement
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature ContainerInstall
        {
            Ensure = "Present"
            Name   = "Container"
        }

        WaitForAll DC
        {
            ResourceName     = '[xADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        xComputer JoinDomain
        {
            Name       = $Node.NodeName
            DomainName = $Node.DomainName
            Credential = $DomainAdminCredential
            DependsOn  = '[WaitForAll]DC'
        }

        File DockerDirectory
        {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = 'c:\Program Files\Docker\'
        }

        xRemoteFile DockerDaemon
        {
            Ensure          = 'Present'
            DestinationPath = 'c:\Program Files\Docker\dockerd.exe'
            Uri             = 'https://aka.ms/tp5/b/dockerd'
            DependsOn       = '[File]DockerDirectory'
        }

        xRemoteFile DockerDaemon
        {
            Ensure          = 'Present'
            DestinationPath = 'c:\Program Files\Docker\docker.exe'
            Uri             = 'https://aka.ms/tp5/b/docker'
            DependsOn       = '[File]DockerDirectory'
        }

        xEnvironment DockerPath
        {
            Ensure          = 'Present'
            Name            = 'Path'
            Value           = 'C:\Program Files\Docker'
            Path            = $True
            DependsOn       = '[File]DockerDirectory'
        }

        Script ADCSAdvConfig
        {
            SetScript = {
                & 'c:\Program Files\Docker\dockerd.exe' @('--register-service')
            }
            GetScript = {
                return @{
                    'Service' = (Get-Service -Name Docker).Name
                }
            }
            TestScript = {
                if (Get-Service -Name Docker -ErrorAction Stop) {
                    return $True
                }
                return $False
            }
            DependsOn = '[xRemoteFile]DockerDaemon'
        }

        xServiceSet DockerService
        {
            Ensure          = 'Present'
            Name            = 'Docker'
            StartupType     = 'Automatic'
            State           = 'Running'
            DependsOn       = '[File]DockerService'
        }
    }
}
