<#
    .SYNOPSIS
        Updates the VM Data Disks to match the VM Configuration.

    .DESCRIPTION
        This cmdlet will take the VM configuration provided and ensure that that data disks that are
        attached to the VM.

        The function will use the array of items in the DataVHDs property of the VM to create and
        attach any data disk VHDs that are missing.

        If the data disk VHD file exists but is not attached it will be attached to the VM. If the
        data disk VHD file does not exist then it will be created and attached.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Update-LabVMDataDisk -Lab $Lab -VM VM[0]
        This will update the data disks for the first VM in the configuration file c:\mylab\config.xml.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .OUTPUTS
        None.
#>
function Update-LabVMDataDisk
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [LabVM]
        $VM
    )

    # If there are no data VHDs just return
    if (-not $VM.DataVHDs)
    {
        return
    }

    # Get the root path of the VM
    [System.String] $VMRootPath = $VM.VMRootPath

    # Get the Virtual Hard Disk Path
    [System.String] $VHDPath = Join-Path `
        -Path $VMRootPath `
        -ChildPath 'Virtual Hard Disks'

    foreach ($DataVhd in @($VM.DataVHDs))
    {
        $Vhd = $DataVhd.Vhd
        if (Test-Path -Path $Vhd)
        {
            Write-LabMessage -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                -f $VM.Name,$Vhd,'Data')

            # Check the parameters of the VHD match
            $ExistingVhd = Get-VHD -Path $Vhd

            # Check the VHD Type
            if (($DataVhd.VhdType) `
                -and ($ExistingVhd.VhdType.ToString() -ne $DataVhd.VhdType.ToString()))
            {
                # The type of disk can't be changed.
                $exceptionParameters = @{
                    errorId = 'VMDataDiskVHDConvertError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDConvertError `
                        -f $VM.name,$Vhd,$DataVhd.VhdType)
                }
                New-LabException @exceptionParameters
            }

            # Check the size
            if ($DataVhd.Size)
            {
                if ($ExistingVhd.Size -lt $DataVhd.Size)
                {
                    # Expand the disk
                    Write-LabMessage -Message $($LocalizedData.ExpandingVMDiskMessage `
                        -f $VM.Name,$Vhd,'Data',$DataVhd.Size)

                    $null = Resize-VHD `
                        -Path $Vhd `
                        -SizeBytes $DataVhd.Size
                }
                elseif ($ExistingVhd.Size -gt $DataVhd.Size)
                {
                    # The disk size can't be reduced.
                    # This could be revisited later.
                    $exceptionParameters = @{
                        errorId = 'VMDataDiskVHDShrinkError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskVHDShrinkError `
                            -f $VM.name,$Vhd,$DataVhd.Size)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if
        }
        else
        {
            # The data disk VHD does not exist so create it
            $SourceVhd = $DataVhd.SourceVhd
            if ($SourceVhd)
            {
                # A source VHD was specified to create the new VHD using
                if (! (Test-Path -Path $SourceVhd))
                {
                    $exceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                            -f $VM.name,$SourceVhd)
                    }
                    New-LabException @exceptionParameters
                } # if
                # Should the Source VHD be copied or moved
                if ($DataVhd.MoveSourceVHD)
                {
                    Write-LabMessage -Message $($LocalizedData.CreatingVMDiskByMovingSourceVHDMessage `
                        -f $VM.Name,$Vhd,$SourceVhd)

                    $null = Move-Item `
                        -Path $SourceVhd `
                        -Destination $VHDPath `
                        -Force `
                        -ErrorAction Stop
                }
                else
                {
                    Write-LabMessage -Message $($LocalizedData.CreatingVMDiskByCopyingSourceVHDMessage `
                        -f $VM.Name,$Vhd,$SourceVhd)

                    $null = Copy-Item `
                        -Path $SourceVhd `
                        -Destination $VHDPath `
                        -Force `
                        -ErrorAction Stop
                } # if
            }
            else
            {
                $Size = $DataVhd.size
                switch ($DataVhd.VhdType)
                {
                    'fixed'
                    {
                        # Create a new Fixed VHD
                        Write-LabMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$Vhd,'Fixed Data')

                        $null = New-VHD `
                            -Path $Vhd `
                            -SizeBytes $Size `
                            -Fixed `
                            -ErrorAction Stop
                        break;
                    } # 'fixed'
                    'dynamic'
                    {
                        # Create a new Dynamic VHD
                        Write-LabMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$Vhd,'Dynamic Data')

                        $null = New-VHD `
                            -Path $Vhd `
                            -SizeBytes $Size `
                            -Dynamic `
                            -ErrorAction Stop
                        break;
                    } # 'dynamic'
                    'differencing'
                    {
                        # A differencing disk is specified so check the Parent VHD
                        # is specified and exists
                        $ParentVhd = $DataVhd.ParentVhd
                        if (-not $ParentVhd)
                        {
                            $exceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDMissingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                                    -f $VM.name)
                            }
                            New-LabException @exceptionParameters
                        } # if
                        if (-not (Test-Path -Path $ParentVhd))
                        {
                            $exceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                                    -f $VM.name,$ParentVhd)
                            }
                            New-LabException @exceptionParameters
                        } # if

                        # Create a new Differencing VHD
                        Write-LabMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$Vhd,"Differencing Data using Parent '$ParentVhd'")

                        $null = New-VHD `
                            -Path $Vhd `
                            -SizeBytes $Size `
                            -Differencing `
                            -ParentPath $ParentVhd `
                            -ErrorAction Stop
                        break;
                    } # 'differencing'
                    default
                    {
                        $exceptionParameters = @{
                            errorId = 'VMDataDiskUnknownTypeError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                                -f $VM.Name,$Vhd,$DataVhd.VhdType)
                        }
                        New-LabException @exceptionParameters
                    } # default
                } # switch
            } # if

            # Do folders need to be copied to this Data Disk?
            if ($null -ne $DataVhd.CopyFolders)
            {
                # Files need to be copied to this Data VHD so
                # set up a mount folder for it to be mounted to.
                # Get Path to LabBuilder files
                [System.String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

                [System.String] $MountPoint = Join-Path `
                    -Path $VMLabBuilderFiles `
                    -ChildPath 'VHDMount'

                if (-not (Test-Path -Path $MountPoint -PathType Container))
                {
                    $null = New-Item `
                        -Path $MountPoint `
                        -ItemType Directory
                }
                # Yes, initialize the disk (or check it is)
                $initializeLabVHDParams = @{
                    Path = $VHD
                    AccessPath = $MountPoint
                }
                # Are we allowed to initialize/format the disk?
                if ($DataVHD.PartitionStyle -and $DataVHD.FileSystem)
                {
                    # Yes, initialize the disk
                    $initializeLabVHDParams += @{
                        PartitionStyle = $DataVHD.PartitionStyle
                        FileSystem = $DataVHD.FileSystem
                    }
                    # Set a FileSystemLabel too?
                    if ($DataVHD.FileSystemLabel)
                    {
                        $initializeLabVHDParams += @{
                            FileSystemLabel = $DataVHD.FileSystemLabel
                        }
                    }
                }
                Write-LabMessage -Message $($LocalizedData.InitializingVMDiskMessage `
                    -f $VM.Name,$VHD)

                Initialize-LabVHD `
                    @initializeLabVHDParams `
                    -ErrorAction Stop

                # Copy each folder to the VM Data Disk
                foreach ($CopyFolder in @($DataVHD.CopyFolders))
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFoldersToVMDiskMessage `
                        -f $VM.Name,$VHD,$CopyFolder)

                    Copy-item `
                        -Path $CopyFolder `
                        -Destination $MountPoint `
                        -Recurse `
                        -Force
                }

                # Dismount the VM Data Disk
                Write-LabMessage -Message $($LocalizedData.DismountingVMDiskMessage `
                    -f $VM.Name,$VHD)

                Dismount-VHD `
                    -Path $VHD `
                    -ErrorAction Stop
            }
            else
            {
                # No folders need to be copied but check if we
                # need to initialize the new disk.
                if ($DataVHD.PartitionStyle -and $DataVHD.FileSystem)
                {
                    $InitializeVHDParams = @{
                        Path = $VHD
                        PartitionStyle = $DataVHD.PartitionStyle
                        FileSystem = $DataVHD.FileSystem
                    }

                    if ($DataVHD.FileSystemLabel)
                    {
                        $InitializeVHDParams += @{
                            FileSystemLabel = $DataVHD.FileSystemLabel
                        }
                    } # if

                    Write-LabMessage -Message $($LocalizedData.InitializingVMDiskMessage `
                        -f $VM.Name,$VHD)

                    Initialize-LabVHD `
                        @InitializeVHDParams `
                        -ErrorAction Stop

                    # Dismount the VM Data Disk
                    Write-LabMessage -Message $($LocalizedData.DismountingVMDiskMessage `
                        -f $VM.Name,$VHD)

                    Dismount-VHD `
                        -Path $VHD `
                        -ErrorAction Stop
                } # if
            } # if
        } # if

        # Get a list of disks attached to the VM
        $VMHardDiskDrives = Get-VMHardDiskDrive `
            -VMName $VM.Name

        # The data disk VHD will now exist so ensure it is attached
        if (($VMHardDiskDrives | Where-Object -Property Path -eq $Vhd).Count -eq 0)
        {
            # The data disk is not yet attached
            Write-LabMessage -Message $($LocalizedData.AddingVMDiskMessage `
                -f $VM.Name,$Vhd,'Data')

            # Determine the ControllerLocation and ControllerNumber to
            # attach the VHD to.
            $ControllerLocation = ($VMHardDiskDrives |
                Measure-Object -Property ControllerLocation -Maximum).Maximum + 1

            $NewHardDiskParams = @{
                VMName = $VM.Name
                Path = $Vhd
                ControllerType = 'SCSI'
                ControllerLocation = $ControllerLocation
                ControllerNumber = 0
                ErrorAction = 'Stop'
            }
            if ($DataVhd.Shared -or $DataVHD.SupportPR)
            {
                    $NewHardDiskParams += @{
                    SupportPersistentReservations = $true
                    }

            } # if
            $null = Add-VMHardDiskDrive @NewHardDiskParams
        } # if
    } # foreach
}
