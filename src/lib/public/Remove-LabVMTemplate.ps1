function Remove-LabVMTemplate
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
        [LabVMTemplate[]] $VMTemplates
    )

    # if VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        $VMTemplates = Get-LabVMTemplate `
            @PSBoundParameters
    } # if
    foreach ($VMTemplate in $VMTemplates)
    {
        if ($Name -and ($VMTemplate.Name -notin $Name))
        {
            # A names list was passed but this VM Template wasn't included
            continue
        } # if

        if (Test-Path $VMTemplate.ParentVhd)
        {
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $false
            Write-LabMessage -Message $($LocalizedData.DeletingParentVHDMessage `
                    -f $VMTemplate.ParentVhd)
            Remove-Item `
                -Path $VMTemplate.ParentVhd `
                -Confirm:$false `
                -Force
        } # if
    } # foreach
}
