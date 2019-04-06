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
        [System.String[]]
        $Name,

        [Parameter(
            Position = 3)]
        [LabSwitch[]]
        $Switches,

        [Parameter(
            Position = 4)]
        [Switch]
        $RemoveExternal
    )

    $PSBoundParameters.Remove('RemoveExternal')

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

        $existingVMSwitch = Get-VMSwitch | Where-Object -Property Name -eq $VMSwitch.Name

        if ($existingVMSwitch.Count -ne 0)
        {
            $SwitchName = $VMSwitch.Name

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
                                    -SwitchName $SwitchName `
                                    -Name $_.Name `
                                    -ManagementOS `
                                    -ErrorAction SilentlyContinue
                            } )
                    } # if

                    if ($RemoveExternal)
                    {
                        Remove-VMSwitch `
                            -Name $SwitchName
                    }
                    break
                } # 'External'

                'Private'
                {
                    Remove-VMSwitch `
                        -Name $SwitchName
                    break
                } # 'Private'

                'Internal'
                {
                    if ($VMSwitch.Adapters)
                    {
                        $VMSwitch.Adapters.foreach( {
                                $null = Remove-VMNetworkAdapter `
                                    -SwitchName $SwitchName `
                                    -Name $_.Name `
                                    -ManagementOS `
                                    -ErrorAction SilentlyContinue
                                } )
                    } # if

                    Remove-VMSwitch `
                        -Name $SwitchName
                    break
                } # 'Internal'

                'NAT'
                {
                    Remove-NetNat `
                        -Name $SwitchName
                    Remove-VMSwitch `
                        -Name $SwitchName
                    break
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
}
