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
    $vmRootPath = $VM.VMRootPath

    # Get the Virtual Hard Disk Path
    $vhdPath = Join-Path `
        -Path $vmRootPath `
        -ChildPath 'Virtual Hard Disks'

    foreach ($dataVhd in @($VM.DataVHDs))
    {
        $vhd = $dataVhd.Vhd
        if (Test-Path -Path $vhd)
        {
            Write-LabMessage -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                -f $VM.Name,$vhd,'Data')

            # Check the parameters of the VHD match
            $existingVhd = Get-VHD -Path $vhd

            # Check the VHD Type
            if (($dataVhd.VhdType) `
                -and ($existingVhd.VhdType.ToString() -ne $dataVhd.VhdType.ToString()))
            {
                # The type of disk can't be changed.
                $exceptionParameters = @{
                    errorId = 'VMDataDiskVHDConvertError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDConvertError `
                        -f $VM.name,$vhd,$dataVhd.VhdType)
                }
                New-LabException @exceptionParameters
            }

            # Check the size
            if ($dataVhd.Size)
            {
                if ($existingVhd.Size -lt $dataVhd.Size)
                {
                    # Expand the disk
                    Write-LabMessage -Message $($LocalizedData.ExpandingVMDiskMessage `
                        -f $VM.Name,$vhd,'Data',$dataVhd.Size)

                    $null = Resize-VHD `
                        -Path $vhd `
                        -SizeBytes $dataVhd.Size
                }
                elseif ($existingVhd.Size -gt $dataVhd.Size)
                {
                    <#
                        The disk size can't be reduced.
                        This could be revisited later.
                    #>
                    $exceptionParameters = @{
                        errorId = 'VMDataDiskVHDShrinkError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskVHDShrinkError `
                            -f $VM.name,$vhd,$dataVhd.Size)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if
        }
        else
        {
            # The data disk VHD does not exist so create it
            $SourceVhd = $dataVhd.SourceVhd
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
                if ($dataVhd.MoveSourceVHD)
                {
                    Write-LabMessage -Message $($LocalizedData.CreatingVMDiskByMovingSourceVHDMessage `
                        -f $VM.Name,$vhd,$SourceVhd)

                    $null = Move-Item `
                        -Path $SourceVhd `
                        -Destination $vhdPath `
                        -Force `
                        -ErrorAction Stop
                }
                else
                {
                    Write-LabMessage -Message $($LocalizedData.CreatingVMDiskByCopyingSourceVHDMessage `
                        -f $VM.Name,$vhd,$SourceVhd)

                    $null = Copy-Item `
                        -Path $SourceVhd `
                        -Destination $vhdPath `
                        -Force `
                        -ErrorAction Stop
                } # if
            }
            else
            {
                $size = $dataVhd.size

                switch ($dataVhd.VhdType)
                {
                    'fixed'
                    {
                        # Create a new Fixed VHD
                        Write-LabMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$vhd,'Fixed Data')

                        $null = New-VHD `
                            -Path $vhd `
                            -SizeBytes $size `
                            -Fixed `
                            -ErrorAction Stop
                        break;
                    } # 'fixed'

                    'dynamic'
                    {
                        # Create a new Dynamic VHD
                        Write-LabMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$vhd,'Dynamic Data')

                        $null = New-VHD `
                            -Path $vhd `
                            -SizeBytes $size `
                            -Dynamic `
                            -ErrorAction Stop
                        break;
                    } # 'dynamic'

                    'differencing'
                    {
                        <#
                            A differencing disk is specified so check the Parent VHD
                            is specified and exists.
                        #>
                        $ParentVhd = $dataVhd.ParentVhd
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
                            -f $VM.Name,$vhd,"Differencing Data using Parent '$ParentVhd'")

                        $null = New-VHD `
                            -Path $vhd `
                            -SizeBytes $size `
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
                                -f $VM.Name,$vhd,$dataVhd.VhdType)
                        }
                        New-LabException @exceptionParameters
                    } # default
                } # switch
            } # if

            # Do folders need to be copied to this Data Disk?
            if ($null -ne $dataVhd.CopyFolders)
            {
                <#
                    Files need to be copied to this Data VHD so
                    set up a mount folder for it to be mounted to.
                    Get Path to LabBuilder files
                #>
                $vmLabBuilderFiles = $VM.LabBuilderFilesPath

                $mountPoint = Join-Path `
                    -Path $vmLabBuilderFiles `
                    -ChildPath 'VHDMount'

                if (-not (Test-Path -Path $mountPoint -PathType Container))
                {
                    $null = New-Item `
                        -Path $mountPoint `
                        -ItemType Directory
                }

                # Yes, initialize the disk (or check it is)
                $initializeLabVHDParams = @{
                    Path = $vhd
                    AccessPath = $mountPoint
                }

                # Are we allowed to initialize/format the disk?
                if ($dataVhd.PartitionStyle -and $dataVhd.FileSystem)
                {
                    # Yes, initialize the disk
                    $initializeLabVHDParams += @{
                        PartitionStyle = $dataVhd.PartitionStyle
                        FileSystem = $dataVhd.FileSystem
                    }

                    # Set a FileSystemLabel too?
                    if ($dataVhd.FileSystemLabel)
                    {
                        $initializeLabVHDParams += @{
                            FileSystemLabel = $dataVhd.FileSystemLabel
                        }
                    }
                }

                Write-LabMessage -Message $($LocalizedData.InitializingVMDiskMessage `
                    -f $VM.Name,$vhd)

                Initialize-LabVHD `
                    @initializeLabVHDParams `
                    -ErrorAction Stop

                # Copy each folder to the VM Data Disk
                foreach ($copyFolder in @($dataVhd.CopyFolders))
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFoldersToVMDiskMessage `
                        -f $VM.Name,$vhd,$copyFolder)

                    Copy-item `
                        -Path $copyFolder `
                        -Destination $mountPoint `
                        -Recurse `
                        -Force
                }

                # Dismount the VM Data Disk
                Write-LabMessage -Message $($LocalizedData.DismountingVMDiskMessage `
                    -f $VM.Name,$vhd)

                Dismount-VHD `
                    -Path $vhd `
                    -ErrorAction Stop
            }
            else
            {
                <#
                    No folders need to be copied but check if we
                    need to initialize the new disk.
                #>
                if ($dataVhd.PartitionStyle -and $dataVhd.FileSystem)
                {
                    $InitializeVHDParams = @{
                        Path = $vhd
                        PartitionStyle = $dataVhd.PartitionStyle
                        FileSystem = $dataVhd.FileSystem
                    }

                    if ($dataVhd.FileSystemLabel)
                    {
                        $InitializeVHDParams += @{
                            FileSystemLabel = $dataVhd.FileSystemLabel
                        }
                    } # if

                    Write-LabMessage -Message $($LocalizedData.InitializingVMDiskMessage `
                        -f $VM.Name,$vhd)

                    Initialize-LabVHD `
                        @InitializeVHDParams `
                        -ErrorAction Stop

                    # Dismount the VM Data Disk
                    Write-LabMessage -Message $($LocalizedData.DismountingVMDiskMessage `
                        -f $VM.Name,$vhd)

                    Dismount-VHD `
                        -Path $vhd `
                        -ErrorAction Stop
                } # if
            } # if
        } # if

        # Get a list of disks attached to the VM
        $VMHardDiskDrives = Get-VMHardDiskDrive `
            -VMName $VM.Name

        # The data disk VHD will now exist so ensure it is attached
        if (($VMHardDiskDrives | Where-Object -Property Path -eq $vhd).Count -eq 0)
        {
            # The data disk is not yet attached
            Write-LabMessage -Message $($LocalizedData.AddingVMDiskMessage `
                -f $VM.Name,$vhd,'Data')

            <#
                Determine the ControllerLocation and ControllerNumber to
                attach the VHD to.
            #>
            $controllerLocation = ($VMHardDiskDrives |
                Measure-Object -Property ControllerLocation -Maximum).Maximum + 1

            $newHardDiskParams = @{
                VMName = $VM.Name
                Path = $vhd
                ControllerType = 'SCSI'
                ControllerLocation = $controllerLocation
                ControllerNumber = 0
                ErrorAction = 'Stop'
            }
            if ($dataVhd.Shared -or $dataVhd.SupportPR)
            {
                $newHardDiskParams += @{
                    SupportPersistentReservations = $true
                }
            } # if

            Write-Verbose -Message ($newHardDiskParams | Out-String | Fl *) -Verbose

            $null = Add-VMHardDiskDrive @newHardDiskParams
        } # if
    } # foreach
}
