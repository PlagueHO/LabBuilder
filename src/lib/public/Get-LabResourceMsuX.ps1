function Get-LabResourceMSU
{
    [OutputType([LabResourceMSU[]])]
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

    [LabResourceMSU[]] $ResourceMSUs = @()
    if ($Lab.labbuilderconfig.resources)
    {
        foreach ($MSU in $Lab.labbuilderconfig.resources.msu)
        {
            $MSUName = $MSU.Name
            if ($Name -and ($MSUName -notin $Name))
            {
                # A names list was passed but this MSU wasn't included
                continue
            } # if

            if ($MSUName -eq 'msu')
            {
                $exceptionParameters = @{
                    errorId       = 'ResourceMSUNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.ResourceMSUNameIsEmptyError)
                }
                New-LabException @exceptionParameters
            } # if
            $ResourceMSU = [LabResourceMSU]::New($MSUName, $MSU.URL)
            $Path = $MSU.Path
            if ($Path)
            {
                if (-not [System.IO.Path]::IsPathRooted($Path))
                {
                    $Path = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.resourcepathfull `
                        -ChildPath $Path
                }
            }
            else
            {
                $Path = $Lab.labbuilderconfig.settings.resourcepathfull
            }
            $FileName = Join-Path `
                -Path $Path `
                -ChildPath $MSU.URL.Substring($MSU.URL.LastIndexOf('/') + 1)
            $ResourceMSU.Path = $Path
            $ResourceMSU.Filename = $Filename
            $ResourceMSUs += @( $ResourceMSU )
        } # foreach
    } # if
    return $ResourceMSUs
} # Get-LabResourceMSU
