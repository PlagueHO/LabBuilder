<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    Join Domain DSC Module
.Desription
    Joins Server to Domain
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    ComputerName = "Server01"
    DomainControllerName = "DC01"
###################################################################################################>

Configuration JOINDOMAIN
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

        # Domain Administrator Credentials
        [Parameter(Mandatory=$true)]
        [System.String]
        $DomainAdminPassword,

        # Set the Computer Name
        [Parameter(Mandatory=$true)]
        [System.String]
        $ComputerName



    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName NetworkingDsc

        # Assemble the Local Admin Credentials
        if ($LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force))
        }
        if ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$DomainName\Administrator", (ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force))
        }

        WaitForAll DC
        {
        ResourceName      = '[ADDomain]CreateDC'
        NodeName          = $DCname
        RetryIntervalSec  = 15
        RetryCount        = 60
        }


        Computer JoinDomain
        {
            Name          = $ComputerName
            DomainName    = $DomainName
            Credential    = $DomainAdminCredential
            DependsOn = "[WaitForAll]DC"
        }

}
