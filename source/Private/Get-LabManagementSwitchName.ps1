<#
    .SYNOPSIS
        Returns the name of the Management Switch to use for this lab.

    .DESCRIPTION
        Each lab has a unique private management switch created for it.
        All Virtual Machines in the Lab are connected to the switch.
        This function returns the name of this swtich for the provided
        lab configuration.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $ManagementSwitch = Get-LabManagementSwitchName -Lab $Lab
        Returns the Management Switch for the Lab c:\mylab\config.xml.

    .OUTPUTS
        A management switch name.
#>
function Get-LabManagementSwitchName
{
    [CmdLetBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab
    )

    $LabId = $Lab.labbuilderconfig.settings.labid

    if (-not $LabId)
    {
        $LabId = $Lab.labbuilderconfig.name
    } # if

    $managementSwitchName = ('{0}Lab Management' -f $LabId)

    return $managementSwitchName
}
