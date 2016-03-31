<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_ADRMS
.Desription
    Builds a Server that is joined to a domain and then made into an ADRMS Server.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
    ADFSSupport = $True
###################################################################################################>

Configuration MEMBER_ADRMS
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature WIDInstall
        {
            Ensure = "Present"
            Name = "Windows-Internal-Database"
        }

        WindowsFeature ADRMSServerInstall
        {
            Ensure = "Present"
            Name = "ADRMS-Server"
            DependsOn = "[WindowsFeature]WIDInstall"
        }

        if ($Node.ADFSSupport)
        {
            WindowsFeature ADRMSIdentityInstall
            {
                Ensure = "Present"
                Name = "ADRMS-Identity"
                DependsOn = "[WindowsFeature]ADRMSServerInstall"
            }
        }
        
        WaitForAll DC
        {
            ResourceName      = '[xADDomain]PrimaryDC'
            NodeName          = $Node.DCname
            RetryIntervalSec  = 15
            RetryCount        = 60
        }

        xComputer JoinDomain
        { 
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential
            DependsOn     = "[WaitForAll]DC"
        }
    }
}
