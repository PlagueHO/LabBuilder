<#
    .SYNOPSIS
        Convert a path to be an absolute by adding it to the base path.
        If the path is already absolute then it is just returned as is.

    .PARAMETER Path
        The path to convert to an absolute path.

    .PARAMETER BasePath
        The full path to the lab.

    .OUTPUTS
        The path converted to an absolute path.
#>
function ConvertTo-LabAbsolutePath
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $BasePath
    )

    if (-not [System.IO.Path]::IsPathRooted($Path))
    {
        $Path = Join-Path `
            -Path $BasePath `
            -ChildPath $Path
    } # if

    return $Path
}
