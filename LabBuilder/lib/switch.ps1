<#
.SYNOPSIS
   Returns the name of the Management Switch to use for this lab.
.DESCRIPTION
   Each lab has a unique private management switch created for it.
   All Virtual Machines in the Lab are connected to the switch.
   This function returns the name of this swtich for the provided
   lab configuration.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $ManagementSwtich = GetManagementSwitchName -Config $Config
   Returns the Management Switch for the Lab c:\mylab\config.xml.
.OUTPUTS
   A management switch name.
#>
function GetManagementSwitchName {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [XML] $Config
    )

    [String] $LabId = $Config.labbuilderconfig.settings.labid 
    if (-not $LabId)
    {
        $LabId = $Config.labbuilderconfig.name
    }
    $ManagementSwitchName = ('{0} Lab Management' `
        -f $LabId)

    return $ManagementSwitchName
} # GetManagementSwitchName
