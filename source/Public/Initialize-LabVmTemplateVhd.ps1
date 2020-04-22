function Initialize-LabVMTemplateVHD
{
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
        [System.String[]] $Name,

        [Parameter(
            Position = 3)]
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

    [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Is an alternate path to DISM specified?
    if ($Lab.labbuilderconfig.settings.DismPath)
    {
        $DismPath = Join-Path `
            -Path $Lab.labbuilderconfig.settings.DismPath `
            -ChildPath 'dism.exe'
        if (-not (Test-Path -Path $DismPath))
        {
            $exceptionParameters = @{
                errorId       = 'FileNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.FileNotFoundError `
                        -f 'alternate DISM.EXE', $DismPath)
            }
            New-LabException @exceptionParameters
        }
    }

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [System.String] $TemplateVHDName = $VMTemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        [System.String] $VHDPath = $VMTemplateVHD.VHDPath

        if (Test-Path -Path ($VHDPath))
        {
            # The SourceVHD already exists
            Write-LabMessage -Message $($LocalizedData.SkipVMTemplateVHDFileMessage `
                    -f $TemplateVHDName, $VHDPath)

            continue
        } # if

        # Create the VHD
        Write-LabMessage -Message $($LocalizedData.CreatingVMTemplateVHDMessage `
                -f $TemplateVHDName, $VHDPath)

        # Check the ISO exists.
        [System.String] $ISOPath = $VMTemplateVHD.ISOPath
        if (-not (Test-Path -Path $ISOPath))
        {
            $exceptionParameters = @{
                errorId       = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                        -f $TemplateVHDName, $ISOPath)
            }
            New-LabException @exceptionParameters
        } # if

        # Mount the ISO so we can read the files.
        Write-LabMessage -Message $($LocalizedData.MountingVMTemplateVHDISOMessage `
                -f $TemplateVHDName, $ISOPath)

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
            $exceptionParameters = @{
                errorId       = 'VolumeNotAvailableAfterMountError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.VolumeNotAvailableAfterMountError `
                        -f $ISOPath)
            }
            New-LabException @exceptionParameters
        }
        [System.String] $DriveLetter = $Volume.DriveLetter
        if (-not $DriveLetter)
        {
            $exceptionParameters = @{
                errorId       = 'DriveLetterNotAssignedError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.DriveLetterNotAssignedError `
                        -f $ISOPath)
            }
            New-LabException @exceptionParameters
        }
        [System.String] $ISODrive = "$([System.String]$DriveLetter):"

        # Determine the path to the WIM
        [System.String] $SourcePath = "$ISODrive\Sources\Install.WIM"
        if ($VMTemplateVHD.OSType -eq [LabOStype]::Nano)
        {
            $SourcePath = "$ISODrive\Nanoserver\NanoServer.WIM"
        } # if

        # This will have to change depending on the version
        # of Convert-WindowsImage being used.
        [System.String] $VHDFormat = $VMTemplateVHD.VHDFormat
        [System.String] $VHDType = $VMTemplateVHD.VHDType
        [System.String] $VHDDiskLayout = 'UEFI'
        if ($VMTemplateVHD.Generation -eq 1)
        {
            $VHDDiskLayout = 'BIOS'
        } # if

        [System.String] $Edition = $VMTemplateVHD.Edition
        # if edition is not set then use Get-WindowsImage to get the name
        # of the first image in the WIM.
        if ([System.String]::IsNullOrWhiteSpace($Edition))
        {
            $Edition = (Get-WindowsImage `
                    -ImagePath $SourcePath `
                    -Index 1).ImageName
        } # if

        $ConvertParams = @{
            sourcepath  = $SourcePath
            vhdpath     = $VHDpath
            vhdformat   = $VHDFormat
            # Convert-WindowsImage doesn't support creating different VHDTypes
            # vhdtype = $VHDType
            edition     = $Edition
            disklayout  = $VHDDiskLayout
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
        if (-not [System.String]::IsNullOrWhitespace($VMTemplateVHD.Features))
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
            [System.String] $VHDFolder = Split-Path `
                -Path $VHDPath `
                -Parent

            [System.String] $NanoPackagesFolder = Join-Path `
                -Path $VHDFolder `
                -ChildPath 'NanoServerPackages'

            if (-not (Test-Path -Path $NanoPackagesFolder -Type Container))
            {
                Write-LabMessage -Message $($LocalizedData.CachingNanoServerPackagesMessage `
                        -f "$ISODrive\Nanoserver\Packages", $NanoPackagesFolder)
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
        if (-not [System.String]::IsNullOrWhitespace($VMTemplateVHD.Packages))
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
                            $exceptionParameters = @{
                                errorId       = 'NanoPackageNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage  = $($LocalizedData.NanoPackageNotFoundError `
                                        -f $PackagePath)
                            }
                            New-LabException @exceptionParameters
                        }
                        $Packages += @( $PackagePath )

                        # Generate the path to the Nano Language Package
                        $PackageLangFile = $Package -replace '.cab', "_$($script:NanoPackageCulture).cab"
                        $PackageLangPath = Join-Path `
                            -Path $NanoPackagesFolder `
                            -ChildPath "$($script:NanoPackageCulture)\$PackageLangFile"
                        # Does it exist?
                        if (-not (Test-Path -Path $PackageLangPath))
                        {
                            $exceptionParameters = @{
                                errorId       = 'NanoPackageNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage  = $($LocalizedData.NanoPackageNotFoundError `
                                        -f $PackageLangPath)
                            }
                            New-LabException @exceptionParameters
                        }
                        $Packages += @( $PackageLangPath )
                    }
                    else
                    {
                        # Tihs is a ResourceMSU type package
                        [System.Boolean] $Found = $false
                        foreach ($ResourceMSU in $ResourceMSUs)
                        {
                            if ($ResourceMSU.Name -eq $Package)
                            {
                                # Found the package
                                $Found = $true
                                break
                            } # if
                        } # foreach
                        if (-not $Found)
                        {
                            $exceptionParameters = @{
                                errorId       = 'PackageNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage  = $($LocalizedData.PackageNotFoundError `
                                        -f $Package)
                            }
                            New-LabException @exceptionParameters
                        } # if

                        $PackagePath = $ResourceMSU.Filename
                        if (-not (Test-Path -Path $PackagePath))
                        {
                            $exceptionParameters = @{
                                errorId       = 'PackageMSUNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage  = $($LocalizedData.PackageMSUNotFoundError `
                                        -f $Package, $PackagePath)
                            }
                            New-LabException @exceptionParameters
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

        Write-LabMessage -Message ($LocalizedData.ConvertingWIMtoVHDMessage `
                -f $SourcePath, $VHDPath, $VHDFormat, $Edition, $VHDPartitionStyle, $VHDType)

        # Work around an issue with Convert-WindowsImage not seeing the drive
        Get-PSDrive `
            -PSProvider FileSystem

        # Dot source the Convert-WindowsImage script
        # Should only be done once
        if (-not (Test-Path -Path Function:Convert-WindowsImage))
        {
            . $script:SupportConvertWindowsImagePath
        } # if

        try
        {
            # Call the Convert-WindowsImage script
            Convert-WindowsImage @ConvertParams
        } # try
        catch
        {
            $exceptionParameters = @{
                errorId       = 'ConvertWindowsImageError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.ConvertWindowsImageError `
                        -f $ISOPath, $SourcePath, $Edition, $VHDFormat, $_.Exception.Message)
            }
            New-LabException @exceptionParameters
        } # catch
        finally
        {
            # Dismount the ISO.
            Write-LabMessage -Message $($LocalizedData.DismountingVMTemplateVHDISOMessage `
                    -f $TemplateVHDName, $ISOPath)

            $null = Dismount-DiskImage `
                -ImagePath $ISOPath
        } # finally
    } # endfor
} # Initialize-LabVMTemplateVHD
