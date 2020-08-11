<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_CONTAINER_HOST
.Desription
    Builds a Server that is joined to a domain and then made into a Container Host with Docker.

    This should only be used on a Windows Server 2016 RTM host.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
###################################################################################################>

Configuration MEMBER_CONTAINER_HOST
{
    $ProgramFiles = $ENV:ProgramFiles
    $DockerPath = Join-Path -Path $ProgramFiles -ChildPath 'Docker'
    $DockerZipFileName = 'docker.zip'
    $DockerZipPath = Join-Path -Path $ProgramFiles -ChildPath $DockerZipFilename
    $DockerUri = 'https://download.docker.com/components/engine/windows-server/cs-1.12/docker.zip'

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0

    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword)
        {
            $LocalAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArguementList ('Administrator', (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }

        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArguementList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
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

        # Install containers feature
        WindowsFeature ContainerInstall
        {
            Ensure = 'Present'
            Name   = 'Containers'
        }

        # Download Docker Engine
        xRemoteFile DockerEngineDownload
        {
            DestinationPath = $ProgramFiles
            Uri             = $DockerUri
            MatchSource     = $false
        }

        # Extract Docker Engine zip file
        xArchive DockerEngineExtract
        {
            Destination = $ProgramFiles
            Path        = $DockerZipPath
            Ensure      = 'Present'
            Validate    = $false
            Force       = $true
            DependsOn   = '[xRemoteFile]DockerEngineDownload'
        }

        # Add Docker to the Path
        xEnvironment DockerPath
        {
            Ensure    = 'Present'
            Name      = 'Path'
            Value     = $DockerPath
            Path      = $true
            DependsOn = '[xArchive]DockerEngineExtract'
        }

        <#
            Reboot the system to complete Containers feature setup
            Perform this after setting the Environment variable
            so that PowerShell and other consoles can access it.
        #>
        PendingReboot Reboot
        {
            Name = 'Reboot After Containers'
        }

        # Install the Docker Daemon as a service
        Script DockerService
        {
            SetScript  = {
                $DockerDPath = (Join-Path -Path $Using:DockerPath -ChildPath 'dockerd.exe')
                & $DockerDPath @('--register-service')
            }
            GetScript  = {
                return @{
                    'Service' = (Get-Service -Name Docker).Name
                }
            }
            TestScript = {
                if (Get-Service -Name Docker -ErrorAction SilentlyContinue)
                {
                    return $true
                }
                return $false
            }
            DependsOn  = '[xArchive]DockerEngineExtract'
        }

        <#
            Start up the Docker Service and ensure it is set
            to start up automatically.
        #>
        xServiceSet DockerService
        {
            Ensure      = 'Present'
            Name        = 'Docker'
            StartupType = 'Automatic'
            State       = 'Running'
            DependsOn   = '[Script]DockerService'
        }
    }
}
