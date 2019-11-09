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
        [System.String[]]
        $Name
    )

    <#
        Determine the ISORootPath where the ISO files should be found.
        If no path is specified then look in the resource path.
        If a path is specified but it is relative, make it relative to the resource path.
        Otherwise use it as is.
    #>
    [System.String] $isoRootPath = $Lab.labbuilderconfig.Resources.ISOPath

    if ($isoRootPath)
    {
        $isoRootPath = ConvertTo-LabAbsolutePath -Path $isoRootPath `
            -BasePath $Lab.labbuilderconfig.settings.resourcepathfull
    }
    else
    {
        $isoRootPath = $Lab.labbuilderconfig.settings.resourcepathfull
    } # if

    [LabResourceISO[]] $resourceISOs = @()

    if ($Lab.labbuilderconfig.resources)
    {
        foreach ($iso in $Lab.labbuilderconfig.resources.iso)
        {
            $isoName = $iso.Name

            if ($Name -and ($isoName -notin $Name))
            {
                # A names list was passed but this ISO wasn't included
                continue
            } # if

            if ($isoName -eq 'iso')
            {
                $exceptionParameters = @{
                    errorId       = 'ResourceISONameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.ResourceISONameIsEmptyError)
                }
                New-LabException @exceptionParameters
            } # if

            $resourceISO = [LabResourceISO]::New($isoName)
            $path = $iso.Path

            if ($path)
            {
                $path = ConvertTo-LabAbsolutePath -Path $path -BasePath $isoRootPath
            }
            else
            {
                # A Path is not provided
                $exceptionParameters = @{
                    errorId       = 'ResourceISOPathIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.ResourceISOPathIsEmptyError `
                            -f $isoName)
                }
                New-LabException @exceptionParameters
            }

            if ($iso.URL)
            {
                $resourceISO.URL = $iso.URL
            } # if

            $resourceISO.Path = $path
            $resourceISOs += @( $resourceISO )
        } # foreach
    } # if

    return $resourceISOs
} # Get-LabResourceISO
