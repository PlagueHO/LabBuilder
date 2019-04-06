function Initialize-LabResourceModule
{
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
        [System.String[]] $Name,

        [Parameter(
            Position = 3)]
        [LabResourceModule[]] $ResourceModules
    )

    # if resource modules was not passed, pull it.
    if (-not $PSBoundParameters.ContainsKey('resourcemodules'))
    {
        $ResourceModules = Get-LabResourceModule `
            @PSBoundParameters
    }

    if ($ResourceModules)
    {
        foreach ($Module in $ResourceModules)
        {
            $Splat = [PSObject] @{ Name = $Module.Name }
            if ($Module.URL)
            {
                $Splat += [PSObject] @{ URL = $Module.URL }
            }
            if ($Module.Folder)
            {
                $Splat += [PSObject] @{ Folder = $Module.Folder }
            }
            if ($Module.RequiredVersion)
            {
                $Splat += [PSObject] @{ RequiredVersion = $Module.RequiredVersion }
            }
            if ($Module.MiniumVersion)
            {
                $Splat += [PSObject] @{ MiniumVersion = $Module.MiniumVersion }
            }

            Write-LabMessage -Message $($LocalizedData.DownloadingResourceModuleMessage `
                    -f $Name, $URL)

            Invoke-LabDownloadResourceModule @Splat
        } # foreach
    } # if
} # Initialize-LabResourceModule
