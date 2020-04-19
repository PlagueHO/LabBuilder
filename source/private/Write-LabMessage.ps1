<#
    .SYNOPSIS
        Writes a Message of the specified Type.

    .DESCRIPTION
        This cmdlet will write a message along with the time to the specified output stream.

    .PARAMETER Type
        This can be one of the following:
        Error - Writes to the Error Stream.
        Warning - Writes to the Warning Stream.
        Verbose - Writes to the Verbose Stream (default)
        Debug - Writes to the Debug Stream.
        Information - Writes to the Information Stream.
        Output - Writes to the Output Stream (so should be used for a terminating message)

    .PARAMETER Message
        The Message to output.

    .PARAMETER ForegroundColor
        The foreground color of the message if being writen to the output stream.

    .EXAMPLE
        Write-LabMessage -Type Verbose -Message 'Downloading file'
        New-LabException @exceptionParameters
        Outputs the message 'Downloading file' to the Verbose stream.

    .OUTPUTS
        None
#>
function Write-LabMessage
{
    [CmdLetBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Error', 'Warning', 'Verbose', 'Debug', 'Info', 'Alert')]
        [System.String]
        $Type = 'Verbose',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [System.String]
        $ForegroundColor = 'Yellow'
    )

    $time = Get-Date -UFormat %T

    switch ($Type)
    {
        'Error'
        {
            Write-Error -Message $Message
            break
        }

        'Warning'
        {
            Write-Warning -Message ('[{0}]: {1}' -f $time, $Message)
            break
        }

        'Verbose'
        {
            Write-Verbose -Message ('[{0}]: {1}' -f $time, $Message)
            break
        }

        'Debug'
        {
            Write-Debug -Message ('[{0}]: {1}' -f $time, $Message)
            break
        }

        'Info'
        {
            Write-Information -MessageData ('INFO: [{0}]: {1}' -f $time, $Message)
            break
        }

        'Alert'
        {
            Write-Host `
                -ForegroundColor $ForegroundColor `
                -Object $Message
            break
        }
    } # switch
}
