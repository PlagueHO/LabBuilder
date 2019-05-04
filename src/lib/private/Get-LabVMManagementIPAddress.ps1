<#
    .SYNOPSIS
        Gets the Management IP Address for a running Lab VM.

    .DESCRIPTION
        This function will return the IPv4 address assigned to the network adapter that
        is connected to the Management switch for the specified VM. The VM must be
        running, otherwise an error will be thrown.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        $IPAddress = Get-LabVMManagementIPAddress -Lab $Lab -VM $VM[0]

    .OUTPUTS
        The IP Managment IP Address.
#>
function Get-LabVMManagementIPAddress
{
    [CmdLetBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM
    )

    $managementSwitchName = Get-LabManagementSwitchName -Lab $Lab
    $managementAdapter = Get-VMNetworkAdapter -VMName $VM.Name |
        Where-Object -Property SwitchName -EQ -Value $managementSwitchName
    $managementAdapterIpAddresses = $managementAdapter.IPAddresses
    $managementAdapterIpAddress = $managementAdapterIpAddresses |
        Where-Object -FilterScript {
            $_.Contains('.')
        }

    if (-not $managementAdapterIpAddress) {
        $exceptionParameters = @{
            errorId = 'ManagmentIPAddressError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ManagmentIPAddressError `
                -f $managementSwitchName,$VM.Name)
        }
        New-LabException @exceptionParameters
    } # if

    return $managementAdapterIpAddress
}
