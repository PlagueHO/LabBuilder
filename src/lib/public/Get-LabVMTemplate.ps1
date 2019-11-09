function Get-LabVMTemplate
{
    [OutputType([LabVMTemplate[]])]
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
                errorId       = 'EmptyTemplateNameError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.EmptyTemplateNameError)
            }
            New-LabException @exceptionParameters
        } # if

        # Does the template already exist in the list?
        [System.Boolean] $Found = $false
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
                errorId       = 'TemplateSourceVHDAndTemplateVHDConflictError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.TemplateSourceVHDAndTemplateVHDConflictError `
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
                    errorId       = 'TemplateTemplateVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.TemplateTemplateVHDNotFoundError `
                            -f $TemplateName, $TemplateVHD)
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
                    errorId       = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.TemplateSourceVHDNotFoundError `
                            -f $TemplateName, $VMTemplate.sourcevhd)
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
                errorId       = 'TemplateSourceVHDandTemplateVHDMissingError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.TemplateSourceVHDandTemplateVHDMissingError `
                        -f $TemplateName)
            }
            New-LabException @exceptionParameters
        } # if

        # Ensure the ParentVHD is up-to-date
        $VMTemplate.parentvhd = Join-Path `
            -Path $VHDParentPath `
            -ChildPath ([System.IO.Path]::GetFileName($VMTemplate.vhd))

        # Write any template specific default VM attributes
        [System.Int64] $MemoryStartupBytes = 1GB
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
