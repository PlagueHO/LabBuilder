# This module provides helper functions for executing tests

<#
    .SYNOPSIS
    Helper function that just creates an exception record for testing.
#>
function Get-LabException
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String] $errorId,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorCategory] $errorCategory,

        [Parameter(Mandatory = $true)]
        [System.String] $errorMessage,

        [Switch]
        $terminate
    )

    $exception = New-Object -TypeName System.Exception `
        -ArgumentList $errorMessage
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $errorId, $errorCategory, $null
    return $errorRecord
}

Export-ModuleMember -Function `
    Get-LabException
