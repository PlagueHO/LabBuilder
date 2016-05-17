<#
.SYNOPSIS
    Initialized a VM VHD for first boot by applying any required files to the image.
.DESCRIPTION
    This function mounts a VM boot VHD image and applies the following files from the
    LabBuilder Files folder to it:
        1. Unattend.xml - a Windows Unattend.xml file.
        2. SetupComplete.cmd - the command file that gets run after the Windows OOBE is complete.
        3. SetupComplete.ps1 - this PowerShell script file that is run at the the end of the
                                SetupComplete.cmd.
    The files should have already been prepared by the CreateVMInitializationFiles function.
    The VM VHD image should contain an installed copy of Windows still in OOBE mode.
    
    This function also applies optional MSU package files from the Lab resource folder if specified in the packages list in the VM.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A VMLab object pulled from the Lab Configuration file using Get-LabVM.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    InitializeBootVHD `
        -Lab $Lab `
        -VM $VMs[0] `
        -VMBootDiskPath $BootVHD[0]
    Prepare the boot VHD in for the first VM in the Lab c:\mylab\config.xml for initial boot.
.OUTPUTS
    None.
#>
function InitializeBootVHD {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        $Lab,

        [Parameter(Mandatory)]
        [LabVM] $VM,

        [Parameter(Mandatory)]
        [String] $VMBootDiskPath
    )

    # Get path to Lab
    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath
    
    # Mount the VMs Boot VHD so that files can be loaded into it
    WriteMessage -Message $($LocalizedData.MountingVMBootDiskMessage `
        -f $VM.Name,$VMBootDiskPath)
      
    # Create a mount point for mounting the Boot VHD
    [String] $MountPoint = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'Mount'

    if (-not (Test-Path -Path $MountPoint -PathType Container))
    {
        $null = New-Item `
            -Path $MountPoint `
            -ItemType Directory
    }

    # Mount the VHD to the Mount point
    $null = Mount-WindowsImage `
        -ImagePath $VMBootDiskPath `
        -Path $MountPoint `
        -Index 1

    try
    {
        $Packages = $VM.Packages
        if ($VM.OSType -eq [LabOSType]::Nano)
        {
            # Now specify the Nano Server packages to add.
            [String] $NanoPackagesFolder = Join-Path `
                -Path $LabPath `
                -ChildPath 'NanoServerPackages'
            if (-not (Test-Path -Path $NanoPackagesFolder))
            {
                $ExceptionParameters = @{
                    errorId = 'NanoServerPackagesFolderMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NanoServerPackagesFolderMissingError `
                    -f $NanoPackagesFolder)
                }
                ThrowException @ExceptionParameters
            }
            # Add DSC Package to packages list if missing
            if ([String]::IsNullOrWhitespace($Packages))
            {
                $Packages = 'Microsoft-NanoServer-DSC-Package.cab'
            }
            else
            {
                if (@($Packages -split ',') -notcontains 'Microsoft-NanoServer-DSC-Package.cab')
                {
                    $Pacakges = "$Packages,Microsoft-NanoServer-DSC-Package.cab"
                } # if
            } # if
        } # if
        
        # Apply any listed packages to the Image
        if (-not [String]::IsNullOrWhitespace($Packages))
        {
            # Get the list of Lab Resource MSUs
            $ResourceMSUs = Get-LabResourceMSU `
                -Lab $Lab

            foreach ($Package in @($Packages -split ','))
            {
                if (([System.IO.Path]::GetExtension($Package) -eq '.cab') `
                    -and ($VM.OSType -eq [LabOSType]::Nano))
                {
                    # This is a Nano Server .CAB pacakge
                    # Generate the path to the Nano Package
                    $PackagePath = Join-Path `
                        -Path $NanoPackagesFolder `
                        -ChildPath $Package

                    # Does it exist?
                    if (-not (Test-Path -Path $PackagePath))
                    {
                        $ExceptionParameters = @{
                            errorId = 'NanoPackageNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.NanoPackageNotFoundError `
                            -f $PackagePath)
                        }
                        ThrowException @ExceptionParameters
                    }

                    # Add the package
                    WriteMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
                        -f $VM.Name,$Package,$PackagePath)

                    $null = Add-WindowsPackage `
                        -PackagePath $PackagePath `
                        -Path $MountPoint

                    # Generate the path to the Nano Language Package
                    $PackageLangFile = $Package -replace '.cab',"_$($Script:NanoPackageCulture).cab"
                    $PackageLangFile = Join-Path `
                        -Path $NanoPackagesFolder `
                        -ChildPath "$($Script:NanoPackageCulture)\$PackageLangFile"

                    # Does it exist?
                    if (-not (Test-Path -Path $PackageLangFile))
                    {
                        $ExceptionParameters = @{
                            errorId = 'NanoPackageNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.NanoPackageNotFoundError `
                            -f $PackageLangFile)
                        }
                        ThrowException @ExceptionParameters
                    }
                    
                    WriteMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
                        -f $VM.Name,$Package,$PackageLangFile)

                    # Add the package
                    $null = Add-WindowsPackage `
                        -PackagePath $PackageLangFile `
                        -Path $MountPoint
                }
                else
                {
                    # Tihs is a ResourceMSU type package
                    [Boolean] $Found = $False
                    foreach ($ResourceMSU in $ResourceMSUs)
                    {
                        if ($ResourceMSU.Name -eq $Package)
                        {
                            # Found the package
                            $Found = $True
                            break
                        } # if
                    } # foreach
                    if (-not $Found)
                    {
                        $ExceptionParameters = @{
                            errorId = 'PackageNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.PackageNotFoundError `
                            -f $Package)
                        }
                        ThrowException @ExceptionParameters
                    } # if

                    $PackagePath = $ResourceMSU.Filename
                    if (-not (Test-Path -Path $PackagePath))
                    {
                        $ExceptionParameters = @{
                            errorId = 'PackageMSUNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.PackageMSUNotFoundError `
                            -f $Package,$PackagePath)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                    # Apply a Pacakge
                    WriteMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
                        -f $VM.Name,$Package,$PackagePath)

                    $null = Add-WindowsPackage `
                        -PackagePath $PackagePath `
                        -Path $MountPoint
                } # if
            } # foreach
        } # if
    }
    catch
    {
        # Dismount Disk Image before throwing exception
        WriteMessage -Message $($LocalizedData.DismountingVMBootDiskMessage `
            -f $VM.Name,$VMBootDiskPath)
        $null = Dismount-WindowsImage -Path $MountPoint -Save
        $null = Remove-Item -Path $MountPoint -Recurse -Force

        Throw $_
    } # try

    # Create the scripts folder where setup scripts will be put
    $null = New-Item `
        -Path "$MountPoint\Windows\Setup\Scripts" `
        -ItemType Directory

    # Apply an unattended setup file
    WriteMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Unattend','Unattend.xml')

    if (-not (Test-Path -Path "$MountPoint\Windows\Panther" -PathType Container))
    {
        WriteMessage -Message $($LocalizedData.CreatingVMBootDiskPantherFolderMessage `
            -f $VM.Name)

        $null = New-Item `
            -Path "$MountPoint\Windows\Panther" `
            -ItemType Directory
    } # if
    $null = Copy-Item `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'Unattend.xml') `
        -Destination "$MountPoint\Windows\Panther\Unattend.xml" `
        -Force

    # If a Certificate PFX file is available, copy it into the c:\Windows
    # folder of the VM.
    $CertificatePfxPath = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath $Script:DSCEncryptionPfxCert
    if (Test-Path -Path $CertificatePfxPath)
    {
        # Apply the CMD Setup Complete File
        WriteMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
            -f $VM.Name,'Credential Certificate PFX',$Script:DSCEncryptionPfxCert)
        $null = Copy-Item `
            -Path $CertificatePfxPath `
            -Destination "$MountPoint\Windows\$Script:DSCEncryptionPfxCert" `
            -Force
    }

    # Apply the CMD Setup Complete File
    WriteMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Setup Complete CMD','SetupComplete.cmd')
    $null = Copy-Item `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.cmd') `
        -Destination "$MountPoint\Windows\Setup\Scripts\SetupComplete.cmd" `
        -Force

    # Apply the PowerShell Setup Complete file
    WriteMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Setup Complete PowerShell','SetupComplete.ps1')
    $null = Copy-Item `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.ps1') `
        -Destination "$MountPoint\Windows\Setup\Scripts\SetupComplete.ps1" `
        -Force

    # Apply the Certificate Generator script if not a Nano Server
    if ($VM.OSType -ne [LabOSType]::Nano)
    {
        $CertGenFilename = Split-Path -Path $Script:SupportGertGenPath -Leaf
        WriteMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
            -f $VM.Name,'Certificate Create Script',$CertGenFilename)
        $null = Copy-Item `
            -Path $Script:SupportGertGenPath `
            -Destination "$MountPoint\Windows\Setup\Scripts\"`
            -Force
    }
            
    # Dismount the VHD in preparation for boot
    WriteMessage -Message $($LocalizedData.DismountingVMBootDiskMessage `
        -f $VM.Name,$VMBootDiskPath)
    $null = Dismount-WindowsImage -Path $MountPoint -Save
    $null = Remove-Item -Path $MountPoint -Recurse -Force
} # InitializeBootVHD


<#
.SYNOPSIS
    This function mount the VHDx passed and enure it is OK to be writen to.
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
    
    This function will not changed the File System and/or Partition Type on the VHDx
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
   InitializeVhd -Path c:\VMs\Tools.VHDx -AccessPath c:\mount
   The VHDx c:\VMs\Tools.VHDx will be mounted and and assigned to the c:\mount folder
   if it is initialized and contains a formatted partition.
.EXAMPLE
   InitializeVhd -Path c:\VMs\Tools.VHDx -PartitionStyle GPT -FileSystem NTFS
   The VHDx c:\VMs\Tools.VHDx will be mounted and initialized with GPT if not already
   initialized. It will also be partitioned and formatted with NTFS if no partitions
   already exist.
.EXAMPLE
   InitializeVhd `
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
function InitializeVhd
{
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    [CmdletBinding(DefaultParameterSetName = 'AssignDriveLetter')]
    Param (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $Path,

        [LabPartitionStyle] $PartitionStyle,

        [LabFileSystem] $FileSystem,
        
        [ValidateNotNullOrEmpty()]
        [String] $FileSystemLabel,
        
        [Parameter(ParameterSetName = 'DriveLetter')]
        [ValidateNotNullOrEmpty()]
        [String] $DriveLetter,
        
        [Parameter(ParameterSetName = 'AccessPath')]
        [ValidateNotNullOrEmpty()]
        [String] $AccessPath
    )

    # Check file exists
    if (-not (Test-Path -Path $Path))
    {
        $ExceptionParameters = @{
            errorId = 'FileNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.FileNotFoundError `
            -f "VHD",$Path)
        }
        ThrowException @ExceptionParameters
    } # if

    # Check disk is not already mounted
    $VHD = Get-VHD `
        -Path $Path
    if (-not $VHD.Attached)
    {
        WriteMessage -Message ($LocalizedData.InitializeVHDMountingMessage `
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
            $ExceptionParameters = @{
                errorId = 'InitializeVHDNotInitializedError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InitializeVHDNotInitializedError `
                -f $Path)
            }
            ThrowException @ExceptionParameters
        } # if
        WriteMessage -Message ($LocalizedData.InitializeVHDInitializingMessage `
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
        WriteMessage -Message ($LocalizedData.InitializeVHDCreatePartitionMessage `
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
            if (-not [String]::IsNullOrWhitespace($VolumeFileSystem))
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
            if (-not [String]::IsNullOrWhitespace($VolumeFileSystem))
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
    if ([String]::IsNullOrWhitespace($Volume.FileSystem))
    {
        # This volume is not formatted
        if (-not $FileSystem)
        {
            # A File System wasn't specified so can't continue
            $ExceptionParameters = @{
                errorId = 'InitializeVHDNotFormattedError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InitializeVHDNotFormattedError `
                -f $Path)
            }
            ThrowException @ExceptionParameters
        }

        # Format the volume
        WriteMessage -Message ($LocalizedData.InitializeVHDFormatVolumeMessage `
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
            WriteMessage -Message ($LocalizedData.InitializeVHDSetLabelVolumeMessage `
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
                    -PartitionNumber 1 `
                    -NewDriveLetter $DriveLetter `
                    -ErrorAction Stop

                $Volume = Get-Volume `
                    -Partition $Partition

                WriteMessage -Message ($LocalizedData.InitializeVHDDriveLetterMessage `
                    -f $Path,$DriveLetter.ToUpper())
            }
            'AccessPath'
            {
                # Check the Access folder exists
                if (-not (Test-Path -Path $AccessPath -Type Container))
                {
                    $ExceptionParameters = @{
                        errorId = 'InitializeVHDAccessPathNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.InitializeVHDAccessPathNotFoundError `
                        -f $Path,$AccessPath)
                    }
                    ThrowException @ExceptionParameters
                }

                # Add the Partition Access Path
                $null = Add-PartitionAccessPath `
                    -DiskNumber $DiskNumber `
                    -PartitionNumber 1 `
                    -AccessPath $AccessPath `
                    -ErrorAction Stop

                WriteMessage -Message ($LocalizedData.InitializeVHDAccessPathMessage `
                    -f $Path,$AccessPath)
            }
        }
    }
    # Return the Volume to the pipeline
    Return $Volume 
} # InitializeVhd