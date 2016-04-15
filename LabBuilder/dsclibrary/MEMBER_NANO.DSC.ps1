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
    PSDscAllowDomainUser = $True
    ODJRequestFile = 'C:\ODJRequest.txt'
###################################################################################################>

Configuration MEMBER_NANO
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

        WaitForAll DC
        {
            ResourceName     = '[xADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        xOfflineDomainJoin JoinDomain 
        {
            IsSingleInstance = 'Yes'
            RequestFile      = $Node.ODJRequestFile
            DependsOn        = '[WaitForAll]DC' 
        }
    }
}
