function Get-LabVM
{
    [OutputType([LabVM[]])]
    [CmdLetBinding()]
    param (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name,

        [Parameter(
            Position=3)]
        [LabVMTemplate[]]
        $vmTemplates,

        [Parameter(
            Position=4)]
        [LabSwitch[]]
        $switches
    )

    # If VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        [LabVMTemplate[]] $vmTemplates = Get-LabVMTemplate `
            -Lab $Lab
    }

    # If Switches array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('Switches'))
    {
        [LabSwitch[]] $switches = Get-LabSwitch `
            -Lab $Lab
    }

    [LabVM[]] $labVMs = @()
    [System.String] $labPath = $Lab.labbuilderconfig.settings.labpath
    [System.String] $labId = $Lab.labbuilderconfig.settings.labid
    $vms = $Lab.labbuilderconfig.vms.vm

    foreach ($vm in $vms)
    {
        if ($vm.Name -eq 'VM')
        {
            $exceptionParameters = @{
                errorId = 'VMNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMNameError)
            }
            New-LabException @exceptionParameters
        } # if

        # Get the Instance Count attribute
        $instanceCount = $vm.InstanceCount

        if (-not $instanceCount)
        {
            $instanceCount = 1
        }

        foreach ($instance in 1..$instanceCount)
        {
            # If InstanceCount is 1 then don't increment the IP or MAC addresses or append count to the name
            if ($instanceCount -eq 1)
            {
                $vmName = $vm.Name
                $computerName = $vm.ComputerName
                $incNetIds = 0
            }
            else
            {
                $vmName = "$($vm.Name)$instance"
                $computerName = "$($vm.ComputerName)$instance"
                # This value is used to increment IP and MAC addresses
                $incNetIds = $instance - 1
            } # if

            if ($Name -and ($vmName -notin $Name))
            {
                # A names list was passed but this VM wasn't included
                continue
            } # if

            # If a LabId is set for the lab, prepend it to the VM name.
            if ($labId)
            {
                $vmName = "$labId$vmName"
            }

            if (-not $vm.Template)
            {
                $exceptionParameters = @{
                    errorId = 'VMTemplateNameEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                        -f $vmName)
                }
                New-LabException @exceptionParameters
            } # if

            # Find the template that this VM uses and get the VHD Path
            [System.String] $parentVHDPath = ''
            [System.Boolean] $found = $false

            foreach ($vmTemplate in $vmTemplates) {
                if ($vmTemplate.Name -eq $vm.Template) {
                    $parentVHDPath = $vmTemplate.ParentVHD
                    $found = $true
                    Break
                } # if
            } # foreach

            if (-not $found)
            {
                $exceptionParameters = @{
                    errorId = 'VMTemplateNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                        -f $vmName,$vm.template)
                }
                New-LabException @exceptionParameters
            } # if

            # Get path to Offline Domain Join file if it exists
            [System.String] $nanoODJPath = $null

            if ($vm.NanoODJPath)
            {
                $nanoODJPath = $vm.NanoODJPath
            } # if

            # Assemble the Network adapters that this VM will use
            [LabVMAdapter[]] $vmAdapters = @()
            [System.Int32] $adapterCount = 0

            foreach ($vmAdapter in $vm.Adapters.Adapter)
            {
                $adapterCount++
                $adapterName = $vmAdapter.Name
                $adapterSwitchName = $vmAdapter.SwitchName

                if ($adapterName -eq 'adapter')
                {
                    $exceptionParameters = @{
                        errorId = 'VMAdapterNameError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMAdapterNameError `
                            -f $vmName)
                    }
                    New-LabException @exceptionParameters
                } # if

                if (-not $adapterSwitchName)
                {
                    $exceptionParameters = @{
                        errorId = 'VMAdapterSwitchNameError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                            -f $vmName,$adapterName)
                    }
                    New-LabException @exceptionParameters
                } # if

                <#
                    If a LabId is set for the lab, prepend it to the adapter name
                    name and switch name.
                #>
                if ($labId)
                {
                    $adapterName = "$labId$adapterName"
                    $adapterSwitchName = "$labId$adapterSwitchName"
                } # if

                # Check the switch is in the switch list
                $found = $false

                foreach ($switch in $switches)
                {
                    <#
                        Match the switch name to the Adapter Switch Name or
                        the LabId and Adapter Switch Name
                    #>
                    if ($switch.Name -eq $adapterSwitchName)
                    {
                        # The switch is found in the switch list - record the VLAN (if there is one)
                        $found = $true
                        $switchVLan = $switch.Vlan
                        break
                    } # if
                    elseif ($switch.Name -eq $vmAdapter.SwitchName)
                    {
                        # The switch is found in the switch list - record the VLAN (if there is one)
                        $found = $true
                        $switchVLan = $switch.Vlan

                        if ($switch.Type -eq [LabSwitchType]::External)
                        {
                            $adapterName = $vmAdapter.Name
                            $adapterSwitchName = $vmAdapter.SwitchName
                        } # if

                        break
                    }
                } # foreach

                if (-not $found)
                {
                    $exceptionParameters = @{
                        errorId = 'VMAdapterSwitchNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMAdapterSwitchNotFoundError `
                            -f $vmName,$adapterName,$adapterSwitchName)
                    }
                    New-LabException @exceptionParameters
                } # if

                # Figure out the VLan - If defined in the VM use it, otherwise use the one defined in the Switch, otherwise keep blank.
                [System.String] $vLan = $vmAdapter.VLan

                if (-not $vLan)
                {
                    $vLan = $switchVLan
                } # if

                [System.Boolean] $MACAddressSpoofing = ($vmAdapter.macaddressspoofing -eq 'On')

                # Have we got any IPv4 settings?
                Remove-Variable -Name IPv4 -ErrorAction SilentlyContinue

                if ($vmAdapter.IPv4)
                {
                    if ($vmAdapter.IPv4.Address)
                    {
                        $ipv4 = [LabVMAdapterIPv4]::New(`
                            (Get-LabNextIpAddress `
                                -IpAddress $vmAdapter.IPv4.Address`
                                -Step $incNetIds)`
                            ,$vmAdapter.IPv4.SubnetMask)
                    } # if

                    $ipv4.defaultgateway = $vmAdapter.IPv4.DefaultGateway
                    $ipv4.dnsserver = $vmAdapter.IPv4.DNSServer
                } # if

                # Have we got any IPv6 settings?
                Remove-Variable -Name IPv6 -ErrorAction SilentlyContinue

                if ($vmAdapter.IPv6)
                {
                    if ($vmAdapter.IPv6.Address)
                    {
                        $ipv6 = [LabVMAdapterIPv6]::New(`
                            (Get-LabNextIpAddress `
                                -IpAddress $vmAdapter.IPv6.Address`
                                -Step $incNetIds)`
                            ,$vmAdapter.IPv6.SubnetMask)
                    } # if

                    $ipv6.defaultgateway = $vmAdapter.IPv6.DefaultGateway
                    $ipv6.dnsserver = $vmAdapter.IPv6.DNSServer
                } # if

                $newVMAdapter = [LabVMAdapter]::New($adapterName)
                $newVMAdapter.SwitchName = $adapterSwitchName

                if ($vmAdapter.macaddress)
                {
                    $newVMAdapter.MACAddress = Get-NextMacAddress `
                        -MacAddress $vmAdapter.macaddress `
                        -Step $incNetIds
                } # if

                $newVMAdapter.MACAddressSpoofing = $MACAddressSpoofing
                $newVMAdapter.VLan = $vLan
                $newVMAdapter.IPv4 = $ipv4
                $newVMAdapter.IPv6 = $ipv6
                $vmAdapters += @( $newVMAdapter )
            } # foreach

            # Assemble the Data Disks this VM will use
            [LabDataVHD[]] $dataVhds = @()
            [System.Int32] $dataVhdCount = 0

            foreach ($vmDataVhd in $vm.DataVhds.DataVhd)
            {
                $dataVhdCount++

                # Load all the VHD properties and check they are valid
                [System.String] $vhd = $vmDataVhd.Vhd

                if (-not $vmDataVhd.Vhd)
                {
                    $exceptionParameters = @{
                        errorId = 'VMDataDiskVHDEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                            -f $vmName)
                    }
                    New-LabException @exceptionParameters
                } # if

                <#
                    Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                    if it doesn't contain a root (e.g. c:\)
                #>
                if (-not [System.IO.Path]::IsPathRooted($vhd))
                {
                    $vhd = Join-Path `
                        -Path $labPath `
                        -ChildPath "$($vmName)\Virtual Hard Disks\$vhd"
                } # if

                # Does the VHD already exist?
                $exists = Test-Path `
                    -Path $vhd

                # Create the new Data VHD object
                $newDataVHD = [LabDataVHD]::New($vhd)

                # Get the Parent VHD and check it exists if passed
                if ($vmDataVhd.ParentVHD)
                {
                    $newDataVHD.ParentVhd = $vmDataVhd.ParentVHD
                    <#
                        Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                        if it doesn't contain a root (e.g. c:\)
                    #>
                    if (-not [System.IO.Path]::IsPathRooted($newDataVHD.ParentVhd))
                    {
                        $newDataVHD.ParentVhd = Join-Path `
                            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $newDataVHD.ParentVhd
                    }

                    if (-not (Test-Path -Path $newDataVHD.ParentVhd))
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskParentVHDNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                                -f $vmName,$newDataVHD.ParentVhd)
                        }
                        New-LabException @exceptionParameters
                    } # if
                } # if

                # Get the Source VHD and check it exists if passed
                if ($vmDataVhd.SourceVHD)
                {
                    $newDataVHD.SourceVhd = $vmDataVhd.SourceVHD
                    <#
                        Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                        if it doesn't contain a root (e.g. c:\)
                    #>
                    if (-not [System.IO.Path]::IsPathRooted($newDataVHD.SourceVhd))
                    {
                        $newDataVHD.SourceVhd = Join-Path `
                            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $newDataVHD.SourceVhd
                    } # if

                    if (-not (Test-Path -Path $newDataVHD.SourceVhd))
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskSourceVHDNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                                -f $vmName,$newDataVHD.SourceVhd)
                        }
                        New-LabException @exceptionParameters
                    } # if
                } # if

                # Get the disk size if provided
                if ($vmDataVhd.Size)
                {
                    $newDataVHD.Size = (Invoke-Expression -Command $vmDataVhd.Size)
                } # if

                # Get the Shared flag
                $newDataVHD.Shared = ($vmDataVhd.Shared -eq 'Y')

                # Get the Support Persistent Reservations
                $newDataVHD.SupportPR = ($vmDataVhd.SupportPR -eq 'Y')

                # Validate the data disk type specified
                if ($vmDataVhd.Type)
                {
                    switch ($vmDataVhd.Type)
                    {
                        'fixed'
                        {
                            break
                        }

                        'dynamic'
                        {
                            break
                        }

                        'differencing'
                        {
                            if (-not $newDataVHD.ParentVhd)
                            {
                                $exceptionParameters = @{
                                    errorId = 'VMDataDiskParentVHDMissingError'
                                    errorCategory = 'InvalidArgument'
                                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                                        -f $vmName)
                                }
                                New-LabException @exceptionParameters
                            } # if

                            if ($newDataVHD.Shared)
                            {
                                $exceptionParameters = @{
                                    errorId = 'VMDataDiskSharedDifferencingError'
                                    errorCategory = 'InvalidArgument'
                                    errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                                        -f $vmName,$VHD)
                                }
                                New-LabException @exceptionParameters
                            } # if

                            break
                        }

                        default
                        {
                            $exceptionParameters = @{
                                errorId = 'VMDataDiskUnknownTypeError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                                    -f $vmName,$VHD,$vmDataVhd.Type)
                            }
                            New-LabException @exceptionParameters
                        }
                    } # switch

                    $newDataVHD.VHDType = [LabVHDType]::$($vmDataVhd.Type)
                } # if

                # Get Partition Style for the new disk.
                if ($vmDataVhd.PartitionStyle)
                {
                    $PartitionStyle = [LabPartitionStyle]::$($vmDataVhd.PartitionStyle)

                    if (-not $PartitionStyle)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskPartitionStyleError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskPartitionStyleError `
                                -f $vmName,$VHD,$vmDataVhd.PartitionStyle)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    $newDataVHD.PartitionStyle = $PartitionStyle
                } # if

                # Get file system for the new disk.
                if ($vmDataVhd.FileSystem)
                {
                    $FileSystem = [LabFileSystem]::$($vmDataVhd.FileSystem)

                    if (-not $FileSystem)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskFileSystemError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskFileSystemError `
                                -f $vmName,$VHD,$vmDataVhd.FileSystem)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    $newDataVHD.FileSystem = $FileSystem
                } # if

                # Has a file system label been provided?
                if ($vmDataVhd.FileSystemLabel)
                {
                    $newDataVHD.FileSystemLabel = $vmDataVhd.FileSystemLabel
                } # if

                <#
                    If the Partition Style, File System or File System Label has been
                    provided then ensure Partition Style and File System are set.
                #>
                if ($newDataVHD.PartitionStyle `
                    -or $newDataVHD.FileSystem `
                    -or $newDataVHD.FileSystemLabel)
                {
                    if (-not $newDataVHD.PartitionStyle)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskPartitionStyleMissingError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                                -f $vmName,$VHD)
                        }
                        New-LabException @exceptionParameters
                    } # if

                    if (-not $newDataVHD.FileSystem)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskFileSystemMissingError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                                -f $vmName,$VHD)
                        }
                        New-LabException @exceptionParameters
                    } # if
                } # if

                # Get the Folder to copy and check it exists if passed
                if ($vmDataVhd.CopyFolders)
                {
                    foreach ($CopyFolder in ($vmDataVhd.CopyFolders -Split ','))
                    {
                        <#
                            Adjust the path to be relative to the configuration folder
                            if it doesn't contain a root (e.g. c:\)
                        #>
                        if (-not [System.IO.Path]::IsPathRooted($CopyFolder))
                        {
                            $CopyFolder = Join-Path `
                                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                                -ChildPath $CopyFolder
                        } # if

                        if (-not (Test-Path -Path $CopyFolder -Type Container))
                        {
                            $exceptionParameters = @{
                                errorId = 'VMDataDiskCopyFolderMissingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskCopyFolderMissingError `
                                    -f $vmName,$VHD,$CopyFolder)
                                }
                            New-LabException @exceptionParameters
                        }
                    } # foreach

                    $newDataVHD.CopyFolders = $vmDataVhd.CopyFolders
                } # if

                # Should the Source VHD be moved rather than copied
                if ($vmDataVhd.MoveSourceVHD)
                {
                    $newDataVHD.MoveSourceVHD = ($vmDataVhd.MoveSourceVHD -eq 'Y')
                    if (-not $newDataVHD.SourceVHD)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskSourceVHDIfMoveError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                                -f $vmName,$VHD)
                        }
                        New-LabException @exceptionParameters
                    } # if
                } # if

                # if the data disk file doesn't exist then some basic parameters MUST be provided
                if (-not $exists `
                    -and ( ( ( -not $newDataVHD.VhdType ) -or ( $newDataVHD.Size -eq 0) ) `
                    -and -not $newDataVHD.SourceVhd ) )
                {
                    $exceptionParameters = @{
                        errorId = 'VMDataDiskCantBeCreatedError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                            -f $vmName,$VHD)
                    }
                    New-LabException @exceptionParameters
                } # if

                $dataVHDs += @( $newDataVHD )
            } # foreach

            # Assemble the DVD Drives this VM will use
            [LabDVDDrive[]] $dvdDrives = @()
            [System.Int32] $dvdDriveCount = 0

            foreach ($vmDVDDrive in $vm.DVDDrives.DVDDrive)
            {
                $dvdDriveCount++

                # Create the new DVD Drive object
                $newDVDDrive = [LabDVDDRive]::New()

                # Load all the DVD Drive properties and check they are valid
                if ($vmDVDDrive.ISO)
                {
                    <#
                        Look the ISO up in the ISO Resources
                        Pull the list of Resource ISOs available if not already pulled from Lab.
                    #>
                    if (-not $resourceISOs)
                    {
                        $resourceISOs = Get-LabResourceISO `
                            -Lab $Lab
                    } # if

                    # Lookup the Resource ISO record
                    $resourceISO = $resourceISOs | Where-Object -Property Name -eq $vmDVDDrive.ISO

                    if (-not $resourceISO)
                    {
                        # The ISO Resource was not found
                        $exceptionParameters = @{
                            errorId = 'VMDVDDriveISOResourceNotFOundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDVDDriveISOResourceNotFOundError `
                                -f $vmName,$vmDVDDrive.ISO)
                        }
                        New-LabException @exceptionParameters
                    } # if

                    # The ISO resource was found so populate the ISO details
                    $newDVDDrive.ISO = $vmDVDDrive.ISO
                    $newDVDDrive.Path = $resourceISO.Path
                } # if

                $dvdDrives += @( $newDVDDrive )
            } # foreach

            # Does the VM have an Unattend file specified?
            $unattendFile = ''

            if ($vm.UnattendFile)
            {
                if ([System.IO.Path]::IsPathRooted($vm.UnattendFile))
                {
                    $unattendFile = $vm.UnattendFile
                }
                else
                {
                    $unattendFile = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $vm.UnattendFile
                } # if

                if (-not (Test-Path $unattendFile))
                {
                    $exceptionParameters = @{
                        errorId = 'UnattendFileMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.UnattendFileMissingError `
                            -f $vmName,$unattendFile)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if

            # Does the VM specify a Setup Complete Script?
            $setupComplete = ''

            if ($vm.SetupComplete)
            {
                if ([System.IO.Path]::IsPathRooted($vm.SetupComplete))
                {
                    $setupComplete = $vm.SetupComplete
                }
                else
                {
                    $setupComplete = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $vm.SetupComplete
                } # if

                if ([System.IO.Path]::GetExtension($setupComplete).ToLower() -notin '.ps1','.cmd' )
                {
                    $exceptionParameters = @{
                        errorId = 'SetupCompleteFileBadTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                            -f $vmName,$setupComplete)
                    }
                    New-LabException @exceptionParameters
                } # if

                if (-not (Test-Path $setupComplete))
                {
                    $exceptionParameters = @{
                        errorId = 'SetupCompleteFileMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                            -f $vmName,$setupComplete)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if

            # Create the Lab DSC object
            $labDSC = [LabDSC]::New($vm.DSC.ConfigName)

            # Load the DSC Config File setting and check it
            $labDSC.ConfigFile = ''

            if ($vm.DSC.ConfigFile)
            {
                if (-not [System.IO.Path]::IsPathRooted($vm.DSC.ConfigFile))
                {
                    $labDSC.ConfigFile = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.dsclibrarypathfull `
                        -ChildPath $vm.DSC.ConfigFile
                }
                else
                {
                    $labDSC.ConfigFile = $vm.DSC.ConfigFile
                } # if

                if ([System.IO.Path]::GetExtension($labDSC.ConfigFile).ToLower() -ne '.ps1' )
                {
                    $exceptionParameters = @{
                        errorId = 'DSCConfigFileBadTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                            -f $vmName,$labDSC.ConfigFile)
                    }
                    New-LabException @exceptionParameters
                } # if

                if (-not (Test-Path $labDSC.ConfigFile))
                {
                    $exceptionParameters = @{
                        errorId = 'DSCConfigFileMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                            -f $vmName,$labDSC.ConfigFile)
                    }
                    New-LabException @exceptionParameters
                } # if

                if (-not $vm.DSC.ConfigName)
                {
                    $exceptionParameters = @{
                        errorId = 'DSCConfigNameIsEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                            -f $vmName)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if

            # Load the DSC Parameters
            $labDSC.Parameters = ''

            if ($vm.DSC.Parameters)
            {
                <#
                    Correct any LFs into CRLFs to ensure the new line format is the same when
                    pulled from the XML.
                #>
                $labDSC.Parameters = ($vm.DSC.Parameters -replace "`r`n","`n") -replace "`n","`r`n"
            } # if

            # Load the DSC Parameters
            $labDSC.Logging = ($vm.DSC.Logging -eq 'Y')

            # Get the Memory Startup Bytes (from the template or VM)
            [System.Int64] $memoryStartupBytes = 1GB

            if ($vm.memorystartupbytes)
            {
                $memoryStartupBytes = (Invoke-Expression -Command $vm.memorystartupbytes)
            }
            elseif ($vmTemplate.memorystartupbytes)
            {
                $memoryStartupBytes = $vmTemplate.memorystartupbytes
            } # if

            # Get the Dynamic Memory Enabled flag
            $dynamicMemoryEnabled = $true

            if ($vm.DynamicMemoryEnabled)
            {
                $dynamicMemoryEnabled = ($vm.DynamicMemoryEnabled -eq 'Y')
            }
            elseif ($vmTemplate.DynamicMemoryEnabled)
            {
                $dynamicMemoryEnabled = $vmTemplate.DynamicMemoryEnabled
            } # if

            # Get the Number of vCPUs (from the template or VM)
            [System.Int32] $processorCount = 1

            if ($vm.processorcount)
            {
                $processorCount = (Invoke-Expression $vm.processorcount)
            }
            elseif ($vmTemplate.processorcount)
            {
                $processorCount = $vmTemplate.processorcount
            } # if

            # Get the Expose Virtualization Extensions flag
            if ($vm.ExposeVirtualizationExtensions)
            {
                $exposeVirtualizationExtensions = ($vm.ExposeVirtualizationExtensions -eq 'Y')
            }
            elseif ($vmTemplate.ExposeVirtualizationExtensions)
            {
                $exposeVirtualizationExtensions = $vmTemplate.ExposeVirtualizationExtensions
            } # if

            <#
                If VM requires ExposeVirtualizationExtensions but
                it is not supported on Host then throw an exception.
            #>
            if ($exposeVirtualizationExtensions -and ($script:currentBuild -lt 10565))
            {
                $exceptionParameters = @{
                    errorId = 'VMVirtualizationExtError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMVirtualizationExtError `
                        -f $vmName)
                }
                New-LabException @exceptionParameters
            } # if

            $useDifferencingDisk = $true

            if ($vm.UseDifferencingDisk -eq 'N')
            {
                $useDifferencingDisk = $false
            } # if

            # Get the Integration Services flags
            if ($null -ne $vm.IntegrationServices)
            {
                $integrationServices = $vm.IntegrationServices
            }
            elseif ($null -ne $vmTemplate.IntegrationServices)
            {
                $integrationServices = $vmTemplate.IntegrationServices
            } # if

            # Get the Administrator password (from the template or VM)
            $administratorPassword = ''

            if ($vm.administratorpassword)
            {
                $administratorPassword = $vm.administratorpassword
            }
            elseif ($vmTemplate.administratorpassword)
            {
                $administratorPassword = $vmTemplate.administratorpassword
            } # if

            # Get the Product Key (from the template or VM)
            $productKey = ''

            if ($vm.productkey)
            {
                $productKey = $vm.productkey
            }
            elseif ($vmTemplate.productkey)
            {
                $productKey = $vmTemplate.productkey
            } # if

            # Get the Timezone (from the template or VM)
            $timezone = 'Pacific Standard Time'

            if ($vm.timezone)
            {
                $timezone = $vm.timezone
            }
            elseif ($vmTemplate.timezone)
            {
                $timezone = $vmTemplate.timezone
            } # if

            # Get the OS Type
            $osType = [LabOStype]::Server

            if ($vm.OSType)
            {
                $osType = $vm.OSType
            }
            elseif ($vmTemplate.OSType)
            {
                $osType = $vmTemplate.OSType
            } # if

            # Get the Bootorder
            [Byte] $bootorder = [Byte]::MaxValue

            if ($vm.bootorder)
            {
                $bootorder = $vm.bootorder
            } # if

            # Get the Packages
            [System.String] $packages = $null

            if ($vm.packages)
            {
                $packages = $vm.packages
            }
            elseif ($vmTemplate.packages)
            {
                $packages = $vmTemplate.packages
            } # if

            # Get the Version (from the template or VM)
            $version = '8.0'

            if ($vm.version)
            {
                $version = $vm.version
            }
            elseif ($vmTemplate.version)
            {
                $version = $vmTemplate.version
            } # if

            # Get the Generation (from the template or VM)
            $generation = '2'

            if ($vm.generation)
            {
                $generation = $vm.generation
            }
            elseif ($vmTemplate.generation)
            {
                $generation = $vmTemplate.generation
            } # if

            # Get the Certificate Source
            $certificateSource = [LabCertificateSource]::Guest

            if ($osType -eq [LabOSType]::Nano)
            {
                # Nano Server can't generate certificates so must always be set to Host
                $certificateSource = [LabCertificateSource]::Host
            }
            elseif ($vm.CertificateSource)
            {
                $certificateSource = $vm.CertificateSource
            } # if


            $labVM = [LabVM]::New($vmName,$computerName)
            $labVM.Template = $vm.Template
            $labVM.ParentVHD = $parentVHDPath
            $labVM.UseDifferencingDisk = $useDifferencingDisk
            $labVM.MemoryStartupBytes = $memoryStartupBytes
            $labVM.DynamicMemoryEnabled = $dynamicMemoryEnabled
            $labVM.ProcessorCount = $processorCount
            $labVM.ExposeVirtualizationExtensions = $exposeVirtualizationExtensions
            $labVM.IntegrationServices = $integrationServices
            $labVM.AdministratorPassword = $administratorPassword
            $labVM.ProductKey = $productKey
            $labVM.TimeZone =$timezone
            $labVM.UnattendFile = $unattendFile
            $labVM.SetupComplete = $setupComplete
            $labVM.OSType = $osType
            $labVM.CertificateSource = $certificateSource
            $labVM.Bootorder = $bootorder
            $labVM.Packages = $packages
            $labVM.Version = $version
            $labVM.Generation = $generation
            $labVM.Adapters = $vmAdapters
            $labVM.DataVHDs = $dataVHDs
            $labVM.DVDDrives = $dvdDrives
            $labVM.DSC = $labDSC
            $labVM.NanoODJPath = $nanoODJPath
            $labVM.VMRootPath = Join-Path `
                -Path $labPath `
                -ChildPath $vmName
            $labVM.LabBuilderFilesPath = Join-Path `
                -Path $labPath `
                -ChildPath "$vmName\LabBuilder Files"
            $labVMs += @( $labVM )
        } # foreach
    } # foreach

    return $labVMs
} # Get-LabVM
