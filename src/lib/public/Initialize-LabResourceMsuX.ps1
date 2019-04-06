function Initialize-LabResourceMSU
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
        [LabResourceMSU[]] $ResourceMSUs
    )

    # if resource MSUs was not passed, pull it.
    if (-not $PSBoundParameters.ContainsKey('resourcemsus'))
    {
        $ResourceMSUs = Get-LabResourceMSU `
            @PSBoundParameters
    }

    if ($ResourceMSUs)
    {
        foreach ($MSU in $ResourceMSUs)
        {
            if (-not (Test-Path -Path $MSU.Filename))
            {
                Write-LabMessage -Message $($LocalizedData.DownloadingResourceMSUMessage `
                        -f $MSU.Name, $MSU.URL)

                Invoke-LabDownloadAndUnzipFile `
                    -URL $MSU.URL `
                    -DestinationPath (Split-Path -Path $MSU.Filename)
            } # if
        } # foreach
    } # if
} # Initialize-LabResourceMSU
