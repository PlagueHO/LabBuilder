<#
    .SYNOPSIS
        Ensures that the virtual adapter is attached to a Virtual Switch
        and configured correctly.

    .DESCRIPTION
        This function is used to add or update the specified virtual network adapter
        that is used by the Management OS to connect to the specifed virtual switch.

    .PARAMETER Name
        Contains the name of the virtual network adapter to add.

    .PARAMETER SwitchName
        Contains the name of the virtual switch to connect this adapter to.

    .PARAMETER ManagementOS
        Whether or not this adapter is attached to the Management OS.

    .PARAMETER StaticMacAddress
        This optional parameter contains the static MAC address to assign to the virtual
        network adapter.

    .PARAMETER VlanId
        This optional parameter contains the VLan Id to assign to this network adapter.

    .EXAMPLE
        Set-LabSwitchAdapter -Name 'Domain Nat SMB' -SwitchName 'Domain Nat' -VlanId 25

    .OUTPUTS
        None.
#>
function Set-LabSwitchAdapter
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SwitchName,

        [Parameter()]
        [Switch]
        $ManagementOS,

        [Parameter()]
        [System.String]
        $StaticMacAddress,

        [Parameter()]
        [AllowNull()]
        [Nullable[System.Int32]]
        $VlanId
    )

    # Determine if we should set the MAC address and VLan Id
    $setVlanId = $PSBoundParameters.ContainsKey('VlanId')
    $setMacAddress = $PSBoundParameters.ContainsKey('StaticMacAddress')

    # Remove VlanId Parameter so this can be splatted
    $null = $PSBoundParameters.Remove('VlanId')
    $null = $PSBoundParameters.Remove('StaticMacAddress')

    $existingManagementAdapter = Get-VMNetworkAdapter `
        @PSBoundParameters `
        -ErrorAction SilentlyContinue

    if (-not $existingManagementAdapter)
    {
        # Adapter does not exist so add it
        if ($SetMacAddress)
        {
            # For a management adapter a Static MAC address can only be assigned at creation time.
            if (-not ([System.String]::IsNullOrEmpty($StaticMacAddress)))
            {
                $PSBoundParameters.Add('StaticMacAddress', $StaticMacAddress)
            }
        }

        $existingManagementAdapter = Add-VMNetworkAdapter `
            @PSBoundParameters `
            -Passthru
    }
    else
    {
        <#
            The MAC Address for an existing Management Adapter can not be changed
            This shouldn't ever happen unless the configuration is changed.
            Not sure of the solution to this problem.
        #>
    }

    # Set or clear the VlanId
    if ($setVlanId)
    {
        $existingManagementAdapterVlan = Get-VMNetworkAdapterVlan `
            -VMNetworkAdapter $existingManagementAdapter

        $existingManagementVlan = $existingManagementAdapterVlan.AccessVlanId

        if ($null -eq $VlanId)
        {
            if ($null -eq $existingManagementVlan)
            {
                $setVMNetworkAdapterVlanParameters = @{
                    VMNetworkAdapter = $existingManagementAdapter
                    Untagged         = $true
                }

                $null = Set-VMNetworkAdapterVlan `
                    @setVMNetworkAdapterVlanParameters `
                    -ErrorAction Stop
            }
        }
        else
        {
            if ($VlanId -ne $existingManagementVlan)
            {
                $setVMNetworkAdapterVlanParameters = @{
                    VMNetworkAdapter = $existingManagementAdapter
                    Access           = $true
                    VlanId           = $VlanId
                }

                $null = Set-VMNetworkAdapterVlan `
                    @setVMNetworkAdapterVlanParameters `
                    -ErrorAction Stop
            }
        }
    }
}
