<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    DC_FORESTPRIMARY
.Desription
    Builds a Domain Controller as the first DC in a forest with the name of the Domain Name parameter passed.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
###################################################################################################>

Configuration DC
{
    Param
    (
        # Set the Domain Name
        [Parameter(Mandatory=$true,Position=1)]
        [System.String]
        $DomainName,

        # Set the Domain Controller Name
        [Parameter(Mandatory=$true)]
        [System.String]
        $DCName,

        # Local Administrator Credentials
        [Parameter(Mandatory=$true)]
        [System.String]
        $LocalAdminPassword,

        # Domain Administrator Credentials
        [Parameter(Mandatory=$true)]
        [System.String]
        $DomainAdminPassword,

        #OUs to Create
        [Parameter(Mandatory=$false)]
        [System.String]
        $OUName
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion 4.1.0.0
    Import-DscResource -ModuleName xDNSServer -ModuleVersion 1.16.0.0

    # Assemble the Local Admin Credentials
    if ($LocalAdminPassword) {
        $LocalAdminCredential = New-Object `
            -TypeName System.Management.Automation.PSCredential `
            -ArgumentList ('Administrator', (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force))
    }

    if ($DomainAdminPassword) {
        $DomainAdminCredential = New-Object `
            -TypeName System.Management.Automation.PSCredential `
            -ArgumentList ('Administrator', (ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force))
    }

    WindowsFeature BackupInstall
    {
        Ensure = 'Present'
        Name = 'Windows-Server-Backup'
    }

    WindowsFeature DNSInstall
    {
        Ensure = 'Present'
        Name = 'DNS'
    }

    WindowsFeature ADDSInstall
    {
        Ensure = 'Present'
        Name = 'AD-Domain-Services'
        DependsOn = '[WindowsFeature]DNSInstall'
    }

    WindowsFeature RSAT-AD-PowerShellInstall
    {
        Ensure = 'Present'
        Name = 'RSAT-AD-PowerShell'
        DependsOn = '[WindowsFeature]ADDSInstall'
    }

    ADDomain ADDomainCreateDC
    {
        DomainName = $DomainName
        Credential                    = $DomainAdminCredential
        SafemodeAdministratorPassword = $LocalAdminCredential
        DependsOn = '[WindowsFeature]ADDSInstall'
    }

    WaitForADDomain DscDomainWait
    {
        DomainName   = $Node.ParentDomainName
        Credential   = $DomainAdminCredential
        WaitTimeout  = 300
        RestartCount = 5
        DependsOn    = '[WindowsFeature]ADDSInstall'
    }

    ADOrganizationalUnit NewOU
    {
        Name = $OUName
        Path = $OUPath
        ProtectedFromAccidentalDeletion = $true
        Description = $OUDescription
        Ensure = 'Present'
        DependsOn = '[WaitForADDomain]DscDomainWait'
    }
}
