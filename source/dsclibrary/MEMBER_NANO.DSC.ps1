<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_NANO
.Desription
    Builds a Nano Server and joins it to a Domain using an ODJ Request File.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    ODJRequestFile = 'C:\ODJRequest.txt'
###################################################################################################>

Configuration MEMBER_NANO
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0

    Node $AllNodes.NodeName {
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
