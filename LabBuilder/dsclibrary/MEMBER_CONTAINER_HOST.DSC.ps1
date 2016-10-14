<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_CONTAINER_HOST
.Desription
    Builds a Server that is joined to a domain and then made into a Container Host with Docker.

    This should only be used on a Windows Server 2016 RTM host.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration MEMBER_CONTAINER_HOST
{
    $DockerPath = 'c:\Program Files\Docker'
    $DockerZipFileName = 'docker.zip'
    $DockerZipPath = (Join-Path -Path $DockerPath -ChildPath $DockerZipFilename)
    $DockerUri = 'https://download.docker.com/components/engine/windows-server/cs-1.12/docker.zip'

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
            DestinationPath = $DockerZipPath
        }

        xRemoteFile DockerEngine
        {
            Ensure          = 'Present'
            DestinationPath = $DockerZipPath
            Uri             = $DockerUri
            DependsOn       = '[File]DockerDirectory'
        }

        xEnvironment DockerEngineExtract
        {
              Destination   = $DockerPath
              Path          = $DockerZipPath
              Ensure        = 'Present'
              Validate      = $false
              Force         = $true
        }

        xEnvironment DockerPath
        {
            Ensure          = 'Present'
            Name            = 'Path'
            Value           = $DockerPath
            Path            = $True
            DependsOn       = '[File]DockerDirectory'
        }

        Script DockerService
        {
            SetScript = {
                $DockerDPath = (Join-Path -Path $Using:DockerPath -ChildPath 'dockerd.exe')
                & $DockerDPath @('--register-service')
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
