<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_NANO
.Desription
    Builds a Nano Server and joins it to a Domain using an ODJ Request File.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    ODJRequestFile = 'C:\ODJRequest.txt'
###################################################################################################>

Configuration MEMBER_NANO
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName ComputerManagementDsc

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

        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        OfflineDomainJoin JoinDomain
        {
            IsSingleInstance = 'Yes'
            RequestFile      = $Node.ODJRequestFile
            DependsOn        = '[WaitForAll]DC'
        }
    }
}
