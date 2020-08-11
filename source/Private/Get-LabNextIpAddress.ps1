<#
    .SYNOPSIS
        Increases the IP Address.

    .PARAMETER IpAddress
        Contains the IP Address to increase.

    .PARAMETER Step
        Contains the number of steps to increase the IP address by.

    .EXAMPLE
        Get-LabNextIpAddress -IpAddress '192.168.123.44' -Step 2
        Returns the IP Address '192.168.123.44'

    .EXAMPLE
        Get-LabNextIpAddress -IpAddress 'fe80::15b4:b934:5d23:1a2f' -Step 2
        Returns the IP Address 'fe80::15b4:b934:5d23:1a31'

    .OUTPUTS
        The increased IP Address.
#>
function Get-LabNextIpAddress
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $IpAddress,

        [Parameter()]
        [System.Byte]
        $Step = 1
    )

    # Check the IP Address is valid
    $ip = Assert-LabValidIpAddress -IpAddress $IpAddress

    # This code will increase the next IP address by the step amount.
    # It uses the IP Address byte array to do this.
    $bytes = $ip.GetAddressBytes()
    $position = $bytes.Length - 1

    while ($Step -gt 0)
    {
        if ($bytes[$position] + $Step -gt 255)
        {
            $bytes[$position] = $bytes[$position] + $Step - 256
            $Step = $Step - $bytes[$position]
            $position--
        }
        else
        {
            $bytes[$position] = $bytes[$position] + $Step
            $Step = 0
        } # if
    } # while

    return [System.Net.IPAddress]::new($bytes).IPAddressToString
}
