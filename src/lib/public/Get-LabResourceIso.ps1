function Get-LabResourceISO
{
    [OutputType([LabResourceISO[]])]
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

    # Determine the ISORootPath where the ISO files should be found.
    # If no path is specified then look in the resource path.
    # If a path is specified but it is relative, make it relative to the resource path.
    # Otherwise use it as is.
    [System.String] $ISORootPath = $Lab.labbuilderconfig.Resources.ISOPath
    if ($ISORootPath)
    {
        if (-not [System.IO.Path]::IsPathRooted($ISORootPath))
        {
            $ISORootPath = Join-Path `
                -Path $Lab.labbuilderconfig.settings.resourcepathfull `
                -ChildPath $ISORootPath
        } # if
    }
    else
    {
        $ISORootPath = $Lab.labbuilderconfig.settings.resourcepathfull
    } # if

    [LabResourceISO[]] $ResourceISOs = @()
    if ($Lab.labbuilderconfig.resources)
    {
        foreach ($ISO in $Lab.labbuilderconfig.resources.iso)
        {
            $ISOName = $ISO.Name
            if ($Name -and ($ISOName -notin $Name))
            {
                # A names list was passed but this ISO wasn't included
                continue
            } # if

            if ($ISOName -eq 'iso')
            {
                $exceptionParameters = @{
                    errorId       = 'ResourceISONameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.ResourceISONameIsEmptyError)
                }
                New-LabException @exceptionParameters
            } # if
            $ResourceISO = [LabResourceISO]::New($ISOName)
            $Path = $ISO.Path
            if ($Path)
            {
                if (-not [System.IO.Path]::IsPathRooted($Path))
                {
                    $Path = Join-Path `
                        -Path $ISORootPath `
                        -ChildPath $Path
                } # if
            }
            else
            {
                # A Path is not provided
                $exceptionParameters = @{
                    errorId       = 'ResourceISOPathIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.ResourceISOPathIsEmptyError `
                            -f $ISOName)
                }
                New-LabException @exceptionParameters
            }
            if ($ISO.URL)
            {
                $ResourceISO.URL = $ISO.URL
            } # if
            $ResourceISO.Path = $Path
            $ResourceISOs += @( $ResourceISO )
        } # foreach
    } # if
    return $ResourceISOs
} # Get-LabResourceISO
