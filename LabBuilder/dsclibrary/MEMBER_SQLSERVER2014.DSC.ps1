<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_SQLSERVER2014
.Desription
    Builds a Server that is joined to a domain and then installs SQL Server 2014.
    It will install SQLServer from a locally mounted ISO file.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
    InstallerUsername = 'Administrator'
    InstallerPassword = 'P@ssword!1'
    SQLAdminAccount = 'Administrator'
    SQLDataDrive = 'E'
    SourcePath = 'D:\'
    SourceFolder = ''
    Instances = @(
        @{
            Name = 'MSSQLSERVER'
            Features = 'SQLENGINE,FULLTEXT,RS,AS,IS'
        }
    )
    InstallManagementTools = $True
###################################################################################################>

Configuration MEMBER_SQLSERVER2014
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xStorage
    Import-DscResource -ModuleName xSQLServer
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }
        If ($Node.InstallerPassword) {
            [PSCredential]$InstallerCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\$($Node.InstallerUsername)", (ConvertTo-SecureString $Node.InstallerPassword -AsPlainText -Force))
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
            DependsOn     = '[WaitForAll]DC'
        }

        xWaitforDisk Disk2
        {
            DiskNumber = 1
            RetryIntervalSec = 60
            RetryCount = 60
            DependsOn = '[xComputer]JoinDomain'
        }
        
        xDisk DVolume
        {
            DiskNumber = 1
            DriveLetter = $Node.SQLDataDrive
            DependsOn = '[xWaitforDisk]Disk2'
        }

        foreach ($Instance in $Node.Instances)
        {
            $Features = $Instance.Features
            if ([String]::IsNullOrEmpty($Features))
            {
                $Features = 'SQLENGINE,FULLTEXT,RS,AS,IS'
            } # if
            xSqlServerSetup ($Instance.Name)
            {
                SourcePath          = $Node.SourcePath
                SourceFolder        = $Node.SourceFolder
                SetupCredential     = $InstallerCredential
                InstanceName        = $Instance.Name
                Features            = $Features
                SQLSysAdminAccounts = "$($Node.DomainName)\$($Node.SQLAdminAccount)"
                InstallSharedDir    = "C:\Program Files\Microsoft SQL Server"
                InstallSharedWOWDir = "C:\Program Files (x86)\Microsoft SQL Server"
                InstanceDir         = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server"
                InstallSQLDataDir   = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLUserDBDir        = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLUserDBLogDir     = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLTempDBDir        = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLTempDBLogDir     = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLBackupDir        = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                ASDataDir           = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Data"
                ASLogDir            = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Log"
                ASBackupDir         = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Backup"
                ASTempDir           = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Temp"
                ASConfigDir         = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Config"
                DependsOn           = "[xComputer]JoinDomain","[WindowsFeature]NET35Install"
            }

            xSqlServerFirewall ($Instance.Name)
            {
                SourcePath   = $Node.SourcePath
                SourceFolder = $Node.SourceFolder
                InstanceName = $Instance.Name
                Features     = $Features
                DependsOn    = "[xSqlServerSetup]$($Instance.Name)"
            }
        }

        if($Node.InstallManagementTools)
        {
            xSqlServerSetup SQLMT
            {
                SourcePath      = $Node.SourcePath
                SourceFolder    = $Node.SourceFolder
                SetupCredential = $InstallerCredential
                InstanceName    = "NULL"
                Features        = "SSMS,ADV_SSMS"
                DependsOn       = "[xComputer]JoinDomain","[WindowsFeature]NET35Install"
            }
        }
    }
}
