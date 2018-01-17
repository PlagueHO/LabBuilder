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
        [Parameter(Mandatory=$True,Position=1)]
        [System.String]
        $DomainName,


        # Set the Domain Controller Name
        [Parameter(Mandatory=$True)]
        [System.String]
        $DCName,

        # Domain Administrator Credentials
        [Parameter(Mandatory=$True)]
        [System.String]
        $DomainAdminPassword,

        # Set the Computer Name
        [Parameter(Mandatory=$True)]
        [System.String]
        $ComputerName



    )

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xNetworking

        # Assemble the Local Admin Credentials
        if ($LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force))
        }
        if ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$DomainName\Administrator", (ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force))
        }

        WaitForAll DC
        {
        ResourceName      = '[xADDomain]CreateDC'
        NodeName          = $DCname
        RetryIntervalSec  = 15
        RetryCount        = 60
        }


        xComputer JoinDomain
        {
            Name          = $ComputerName
            DomainName    = $DomainName
            Credential    = $DomainAdminCredential
            DependsOn = "[WaitForAll]DC"
        }

}
