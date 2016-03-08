<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    DC_FORESTDOMAIN
.Desription
    Builds a Domain Controller and creates it as the first DC in a new child domain within the
    existing forest specified in the DomainName parameter.
.Parameters:
    ParentDomainName = "LABBUILDER.COM"
    DomainName = "DEV"
    DomainAdminPassword = "P@ssword!1"
    PSDscAllowDomainUser = $True
###################################################################################################>

Configuration DC_FORESTDOMAIN
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xActiveDirectory
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.ParentDomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature BackupInstall
        {
            Ensure = "Present"
            Name = "Windows-Server-Backup"
        }

        WindowsFeature DNSInstall
        {
            Ensure = "Present"
            Name = "DNS"
        }

        WindowsFeature ADDSInstall
        { 
            Ensure = "Present"
            Name = "AD-Domain-Services"
            DependsOn = "[WindowsFeature]DNSInstall"
        } 
        
        WindowsFeature RSAT-AD-PowerShellInstall
        {
            Ensure = "Present"
            Name = "RSAT-AD-PowerShell"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        xWaitForADDomain DscDomainWait
        {
            DomainName = $Node.ParentDomainName
            DomainUserCredential = $DomainAdminCredential
            RetryCount = 100
            RetryIntervalSec = 10
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
        
        xADDomain PrimaryDC 
        { 
            DomainName = $Node.DomainName
            ParentDomainName = $Node.ParentDomainName
            DomainAdministratorCredential = $DomainAdminCredential
            SafemodeAdministratorPassword = $LocalAdminCredential
            DependsOn = "[xWaitForADDomain]DscDomainWait"
        }
    }
}
