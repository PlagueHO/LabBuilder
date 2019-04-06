function Get-LabResourceModule
{
    [OutputType([LabResourceModule[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position = 1,
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Name
    )

    [LabResourceModule[]] $ResourceModules = @()
    if ($Lab.labbuilderconfig.resources)
    {
        foreach ($Module in $Lab.labbuilderconfig.resources.module)
        {
            $ModuleName = $Module.Name
            if ($Name -and ($ModuleName -notin $Name))
            {
                # A names list was passed but this Module wasn't included
                continue
            } # if

            if ($ModuleName -eq 'module')
            {
                $exceptionParameters = @{
                    errorId       = 'ResourceModuleNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.ResourceModuleNameIsEmptyError)
                }
                New-LabException @exceptionParameters
            } # if
            $ResourceModule = [LabResourceModule]::New($ModuleName)
            $ResourceModule.URL = $Module.URL
            $ResourceModule.Folder = $Module.Folder
            $ResourceModule.MinimumVersion = $Module.MinimumVersion
            $ResourceModule.RequiredVersion = $Module.RequiredVersion
            $ResourceModules += @( $ResourceModule )
        } # foreach
    } # if
    return $ResourceModules
} # Get-LabResourceModule
