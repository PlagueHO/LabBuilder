<#
    .SYNOPSIS
        This function mounts the VHDx passed and ensures it is OK to be written to.

    .DESCRIPTION
        The function checks that the disk has been paritioned and that it contains
        a volume that has been formatted.

        This function will work for the following situations:
        0. VHDx is not mounted.
        1. VHDx is not initialized and PartitionStyle is passed.
        2. VHDx is initialized but has 0 partitions and FileSystem is passed.
        3. VHDx has 1 partition but 0 volumes and FileSystem is passed.
        4. VHDx has 1 partition and 1 volume that is unformatted and FileSystem is passed.
        5. VHDx has 1 partition and 1 volume that is formatted.

        If the VHDx is any other state an exception will be thrown.

        If the FileSystemLabel passed is different to the current label then it will
        be updated.

        This function will not change the File System and/or Partition Type on the VHDx
        if it is different to the values provided.

    .PARAMETER Path
        This is the path to the VHD/VHDx file to mount and initialize.

    .PARAMETER PartitionStyle
        The Partition Style to set an uninitialized VHD/VHDx to. It can be MBR or GPT.
        If it is not passed and the VHD is not initialized then an exception will be
        thrown.

    .PARAMETER FileSystem
        The File System to format the new parition with on an VHD/VHDx. It can be
        FAT, FAT32, exFAT, NTFS, ReFS.
        If it is not passed and the VHD does not contain any formatted volumes then
        an exception will be thrown.

    .PARAMETER FileSystemLabel
        This parameter will allow the File System Label of the disk to be changed to this
        value.

    .PARAMETER DriveLetter
        Setting this parameter to a drive letter that is not in use will cause the VHD
        to be assigned to this drive letter.

    .PARAMETER AccessPath
        Setting this parameter to an existing folder will cause the VHD to be assigned
        to the AccessPath defined. The folder must already exist otherwise an exception
        will be thrown.

    .EXAMPLE
        Initialize-LabVHD -Path c:\VMs\Tools.VHDx -AccessPath c:\mount
        The VHDx c:\VMs\Tools.VHDx will be mounted and and assigned to the c:\mount folder
        if it is initialized and contains a formatted partition.

    .EXAMPLE
        Initialize-LabVHD -Path c:\VMs\Tools.VHDx -PartitionStyle GPT -FileSystem NTFS
        The VHDx c:\VMs\Tools.VHDx will be mounted and initialized with GPT if not already
        initialized. It will also be partitioned and formatted with NTFS if no partitions
        already exist.

    .EXAMPLE
        Initialize-LabVHD `
            -Path c:\VMs\Tools.VHDx `
            -PartitionStyle GPT `
            -FileSystem NTFS `
            -FileSystemLabel ToolsDisk
            -DriveLetter X
        The VHDx c:\VMs\Tools.VHDx will be mounted and initialized with GPT if not already
        initialized. It will also be partitioned and formatted with NTFS if no partitions
        already exist. The File System label will also be set to ToolsDisk and the disk
        will be mounted to X drive.

    .OUTPUTS
        It will return the Volume object that can then be mounted to a Drive Letter
        or path.
#>
function Initialize-LabVHD
{
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    [CmdletBinding(DefaultParameterSetName = 'AssignDriveLetter')]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [LabPartitionStyle]
        $PartitionStyle,

        [Parameter()]
        [LabFileSystem]
        $FileSystem,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $FileSystemLabel,

        [Parameter(ParameterSetName = 'DriveLetter')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DriveLetter,

        [Parameter(ParameterSetName = 'AccessPath')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AccessPath
    )

    # Check file exists
    if (-not (Test-Path -Path $Path))
    {
        $exceptionParameters = @{
            errorId = 'FileNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.FileNotFoundError `
            -f "VHD",$Path)
        }
        New-LabException @exceptionParameters
    } # if

    # Check disk is not already mounted
    $VHD = Get-VHD `
        -Path $Path
    if (-not $VHD.Attached)
    {
        Write-LabMessage -Message ($LocalizedData.InitializeVHDMountingMessage `
            -f $Path)

        $null = Mount-VHD `
            -Path $Path `
            -ErrorAction Stop
        $VHD = Get-VHD `
            -Path $Path
    } # if

    # Check partition style
    $DiskNumber = $VHD.DiskNumber
    if ((Get-Disk -Number $DiskNumber).PartitionStyle -eq 'RAW')
    {
        if (-not $PartitionStyle)
        {
            $exceptionParameters = @{
                errorId = 'InitializeVHDNotInitializedError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InitializeVHDNotInitializedError `
                -f $Path)
            }
            New-LabException @exceptionParameters
        } # if
        Write-LabMessage -Message ($LocalizedData.InitializeVHDInitializingMessage `
            -f $Path,$PartitionStyle)

        $null = Initialize-Disk `
            -Number $DiskNumber `
            -PartitionStyle $PartitionStyle `
            -ErrorAction Stop
    } # if

    # Check for a partition that is not 'reserved'
    $Partitions = @(Get-Partition `
        -DiskNumber $DiskNumber `
        -ErrorAction SilentlyContinue)
    if (-not ($Partitions) `
        -or (($Partitions | Where-Object -Property Type -ne 'Reserved').Count -eq 0))
    {
        Write-LabMessage -Message ($LocalizedData.InitializeVHDCreatePartitionMessage `
            -f $Path)

        $Partitions = @(New-Partition `
            -DiskNumber $DiskNumber `
            -UseMaximumSize `
            -ErrorAction Stop)
    } # if

    # Find the best partition to work with
    # This will usually be the one just created if it was
    # Otherwise we'll try and match by FileSystem and then
    # format and failing that the first partition.
    foreach ($Partition in $Partitions)
    {
        $VolumeFileSystem = (Get-Volume `
            -Partition $Partition).FileSystem
        if ($FileSystem)
        {
            if (-not [System.String]::IsNullOrWhitespace($VolumeFileSystem))
            {
                # Found a formatted partition
                $FoundFormattedPartition = $Partition
            } # if
            if ($FileSystem -eq $VolumeFileSystem)
            {
                # Found a parition with a matching file system
                $FoundPartition = $Partition
                break
            } # if
        }
        else
        {
            if (-not [System.String]::IsNullOrWhitespace($VolumeFileSystem))
            {
                # Found an formatted partition
                $FoundFormattedPartition = $Partition
                break
            } # if
        } # if
    } # foreach
    if ($FoundPartition)
    {
        # Use the formatted partition
        $Partition = $FoundPartition
    }
    elseif ($FoundFormattedPartition)
    {
        # An unformatted partition was found
        $Partition = $FoundFormattedPartition
    }
    else
    {
        # There are no formatted partitions so use the first one
        $Partition = $Partitions[0]
    } # if

    $PartitionNumber = $Partition.PartitionNumber

    # Check for volume
    $Volume = Get-Volume `
        -Partition $Partition

    # Check for file system
    if ([System.String]::IsNullOrWhitespace($Volume.FileSystem))
    {
        # This volume is not formatted
        if (-not $FileSystem)
        {
            # A File System wasn't specified so can't continue
            $exceptionParameters = @{
                errorId = 'InitializeVHDNotFormattedError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InitializeVHDNotFormattedError `
                -f $Path)
            }
            New-LabException @exceptionParameters
        }

        # Format the volume
        Write-LabMessage -Message ($LocalizedData.InitializeVHDFormatVolumeMessage `
            -f $Path,$FileSystem,$PartitionNumber)
        $FormatProperties = @{
            InputObject = $Volume
            FileSystem = $FileSystem
        }
        if ($FileSystemLabel)
        {
            $FormatProperties += @{
                NewFileSystemLabel = $FileSystemLabel
            }
        }
        $Volume = Format-Volume `
            @FormatProperties `
            -ErrorAction Stop
    }
    else
    {
        # Check the File System Label
        if (($FileSystemLabel) -and `
            ($Volume.FileSystemLabel -ne $FileSystemLabel))
        {
            Write-LabMessage -Message ($LocalizedData.InitializeVHDSetLabelVolumeMessage `
                -f $Path,$FileSystemLabel)
            $Volume = Set-Volume `
                -InputObject $Volume `
                -NewFileSystemLabel $FileSystemLabel `
                -ErrorAction Stop
        }
    }

    # Assign an access path or Drive letter
    if ($DriveLetter -or $AccessPath)
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'DriveLetter'
            {
                # Mount the partition to a Drive Letter
                $null = Set-Partition `
                    -DiskNumber $Disknumber `
                    -PartitionNumber $PartitionNumber `
                    -NewDriveLetter $DriveLetter `
                    -ErrorAction Stop

                $Volume = Get-Volume `
                    -Partition $Partition

                Write-LabMessage -Message ($LocalizedData.InitializeVHDDriveLetterMessage `
                    -f $Path,$DriveLetter.ToUpper())
            }
            'AccessPath'
            {
                # Check the Access folder exists
                if (-not (Test-Path -Path $AccessPath -Type Container))
                {
                    $exceptionParameters = @{
                        errorId = 'InitializeVHDAccessPathNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.InitializeVHDAccessPathNotFoundError `
                        -f $Path,$AccessPath)
                    }
                    New-LabException @exceptionParameters
                }

                # Add the Partition Access Path
                $null = Add-PartitionAccessPath `
                    -DiskNumber $DiskNumber `
                    -PartitionNumber $partitionNumber `
                    -AccessPath $AccessPath `
                    -ErrorAction Stop

                Write-LabMessage -Message ($LocalizedData.InitializeVHDAccessPathMessage `
                    -f $Path,$AccessPath)
            }
        }
    }

    # Return the Volume to the pipeline
    return $Volume
}
