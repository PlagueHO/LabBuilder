<#
.SYNOPSIS
    Gets an array of switches from a Lab.
.DESCRIPTION
    Takes a provided Lab and returns the array of LabSwitch objects required for this Lab.
    This list is usually passed to Initialize-LabSwitch to configure the switches required for this lab.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of Switch names.

    Only Switches matching names in this list will be pulled into the returned in the array.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $Switches = Get-LabSwitch -Lab $Lab
    Loads a Lab and pulls the array of switches from it.
.OUTPUTS
    Returns an array of LabSwitch objects.
#>
function Get-LabSwitch
{
    [OutputType([LabSwitch[]])]
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
        [String[]] $Name
    )

    [System.String] $LabId = $Lab.labbuilderconfig.settings.labid
    [LabSwitch[]] $Switches = @()
    $ConfigSwitches = $Lab.labbuilderconfig.Switches.Switch

    foreach ($ConfigSwitch in $ConfigSwitches)
    {
        # It can't be switch because if the name attrib/node is missing the name property on the
        # XML object defaults to the name of the parent. So we can't easily tell if no name was
        # specified or if they actually specified 'switch' as the name.
        $SwitchName = $ConfigSwitch.Name
        if ($Name -and ($SwitchName -notin $Name))
        {
            # A names list was passed but this swtich wasn't included
            continue
        } # if

        if ($SwitchName -eq 'switch')
        {
            $exceptionParameters = @{
                errorId       = 'SwitchNameIsEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.SwitchNameIsEmptyError)
            }
            New-Exception @exceptionParameters
        }

        # Convert the switch type string to a LabSwitchType
        $SwitchType = [LabSwitchType]::$($ConfigSwitch.Type)

        # If the SwitchType string doesn't match any enum value it will be
        # set to null.
        if (-not $SwitchType)
        {
            $exceptionParameters = @{
                errorId       = 'UnknownSwitchTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.UnknownSwitchTypeError `
                        -f $ConfigSwitch.Type, $SwitchName)
            }
            New-Exception @exceptionParameters
        } # if

        # if a LabId is set for the lab, prepend it to the Switch name as long as it isn't
        # an external switch.
        if ($LabId -and ($SwitchType -ne [LabSwitchType]::External))
        {
            $SwitchName = "$LabId$SwitchName"
        } # if

        # Assemble the list of Mangement OS Adapters if any are specified for this switch
        # Only Intenal and External switches are allowed Management OS adapters.
        if ($ConfigSwitch.Adapters)
        {
            [LabSwitchAdapter[]] $ConfigAdapters = @()
            foreach ($Adapter in $ConfigSwitch.Adapters.Adapter)
            {
                $AdapterName = $Adapter.Name
                # if a LabId is set for the lab, prepend it to the adapter name.
                # But only if it is not an External switch.
                if ($LabId -and ($SwitchType -ne [LabSwitchType]::External))
                {
                    $AdapterName = "$LabId$AdapterName"
                }

                $ConfigAdapter = [LabSwitchAdapter]::New($AdapterName)
                $ConfigAdapter.MACAddress = $Adapter.MacAddress
                $ConfigAdapters += @( $ConfigAdapter )
            } # foreach
            if (($ConfigAdapters.Count -gt 0) `
                    -and ($SwitchType -notin [LabSwitchType]::External, [LabSwitchType]::Internal))
            {
                $exceptionParameters = @{
                    errorId       = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.AdapterSpecifiedError `
                            -f $SwitchType, $SwitchName)
                }
                New-Exception @exceptionParameters
            } # if
        }
        else
        {
            $ConfigAdapters = $null
        } # if

        # Create the new Switch object
        [LabSwitch] $NewSwitch = [LabSwitch]::New($SwitchName, $SwitchType)
        $NewSwitch.VLAN = $ConfigSwitch.VLan
        $NewSwitch.BindingAdapterName = $ConfigSwitch.BindingAdapterName
        $NewSwitch.BindingAdapterMac = $ConfigSwitch.BindingAdapterMac
        $NewSwitch.BindingAdapterMac = $ConfigSwitch.BindingAdapterMac
        $NewSwitch.NatSubnet = $ConfigSwitch.NatSubnet
        $NewSwitch.NatGatewayAddress = $ConfigSwitch.NatGatewayAddress
        $NewSwitch.Adapters = $ConfigAdapters
        $Switches += @( $NewSwitch )
    } # foreach
    return $Switches
} # Get-LabSwitch


<#
.SYNOPSIS
    Creates Hyper-V Virtual Switches from a provided array of LabSwitch objects.
.DESCRIPTION
    Takes an array of LabSwitch objectsthat were pulled from a Lab object by calling
    Get-LabSwitch and ensures that they Hyper-V Virtual Switches on the system
    are configured to match.
.PARAMETER Lab
    Contains Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of Switch names.

    Only Switches matching names in this list will be initialized.
.PARAMETER Switches
    The array of LabSwitch objects pulled from the Lab using Get-LabSwitch.

    If not provided it will attempt to pull the array from the Lab object provided.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $Switches = Get-LabSwitch -Lab $Lab
    Initialize-LabSwitch -Lab $Lab -Switches $Switches
    Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Initialize-LabSwitch -Lab $Lab
    Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
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
        [String[]] $Name,

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
                New-Exception @exceptionParameters
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
                        New-Exception @exceptionParameters
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
                        New-Exception @exceptionParameters
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
                    if ($Script:CurrentBuild -lt 14295)
                    {
                        $exceptionParameters = @{
                            errorId       = 'NatSwitchNotSupportedError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.NatSwitchNotSupportedError -f $SwitchName)
                        }
                        New-Exception @exceptionParameters
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
                        New-Exception @exceptionParameters
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
                        New-Exception @exceptionParameters
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
                        New-Exception @exceptionParameters
                    } # if
                    # Validate the Nat Subnet Prefix Length
                    [int] $NatSubnetPrefixLength = $NatSubnetComponents[1]
                    if (($NatSubnetPrefixLength -lt 1) -or ($NatSubnetPrefixLength -gt 31))
                    {
                        $exceptionParameters = @{
                            errorId       = 'NatSubnetPrefixLengthInvalidError'
                            errorCategory = 'InvalidArgument'
                            errorMessage  = $($LocalizedData.NatSubnetPrefixLengthInvalidError `
                                    -f $SwitchName, $NatSubnetPrefixLength)
                        }
                        New-Exception @exceptionParameters
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
                        New-Exception @exceptionParameters
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
                        New-Exception @exceptionParameters
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
                        $null = $NetNat | Remove-NetNat -Confirm:$False
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
                    New-Exception @exceptionParameters
                }
            } # switch

            if ($SwitchType -ne 'Private')
            {
                # Configure the VLan on the default Management Adapter
                $Splat = @{
                    Name       = $SwitchName
                    SwitchName = $SwitchName
                }
                if ($VMSwitch.VLan)
                {
                    $Splat += @{ VlanId = $VMSwitch.Vlan }
                } # if
                UpdateSwitchManagementAdapter @Splat

                # Add any management OS adapters to the switch
                if ($VMSwitch.Adapters)
                {
                    foreach ($Adapter in $VMSwitch.Adapters)
                    {
                        $Splat = @{
                            Name       = $Adapter.Name
                            SwitchName = $SwitchName
                        }
                        if ($Adapter.MacAddress)
                        {
                            $Splat += @{ StaticMacAddress = $Adapter.MacAddress }
                        } # if
                        if ($VMSwitch.VLan)
                        {
                            $Splat += @{ VlanId = $VMSwitch.Vlan }
                        } # if
                        UpdateSwitchManagementAdapter @Splat
                    } # foreach
                } # if
            } # if
        } # if
    } # foreach
} # Initialize-LabSwitch


<#
.SYNOPSIS
    Removes all Hyper-V Virtual Switches provided.
.DESCRIPTION
    This cmdlet is used to remove any Hyper-V Virtual Switches that were created by
    the Initialize-LabSwitch cmdlet.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of Switch names.

    Only Switches matching names in this list will be removed.
.PARAMETER Switches
    The array of LabSwitch objects pulled from the Lab using Get-LabSwitch.

    If not provided it will attempt to pull the array from the Lab object.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $Switches = Get-LabSwitch -Lab $Lab
    Remove-LabSwitch -Lab $Lab -Switches $Switches
    Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Remove-LabSwitch -Lab $Lab
    Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Remove-LabSwitch
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
        [String[]] $Name,

        [Parameter(
            Position = 3)]
        [LabSwitch[]] $Switches
    )

    # if switches were not passed so pull them
    if (-not $PSBoundParameters.ContainsKey('switches'))
    {
        [LabSwitch[]] $Switches = Get-LabSwitch `
            @PSBoundParameters
    }

    # Delete Hyper-V Switches
    foreach ($VMSwitch in $Switches)
    {
        if ($Name -and ($VMSwitch.name -notin $Name))
        {
            # A names list was passed but this swtich wasn't included
            continue
        } # if

        if ((Get-VMSwitch | Where-Object -Property Name -eq $VMSwitch.Name).Count -ne 0)
        {
            [System.String] $SwitchName = $VMSwitch.Name
            if (-not $SwitchName)
            {
                $exceptionParameters = @{
                    errorId       = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.SwitchNameIsEmptyError)
                }
                New-Exception @exceptionParameters
            }
            [LabSwitchType] $SwitchType = $VMSwitch.Type
            Write-LabMessage -Message $($LocalizedData.DeleteingVirtualSwitchMessage `
                    -f $SwitchType, $SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    if ($VMSwitch.Adapters)
                    {
                        $VMSwitch.Adapters.foreach( {
                                $null = Remove-VMNetworkAdapter `
                                    -ManagementOS `
                                    -Name $_.Name
                            } )
                    } # if
                    Remove-VMSwitch `
                        -Name $SwitchName
                    Break
                } # 'External'
                'Private'
                {
                    Remove-VMSwitch `
                        -Name $SwitchName
                    Break
                } # 'Private'
                'Internal'
                {
                    Remove-VMSwitch `
                        -Name $SwitchName
                    if ($VMSwitch.Adapters)
                    {
                        $VMSwitch.Adapters.foreach( {
                                $null = Remove-VMNetworkAdapter `
                                    -ManagementOS `
                                    -Name $_.Name
                            } )
                    } # if
                    Break
                } # 'Internal'
                'NAT'
                {
                    Remove-NetNat `
                        -Name $SwitchName
                    Remove-VMSwitch `
                        -Name $SwitchName
                    Break
                } # 'Internal'

                Default
                {
                    $exceptionParameters = @{
                        errorId       = 'UnknownSwitchTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage  = $($LocalizedData.UnknownSwitchTypeError `
                                -f $SwitchType, $SwitchName)
                    }
                    New-Exception @exceptionParameters
                }
            } # Switch
        } # if
    } # foreach
} # Remove-LabSwitch
