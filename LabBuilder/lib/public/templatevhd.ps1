<#
.SYNOPSIS
    Gets an Array of TemplateVHDs for a Lab.
.DESCRIPTION
    Takes a provided Lab and returns the list of Template Disks that will be used to 
    create the Virtual Machines in this lab. This list is usually passed to
    Initialize-LabVMTemplateVHD.

    It will validate the paths to the ISO folder as well as to the ISO files themselves.

    If any ISO files references can't be found an exception will be thrown.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM Template VHD names.

    Only VM Template VHDs matching names in this list will be returned in the array.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
    Loads a Lab and pulls the array of TemplateVHDs from it.
.OUTPUTS
    Returns an array of LabVMTemplateVHD objects.
    It will return Null if the TemplateVHDs node does not exist or contains no TemplateVHD nodes.
#>
function Get-LabVMTemplateVHD {
    [OutputType([LabVMTemplateVHD[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter (
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name
    )

    # return null if the TemplateVHDs node does not exist
    if (-not $Lab.labbuilderconfig.TemplateVHDs)
    {
        return
    }

    # Determine the ISORootPath where the ISO files should be found
    # if no path is specified then look in the same path as the config
    # if a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $ISORootPath = $Lab.labbuilderconfig.TemplateVHDs.ISOPath
    if (-not $ISORootPath)
    {
        $ISORootPath = $Lab.labbuilderconfig.settings.fullconfigpath
    }
    else
    {
        if (-not [System.IO.Path]::IsPathRooted($ISORootPath))
        {
            $ISORootPath = Join-Path `
                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $ISORootPath
        } # if
    } # if
    if (-not (Test-Path -Path $ISORootPath -Type Container))
    {
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDISORootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                -f $ISORootPath)
        }
        ThrowException @ExceptionParameters
    } # if

    # Determine the VHDRootPath where the VHD files should be put
    # if no path is specified then look in the same path as the config
    # if a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $VHDRootPath = $Lab.labbuilderconfig.TemplateVHDs.VHDPath
    if (-not $VHDRootPath)
    {
        $VHDRootPath = $Lab.labbuilderconfig.settings.fullconfigpath
    }
    else
    {
        if (-not [System.IO.Path]::IsPathRooted($VHDRootPath))
        {
            $VHDRootPath = Join-Path `
                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VHDRootPath
        } # if
    } # if
    if (-not (Test-Path -Path $VHDRootPath -Type Container))
    {
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDRootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                -f $VHDRootPath)
        }
        ThrowException @ExceptionParameters
    } # if

    $TemplatePrefix = $Lab.labbuilderconfig.templatevhds.prefix

    # Read the list of templateVHD from the configuration file
    $TemplateVHDs = $Lab.labbuilderconfig.templatevhds.templatevhd
    [LabVMTemplateVHD[]] $VMTemplateVHDs = @()
    foreach ($TemplateVHD in $TemplateVHDs)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'templatevhd' as the name.
        $TemplateVHDName = $TemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        if (($TemplateVHDName -eq 'TemplateVHD') `
            -or ([String]::IsNullOrWhiteSpace($TemplateVHDName)))
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDNameError)
            }
            ThrowException @ExceptionParameters
        } # if
        
        # Get the ISO Path
        [String] $ISOPath = $TemplateVHD.ISO
        if (-not $ISOPath)
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDISOPathError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDISOPathError `
                    -f $TemplateVHD.Name)
            }
            ThrowException @ExceptionParameters
        } # if

        # Adjust the ISO Path if required
        if (-not [System.IO.Path]::IsPathRooted($ISOPath))
        {
            $ISOPath = Join-Path `
                -Path $ISORootPath `
                -ChildPath $ISOPath
        } # if

        # Does the ISO Exist?
        if (-not (Test-Path -Path $ISOPath))
        {
            $URL = $TemplateVHD.URL
            if ($URL)
            {
                WriteMessage `
                    -Type Alert `
                    -Message $($LocalizedData.ISONotFoundDownloadURLMessage `
                        -f $TemplateVHD.Name,$ISOPath,$URL)
            } # if
            $ExceptionParameters = @{
                errorId = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                    -f $TemplateVHD.Name,$ISOPath)
            }
            ThrowException @ExceptionParameters
        } # if

        # Get the VHD Path
        [String] $VHDPath = $TemplateVHD.VHD
        if (-not $VHDPath)
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDPathError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDPathError `
                    -f $TemplateVHD.Name)
            }
            ThrowException @ExceptionParameters
        } # if

        # Adjust the VHD Path if required
        if (-not [System.IO.Path]::IsPathRooted($VHDPath))
        {
            $VHDPath = Join-Path `
                -Path $VHDRootPath `
                -ChildPath $VHDPath
        } # if
        
        # Add the template prefix to the VHD name.
        if ([String]::IsNullOrWhitespace($TemplatePrefix))
        {
             $VHDPath = Join-Path `
                -Path (Split-Path -Path $VHDPath)`
                -ChildPath ("$TemplatePrefix$(Split-Path -Path $VHDPath -Leaf)")
        } # if
        
        # Get the Template OS Type 
        $OSType = [LabOStype]::Server
        if ($TemplateVHD.OSType)
        {
            $OSType = [LabOStype]::$($TemplateVHD.OSType)
        } # if
        if (-not $OSType)
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDOSTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDOSTypeError `
                    -f $TemplateVHD.Name,$TemplateVHD.OSType)
            }
            ThrowException @ExceptionParameters
        } # if

        # Get the Template Wim Image to use
        $Edition = $null
        if ($TemplateVHD.Edition)
        {
            $Edition = $TemplateVHD.Edition
        } # if

        # Get the Template VHD Format 
        $VHDFormat = [LabVHDFormat]::VHDx
        if ($TemplateVHD.VHDFormat)
        {
            $VHDFormat = [LabVHDFormat]::$($TemplateVHD.VHDFormat)
        } # if
        if (-not $VHDFormat)
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDVHDFormatError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDFormatError `
                    -f $TemplateVHD.Name,$TemplateVHD.VHDFormat)
            }
            ThrowException @ExceptionParameters
        }

        # Get the Template VHD Type 
        $VHDType = [LabVHDType]::Dynamic
        if ($TemplateVHD.VHDType)
        {
            $VHDType = [LabVHDType]::$($TemplateVHD.VHDType)
        } # if
        if (-not $VHDType)
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDVHDTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDTypeError `
                    -f $TemplateVHD.Name,$TemplateVHD.VHDType)
            }
            ThrowException @ExceptionParameters
        } # if
        
        # Get the disk size if provided
        [Int64] $Size = 25GB
        if ($TemplateVHD.VHDSize)
        {
            $VHDSize = (Invoke-Expression $TemplateVHD.VHDSize)
        } # if

        # Get the Template VM Generation 
        [int] $Generation = 2
        if ($TemplateVHD.Generation)
        {
            $Generation = $TemplateVHD.Generation
        } # if
        if ($Generation -notin @(1,2) )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDGenerationError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDGenerationError `
                    -f $TemplateVHD.Name,$Generation)
            }
            ThrowException @ExceptionParameters
        }

        # Get the Template Packages
        if ($TemplateVHD.packages)
        {
            $Packages = $TemplateVHD.Packages
        } # if

        # Get the Template Features
        if ($TemplateVHD.features)
        {
            $Features = $TemplateVHD.Features
        } # if

        # Add template VHD to the list
        $NewVMTemplateVHD = [LabVMTemplateVHD]::New($TemplateVHDName)
        $NewVMTemplateVHD.ISOPath = $ISOPath
        $NewVMTemplateVHD.VHDPath = $VHDPath
        $NewVMTemplateVHD.OSType = $OSType
        $NewVMTemplateVHD.Edition = $Edition
        $NewVMTemplateVHD.Generation = $Generation
        $NewVMTemplateVHD.VHDFormat = $VHDFormat
        $NewVMTemplateVHD.VHDType = $VHDType
        $NewVMTemplateVHD.VHDSize = $VHDSize
        $NewVMTemplateVHD.Packages = $Packages
        $NewVMTemplateVHD.Features = $Features
        $VMTemplateVHDs += @( $NewVMTemplateVHD ) 
     } # foreach
    Return $VMTemplateVHDs
} # Get-LabVMTemplateVHD


<#
.SYNOPSIS
    Scans through an array of LabVMTemplateVHD objects and creates them from the ISO if missing.
.DESCRIPTION
    This function will take an array of LabVMTemplateVHD objects from a Lab or it will
    extract the arrays itself if it is not provided and ensure that each VHD file is available.

    If the VHD file is not available then it will attempt to create it from the ISO.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM Template VHD names.

    Only VM Template VHDs matching names in this list will be initialized.
.PARAMETER VMTemplateVHDs
    The array of LabVMTemplateVHD objects pulled from the Lab using Get-LabVMTemplateVHD

    If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
    Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs
    Loads a Lab and pulls the array of VM Template VHDs from it and then
    ensures all the VHDs are available.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Initialize-LabVMTemplateVHD -Lab $Lab
    Loads a Lab and then ensures VM Template VHDs all the VHDs are available.
.OUTPUTS
    None.
#>
function Initialize-LabVMTemplateVHD
{
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
        [String[]] $Name,

        [Parameter(
            Position=3)]
        [LabVMTemplateVHD[]] $VMTemplateVHDs
    )

    # if VMTeplateVHDs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplateVHDs'))
    {
        [LabVMTemplateVHD[]] $VMTemplateVHDs = Get-LabVMTemplateVHD `
            @PSBoundParameters
    } # if

    # if there are no VMTemplateVHDs just return
    if ($null -eq $VMTemplateVHDs)
    {
        return
    } # if

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Is an alternate path to DISM specified?
    if ($Lab.labbuilderconfig.settings.DismPath)
    {
        $DismPath = Join-Path `
            -Path $Lab.labbuilderconfig.settings.DismPath `
            -ChildPath 'dism.exe'
        if (-not (Test-Path -Path $DismPath))
        {
            $ExceptionParameters = @{
                errorId = 'FileNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.FileNotFoundError `
                -f 'alternate DISM.EXE',$DismPath)
            }
            ThrowException @ExceptionParameters
        }
    }

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [String] $TemplateVHDName = $VMTemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        [String] $VHDPath = $VMTemplateVHD.VHDPath
        
        if (Test-Path -Path ($VHDPath))
        {
            # The SourceVHD already exists
            WriteMessage -Message $($LocalizedData.SkipVMTemplateVHDFileMessage `
                -f $TemplateVHDName,$VHDPath)

            continue
        } # if
        
        # Create the VHD
        WriteMessage -Message $($LocalizedData.CreatingVMTemplateVHDMessage `
            -f $TemplateVHDName,$VHDPath)
            
        # Check the ISO exists.
        [String] $ISOPath = $VMTemplateVHD.ISOPath
        if (-not (Test-Path -Path $ISOPath))
        {
            $ExceptionParameters = @{
                errorId = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                    -f $TemplateVHDName,$ISOPath)
            }
            ThrowException @ExceptionParameters
        } # if

        # Mount the ISO so we can read the files.
        WriteMessage -Message $($LocalizedData.MountingVMTemplateVHDISOMessage `
                -f $TemplateVHDName,$ISOPath)

        $null = Mount-DiskImage `
            -ImagePath $ISOPath `
            -StorageType ISO `
            -Access Readonly

        # Refresh the PS Drive list to make sure the new drive can be detected
        Get-PSDrive `
            -PSProvider FileSystem

        $DiskImage = Get-DiskImage -ImagePath $ISOPath
        $Volume = Get-Volume -DiskImage $DiskImage
        if (-not $Volume)
        {
            $ExceptionParameters = @{
                errorId = 'VolumeNotAvailableAfterMountError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VolumeNotAvailableAfterMountError `
                -f $ISOPath)
            }
            ThrowException @ExceptionParameters
        }
        [String] $DriveLetter = $Volume.DriveLetter
        if (-not $DriveLetter)
        {
            $ExceptionParameters = @{
                errorId = 'DriveLetterNotAssignedError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DriveLetterNotAssignedError `
                -f $ISOPath)
            }
            ThrowException @ExceptionParameters
        }
        [String] $ISODrive = "$([string]$DriveLetter):"

        # Determine the path to the WIM
        [String] $SourcePath = "$ISODrive\Sources\Install.WIM"
        if ($VMTemplateVHD.OSType -eq [LabOStype]::Nano)
        {
            $SourcePath = "$ISODrive\Nanoserver\NanoServer.WIM"
        } # if

        # This will have to change depending on the version
        # of Convert-WindowsImage being used.
        [String] $VHDFormat = $VMTemplateVHD.VHDFormat
        [String] $VHDType = $VMTemplateVHD.VHDType
        [String] $VHDDiskLayout = 'UEFI'
        if ($VMTemplateVHD.Generation -eq 1)
        {
            $VHDDiskLayout = 'BIOS'
        } # if

        [String] $Edition = $VMTemplateVHD.Edition
        # if edition is not set then use Get-WindowsImage to get the name
        # of the first image in the WIM.
        if ([String]::IsNullOrWhiteSpace($Edition))
        {
            $Edition = (Get-WindowsImage `
                -ImagePath $SourcePath `
                -Index 1).ImageName
        } # if

        $ConvertParams = @{
            sourcepath = $SourcePath
            vhdpath = $VHDpath
            vhdformat = $VHDFormat
            # Convert-WindowsImage doesn't support creating different VHDTypes
            # vhdtype = $VHDType
            edition = $Edition
            disklayout = $VHDDiskLayout
            erroraction = 'Stop'
        }

        # Set the size
        if ($null -ne $VMTemplateVHD.VHDSize)
        {
            $ConvertParams += @{
                sizebytes = $VMTemplateVHD.VHDSize
            }
        } # if

        # Are any features specified?
        if (-not [String]::IsNullOrWhitespace($VMTemplateVHD.Features))
        {
            $Features = @($VMTemplateVHD.Features -split ',')
            $ConvertParams += @{
                feature = $Features
            }
        } # if

        # Is an alternate path to DISM specified?
        if ($DismPath)
        {
            $ConvertParams += @{
                DismPath = $DismPath
            }
        }

        # Perform Nano Server package prep
        if ($VMTemplateVHD.OSType -eq [LabOStype]::Nano)
        {
            # Make a copy of the all the Nano packages in the VHD root folder
            # So that if any VMs need to add more packages they are accessible
            # once the ISO has been dismounted.
            [String] $VHDFolder = Split-Path `
                -Path $VHDPath `
                -Parent

            [String] $NanoPackagesFolder = Join-Path `
                -Path $VHDFolder `
                -ChildPath 'NanoServerPackages'

            if (-not (Test-Path -Path $NanoPackagesFolder -Type Container))
            {
                WriteMessage -Message $($LocalizedData.CachingNanoServerPackagesMessage `
                        -f "$ISODrive\Nanoserver\Packages",$NanoPackagesFolder)
                Copy-Item `
                    -Path "$ISODrive\Nanoserver\Packages" `
                    -Destination $VHDFolder `
                    -Recurse `
                    -Force
                Rename-Item `
                    -Path "$VHDFolder\Packages" `
                    -NewName 'NanoServerPackages'
            } # if
        } # if

        # Do we need to add any packages?
        if (-not [String]::IsNullOrWhitespace($VMTemplateVHD.Packages))
        {
            $Packages = @()

            # Get the list of Lab Resource MSUs
            $ResourceMSUs = Get-LabResourceMSU `
                -Lab $Lab

            try
            {
                foreach ($Package in @($VMTemplateVHD.Packages -split ','))
                {
                    if (([System.IO.Path]::GetExtension($Package) -eq '.cab') `
                        -and ($VMTemplateVHD.OSType -eq [LabOSType]::Nano))
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
                        $Packages += @( $PackagePath )

                        # Generate the path to the Nano Language Package
                        $PackageLangFile = $Package -replace '.cab',"_$($Script:NanoPackageCulture).cab"
                        $PackageLangPath = Join-Path `
                            -Path $NanoPackagesFolder `
                            -ChildPath "$($Script:NanoPackageCulture)\$PackageLangFile"
                        # Does it exist?
                        if (-not (Test-Path -Path $PackageLangPath))
                        {
                            $ExceptionParameters = @{
                                errorId = 'NanoPackageNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.NanoPackageNotFoundError `
                                -f $PackageLangPath)
                            }
                            ThrowException @ExceptionParameters
                        }
                        $Packages += @( $PackageLangPath )
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
                        $Packages += @( $PackagePath )
                    }
                } # foreach
                $ConvertParams += @{
                    Package = $Packages
                }
            }
            catch
            {
                # Dismount Disk Image before throwing exception
                $null = Dismount-DiskImage `
                    -ImagePath $ISOPath

                Throw $_
            } # try
        } # if

        WriteMessage -Message ($LocalizedData.ConvertingWIMtoVHDMessage `
            -f $SourcePath,$VHDPath,$VHDFormat,$Edition,$VHDPartitionStyle,$VHDType)

        # Work around an issue with Convert-WindowsImage not seeing the drive
        Get-PSDrive `
            -PSProvider FileSystem

        # Dot source the Convert-WindowsImage script
        # Should only be done once 
        if (-not (Test-Path -Path Function:Convert-WindowsImage))
        {
            . $Script:SupportConvertWindowsImagePath
        } # if

        try
        {
            # Call the Convert-WindowsImage script
            Convert-WindowsImage @ConvertParams
        } # try
        catch
        {
            $ExceptionParameters = @{
                errorId = 'ConvertWindowsImageError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.ConvertWindowsImageError `
                    -f $ISOPath,$SourcePath,$Edition,$VHDFormat,$_.Exception.Message)
            }
            ThrowException @ExceptionParameters
        } # catch
        finally
        {
            # Dismount the ISO.
            WriteMessage -Message $($LocalizedData.DismountingVMTemplateVHDISOMessage `
                    -f $TemplateVHDName,$ISOPath)

            $null = Dismount-DiskImage `
                -ImagePath $ISOPath
        } # finally
    } # endfor
} # Initialize-LabVMTemplateVHD


<#
.SYNOPSIS
    Scans through an array of LabVMTemplateVHD objects and removes them if they exist.
.DESCRIPTION
    This function will take an array of LabVMTemplateVHD objects from a Lab or it will
    extract the list itself if it is not provided and remove the VHD file if it exists.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM Template VHD names.
    
    Only VM Template VHDs matching names in this list will be removed.
.PARAMETER VMTemplateVHDs
    The array of LabVMTemplateVHD objects from the Lab using Get-LabVMTemplateVHD.

    If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
    Remove-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs
    Loads a Lab and pulls the array of VM Template VHDs from it and then
    ensures all the VM template VHDs are deleted.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Remove-LabVMTemplateVHD -Lab $Lab
    Loads a Lab and then ensures the VM template VHDs are deleted.
.OUTPUTS
    None.
#>
function Remove-LabVMTemplateVHD
{
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
        [String[]] $Name,

        [Parameter(
            Position=3)]
        [LabVMTemplateVHD[]] $VMTemplateVHDs
    )

    # if VMTeplateVHDs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplateVHDs'))
    {
        [LabVMTemplateVHD[]] $VMTemplateVHDs = Get-LabVMTemplateVHD `
           @PSBoundParameters
    } # if

    # if there are no VMTemplateVHDs just return
    if ($null -eq $VMTemplateVHDs)
    {
        return
    } # if

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [String] $TemplateVHDName = $VMTemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        [String] $VHDPath = $VMTemplateVHD.VHDPath
        
        if (Test-Path -Path ($VHDPath))
        {
            Remove-Item `
                -Path $VHDPath `
                -Force
            WriteMessage -Message $($LocalizedData.DeletingVMTemplateVHDFileMessage `
                -f $TemplateVHDName,$VHDPath)
        } # if
    } # endfor
} # Remove-LabVMTemplateVHD
