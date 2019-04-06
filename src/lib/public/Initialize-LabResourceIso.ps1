function Initialize-LabResourceISO
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
        [LabResourceISO[]] $ResourceISOs
    )

    # if resource ISOs was not passed, pull it.
    if (-not $PSBoundParameters.ContainsKey('resourceisos'))
    {
        $ResourceMSUs = Get-LabResourceISO `
            @PSBoundParameters
    } # if

    if ($ResourceISOs)
    {
        foreach ($ResourceISO in $ResourceISOs)
        {
            if (-not (Test-Path -Path $ResourceISO.Path))
            {
                # The Resource ISO does not exist
                if (-not ($ResourceISO.URL))
                {
                    $exceptionParameters = @{
                        errorId       = 'ResourceISOFileNotFoundAndNoURLError'
                        errorCategory = 'InvalidArgument'
                        errorMessage  = $($LocalizedData.ResourceISOFileNotFoundAndNoURLError `
                                -f $ISOName, $Path)
                    }
                    New-LabException @exceptionParameters
                } # if

                $URLLeaf = [System.IO.Path]::GetFileName($ResourceISO.URL)
                $URLExtension = [System.IO.Path]::GetExtension($URLLeaf)
                if ($URLExtension -in @('.zip', '.iso'))
                {
                    Write-LabMessage -Message $($LocalizedData.DownloadingResourceISOMessage `
                            -f $ResourceISO.Name, $ResourceISO.URL)

                    Invoke-LabDownloadAndUnzipFile `
                        -URL $ResourceISO.URL `
                        -DestinationPath (Split-Path -Path $ResourceISO.Path)
                }
                elseif ([System.String]::IsNullOrEmpty($URLExtension))
                {
                    Write-LabMessage `
                        -Type Alert `
                        -Message $($LocalizedData.ISONotFoundDownloadURLMessage `
                            -f $ResourceISO.Name, $ResourceISO.Path, $ResourceISO.URL)
                } # if
                if (-not (Test-Path -Path $ResourceISO.Path))
                {
                    $exceptionParameters = @{
                        errorId       = 'ResourceISOFileNotDownloadedError'
                        errorCategory = 'InvalidArgument'
                        errorMessage  = $($LocalizedData.ResourceISOFileNotDownloadedError `
                                -f $ResourceISO.Name, $ResourceISO.Path, $ResourceISO.URL)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if
        } # foreach
    } # if
} # Initialize-LabResourceISO
