function Update-Lab
{
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [System.String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    ) # Param

    begin
    {
        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters
        } # if
    } # begin

    process
    {
        Install-Lab `
            @PSBoundParameters

        Write-LabMessage -Message $($LocalizedData.LabUpdateCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)
    } # process

    end
    {
    } # end
} # Update-Lab
