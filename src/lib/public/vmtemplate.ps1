function Get-LabVMTemplate {
    [OutputType([LabVMTemplate[]])]
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
        [String[]] $Name,

        [Parameter(
            Position=3)]
        [LabVMTemplateVHD[]] $VMTemplateVHDs
    )

    # if VMTeplateVHDs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplateVHDs'))
    {
        [LabVMTemplateVHD[]] $VMTemplateVHDs = Get-LabVMTemplateVHD `
            -Lab $Lab
    } # if

    [LabVMTemplate[]] $VMTemplates = @()
    [System.String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull

    # Get a list of all templates in the Hyper-V system matching the phrase found in the fromvm
    # config setting
    [System.String] $FromVM = $Lab.labbuilderconfig.templates.fromvm
    if ($FromVM)
    {
        $Templates = @(Get-VM -Name $FromVM)
        foreach ($Template in $Templates)
        {
            if ($Name -and ($Template.Name -notin $Name))
            {
                # A names list was passed but this VM Template wasn't included
                continue
            } # if

            [System.String] $VHDFilepath = (Get-VMHardDiskDrive -VMName $Template.Name).Path
            [System.String] $VHDFilename = [System.IO.Path]::GetFileName($VHDFilepath)
            [LabVMTemplate] $VMTemplate = [LabVMTemplate]::New($Template.Name)
            $VMTemplate.Vhd = $VHDFilename
            $VMTemplate.SourceVhd = $VHDFilepath
            $VMTemplate.ParentVhd = (Join-Path -Path $VHDParentPath -ChildPath $VHDFilename)
            $VMTemplates += @( $VMTemplate )
        } # foreach
    } # if

    # Read the list of templates from the configuration file
    $Templates = $Lab.labbuilderconfig.templates.template
    foreach ($Template in $Templates)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'template' as the name.
        $TemplateName = $Template.Name
        if ($Name -and ($TemplateName -notin $Name))
        {
            # A names list was passed but this VM Template wasn't included
            continue
        } # if

        if ($TemplateName -eq 'template')
        {
            $exceptionParameters = @{
                errorId = 'EmptyTemplateNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyTemplateNameError)
            }
            New-LabException @exceptionParameters
        } # if

        # Does the template already exist in the list?
        [Boolean] $Found = $false
        foreach ($VMTemplate in $VMTemplates)
        {
            if ($VMTemplate.Name -eq $TemplateName)
            {
                # The template already exists - so don't add it again
                $Found = $true
                Break
            } # if
        } # foreach
        if (-not $Found)
        {
            # The template wasn't found in the list of templates so add it
            $VMTemplate = [LabVMTemplate]::New($TemplateName)
            # Add the new Template to the Templates Array
            $VMTemplates += @( $VMTemplate )
        } # if

        # Determine the Source VHD, Template VHD and VHD
        [System.String] $SourceVHD = $Template.SourceVHD
        [System.String] $TemplateVHD = $Template.TemplateVHD

        # Throw an error if both a TemplateVHD and SourceVHD are provided
        if ($TemplateVHD -and $SourceVHD)
        {
            $exceptionParameters = @{
                errorId = 'TemplateSourceVHDAndTemplateVHDConflictError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.TemplateSourceVHDAndTemplateVHDConflictError `
                    -f $TemplateName)
            }
            New-LabException @exceptionParameters
        } # if

        if ($TemplateVHD)
        {
            # A TemplateVHD was provided so look it up.
            $VMTemplateVHD = `
                $VMTemplateVHDs | Where-Object -Property Name -EQ $TemplateVHD
            if ($VMTemplateVHD)
            {
                # The TemplateVHD was found
                $VMTemplate.Sourcevhd = $VMTemplateVHD.VHDPath

                # if a VHD filename wasn't specified in the TemplateVHD
                # Just use the leaf of the SourceVHD
                if ($VMTemplateVHD.VHD)
                {
                    $VMTemplate.Vhd = $VMTemplateVHD.VHD
                }
                else
                {
                    $VMTemplate.Vhd = Split-Path `
                        -Path $VMTemplate.sourcevhd `
                        -Leaf
                } # if
            }
            else
            {
                # The TemplateVHD could not be found in the list
                $exceptionParameters = @{
                    errorId = 'TemplateTemplateVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateTemplateVHDNotFoundError `
                        -f $TemplateName,$TemplateVHD)
                }
                New-LabException @exceptionParameters
            } # if
        }
        elseif ($SourceVHD)
        {
            # A Source VHD was provided so use that.
            # if this is a relative path, add it to the config path
            if ([System.IO.Path]::IsPathRooted($SourceVHD))
            {
                $VMTemplate.SourceVhd = $SourceVHD
            }
            else
            {
                $VMTemplate.SourceVhd = Join-Path `
                    -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                    -ChildPath $SourceVHD
            }

            # A Source VHD file was specified - does it exist?
            if (-not (Test-Path -Path $VMTemplate.sourcevhd))
            {
                $exceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $TemplateName,$VMTemplate.sourcevhd)
                }
                New-LabException @exceptionParameters
            } # if

            # if a VHD filename wasn't specified in the Template
            # Just use the leaf of the SourceVHD
            if ($Template.VHD)
            {
                $VMTemplate.vhd = $Template.VHD
            }
            else
            {
                $VMTemplate.vhd = Split-Path `
                    -Path $VMTemplate.sourcevhd `
                    -Leaf
            } # if
        }
        elseif ($VMTemplate.SourceVHD)
        {
            # A SourceVHD is already set
            # Usually because it was pulled From a Hyper-V VM template.
        }
        else
        {
            # Neither a SourceVHD or TemplateVHD was provided
            # So throw an exception
            $exceptionParameters = @{
                errorId = 'TemplateSourceVHDandTemplateVHDMissingError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.TemplateSourceVHDandTemplateVHDMissingError `
                    -f $TemplateName)
            }
            New-LabException @exceptionParameters
        } # if

        # Ensure the ParentVHD is up-to-date
        $VMTemplate.parentvhd = Join-Path `
            -Path $VHDParentPath `
            -ChildPath ([System.IO.Path]::GetFileName($VMTemplate.vhd))

        # Write any template specific default VM attributes
        [Int64] $MemoryStartupBytes = 1GB
        if ($Template.MemoryStartupBytes)
        {
            $MemoryStartupBytes = (Invoke-Expression $Template.MemoryStartupBytes)
        } # if
        if ($MemoryStartupBytes -gt 0)
        {
            $VMTemplate.memorystartupbytes = $MemoryStartupBytes
        } # if
        if ($Template.DynamicMemoryEnabled)
        {
            $VMTemplate.DynamicMemoryEnabled = ($Template.DynamicMemoryEnabled -eq 'Y')
        }
        elseif (-not $VMTemplate.DynamicMemoryEnabled)
        {
            $VMTemplate.DynamicMemoryEnabled = $true
        } # if
        if ($Template.version)
        {
            $VMTemplate.version = $Template.version
        }
        elseif (-not $Template.version)
        {
            $VMTemplate.version = "8.0"
        } # if
        if ($Template.generation)
        {
            $VMTemplate.generation = $Template.generation
        }
        elseif (-not $Template.generation)
        {
            $VMTemplate.generation = 2
        } # if

        if ($Template.ProcessorCount)
        {
            $VMTemplate.ProcessorCount = $Template.ProcessorCount
        } # if
        if ($Template.ExposeVirtualizationExtensions)
        {
            $VMTemplate.ExposeVirtualizationExtensions = ($Template.ExposeVirtualizationExtensions -eq 'Y')
        } # if
        if ($Template.AdministratorPassword)
        {
            $VMTemplate.AdministratorPassword = $Template.AdministratorPassword
        } # if
        if ($Template.ProductKey)
        {
            $VMTemplate.ProductKey = $Template.ProductKey
        } # if
        if ($Template.TimeZone)
        {
            $VMTemplate.TimeZone = $Template.TimeZone
        } # if

        if ($Template.OSType)
        {
            $VMTemplate.OSType = [LabOSType]::$($Template.OSType)
        }
        elseif (-not $VMTemplate.OSType)
        {
            $VMTemplate.OSType = [LabOStype]::Server
        } # if
        if ($Template.IntegrationServices)
        {
            $VMTemplate.IntegrationServices = $Template.IntegrationServices
        }
        else
        {
            $VMTemplate.IntegrationServices = $null
        } # if
        if ($Template.Packages)
        {
            $VMTemplate.Packages = $Template.Packages
        }
        else
        {
            $VMTemplate.Packages = $null
        } # if
    } # foreach
    Return $VMTemplates
} # Get-LabVMTemplate

function Initialize-LabVMTemplate {
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
        [String[]] $Name,

        [Parameter(
            Position=3)]
        [LabVMTemplate[]] $VMTemplates,

        [Parameter(
            Position=4)]
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
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $VMTemplate.Name,$VMTemplate.sourcevhd)
                }
                New-LabException @exceptionParameters
            }

            Write-LabMessage -Message $($LocalizedData.CopyingTemplateSourceVHDMessage `
                -f $VMTemplate.SourceVhd,$VMTemplate.ParentVhd)
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
                        -f $VMTemplate.Name,$VMTemplate.ParentVhd)

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
                        [Boolean] $Found = $false
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
                                -f $VMTemplate.Name,$VMTemplate.parentvhd)
                            $null = Dismount-WindowsImage `
                                -Path $MountPoint `
                                -Save
                            $null = Remove-Item `
                                -Path $MountPoint `
                                -Recurse `
                                -Force

                            $exceptionParameters = @{
                                errorId = 'PackageNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.PackageNotFoundError `
                                -f $Package)
                            }
                            New-LabException @exceptionParameters
                        } # if

                        $PackagePath = $ResourceMSU.Filename
                        if (-not (Test-Path -Path $PackagePath))
                        {
                            # Dismount before throwing the error
                            Write-LabMessage -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
                                -f $VMTemplate.Name,$VMTemplate.ParentVhd)
                            $null = Dismount-WindowsImage `
                                -Path $MountPoint `
                                -Save
                            $null = Remove-Item `
                                -Path $MountPoint `
                                -Recurse `
                                -Force

                            $exceptionParameters = @{
                                errorId = 'PackageMSUNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.PackageMSUNotFoundError `
                                -f $Package,$PackagePath)
                            }
                            New-LabException @exceptionParameters
                        } # if

                        # Apply a Pacakge
                        Write-LabMessage -Message $($LocalizedData.ApplyingTemplateBootDiskFileMessage `
                            -f $VMTemplate.Name,$Package,$PackagePath)

                        $null = Add-WindowsPackage `
                            -PackagePath $PackagePath `
                            -Path $MountPoint
                    } # foreach

                    # Dismount the VHD
                    Write-LabMessage -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
                        -f $VMTemplate.Name,$VMTemplate.parentvhd)
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
                -f $VMTemplate.Name,$VMTemplate.parentvhd)
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
                        -f $VHDPackagesFolder,$NanoPackagesFolder)
                Copy-Item `
                    -Path $VHDPackagesFolder `
                    -Destination $LabPath `
                    -Recurse `
                    -Force
            }
        }
    }
} # Initialize-LabVMTemplate

function Remove-LabVMTemplate {
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
        [String[]] $Name,

        [Parameter(
            Position=3)]
        [LabVMTemplate[]] $VMTemplates
    )

    # if VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        $VMTemplates = Get-LabVMTemplate `
           @PSBoundParameters
    } # if
    foreach ($VMTemplate in $VMTemplates)
    {
        if ($Name -and ($VMTemplate.Name -notin $Name))
        {
            # A names list was passed but this VM Template wasn't included
            continue
        } # if

        if (Test-Path $VMTemplate.ParentVhd)
        {
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $false
            Write-LabMessage -Message $($LocalizedData.DeletingParentVHDMessage `
                -f $VMTemplate.ParentVhd)
            Remove-Item `
                -Path $VMTemplate.ParentVhd `
                -Confirm:$false `
                -Force
        } # if
    } # foreach
} # Remove-LabVMTemplate
