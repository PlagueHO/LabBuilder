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
        [System.String[]] $Name
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
            New-LabException @exceptionParameters
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
            New-LabException @exceptionParameters
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
                New-LabException @exceptionParameters
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
