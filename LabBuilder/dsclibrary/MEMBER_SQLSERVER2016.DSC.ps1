<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_SQLSERVER2016
.Desription
    Builds a Server that is joined to a domain and then installs SQL Server 2016.
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
    Instances = @(
        @{
            Name = 'MSSQLSERVER'
            Features = 'SQLENGINE,FULLTEXT,RS,AS,IS'
        }
    )
    InstallManagementTools = $True
###################################################################################################>

Configuration MEMBER_SQLSERVER2016
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName SQLServerDsc

    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword)
        {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        if ($Node.DomainAdminPassword)
        {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }
        if ($Node.InstallerPassword)
        {
            [PSCredential]$InstallerCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\$($Node.InstallerUsername)", (ConvertTo-SecureString $Node.InstallerPassword -AsPlainText -Force))
        }

        # Install the SQL Server Dependencies
        WindowsFeature Net35Install
        {
            Name   = 'NET-Framework-Core'
            Ensure = 'Present'
        }

        WaitForAll DC
        {
            ResourceName     = '[xADDomain]PrimaryDC'
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

        WaitforDisk Disk2
        {
            DiskId           = 1
            RetryIntervalSec = 60
            RetryCount       = 60
            DependsOn        = '[Computer]JoinDomain'
        }

        Disk DVolume
        {
            DiskId      = 1
            DriveLetter = $Node.SQLDataDrive
            DependsOn   = '[WaitforDisk]Disk2'
        }

        foreach ($Instance in $Node.Instances)
        {
            $Features = $Instance.Features
            if ([System.String]::IsNullOrEmpty($Features))
            {
                $Features = 'SQLENGINE,FULLTEXT,RS,AS,IS'
            } # if
            SqlServerSetup ($Instance.Name)
            {
                SourcePath           = $Node.SourcePath
                InstanceName         = $Instance.Name
                Features             = $Features
                SQLSysAdminAccounts  = "$($Node.DomainName)\$($Node.SQLAdminAccount)"
                InstallSharedDir     = "C:\Program Files\Microsoft SQL Server"
                InstallSharedWOWDir  = "C:\Program Files (x86)\Microsoft SQL Server"
                InstanceDir          = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server"
                InstallSQLDataDir    = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLUserDBDir         = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLUserDBLogDir      = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLTempDBDir         = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLTempDBLogDir      = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLBackupDir         = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                ASDataDir            = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Data"
                ASLogDir             = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Log"
                ASBackupDir          = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Backup"
                ASTempDir            = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Temp"
                ASConfigDir          = "$($Node.SQLDataDrive):\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Config"
                PsDscRunAsCredential = $InstallerCredential
                DependsOn            = "[Computer]JoinDomain", "[WindowsFeature]NET35Install"
            }

            SqlServerFirewall ($Instance.Name)
            {
                SourcePath   = $Node.SourcePath
                InstanceName = $Instance.Name
                Features     = $Features
                DependsOn    = "[SqlServerSetup]$($Instance.Name)"
            }
        }

        if ($Node.InstallManagementTools)
        {
            SqlServerSetup SQLMT
            {
                SourcePath           = $Node.SourcePath
                InstanceName         = "NULL"
                Features             = "SSMS,ADV_SSMS"
                PsDscRunAsCredential = $InstallerCredential
                DependsOn            = "[Computer]JoinDomain", "[WindowsFeature]NET35Install"
            }
        }
    }
}
