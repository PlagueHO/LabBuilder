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
                New-LabException @exceptionParameters
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
                    New-LabException @exceptionParameters
                }
            } # Switch
        } # if
    } # foreach
} # Remove-LabSwitch
