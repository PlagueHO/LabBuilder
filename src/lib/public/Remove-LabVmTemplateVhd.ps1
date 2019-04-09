function Remove-LabVMTemplateVHD
{
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
        [LabVMTemplateVHD[]] $VMTemplateVHDs
    )

    # if VMTeplateVHDs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplateVHDs'))
    {
        [LabVMTemplateVHD[]] $VMTemplateVHDs = Get-LabVMTemplateVHD `
            @PSBoundParameters
    } # if

    # if there are no VMTemplateVHDs just return
    if ($null -eq $VMTemplateVHDs)
    {
        return
    } # if

    [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [System.String] $TemplateVHDName = $VMTemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        [System.String] $VHDPath = $VMTemplateVHD.VHDPath

        if (Test-Path -Path ($VHDPath))
        {
            Remove-Item `
                -Path $VHDPath `
                -Force
            Write-LabMessage -Message $($LocalizedData.DeletingVMTemplateVHDFileMessage `
                    -f $TemplateVHDName, $VHDPath)
        } # if
    } # endfor
} # Remove-LabVMTemplateVHD
