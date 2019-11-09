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

    $module = Get-Module -Name LabBuilder

    if (-not $module)
    {
        $exceptionParameters = @{
            errorId       = 'LabBuilderModuleNotLoadedError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.LabBuilderModulePathDetectionError)
        }
        New-LabException @exceptionParameters
    }

    if ([System.String]::IsNullOrEmpty($module.Path))
    {
        $exceptionParameters = @{
            errorId       = 'LabBuilderModulePathNullError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.LabBuilderModulePathNullError)
        }
        New-LabException @exceptionParameters
    }

    return Split-Path -Path $module.Path -Parent
}
