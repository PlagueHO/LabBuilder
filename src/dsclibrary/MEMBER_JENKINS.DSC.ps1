<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_JENKINS
.Desription
    Builds a Windows Server, joins it to a Domain and installs Jenkins CI on it.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    JenkinsPort = 80
###################################################################################################>

Configuration MEMBER_JENKINS
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName cChoco
    Import-DscResource -ModuleName NetworkingDsc

    Node $AllNodes.NodeName {
        # Assemble the Admin Credentials
        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature NetFrameworkCore
        {
            Ensure = 'Present'
            Name   = 'NET-Framework-Core'
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

        # Install Chocolatey
        cChocoInstaller installChoco
        {
            InstallDir = 'c:\choco'
            DependsOn  = '[WindowsFeature]NetFrameworkCore'
        }

        # Install JDK8
        cChocoPackageInstaller installJdk8
        {
            Name      = 'jdk8'
            DependsOn = '[cChocoInstaller]installChoco'
        }

        # Install Jenkins
        cChocoPackageInstaller installJenkins
        {
            Name      = 'Jenkins'
            DependsOn = '[cChocoInstaller]installChoco'
        }

        # Set the Jenkins Port
        $JenkinsPort = 8080
        if ($Node.JenkinsPort)
        {
            $JenkinsPort = $Node.JenkinsPort
        }
        Script SetJenkinsPort
        {
            SetScript  = {
                Write-Verbose -Message "Setting Jenkins Port to $Using:JenkinsPort"
                $Config = Get-Content `
                    -Path "${ENV:ProgramFiles(x86)}\Jenkins\Jenkins.xml"
                $NewConfig = $Config `
                    -replace '--httpPort=[0-9]*\s', "--httpPort=$Using:JenkinsPort "
                Set-Content `
                    -Path "${ENV:ProgramFiles(x86)}\Jenkins\Jenkins.xml" `
                    -Value $NewConfig `
                    -Force
                Write-Verbose -Message 'Restarting Jenkins'
                Restart-Service `
                    -Name Jenkins
            }
            GetScript  = {
                $Config = Get-Content `
                    -Path "${ENV:ProgramFiles(x86)}\Jenkins\Jenkins.xml"
                $Matches = @([regex]::matches($Config, "--httpPort=([0-9]*)\s", 'IgnoreCase'))
                $CurrentPort = $Matches.Groups[1].Value
                Return @{
                    'JenkinsPort' = $CurrentPort
                }
            }
            TestScript = {
                $Config = Get-Content `
                    -Path "${ENV:ProgramFiles(x86)}\Jenkins\Jenkins.xml"
                $Matches = @([regex]::matches($Config, "--httpPort=([0-9]*)\s", 'IgnoreCase'))
                $CurrentPort = $Matches.Groups[1].Value

                if ($Using:JenkinsPort -ne $CurrentPort)
                {
                    # Jenkins port must be changed
                    Return $false
                }
                # Jenkins is already on correct port
                Return $true
            }
            DependsOn  = '[cChocoPackageInstaller]installJenkins'
        }
    }
}
