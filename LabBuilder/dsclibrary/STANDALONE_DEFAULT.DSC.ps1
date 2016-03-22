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
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
    }
}
