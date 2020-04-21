function Initialize-LabSwitch
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position = 1,
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Name,

        [Parameter(
            Position = 3)]
        [LabSwitch[]] $Switches
    )

    # if switches was not passed, pull it.
    if (-not $PSBoundParameters.ContainsKey('switches'))
    {
        [LabSwitch[]] $Switches = Get-LabSwitch `
            @PSBoundParameters
    }

    # Create Hyper-V Switches
    foreach ($VMSwitch in $Switches)
    {
        if ($Name -and ($VMSwitch.name -notin $Name))
        {
            # A names list was passed but this swtich wasn't included
            continue
        } # if

        if ((Get-VMSwitch | Where-Object -Property Name -eq $($VMSwitch.Name)).Count -eq 0)
        {
            [System.String] $SwitchName = $VMSwitch.Name
            if (-not $SwitchName)
            {
                $exceptionParameters = @{
                    errorId       = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.SwitchNameIsEmptyError)
                }
                New-LabException @exceptionParameters
            }
            [LabSwitchType] $SwitchType = $VMSwitch.Type
            Write-LabMessage -Message $($LocalizedData.CreatingVirtualSwitchMessage `
                    -f $SwitchType, $SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    # Determine which Physical Adapter to bind this switch to
                    if ($VMSwitch.BindingAdapterMac)
                    {
                        $BindingAdapter = Get-NetAdapter | Where-Object {
                            ($_.MacAddress -replace '-', '') -eq $VMSwitch.BindingAdapterMac
                        }
                        $ErrorDetail = "with a MAC address '$($VMSwitch.BindingAdapterMac)' "
                    }
                    elseif ($VMSwitch.BindingAdapterName)
                    {
                        $BindingAdapter = Get-NetAdapter `
                            -Name $VMSwitch.BindingAdapterName `
                            -ErrorAction SilentlyContinue
                        $ErrorDetail = "with a name '$($VMSwitch.BindingAdapterName)' "
                    }
                    else
                    {
                        $BindingAdapter = Get-NetAdapter | `
                            Where-Object {
                            ($_.Status -eq 'Up') `
                                -and (-not $_.Virtual) `
                        } | Select-Object -First 1
                        $ErrorDetail = ''
                    } # if

                    # Check that a Binding Adapter was found
                    if (-not $BindingAdapter)
                    {
                        $exceptionParameters = @{
                            errorId       = 'BindingAdapterNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.BindingAdapterNotFoundError `
                                    -f $SwitchName, $ErrorDetail)
                        }
                        New-LabException @exceptionParameters
                    } # if

                    # Check this adapter is not already bound to a switch
                    $VMSwitchNames = (Get-VMSwitch | Where-Object {
                            $_.SwitchType -eq 'External'
                        }).Name
                    $MacAddress = @()

                    foreach ($VmSwitchName in $VmSwitchNames)
                    {
                        $MacAddress += (Get-VMNetworkAdapter `
                                -ManagementOS `
                                -SwitchName $VmSwitchName `
                                -Name $VmSwitchName `
                                -ErrorAction SilentlyContinue).MacAddress
                    } # foreach

                    $UsedAdapters = @((Get-NetAdapter | Where-Object {
                                ($_.MacAddress -replace '-', '') -in $MacAddress
                            }).Name)
                    if ($BindingAdapter.Name -in $UsedAdapters)
                    {
                        $exceptionParameters = @{
                            errorId       = 'BindingAdapterUsedError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.BindingAdapterUsedError `
                                    -f $SwitchName, $BindingAdapter.Name)
                        }
                        New-LabException @exceptionParameters
                    } # if

                    # Create the swtich
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -NetAdapterName $BindingAdapter.Name
                    break
                } # 'External'

                'Private'
                {
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -SwitchType Private
                    Break
                } # 'Private'

                'Internal'
                {
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -SwitchType Internal
                    Break
                } # 'Internal'

                'NAT'
                {
                    if ($script:currentBuild -lt 14295)
                    {
                        $exceptionParameters = @{
                            errorId       = 'NatSwitchNotSupportedError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.NatSwitchNotSupportedError -f $SwitchName)
                        }
                        New-LabException @exceptionParameters
                    }

                    $NatSubnet = $VMSwitch.NatSubnet
                    # Check Nat Subnet is set
                    if (-not $NatSubnet)
                    {
                        $exceptionParameters = @{
                            errorId       = 'NatSubnetEmptyError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.NatSubnetEmptyError `
                                    -f $SwitchName)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    # Ensure Nat Subnet looks valid
                    if ($NatSubnet -notmatch '[0-9]+.[0-9]+.[0-9]+.[0-9]+/[0-9]+')
                    {
                        $exceptionParameters = @{
                            errorId       = 'NatSubnetInvalidError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.NatSubnetInvalidError `
                                    -f $SwitchName, $NatSubnet)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    $NatSubnetComponents = ($NatSubnet -split '/')
                    $NatSubnetAddress = $NatSubnetComponents[0]
                    # Validate the Nat Subnet Address
                    if (-not ([System.Net.Ipaddress]::TryParse($NatSubnetAddress, [ref]0)))
                    {
                        $exceptionParameters = @{
                            errorId       = 'NatSubnetAddressInvalidError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.NatSubnetAddressInvalidError `
                                    -f $SwitchName, $NatSubnetAddress)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    # Validate the Nat Subnet Prefix Length
                    [System.Int32] $NatSubnetPrefixLength = $NatSubnetComponents[1]
                    if (($NatSubnetPrefixLength -lt 1) -or ($NatSubnetPrefixLength -gt 31))
                    {
                        $exceptionParameters = @{
                            errorId       = 'NatSubnetPrefixLengthInvalidError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.NatSubnetPrefixLengthInvalidError `
                                    -f $SwitchName, $NatSubnetPrefixLength)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    $NatGatewayAddress = $VMSwitch.NatGatewayAddress

                    # Create the Internal Switch
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -SwitchType Internal `
                        -ErrorAction Stop
                    # Set the IP Address on the default adapter connected to the NAT switch
                    $MacAddress = (Get-VMNetworkAdapter `
                            -ManagementOS `
                            -SwitchName $SwitchName `
                            -Name $SwitchName `
                            -ErrorAction Stop).MacAddress
                    if ([System.String]::IsNullOrEmpty($MacAddress))
                    {
                        $exceptionParameters = @{
                            errorId       = 'NatSwitchDefaultAdapterMacEmptyError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.NatSwitchDefaultAdapterMacEmptyError `
                                    -f $SwitchName)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    $Adapter = Get-NetAdapter |
                        Where-Object { ($_.MacAddress -replace '-', '') -eq $MacAddress }
                    if (-not $Adapter)
                    {
                        $exceptionParameters = @{
                            errorId       = 'NatSwitchDefaultAdapterNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.NatSwitchDefaultAdapterNotFoundError `
                                    -f $SwitchName)
                        }
                        New-LabException @exceptionParameters
                    }
                    $null = $Adapter | New-NetIPAddress `
                        -IPAddress $NatGatewayAddress `
                        -PrefixLength $NatSubnetPrefixLength `
                        -ErrorAction Stop
                    # Does the NAT already exist?
                    $NetNat = Get-NetNat `
                        -Name $SwitchName `
                        -ErrorAction SilentlyContinue
                    if ($NetNat)
                    {
                        # If the NAT already exists, remove it so it can be recreated
                        $null = $NetNat | Remove-NetNat -Confirm:$false
                    }
                    # Create the new NAT
                    $null = New-NetNat `
                        -Name $SwitchName `
                        -InternalIPInterfaceAddressPrefix $NatSubnet `
                        -ErrorAction Stop
                    Break
                } # 'NAT'
                Default
                {
                    $exceptionParameters = @{
                        errorId       = 'UnknownSwitchTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage  = $($LocalizedData.UnknownSwitchTypeError `
                                -f $SwitchType, $SwitchName)
                    }
                    New-LabException @exceptionParameters
                }
            } # switch

            if ($SwitchType -ne 'Private')
            {
                # Configure the VLan on the default Management Adapter
                $setLabSwitchAdapterParameters = @{
                    Name       = $SwitchName
                    SwitchName = $SwitchName
                }

                if ($VMSwitch.VLan)
                {
                    $setLabSwitchAdapterParameters += @{
                        VlanId = $VMSwitch.Vlan
                    }
                } # if

                Set-LabSwitchAdapter @setLabSwitchAdapterParameters

                # Add any management OS adapters to the switch
                if ($VMSwitch.Adapters)
                {
                    foreach ($Adapter in $VMSwitch.Adapters)
                    {
                        $setLabSwitchAdapterParameters = @{
                            Name       = $Adapter.Name
                            SwitchName = $SwitchName
                        }

                        if ($Adapter.MacAddress)
                        {
                            $setLabSwitchAdapterParameters += @{
                                StaticMacAddress = $Adapter.MacAddress
                            }
                        } # if

                        if ($VMSwitch.VLan)
                        {
                            $setLabSwitchAdapterParameters += @{
                                VlanId = $VMSwitch.Vlan
                            }
                        } # if

                        Set-LabSwitchAdapter @setLabSwitchAdapterParameters
                    } # foreach
                } # if
            } # if
        } # if
    } # foreach
} # Initialize-LabSwitch
