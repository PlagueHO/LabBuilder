<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_DEFAULT
.Desription
    Builds a Server that is joined to a domain.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
###################################################################################################>

Configuration MEMBER_DEFAULT
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName ComputerManagementDsc

    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        if ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
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
            DependsOn  = "[WaitForAll]DC"
        }
    }
}
