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
function Get-LabSwitch {
    [OutputType([LabSwitch[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,
        
        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name
    )

    [String] $LabId = $Lab.labbuilderconfig.settings.labid 
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
            $ExceptionParameters = @{
                errorId = 'SwitchNameIsEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
            }
            ThrowException @ExceptionParameters
        }

        # Convert the switch type string to a LabSwitchType
        $SwitchType = [LabSwitchType]::$($ConfigSwitch.Type)

        # If the SwitchType string doesn't match any enum value it will be
        # set to null.
        if (-not $SwitchType)
        {
            $ExceptionParameters = @{
                errorId = 'UnknownSwitchTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                    -f $ConfigSwitch.Type,$SwitchName)
            }
            ThrowException @ExceptionParameters
        } # if

        # if a LabId is set for the lab, prepend it to the Switch name as long as it isn't
        # an external switch.
        if ($LabId -and ($SwitchType -ne [LabSwitchType]::External))
        {
            $SwitchName = "$LabId $SwitchName"
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
                    $AdapterName = "$LabId $AdapterName"
                }

                $ConfigAdapter = [LabSwitchAdapter]::New($AdapterName)
                $ConfigAdapter.MACAddress = $Adapter.MacAddress
                $ConfigAdapters += @( $ConfigAdapter )
            } # foreach
            if (($ConfigAdapters.Count -gt 0) `
                -and ($SwitchType -notin [LabSwitchType]::External,[LabSwitchType]::Internal))
            {
                $ExceptionParameters = @{
                    errorId = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.AdapterSpecifiedError `
                        -f $SwitchType,$SwitchName)
                }
                ThrowException @ExceptionParameters
            } # if
        }
        else
        {
            $ConfigAdapters = $null
        } # if

        # Create the new Switch object
        [LabSwitch] $NewSwitch = [LabSwitch]::New($SwitchName,$SwitchType)
        $NewSwitch.VLAN = $ConfigSwitch.VLan
        $NewSwitch.NATSubnetAddress = $ConfigSwitch.NatSubnetAddress
        $NewSwitch.BindingAdapterName = $ConfigSwitch.BindingAdapterName
        $NewSwitch.BindingAdapterMac = $ConfigSwitch.BindingAdapterMac
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
function Initialize-LabSwitch {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,
        
        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,

        [Parameter(
            Position=3)]
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
            [String] $SwitchName = $VMSwitch.Name
            if (-not $SwitchName)
            {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                ThrowException @ExceptionParameters
            }
            [LabSwitchType] $SwitchType = $VMSwitch.Type
            Write-Verbose -Message $($LocalizedData.CreatingVirtualSwitchMessage `
                -f $SwitchType,$SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    # Determine which Physical Adapter to bind this switch to
                    if ($VMSwitch.BindingAdapterMac)
                    {
                        $BindingAdapter = Get-NetAdapter `
                            -Physical | Where-Object {
                            ($_.MacAddress -replace '-','') -eq $VMSwitch.BindingAdapterMac
                        }
                        $ErrorDetail="with a MAC address '$($VMSwitch.BindingAdapterMac)' "
                    }
                    elseif ($VMSwitch.BindingAdapterName)
                    {
                        $BindingAdapter = Get-NetAdapter `
                            -Physical `
                            -Name $VMSwitch.BindingAdapterName `
                            -ErrorAction SilentlyContinue
                        $ErrorDetail="with a name '$($VMSwitch.BindingAdapterName)' "
                    }
                    else
                    {
                        $BindingAdapter = Get-NetAdapter | `
                            Where-Object {
                                ($_.Status -eq 'Up') `
                                -and (-not $_.Virtual) `
                            } | Select-Object -First 1
                        $ErrorDetail=''
                    } # if
                    # Check that a Binding Adapter was found
                    if (-not $BindingAdapter)
                    {
                        $ExceptionParameters = @{
                            errorId = 'BindingAdapterNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.BindingAdapterNotFoundError `
                                -f $SwitchName,$ErrorDetail)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                    # Check this adapter is not already bound to a switch
                    $VMSwitchNames = (Get-VMSwitch | Where-Object {
                        $_.SwitchType -eq 'External'
                    }).Name
                    $MacAddress = @()
                    ForEach ($VmSwitchName in $VmSwitchNames)
                    {
                        $MacAddress += `
                            (Get-VMNetworkAdapter `
                            -ManagementOS `
                            -Name $VmSwitchName -ErrorAction SilentlyContinue).MacAddress
                    } # foreach

                    $UsedAdapters = @((Get-NetAdapter -Physical | ? {
                        ($_.MacAddress -replace '-','') -in $MacAddress
                        }).Name)
                    if ($BindingAdapter.Name -in $UsedAdapters)
                    {
                        $ExceptionParameters = @{
                            errorId = 'BindingAdapterUsedError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.BindingAdapterUsedError `
                                -f $SwitchName,$BindingAdapter.Name)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                    # Create the swtich
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -NetAdapterName ($BindingAdapter.Name)
                    if ($VMSwitch.Adapters)
                    {
                        foreach ($Adapter in $VMSwitch.Adapters)
                        {
                            if ($VMSwitch.VLan)
                            {
                                # A default VLAN is assigned to this Switch so assign it to the
                                # management adapters
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $Adapter.Name `
                                    -StaticMacAddress $Adapter.MacAddress `
                                    
                                    -Passthru | `
                                    Set-VMNetworkAdapterVlan `
                                        -Access `
                                        -VlanId $($VMSwitch.Vlan)
                            }
                            else
                            { 
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $Adapter.Name `
                                    -StaticMacAddress $Adapter.MacAddress
                            } # if
                        } # foreach
                    } # if
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
                    if ($VMSwitch.Adapters)
                    {
                        foreach ($Adapter in $VMSwitch.Adapters)
                        {
                            if ($VMSwitch.VLan)
                            {
                                # A default VLAN is assigned to this Switch so assign it to the
                                # management adapters
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress) `
                                    -Passthru | `
                                    Set-VMNetworkAdapterVlan `
                                        -Access `
                                        -VlanId $($VMSwitch.Vlan)
                            }
                            Else
                            { 
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress)
                            } # if
                        } # foreach
                    } # if
                    Break
                } # 'Internal'
                'NAT'
                {
                    $NatSubnetAddress = $VMSwitch.NatSubnetAddress
                    if (-not $NatSubnetAddress) {
                        $ExceptionParameters = @{
                            errorId = 'NatSubnetAddressEmptyError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.NatSubnetAddressEmptyError `
                                -f $SwitchName)
                        }
                        ThrowException @ExceptionParameters
                    }
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -SwitchType NAT `
                        -NATSubnetAddress $NatSubnetAddress
                    $null = New-NetNat `
                        -Name $SwitchName `
                        -InternalIPInterfaceAddressPrefix $NatSubnetAddress
                    Break
                } # 'NAT'
                Default
                {
                    $ExceptionParameters = @{
                        errorId = 'UnknownSwitchTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                            -f $SwitchType,$SwitchName)
                    }
                    ThrowException @ExceptionParameters
                }
            } # Switch
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
function Remove-LabSwitch {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,

        [Parameter(
            Position=3)]
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
            [String] $SwitchName = $VMSwitch.Name
            if (-not $SwitchName)
            {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                ThrowException @ExceptionParameters
            }
            [LabSwitchType] $SwitchType = $VMSwitch.Type
            Write-Verbose -Message $($LocalizedData.DeleteingVirtualSwitchMessage `
                -f $SwitchType,$SwitchName)
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
                    Remove-NetNAT `
                        -Name $SwitchName
                    Remove-VMSwitch `
                        -Name $SwitchName
                    Break
                } # 'Internal'

                Default
                {
                    $ExceptionParameters = @{
                        errorId = 'UnknownSwitchTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                            -f $SwitchType,$SwitchName)
                    }
                    ThrowException @ExceptionParameters
                }
            } # Switch
        } # if
    } # foreach
} # Remove-LabSwitch
