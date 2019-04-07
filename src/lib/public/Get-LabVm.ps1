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
        [System.String[]] $Name,

        [Parameter(
            Position=3)]
        [LabVMTemplate[]] $VMTemplates,

        [Parameter(
            Position=4)]
        [LabSwitch[]] $Switches
    )

    # if VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        [LabVMTemplate[]] $VMTemplates = Get-LabVMTemplate `
            -Lab $Lab
    }

    # if Switches array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('Switches'))
    {
        [LabSwitch[]] $Switches = Get-LabSwitch `
            -Lab $Lab
    }

    [LabVM[]] $LabVMs = @()
    [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    [System.String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
    [System.String] $LabId = $Lab.labbuilderconfig.settings.labid
    $VMs = $Lab.labbuilderconfig.vms.vm

    foreach ($VM in $VMs)
    {
        if ($VM.Name -eq 'VM')
        {
            $exceptionParameters = @{
                errorId = 'VMNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMNameError)
            }
            New-LabException @exceptionParameters
        } # if

        # Get the Instance Count attribute
        $InstanceCount = $VM.InstanceCount
        if (-not $InstanceCount)
        {
            $InstanceCount = 1
        }

        foreach ($Instance in 1..$InstanceCount)
        {
            # If InstanceCount is 1 then don't increment the IP or MAC addresses or append count to the name
            if ($InstanceCount -eq 1)
            {
                $VMName = $VM.Name
                $ComputerName = $VM.ComputerName
                $IncNetIds = 0
            }
            else
            {
                $VMName = "$($VM.Name)$Instance"
                $ComputerName = "$($VM.ComputerName)$Instance"
                # This value is used to increment IP and MAC addresses
                $IncNetIds = $Instance - 1
            } # if

            if ($Name -and ($VMName -notin $Name))
            {
                # A names list was passed but this VM wasn't included
                continue
            } # if

            # if a LabId is set for the lab, prepend it to the VM name.
            if ($LabId)
            {
                $VMName = "$LabId$VMName"
            }

            if (-not $VM.Template)
            {
                $exceptionParameters = @{
                    errorId = 'VMTemplateNameEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                        -f $VMName)
                }
                New-LabException @exceptionParameters
            } # if

            # Find the template that this VM uses and get the VHD Path
            [System.String] $ParentVHDPath = ''
            [Boolean] $Found = $false
            foreach ($VMTemplate in $VMTemplates) {
                if ($VMTemplate.Name -eq $VM.Template) {
                    $ParentVHDPath = $VMTemplate.ParentVHD
                    $Found = $true
                    Break
                } # if
            } # foreach

            if (-not $Found)
            {
                $exceptionParameters = @{
                    errorId = 'VMTemplateNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                        -f $VMName,$VM.template)
                }
                New-LabException @exceptionParameters
            } # if

            # Get path to Offline Domain Join file if it exists
            [System.String]$NanoODJPath = $null
            if ($VM.NanoODJPath)
            {
                $NanoODJPath = $VM.NanoODJPath
            } # if

            # Assemble the Network adapters that this VM will use
            [LabVMAdapter[]] $VMAdapters = @()
            [System.Int32] $AdapterCount = 0
            foreach ($VMAdapter in $VM.Adapters.Adapter)
            {
                $AdapterCount++
                $AdapterName = $VMAdapter.Name
                $AdapterSwitchName = $VMAdapter.SwitchName
                if ($AdapterName -eq 'adapter')
                {
                    $exceptionParameters = @{
                        errorId = 'VMAdapterNameError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMAdapterNameError `
                            -f $VMName)
                    }
                    New-LabException @exceptionParameters
                } # if

                if (-not $AdapterSwitchName)
                {
                    $exceptionParameters = @{
                        errorId = 'VMAdapterSwitchNameError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                            -f $VMName,$AdapterName)
                    }
                    New-LabException @exceptionParameters
                } # if

                # if a LabId is set for the lab, prepend it to the adapter name
                # name and switch name.
                if ($LabId)
                {
                    $AdapterName = "$LabId$AdapterName"
                    $AdapterSwitchName = "$LabId$AdapterSwitchName"
                } # if

                # Check the switch is in the switch list
                [Boolean] $Found = $false
                foreach ($Switch in $Switches)
                {
                    # Match the switch name to the Adapter Switch Name or
                    # the LabId and Adapter Switch Name
                    if ($Switch.Name -eq $AdapterSwitchName)
                    {
                        # The switch is found in the switch list - record the VLAN (if there is one)
                        $Found = $true
                        $SwitchVLan = $Switch.Vlan
                        Break
                    } # if
                    elseif ($Switch.Name -eq $VMAdapter.SwitchName)
                    {
                        # The switch is found in the switch list - record the VLAN (if there is one)
                        $Found = $true
                        $SwitchVLan = $Switch.Vlan
                        if ($Switch.Type -eq [LabSwitchType]::External)
                        {
                            $AdapterName = $VMAdapter.Name
                            $AdapterSwitchName = $VMAdapter.SwitchName
                        } # if
                        Break
                    }
                } # foreach
                if (-not $Found)
                {
                    $exceptionParameters = @{
                        errorId = 'VMAdapterSwitchNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMAdapterSwitchNotFoundError `
                            -f $VMName,$AdapterName,$AdapterSwitchName)
                    }
                    New-LabException @exceptionParameters
                } # if

                # Figure out the VLan - If defined in the VM use it, otherwise use the one defined in the Switch, otherwise keep blank.
                [System.String] $VLan = $VMAdapter.VLan
                if (-not $VLan)
                {
                    $VLan = $SwitchVLan
                } # if

                [Boolean] $MACAddressSpoofing = ($VMAdapter.macaddressspoofing -eq 'On')

                # Have we got any IPv4 settings?
                Remove-Variable -Name IPv4 -ErrorAction SilentlyContinue
                if ($VMAdapter.IPv4)
                {
                    if ($VMAdapter.IPv4.Address)
                    {
                        $IPv4 = [LabVMAdapterIPv4]::New(`
                            (Get-LabNextIpAddress `
                                -IpAddress $VMAdapter.IPv4.Address`
                                -Step $IncNetIds)`
                            ,$VMAdapter.IPv4.SubnetMask)
                    } # if
                    $IPv4.defaultgateway = $VMAdapter.IPv4.DefaultGateway
                    $IPv4.dnsserver = $VMAdapter.IPv4.DNSServer
                } # if

                # Have we got any IPv6 settings?
                Remove-Variable -Name IPv6 -ErrorAction SilentlyContinue
                if ($VMAdapter.IPv6)
                {
                    if ($VMAdapter.IPv6.Address)
                    {
                        $IPv6 = [LabVMAdapterIPv6]::New(`
                            (Get-LabNextIpAddress `
                                -IpAddress $VMAdapter.IPv6.Address`
                                -Step $IncNetIds)`
                            ,$VMAdapter.IPv6.SubnetMask)
                    } # if
                    $IPv6.defaultgateway = $VMAdapter.IPv6.DefaultGateway
                    $IPv6.dnsserver = $VMAdapter.IPv6.DNSServer
                } # if

                $NewVMAdapter = [LabVMAdapter]::New($AdapterName)
                $NewVMAdapter.SwitchName = $AdapterSwitchName
                if($VMAdapter.macaddress)
                {
                    $NewVMAdapter.MACAddress = Get-NextMacAddress `
                        -MacAddress $VMAdapter.macaddress `
                        -Step $IncNetIds
                } # if
                $NewVMAdapter.MACAddressSpoofing = $MACAddressSpoofing
                $NewVMAdapter.VLan = $VLan
                $NewVMAdapter.IPv4 = $IPv4
                $NewVMAdapter.IPv6 = $IPv6
                $VMAdapters += @( $NewVMAdapter )
            } # foreach

            # Assemble the Data Disks this VM will use
            [LabDataVHD[]] $DataVhds = @()
            [System.Int32] $DataVhdCount = 0
            foreach ($VMDataVhd in $VM.DataVhds.DataVhd)
            {
                $DataVhdCount++

                # Load all the VHD properties and check they are valid
                [System.String] $Vhd = $VMDataVhd.Vhd
                if (-not $VMDataVhd.Vhd)
                {
                    $exceptionParameters = @{
                        errorId = 'VMDataDiskVHDEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                            -f $VMName)
                    }
                    New-LabException @exceptionParameters
                } # if

                # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                # if it doesn't contain a root (e.g. c:\)
                if (-not [System.IO.Path]::IsPathRooted($Vhd))
                {
                    $Vhd = Join-Path `
                        -Path $LabPath `
                        -ChildPath "$($VMName)\Virtual Hard Disks\$Vhd"
                } # if

                # Does the VHD already exist?
                $Exists = Test-Path `
                    -Path $Vhd

                # Create the new Data VHD object
                $NewDataVHD = [LabDataVHD]::New($Vhd)

                # Get the Parent VHD and check it exists if passed
                if ($VMDataVhd.ParentVHD)
                {
                    $NewDataVHD.ParentVhd = $VMDataVhd.ParentVHD
                    # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                    # if it doesn't contain a root (e.g. c:\)
                    if (-not [System.IO.Path]::IsPathRooted($NewDataVHD.ParentVhd))
                    {
                        $NewDataVHD.ParentVhd = Join-Path `
                            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $NewDataVHD.ParentVhd
                    }
                    if (-not (Test-Path -Path $NewDataVHD.ParentVhd))
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskParentVHDNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                                -f $VMName,$NewDataVHD.ParentVhd)
                        }
                        New-LabException @exceptionParameters
                    } # if
                } # if

                # Get the Source VHD and check it exists if passed
                if ($VMDataVhd.SourceVHD)
                {
                    $NewDataVHD.SourceVhd = $VMDataVhd.SourceVHD
                    # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                    # if it doesn't contain a root (e.g. c:\)
                    if (-not [System.IO.Path]::IsPathRooted($NewDataVHD.SourceVhd))
                    {
                        $NewDataVHD.SourceVhd = Join-Path `
                            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $NewDataVHD.SourceVhd
                    } # if
                    if (-not (Test-Path -Path $NewDataVHD.SourceVhd))
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskSourceVHDNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                                -f $VMName,$NewDataVHD.SourceVhd)
                        }
                        New-LabException @exceptionParameters
                    } # if
                } # if

                # Get the disk size if provided
                if ($VMDataVhd.Size)
                {
                    $NewDataVHD.Size = (Invoke-Expression $VMDataVhd.Size)
                } # if

                # Get the Shared flag
                $NewDataVHD.Shared = ($VMDataVhd.Shared -eq 'Y')

                # Get the Support Persistent Reservations
                $NewDataVHD.SupportPR = ($VMDataVhd.SupportPR -eq 'Y')
                # Validate the data disk type specified
                if ($VMDataVhd.Type)
                {
                    switch ($VMDataVhd.Type)
                    {
                        'fixed'
                        {
                            break;
                        }
                        'dynamic'
                        {
                            break;
                        }
                        'differencing'
                        {
                            if (-not $NewDataVHD.ParentVhd)
                            {
                                $exceptionParameters = @{
                                    errorId = 'VMDataDiskParentVHDMissingError'
                                    errorCategory = 'InvalidArgument'
                                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                                        -f $VMName)
                                }
                                New-LabException @exceptionParameters
                            } # if
                            if ($NewDataVHD.Shared)
                            {
                                $exceptionParameters = @{
                                    errorId = 'VMDataDiskSharedDifferencingError'
                                    errorCategory = 'InvalidArgument'
                                    errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                                        -f $VMName,$VHD)
                                }
                                New-LabException @exceptionParameters
                            } # if
                        }
                        Default
                        {
                            $exceptionParameters = @{
                                errorId = 'VMDataDiskUnknownTypeError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                                    -f $VMName,$VHD,$VMDataVhd.Type)
                            }
                            New-LabException @exceptionParameters
                        }
                    } # switch
                    $NewDataVHD.VHDType = [LabVHDType]::$($VMDataVhd.Type)
                } # if

                # Get Partition Style for the new disk.
                if ($VMDataVhd.PartitionStyle)
                {
                    $PartitionStyle = [LabPartitionStyle]::$($VMDataVhd.PartitionStyle)
                    if (-not $PartitionStyle)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskPartitionStyleError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskPartitionStyleError `
                                -f $VMName,$VHD,$VMDataVhd.PartitionStyle)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    $NewDataVHD.PartitionStyle = $PartitionStyle
                } # if

                # Get file system for the new disk.
                if ($VMDataVhd.FileSystem)
                {
                    $FileSystem = [LabFileSystem]::$($VMDataVhd.FileSystem)
                    if (-not $FileSystem)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskFileSystemError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskFileSystemError `
                                -f $VMName,$VHD,$VMDataVhd.FileSystem)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    $NewDataVHD.FileSystem = $FileSystem
                } # if

                # Has a file system label been provided?
                if ($VMDataVhd.FileSystemLabel)
                {
                    $NewDataVHD.FileSystemLabel = $VMDataVhd.FileSystemLabel
                } # if

                # if the Partition Style, File System or File System Label has been
                # provided then ensure Partition Style and File System are set.
                if ($NewDataVHD.PartitionStyle `
                    -or $NewDataVHD.FileSystem `
                    -or $NewDataVHD.FileSystemLabel)
                {
                    if (-not $NewDataVHD.PartitionStyle)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskPartitionStyleMissingError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                                -f $VMName,$VHD)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    if (-not $NewDataVHD.FileSystem)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskFileSystemMissingError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                                -f $VMName,$VHD)
                        }
                        New-LabException @exceptionParameters
                    } # if
                } # if

                # Get the Folder to copy and check it exists if passed
                if ($VMDataVhd.CopyFolders)
                {
                    foreach ($CopyFolder in ($VMDataVhd.CopyFolders -Split ','))
                    {
                        # Adjust the path to be relative to the configuration folder
                        # if it doesn't contain a root (e.g. c:\)
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
                                -f $VMName,$VHD,$CopyFolder)
                            }
                        New-LabException @exceptionParameters
                        }
                    } # foreach
                    $NewDataVHD.CopyFolders = $VMDataVhd.CopyFolders
                } # if

                # Should the Source VHD be moved rather than copied
                if ($VMDataVhd.MoveSourceVHD)
                {
                    $NewDataVHD.MoveSourceVHD = ($VMDataVhd.MoveSourceVHD -eq 'Y')
                    if (-not $NewDataVHD.SourceVHD)
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskSourceVHDIfMoveError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                                -f $VMName,$VHD)
                        }
                        New-LabException @exceptionParameters
                    } # if
                } # if

                # if the data disk file doesn't exist then some basic parameters MUST be provided
                if (-not $Exists `
                    -and ( ( ( -not $NewDataVHD.VhdType ) -or ( $NewDataVHD.Size -eq 0) ) `
                    -and -not $NewDataVHD.SourceVhd ) )
                {
                    $exceptionParameters = @{
                        errorId = 'VMDataDiskCantBeCreatedError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                            -f $VMName,$VHD)
                    }
                    New-LabException @exceptionParameters
                } # if

                $DataVHDs += @( $NewDataVHD )
            } # foreach

            # Assemble the DVD Drives this VM will use
            [LabDVDDrive[]] $DVDDrives = @()
            [System.Int32] $DVDDriveCount = 0
            foreach ($VMDVDDrive in $VM.DVDDrives.DVDDrive)
            {
                $DVDDriveCount++

                # Create the new DVD Drive object
                $NewDVDDrive = [LabDVDDRive]::New()

                # Load all the DVD Drive properties and check they are valid
                if ($VMDVDDrive.ISO)
                {
                    # Look the ISO up in the ISO Resources
                    # Pull the list of Resource ISOs available if not already pulled from Lab.
                    if (-not $ResourceISOs)
                    {
                        $ResourceISOs = Get-LabResourceISO `
                            -Lab $Lab
                    } # if

                    # Lookup the Resource ISO record
                    $ResourceISO = $ResourceISOs | Where-Object -Property Name -eq $VMDVDDrive.ISO
                    if (-not $ResourceISO)
                    {
                        # The ISO Resource was not found
                        $exceptionParameters = @{
                            errorId = 'VMDVDDriveISOResourceNotFOundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDVDDriveISOResourceNotFOundError `
                                -f $VMName,$VMDVDDrive.ISO)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    # The ISO resource was found so populate the ISO details
                    $NewDVDDrive.ISO = $VMDVDDrive.ISO
                    $NewDVDDrive.Path = $ResourceISO.Path
                } # if

                $DVDDrives += @( $NewDVDDrive )
            } # foreach

            # Does the VM have an Unattend file specified?
            [System.String] $UnattendFile = ''
            if ($VM.UnattendFile)
            {
                if ([System.IO.Path]::IsPathRooted($VM.UnattendFile))
                {
                    $UnattendFile = $VM.UnattendFile
                }
                else
                {
                    $UnattendFile = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $VM.UnattendFile
                } # if
                if (-not (Test-Path $UnattendFile))
                {
                    $exceptionParameters = @{
                        errorId = 'UnattendFileMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.UnattendFileMissingError `
                            -f $VMName,$UnattendFile)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if

            # Does the VM specify a Setup Complete Script?
            [System.String] $SetupComplete = ''
            if ($VM.SetupComplete)
            {
                if ([System.IO.Path]::IsPathRooted($VM.SetupComplete))
                {
                    $SetupComplete = $VM.SetupComplete
                }
                else
                {
                    $SetupComplete = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $VM.SetupComplete
                } # if
                if ([System.IO.Path]::GetExtension($SetupComplete).ToLower() -notin '.ps1','.cmd' )
                {
                    $exceptionParameters = @{
                        errorId = 'SetupCompleteFileBadTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                            -f $VMName,$SetupComplete)
                    }
                    New-LabException @exceptionParameters
                } # if
                if (-not (Test-Path $SetupComplete))
                {
                    $exceptionParameters = @{
                        errorId = 'SetupCompleteFileMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                            -f $VMName,$SetupComplete)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if

            # Create the Lab DSC object
            $LabDSC = [LabDSC]::New($VM.DSC.ConfigName)

            # Load the DSC Config File setting and check it
            [System.String] $LabDSC.ConfigFile = ''
            if ($VM.DSC.ConfigFile)
            {
                if (-not [System.IO.Path]::IsPathRooted($VM.DSC.ConfigFile))
                {
                    $LabDSC.ConfigFile = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.dsclibrarypathfull `
                        -ChildPath $VM.DSC.ConfigFile
                }
                else
                {
                    $LabDSC.ConfigFile = $VM.DSC.ConfigFile
                } # if

                if ([System.IO.Path]::GetExtension($LabDSC.ConfigFile).ToLower() -ne '.ps1' )
                {
                    $exceptionParameters = @{
                        errorId = 'DSCConfigFileBadTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                            -f $VMName,$LabDSC.ConfigFile)
                    }
                    New-LabException @exceptionParameters
                } # if

                if (-not (Test-Path $LabDSC.ConfigFile))
                {
                    $exceptionParameters = @{
                        errorId = 'DSCConfigFileMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                            -f $VMName,$LabDSC.ConfigFile)
                    }
                    New-LabException @exceptionParameters
                } # if
                if (-not $VM.DSC.ConfigName)
                {
                    $exceptionParameters = @{
                        errorId = 'DSCConfigNameIsEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                            -f $VMName)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if

            # Load the DSC Parameters
            [System.String] $LabDSC.Parameters = ''
            if ($VM.DSC.Parameters)
            {
                # Correct any LFs into CRLFs to ensure the new line format is the same when
                # pulled from the XML.
                $LabDSC.Parameters = ($VM.DSC.Parameters -replace "`r`n","`n") -replace "`n","`r`n"
            } # if

            # Load the DSC Parameters
            [Boolean] $LabDSC.Logging = ($VM.DSC.Logging -eq 'Y')

            # Get the Memory Startup Bytes (from the template or VM)
            [Int64] $MemoryStartupBytes = 1GB
            if ($VM.memorystartupbytes)
            {
                $MemoryStartupBytes = (Invoke-Expression $VM.memorystartupbytes)
            }
            elseif ($VMTemplate.memorystartupbytes)
            {
                $MemoryStartupBytes = $VMTemplate.memorystartupbytes
            } # if

            # Get the Dynamic Memory Enabled flag
            [Boolean] $DynamicMemoryEnabled = $true
            if ($VM.DynamicMemoryEnabled)
            {
                $DynamicMemoryEnabled = ($VM.DynamicMemoryEnabled -eq 'Y')
            }
            elseif ($VMTemplate.DynamicMemoryEnabled)
            {
                $DynamicMemoryEnabled = $VMTemplate.DynamicMemoryEnabled
            } # if

            # Get the Number of vCPUs (from the template or VM)
            [System.Int32] $ProcessorCount = 1
            if ($VM.processorcount)
            {
                $ProcessorCount = (Invoke-Expression $VM.processorcount)
            }
            elseif ($VMTemplate.processorcount)
            {
                $ProcessorCount = $VMTemplate.processorcount
            } # if

            # Get the Expose Virtualization Extensions flag
            if ($VM.ExposeVirtualizationExtensions)
            {
                $ExposeVirtualizationExtensions = ($VM.ExposeVirtualizationExtensions -eq 'Y')
            }
            elseif ($VMTemplate.ExposeVirtualizationExtensions)
            {
                $ExposeVirtualizationExtensions = $VMTemplate.ExposeVirtualizationExtensions
            } # if

            # If VM requires ExposeVirtualizationExtensions but
            # it is not supported on Host then throw an exception.
            if ($ExposeVirtualizationExtensions -and ($Script:CurrentBuild -lt 10565))
            {
                $exceptionParameters = @{
                    errorId = 'VMVirtualizationExtError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMVirtualizationExtError `
                        -f $VMName)
                }
                New-LabException @exceptionParameters
            } # if

            [Boolean] $UseDifferencingDisk = $true
            if ($VM.UseDifferencingDisk -eq 'N')
            {
                $UseDifferencingDisk = $false
            } # if

            # Get the Integration Services flags
            if ($null -ne $VM.IntegrationServices)
            {
                $IntegrationServices = $VM.IntegrationServices
            }
            elseif ($null -ne $VMTemplate.IntegrationServices)
            {
                $IntegrationServices = $VMTemplate.IntegrationServices
            } # if

            # Get the Administrator password (from the template or VM)
            [System.String] $AdministratorPassword = ''
            if ($VM.administratorpassword)
            {
                $AdministratorPassword = $VM.administratorpassword
            }
            elseif ($VMTemplate.administratorpassword)
            {
                $AdministratorPassword = $VMTemplate.administratorpassword
            } # if

            # Get the Product Key (from the template or VM)
            [System.String] $ProductKey = ''
            if ($VM.productkey)
            {
                $ProductKey = $VM.productkey
            }
            elseif ($VMTemplate.productkey)
            {
                $ProductKey = $VMTemplate.productkey
            } # if

            # Get the Timezone (from the template or VM)
            [System.String] $Timezone = 'Pacific Standard Time'
            if ($VM.timezone)
            {
                $Timezone = $VM.timezone
            }
            elseif ($VMTemplate.timezone)
            {
                $Timezone = $VMTemplate.timezone
            } # if

            # Get the OS Type
            $OSType = [LabOStype]::Server
            if ($VM.OSType)
            {
                $OSType = $VM.OSType
            }
            elseif ($VMTemplate.OSType)
            {
                $OSType = $VMTemplate.OSType
            } # if

            # Get the Bootorder
            [Byte] $Bootorder = [Byte]::MaxValue
            if ($VM.bootorder)
            {
                $Bootorder = $VM.bootorder
            } # if

            # Get the Packages
            [System.String] $Packages = $null
            if ($VM.packages)
            {
                $Packages = $VM.packages
            }
            elseif ($VMTemplate.packages)
            {
                $Packages = $VMTemplate.packages
            } # if

            # Get the Version (from the template or VM)
            [System.String] $Version = '8.0'
            if ($VM.version)
            {
                $Version = $VM.version
            }
            elseif ($VMTemplate.version)
            {
                $Version = $VMTemplate.version
            } # if

            # Get the Generation (from the template or VM)
            [System.String] $Generation = 2
            if ($VM.generation)
            {
                $Generation = $VM.generation
            }
            elseif ($VMTemplate.generation)
            {
                $Generation = $VMTemplate.generation
            } # if

            # Get the Certificate Source
            $CertificateSource = [LabCertificateSource]::Guest
            if ($OSType -eq [LabOSType]::Nano)
            {
                # Nano Server can't generate certificates so must always be set to Host
                $CertificateSource = [LabCertificateSource]::Host
            }
            elseif ($VM.CertificateSource)
            {
                $CertificateSource = $VM.CertificateSource
            } # if


            $LabVM = [LabVM]::New($VMName,$ComputerName)
            $LabVM.Template = $VM.Template
            $LabVM.ParentVHD = $ParentVHDPath
            $LabVM.UseDifferencingDisk = $UseDifferencingDisk
            $LabVM.MemoryStartupBytes = $MemoryStartupBytes
            $LabVM.DynamicMemoryEnabled = $DynamicMemoryEnabled
            $LabVM.ProcessorCount = $ProcessorCount
            $LabVM.ExposeVirtualizationExtensions = $ExposeVirtualizationExtensions
            $LabVM.IntegrationServices = $IntegrationServices
            $LabVM.AdministratorPassword = $AdministratorPassword
            $LabVM.ProductKey = $ProductKey
            $LabVM.TimeZone =$Timezone
            $LabVM.UnattendFile = $UnattendFile
            $LabVM.SetupComplete = $SetupComplete
            $LabVM.OSType = $OSType
            $LabVM.CertificateSource = $CertificateSource
            $LabVM.Bootorder = $Bootorder
            $LabVM.Packages = $Packages
            $LabVM.Version = $Version
            $LabVM.Generation = $Generation
            $LabVM.Adapters = $VMAdapters
            $LabVM.DataVHDs = $DataVHDs
            $LabVM.DVDDrives = $DVDDrives
            $LabVM.DSC = $LabDSC
            $LabVM.NanoODJPath = $NanoODJPath
            $LabVM.VMRootPath = Join-Path `
                -Path $LabPath `
                -ChildPath $VMName
            $LabVM.LabBuilderFilesPath = Join-Path `
                -Path $LabPath `
                -ChildPath "$VMName\LabBuilder Files"
            $LabVMs += @( $LabVM )
        } # foreach
    } # foreach

    Return $LabVMs
} # Get-LabVM
