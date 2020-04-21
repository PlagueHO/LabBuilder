function Initialize-LabVM
{
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
        [System.String[]] $Name,

        [Parameter(
            Position=3)]
        [LabVM[]] $VMs
    )

    # if VMs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMs'))
    {
        [LabVM[]] $VMs = Get-LabVM `
            @PSBoundParameters
    } # if

    # if there are not VMs just return
    if (-not $VMs)
    {
        return
    } # if

    $CurrentVMs = Get-VM

    [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Figure out the name of the LabBuilder control switch
    $ManagementSwitchName = Get-LabManagementSwitchName `
        -Lab $Lab
    if ($Lab.labbuilderconfig.switches.ManagementVlan)
    {
        [Int32] $ManagementVlan = $Lab.labbuilderconfig.switches.ManagementVlan
    }
    else
    {
        [Int32] $ManagementVlan = $script:DefaultManagementVLan
    } # if

    foreach ($VM in $VMs)
    {
        if ($Name -and ($VM.Name -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if

        # Get the root path of the VM
        [System.String] $VMRootPath = $VM.VMRootPath

        # Get the Virtual Machine Path
        [System.String] $VMPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Machines'

        # Get the Virtual Hard Disk Path
        [System.String] $VHDPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Hard Disks'

        # Get Path to LabBuilder files
        [System.String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -eq 0)
        {
            Write-LabMessage -Message $($LocalizedData.CreatingVMMessage `
                -f $VM.Name)

            # Make sure the appropriate folders exist
            Initialize-LabVMPath `
                -VMPath $VMRootPath

            # Create the boot disk
            $VMBootDiskPath = "$VHDPath\$($VM.Name) Boot Disk.vhdx"
            if (-not (Test-Path -Path $VMBootDiskPath))
            {
                if ($VM.UseDifferencingDisk)
                {
                    Write-LabMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Differencing Boot')

                    $null = New-VHD `
                        -Differencing `
                        -Path $VMBootDiskPath `
                        -ParentPath $VM.ParentVHD
                }
                else
                {
                    Write-LabMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Boot')

                    $null = Copy-Item `
                        -Path $VM.ParentVHD `
                        -Destination $VMBootDiskPath
                }

                # Create all the required initialization files for this VM
                New-LabVMInitializationFile `
                    -Lab $Lab `
                    -VM $VM

                # Because this is a new boot disk apply any required initialization
                Initialize-LabBootVHD `
                    -Lab $Lab `
                    -VM $VM `
                    -VMBootDiskPath $VMBootDiskPath
            }
            else
            {
                Write-LabMessage -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                    -f $VM.Name,$VMBootDiskPath,'Boot')
            } # if

            # Create New VM from settings
            if ($VM.Version -and ($script:currentBuild -ge 14352))
            {
                $null = New-VM `
                    -Name $VM.Name `
                    -MemoryStartupBytes $VM.MemoryStartupBytes `
                    -Generation $VM.Generation `
                    -Path $LabPath `
                    -VHDPath $VMBootDiskPath `
                    -Version $VM.Version
            }

            else
            {
                $null = New-VM `
                    -Name $VM.Name `
                    -MemoryStartupBytes $VM.MemoryStartupBytes `
                    -Generation $VM.Generation `
                    -Path $LabPath `
                    -VHDPath $VMBootDiskPath `


            }

            # Remove the default network adapter created with the VM because we don't need it
            Remove-VMNetworkAdapter `
                -VMName $VM.Name `
                -Name 'Network Adapter'
        }

        # Set the processor count if different to default and if specified in config file
        if ($VM.ProcessorCount)
        {
            if ($VM.ProcessorCount -ne (Get-VM -Name $VM.Name).ProcessorCount)
            {
                Set-VM `
                    -Name $VM.Name `
                    -ProcessorCount $VM.ProcessorCount
            } # if
        } # if

        # Enable/Disable Dynamic Memory
        Write-Verbose -Message "Checking Dynamic Memory: $($VM.DynamicMemoryEnabled) = $((Get-VMMemory -VMName $VM.Name).DynamicMemoryEnabled)" -Verbose
        if ($VM.DynamicMemoryEnabled -ne (Get-VMMemory -VMName $VM.Name).DynamicMemoryEnabled)
        {
            Write-Verbose -Message "Checking Dynamic Memory: $($VM.DynamicMemoryEnabled)" -Verbose
            Set-VMMemory `
                -VMName $VM.Name `
                -DynamicMemoryEnabled:$($VM.DynamicMemoryEnabled)
        } # if

        # Is ExposeVirtualizationExtensions supported?
        if ($script:currentBuild -lt 10565)
        {
            # No, it is not supported - is it required by VM?
            if ($VM.ExposeVirtualizationExtensions)
            {
                # ExposeVirtualizationExtensions is required for this VM
                $exceptionParameters = @{
                    errorId = 'VMVirtualizationExtError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMVirtualizationExtError `
                        -f $VM.Name)
                }
                New-LabException @exceptionParameters
            } # if
        }
        else
        {
            # Yes, it is - is the setting different?
            if ($VM.ExposeVirtualizationExtensions `
                -ne (Get-VMProcessor -VMName $VM.Name).ExposeVirtualizationExtensions)
            {
                if ($script:currentBuild -ge 14352 -and ($VM.Version -eq "8.0"))
                {
                    Set-VMSecurity `
                        -VMName $VM.Name `
                        -VirtualizationBasedSecurityOptOut $true
                } # if
                # Try and update it
                Set-VMProcessor `
                    -VMName $VM.Name `
                    -ExposeVirtualizationExtensions:$VM.ExposeVirtualizationExtensions `
                    -ErrorAction Stop
            } # if
        } # if

        # Enable/Disable the Integration Services
        Update-LabVMIntegrationService `
            -VM $VM

        # Update the data disks for the VM
        Update-LabVMDataDisk `
            -Lab $Lab `
            -VM $VM

        # Update the DVD Drives for the VM
        Update-LabVMDvdDrive `
            -Lab $Lab `
            -VM $VM

        # Create/Update the Management Network Adapter
        if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $ManagementSwitchName).Count -eq 0)
        {
            Write-LabMessage -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                -f $VM.Name,$ManagementSwitchName,'Management')

            Add-VMNetworkAdapter `
                -VMName $VM.Name `
                -SwitchName $ManagementSwitchName `
                -Name $ManagementSwitchName
        }
        $VMNetworkAdapter = Get-VMNetworkAdapter `
            -VMName $VM.Name `
            -Name $ManagementSwitchName
        $null = $VMNetworkAdapter |
            Set-VMNetworkAdapterVlan `
                -Access `
                -VlanId $ManagementVlan

        Write-LabMessage -Message $($LocalizedData.SettingVMNetworkAdapterVlanMessage `
            -f $VM.Name,$ManagementSwitchName,'Management',$ManagementVlan)

        # Create any network adapters
        foreach ($VMAdapter in $VM.Adapters)
        {
            if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $VMAdapter.Name).Count -eq 0)
            {
                Write-LabMessage -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                    -f $VM.Name,$VMAdapter.SwitchName,$VMAdapter.Name)

                Add-VMNetworkAdapter `
                    -VMName $VM.Name `
                    -SwitchName $VMAdapter.SwitchName `
                    -Name $VMAdapter.Name
            } # if

            $VMNetworkAdapter = Get-VMNetworkAdapter `
                -VMName $VM.Name `
                -Name $VMAdapter.Name
            if ($VMAdapter.VLan)
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapterVlan `
                        -Access `
                        -VlanId $VMAdapter.VLan

                Write-LabMessage -Message $($LocalizedData.SettingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'',$VMAdapter.VLan)
            }
            else
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapterVlan `
                        -Untagged

                Write-LabMessage -Message $($LocalizedData.ClearingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'')
            } # if

            if ([System.String]::IsNullOrWhitespace($VMAdapter.MACAddress))
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -DynamicMacAddress
            }
            else
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -StaticMacAddress $VMAdapter.MACAddress
            } # if

            # Enable Device Naming if supported by VM version and generation
            if (((Get-Command -Name Set-VMNetworkAdapter).Parameters.ContainsKey('DeviceNaming')) -and (($VM.Version -ge "6.2") -and ($VM.Generation -eq 2)))
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -DeviceNaming On
            } # if
            if ($VMAdapter.MACAddressSpoofing -ne $VMNetworkAdapter.MACAddressSpoofing)
            {
                $MACAddressSpoofing = if ($VMAdapter.MACAddressSpoofing) {'On'} else {'Off'}
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -MacAddressSpoofing $MACAddressSpoofing
            } # if
        } # foreach

        Install-LabVM `
            -Lab $Lab `
            -VM $VM
    } # foreach
} # Initialize-LabVM
