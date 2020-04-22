<#
    .SYNOPSIS
        Increases the MAC Address.

    .PARAMETER MACAddress
        Contains the MAC Address to increase.

    .PARAMETER Step
        Contains the number of steps to increase the MAC address by.

    .EXAMPLE
        Get-NextMacAddress -MacAddress '00155D0106ED' -Step 2
        Returns the MAC Address '00155D0106EF'

    .OUTPUTS
        The increased MAC Address.
#>
function Get-NextMacAddress
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $MacAddress,

        [System.Byte]
        $Step = 1
    )

    return [System.String]::Format("{0:X}", [Convert]::ToUInt64($MACAddress, 16) + $Step).PadLeft(12, '0')
}
