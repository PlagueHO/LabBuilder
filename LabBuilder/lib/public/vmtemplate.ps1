<#
.SYNOPSIS
   Gets an Array of VM Templates for a Lab.
.DESCRIPTION
   Takes the provided Lab and returns the list of Virtul Machine template machines
   that will be used to create the Virtual Machines in this lab.
   
   This list is usually passed to Initialize-LabVMTemplate.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM Template names.

   Only VM Templates matching names in this list will be returned in the array.
.PARAMETER VMTemplateVHDs
   The array of VMTemplateVHDs pulled from the Lab using Get-LabVMTemplateVHD.

   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Lab $Lab
   Loads a Lab and pulls the array of VMTemplates from it.
.OUTPUTS
   Returns an array of LabVMTemplate objects.
#>
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
    }

    [LabVMTemplate[]] $VMTemplates = @()
    [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
    
    # Get a list of all templates in the Hyper-V system matching the phrase found in the fromvm
    # config setting
    [String] $FromVM=$Lab.labbuilderconfig.templates.fromvm
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

            [String] $VHDFilepath = (Get-VMHardDiskDrive -VMName $Template.Name).Path
            [String] $VHDFilename = [System.IO.Path]::GetFileName($VHDFilepath)
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
            $ExceptionParameters = @{
                errorId = 'EmptyTemplateNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyTemplateNameError)
            }
            ThrowException @ExceptionParameters
        } # if

        # Does the template already exist in the list?
        [Boolean] $Found = $False
        foreach ($VMTemplate in $VMTemplates)
        {
            if ($VMTemplate.Name -eq $TemplateName)
            {
                # The template already exists - so don't add it again
                $Found = $True
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
        [String] $SourceVHD = $Template.SourceVHD
        [String] $TemplateVHD = $Template.TemplateVHD

        # Throw an error if both a TemplateVHD and SourceVHD are provided
        if ($TemplateVHD -and $SourceVHD)
        {
            $ExceptionParameters = @{
                errorId = 'TemplateSourceVHDAndTemplateVHDConflictError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.TemplateSourceVHDAndTemplateVHDConflictError `
                    -f $TemplateName)
            }
            ThrowException @ExceptionParameters
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
                $ExceptionParameters = @{
                    errorId = 'TemplateTemplateVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateTemplateVHDNotFoundError `
                        -f $TemplateName,$TemplateVHD)
                }
                ThrowException @ExceptionParameters
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
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $TemplateName,$VMTemplate.sourcevhd)
                }
                ThrowException @ExceptionParameters
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
            $ExceptionParameters = @{
                errorId = 'TemplateSourceVHDandTemplateVHDMissingError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.TemplateSourceVHDandTemplateVHDMissingError `
                    -f $TemplateName)
            }
            ThrowException @ExceptionParameters
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
            $VMTemplate.DynamicMemoryEnabled = $True
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
#region


#region LabVMTemplateFunctions
<#
.SYNOPSIS
   Initializes the Virtual Machine templates used by a Lab from a provided array.
.DESCRIPTION
   Takes an array of LabVMTemplate objects that were configured in the Lab.

   The Virtual Machine templates are used to create the Virtual Machines specified in
   a Lab. The Virtual Machine template VHD files are copied to a folder where
   they will be copied to create new Virtual Machines or as parent difference disks for new
   Virtual Machines.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM Template names.
   
   Only VM Templates matching names in this list will be initialized.
.PARAMETER VMTemplates
   The array of LabVMTemplate objects pulled from the Lab using Get-LabVMTemplate.

   If not provided it will attempt to pull the list from the Lab.
.PARAMETER VMTemplateVHDs
   The array of LabVMTemplateVHD objects pulled from the Lab using Get-LabVMTemplateVHD.

   If not provided it will attempt to pull the list from the Lab.

   This parameter is only used if the VMTemplates parameter is not provided.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Lab $Lab
   Initialize-LabVMTemplate `
    -Lab $Lab `
    -VMTemplates $VMTemplates
   Initializes the Virtual Machine templates in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Initialize-LabVMTemplate -Lab $Lab
   Initializes the Virtual Machine templates in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
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

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    
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
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $VMTemplate.Name,$VMTemplate.sourcevhd)
                }
                ThrowException @ExceptionParameters
            }

            WriteMessage -Message $($LocalizedData.CopyingTemplateSourceVHDMessage `
                -f $VMTemplate.SourceVhd,$VMTemplate.ParentVhd)
            Copy-Item `
                -Path $VMTemplate.SourceVhd `
                -Destination $VMTemplate.ParentVhd

            # Add any packages to the template if required
            if (-not [String]::IsNullOrWhitespace($VMTemplate.Packages))
            {
                if ($VMTemplate.OSType -ne [LabOStype]::Nano)
                {
                    # Mount the Template Boot VHD so that files can be loaded into it
                    WriteMessage -Message $($LocalizedData.MountingTemplateBootDiskMessage `
                        -f $VMTemplate.Name,$VMTemplate.ParentVhd)

                    # Create a mount point for mounting the Boot VHD
                    [String] $MountPoint = Join-Path `
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
                            # Dismount before throwing the error
                            WriteMessage -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
                                -f $VMTemplate.Name,$VMTemplate.parentvhd)
                            $null = Dismount-WindowsImage `
                                -Path $MountPoint `
                                -Save
                            $null = Remove-Item `
                                -Path $MountPoint `
                                -Recurse `
                                -Force

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
                            # Dismount before throwing the error
                            WriteMessage -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
                                -f $VMTemplate.Name,$VMTemplate.ParentVhd)
                            $null = Dismount-WindowsImage `
                                -Path $MountPoint `
                                -Save
                            $null = Remove-Item `
                                -Path $MountPoint `
                                -Recurse `
                                -Force

                            $ExceptionParameters = @{
                                errorId = 'PackageMSUNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.PackageMSUNotFoundError `
                                -f $Package,$PackagePath)
                            }
                            ThrowException @ExceptionParameters
                        } # if

                        # Apply a Pacakge
                        WriteMessage -Message $($LocalizedData.ApplyingTemplateBootDiskFileMessage `
                            -f $VMTemplate.Name,$Package,$PackagePath)

                        $null = Add-WindowsPackage `
                            -PackagePath $PackagePath `
                            -Path $MountPoint
                    } # foreach

                    # Dismount the VHD
                    WriteMessage -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
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

            WriteMessage -Message $($LocalizedData.OptimizingParentVHDMessage `
                -f $VMTemplate.parentvhd)
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $False
            Optimize-VHD `
                -Path $VMTemplate.parentvhd `
                -Mode Full
            WriteMessage -Message $($LocalizedData.SettingParentVHDReadonlyMessage `
                -f $VMTemplate.parentvhd)
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $True
        }
        Else
        {
            WriteMessage -Message $($LocalizedData.SkipParentVHDFileMessage `
                -f $VMTemplate.Name,$VMTemplate.parentvhd)
        }

        # if this is a Nano Server template, we need to ensure that the
        # NanoServerPackages folder is copied to our Lab folder
        if ($VMTemplate.OSType -eq [LabOStype]::Nano)
        {
            [String] $VHDPackagesFolder = Join-Path `
                -Path (Split-Path -Path $VMTemplate.SourceVhd -Parent)`
                -ChildPath 'NanoServerPackages'

            [String] $NanoPackagesFolder = Join-Path `
                -Path $LabPath `
                -ChildPath 'NanoServerPackages'

            if (-not (Test-Path -Path $NanoPackagesFolder -Type Container))
            {
                WriteMessage -Message $($LocalizedData.CachingNanoServerPackagesMessage `
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


<#
.SYNOPSIS
   Removes all Lab Virtual Machine Template VHDs.
.DESCRIPTION
   This cmdlet is used to remove any Virtual Machine Template VHDs that were copied when
   creating this Lab.

   This function should never be run unless the Lab has no Differencing Disks using these
   Template VHDs or the Lab is being completely removed. Removing these Template VHDs if
   Lab Virtual Machines are using these templates as differencing disk parents will cause
   the Lab Virtual Hard Drives to become corrupt.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM Template names.

   Only VM Templates matching names in this list will be removed.
.PARAMETER VMTemplates
   The array of LabVMTemplate objects pulled from the Lab using Get-LabVMTemplate.

   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Lab $Lab
   Remove-LabVMTemplate -Lab $Lab -VMTemplates $VMTemplates
   Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Remove-LabVMTemplate -Lab $Lab
   Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
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
                -Value $False
            WriteMessage -Message $($LocalizedData.DeletingParentVHDMessage `
                -f $VMTemplate.ParentVhd)
            Remove-Item `
                -Path $VMTemplate.ParentVhd `
                -Confirm:$false `
                -Force
        } # if
    } # foreach
} # Remove-LabVMTemplate
