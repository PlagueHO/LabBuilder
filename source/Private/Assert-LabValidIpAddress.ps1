<#
    .SYNOPSIS
        Validates the IP Address.

    .PARAMETER IpAddress
        Contains the IP Address to validate.

    .EXAMPLE
        Assert-LabValidIpAddress -IpAddress '192.168.123.44'
        Does not throw an exception and returns '192.168.123.44'.

    .EXAMPLE
        Assert-LabValidIpAddress -IpAddress '192.168.123.4432'
        Throws an exception.

    .OUTPUTS
        The IP address if valid.
#>
function Assert-LabValidIpAddress
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $IpAddress
    )

    $ip = [System.Net.IPAddress]::Any
    if (-not [System.Net.IPAddress]::TryParse($IpAddress, [ref] $ip))
    {
        $exceptionParameters = @{
            errorId       = 'IPAddressError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.IPAddressError -f $IpAddress)
        }
        New-LabException @exceptionParameters
    }
    return $ip
}
