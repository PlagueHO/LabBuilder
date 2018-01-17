<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    DC_FORESTPRIMARY
.Desription
    Builds a Domain Controller as the first DC in a forest with the name of the Domain Name parameter passed.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
###################################################################################################>

Configuration DC
{
    Param
    (
        # Set the Domain Name
        [Parameter(Mandatory=$True,Position=1)]
        [System.String]
        $DomainName,

        # Set the Domain Controller Name
        [Parameter(Mandatory=$True)]
        [System.String]
        $DCName,

        # Local Administrator Credentials
        [Parameter(Mandatory=$True)]
        [System.String]
        $LocalAdminPassword,

        # Domain Administrator Credentials
        [Parameter(Mandatory=$True)]
        [System.String]
        $DomainAdminPassword,

        #OUs to Create
        [Parameter(Mandatory=$False)]
        [System.String]
        $OUName




    )




    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xDNSServer

        # Assemble the Local Admin Credentials
        If ($LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force))
        }
        If ($DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force))
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

        xADDomain CreateDC
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainAdminCredential
            SafemodeAdministratorPassword = $LocalAdminCredential
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential = $DomainAdminCredential
            RetryCount = 20
            RetryIntervalSec = 30
            DependsOn = "[xADDomain]CreateDC"
        }


		xADOrganizationalUnit NewOU
        {
			Name = $OUName
			Path = $OUPath
			ProtectedFromAccidentalDeletion = $true
			Description = $OUDescription
			Ensure = 'Present'
			DependsOn = "[xADDomain]CreateDC"
        }


}
