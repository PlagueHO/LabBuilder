function Initialize-LabVMTemplate
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
        [System.String[]] $Name,

        [Parameter(
            Position = 3)]
        [LabVMTemplate[]] $VMTemplates,

        [Parameter(
            Position = 4)]
        [LabVMTemplateVHD[]] $VMTemplateVHDs
    )

    # if VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        [LabVMTemplate[]] $VMTemplates = Get-LabVMTemplate `
            @PSBoundParameters
    }

    [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Check each Parent VHD exists in the Parent VHDs folder for the
    # Lab. If it isn't, try and copy it from the SourceVHD
    # Location.
    foreach ($VMTemplate in $VMTemplates)
    {
        if ($Name -and ($VMTemplate.Name -notin $Name))
        {
            # A names list was passed but this VM Template wasn't included
            continue
        } # if

        if (-not (Test-Path $VMTemplate.ParentVhd))
        {
            # The Parent VHD isn't in the VHD Parent folder
            # so copy it there, optimize it and mark it read-only.
            if (-not (Test-Path $VMTemplate.SourceVhd))
            {
                # The source VHD could not be found.
                $exceptionParameters = @{
                    errorId       = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.TemplateSourceVHDNotFoundError `
                            -f $VMTemplate.Name, $VMTemplate.sourcevhd)
                }
                New-LabException @exceptionParameters
            }

            Write-LabMessage -Message $($LocalizedData.CopyingTemplateSourceVHDMessage `
                    -f $VMTemplate.SourceVhd, $VMTemplate.ParentVhd)
            Copy-Item `
                -Path $VMTemplate.SourceVhd `
                -Destination $VMTemplate.ParentVhd

            # Add any packages to the template if required
            if (-not [System.String]::IsNullOrWhitespace($VMTemplate.Packages))
            {
                if ($VMTemplate.OSType -ne [LabOStype]::Nano)
                {
                    # Mount the Template Boot VHD so that files can be loaded into it
                    Write-LabMessage -Message $($LocalizedData.MountingTemplateBootDiskMessage `
                            -f $VMTemplate.Name, $VMTemplate.ParentVhd)

                    # Create a mount point for mounting the Boot VHD
                    [System.String] $MountPoint = Join-Path `
                        -Path (Split-Path -Path $VMTemplate.ParentVHD) `
                        -ChildPath 'Mount'

                    if (-not (Test-Path -Path $MountPoint -PathType Container))
                    {
                        $null = New-Item `
                            -Path $MountPoint `
                            -ItemType Directory
                    }

                    # Mount the VHD to the Mount point
                    $null = Mount-WindowsImage `
                        -ImagePath $VMTemplate.parentvhd `
                        -Path $MountPoint `
                        -Index 1

                    # Get the list of Packages to apply
                    $ApplyPackages = @($VMTemplate.Packages -split ',')

                    # Get the list of Lab Resource MSUs
                    $ResourceMSUs = Get-LabResourceMSU `
                        -Lab $Lab

                    foreach ($Package in $ApplyPackages)
                    {
                        # Find the package in the Resources
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
                            # Dismount before throwing the error
                            Write-LabMessage -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
                                    -f $VMTemplate.Name, $VMTemplate.parentvhd)
                            $null = Dismount-WindowsImage `
                                -Path $MountPoint `
                                -Save
                            $null = Remove-Item `
                                -Path $MountPoint `
                                -Recurse `
                                -Force

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
                            # Dismount before throwing the error
                            Write-LabMessage -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
                                    -f $VMTemplate.Name, $VMTemplate.ParentVhd)
                            $null = Dismount-WindowsImage `
                                -Path $MountPoint `
                                -Save
                            $null = Remove-Item `
                                -Path $MountPoint `
                                -Recurse `
                                -Force

                            $exceptionParameters = @{
                                errorId       = 'PackageMSUNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage  = $($LocalizedData.PackageMSUNotFoundError `
                                        -f $Package, $PackagePath)
                            }
                            New-LabException @exceptionParameters
                        } # if

                        # Apply a Pacakge
                        Write-LabMessage -Message $($LocalizedData.ApplyingTemplateBootDiskFileMessage `
                                -f $VMTemplate.Name, $Package, $PackagePath)

                        $null = Add-WindowsPackage `
                            -PackagePath $PackagePath `
                            -Path $MountPoint
                    } # foreach

                    # Dismount the VHD
                    Write-LabMessage -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
                            -f $VMTemplate.Name, $VMTemplate.parentvhd)
                    $null = Dismount-WindowsImage `
                        -Path $MountPoint `
                        -Save
                    $null = Remove-Item `
                        -Path $MountPoint `
                        -Recurse `
                        -Force
                } # if
            } # if

            Write-LabMessage -Message $($LocalizedData.OptimizingParentVHDMessage `
                    -f $VMTemplate.parentvhd)
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $false
            Optimize-VHD `
                -Path $VMTemplate.parentvhd `
                -Mode Full
            Write-LabMessage -Message $($LocalizedData.SettingParentVHDReadonlyMessage `
                    -f $VMTemplate.parentvhd)
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $true
        }
        Else
        {
            Write-LabMessage -Message $($LocalizedData.SkipParentVHDFileMessage `
                    -f $VMTemplate.Name, $VMTemplate.parentvhd)
        }

        # if this is a Nano Server template, we need to ensure that the
        # NanoServerPackages folder is copied to our Lab folder
        if ($VMTemplate.OSType -eq [LabOStype]::Nano)
        {
            [System.String] $VHDPackagesFolder = Join-Path `
                -Path (Split-Path -Path $VMTemplate.SourceVhd -Parent)`
                -ChildPath 'NanoServerPackages'

            [System.String] $NanoPackagesFolder = Join-Path `
                -Path $LabPath `
                -ChildPath 'NanoServerPackages'

            if (-not (Test-Path -Path $NanoPackagesFolder -Type Container))
            {
                Write-LabMessage -Message $($LocalizedData.CachingNanoServerPackagesMessage `
                        -f $VHDPackagesFolder, $NanoPackagesFolder)
                Copy-Item `
                    -Path $VHDPackagesFolder `
                    -Destination $LabPath `
                    -Recurse `
                    -Force
            }
        }
    }
}
