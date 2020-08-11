<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    STANDALONE_DEFAULT
.Desription
    Builds a Standalone computer with no additional DSC resources.
.Parameters:
###################################################################################################>

Configuration STANDALONE_DEFAULT
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration' -ModuleVersion 1.1
    Import-DscResource -ModuleName xActiveDirectory 2.9.0.0
    Import-DscResource ComputerManagementDsc -ModuleVersion 1.4.0.0
    Import-DscResource xDHCPServer 1.3.0.0
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword) {
            $LocalAdminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
    }
}
