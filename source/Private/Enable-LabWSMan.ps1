<#
    .SYNOPSIS
        Ensures the WS-Man is configured on this system.

    .DESCRIPTION
        If WS-Man is not enabled on this system it will be enabled.
        This is required to communicate with the managed Lab Virtual Machines.

    .EXAMPLE
        Enable-LabWSMan
        Enables WS-Man on this machine.

    .OUTPUTS
        None
#>
function Enable-LabWSMan
{
    [CmdLetBinding()]
    param
    (
        [Parameter()]
        [Switch]
        $Force
    )

    if (-not (Get-PSPRovider -PSProvider WSMan -ErrorAction SilentlyContinue))
    {
        Write-LabMessage -Message ($LocalizedData.EnablingWSManMessage)

        try
        {
            Start-Service -Name WinRm -ErrorAction Stop
        }
        catch
        {
            $null = Enable-PSRemoting `
                @PSBoundParameters `
                -SkipNetworkProfileCheck `
                -ErrorAction Stop
        }

        # Check WS-Man was enabled
        if (-not (Get-PSProvider -PSProvider WSMan -ErrorAction SilentlyContinue))
        {
            $exceptionParameters = @{
                errorId       = 'WSManNotEnabledError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.WSManNotEnabledError)
            }
            New-LabException @exceptionParameters
        } # if
    } # if

    # Make sure the WinRM service is running
    if ((Get-Service -Name WinRM).Status -ne 'Running')
    {
        try
        {
            Start-Service -Name WinRm -ErrorAction Stop
        }
        catch
        {
            $exceptionParameters = @{
                errorId       = 'WinRMServiceFailedToStartError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.WinRMServiceFailedToStartError)
            }
            New-LabException @exceptionParameters
        }
    }
}
