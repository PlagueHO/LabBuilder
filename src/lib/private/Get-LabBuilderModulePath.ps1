<#
    .SYNOPSIS
        Returns the path of the currently loaded LabBuilder module.

    .OUTPUTS
        The path to the currently loaded LabBuilder module.
#>
function Get-LabBuilderModulePath
{
    [CmdLetBinding()]
    [OutputType([System.String])]
    param ()

    return $script:LabBuidlerModuleRoot
}
