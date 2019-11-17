<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_ADRMS
.Desription
    Builds a Server that is joined to a domain and then made into an ADRMS Server.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    ADFSSupport = $true
###################################################################################################>

Configuration MEMBER_ADRMS
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

        WindowsFeature ADRMSServerInstall
        {
            Ensure    = 'Present'
            Name      = 'ADRMS-Server'
            DependsOn = '[WindowsFeature]WIDInstall'
        }

        if ($Node.ADFSSupport)
        {
            WindowsFeature ADRMSIdentityInstall
            {
                Ensure    = 'Present'
                Name      = 'ADRMS-Identity'
                DependsOn = '[WindowsFeature]ADRMSServerInstall'
            }
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
    }
}
