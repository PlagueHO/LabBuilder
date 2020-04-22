<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_NPS
.Desription
    Builds a Server that is joined to a domain and then contains NPS/Radius components.
.Requires
    Windows Server 2012 R2 Full (Server core not supported).
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
###################################################################################################>

Configuration MEMBER_NPS
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0

    Node $AllNodes.NodeName {
        # Assemble the Admin Credentials
        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature NPASPolicyServerInstall
        {
            Ensure = 'Present'
            Name   = 'NPAS-Policy-Server'
        }

        WindowsFeature NPASHealthInstall
        {
            Ensure    = 'Present'
            Name      = 'NPAS-Health'
            DependsOn = '[WindowsFeature]NPASPolicyServerInstall'
        }

        WindowsFeature RSATNPAS
        {
            Ensure    = 'Present'
            Name      = 'RSAT-NPAS'
            DependsOn = '[WindowsFeature]NPASPolicyServerInstall'
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
