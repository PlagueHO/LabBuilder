<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_SQLSERVER2014
.Desription
    Builds a Server that is joined to a domain and then installs SQL Server 2014.
    
    This conifguration is not complete.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration MEMBER_SQLSERVER2014
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

        # Install the SQL Server Dependencies
        WindowsFeature Net35Install
        {
            Name = 'NET-Framework-Core'
            Ensure = 'Present'
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
