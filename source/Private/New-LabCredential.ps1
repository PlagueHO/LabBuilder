<#
    .SYNOPSIS
        Generates a credential object from a username and password.
#>
function New-LabCredential()
{
    [CmdletBinding()]
    [OutputType([PSCredential])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Username,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Password
    )

    $credential = New-Object `
        -TypeName System.Management.Automation.PSCredential `
        -ArgumentList ($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))

    return $credential
}
