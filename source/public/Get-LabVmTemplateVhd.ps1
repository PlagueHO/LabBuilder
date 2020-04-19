function Get-LabVMTemplateVHD
{
    [OutputType([LabVMTemplateVHD[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter (
            Position = 1,
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Name
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
    [System.String] $ISORootPath = $Lab.labbuilderconfig.TemplateVHDs.ISOPath
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
        $exceptionParameters = @{
            errorId       = 'VMTemplateVHDISORootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                    -f $ISORootPath)
        }
        New-LabException @exceptionParameters
    } # if

    # Determine the VHDRootPath where the VHD files should be put
    # if no path is specified then look in the same path as the config
    # if a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [System.String] $VHDRootPath = $Lab.labbuilderconfig.TemplateVHDs.VHDPath
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
        $exceptionParameters = @{
            errorId       = 'VMTemplateVHDRootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                    -f $VHDRootPath)
        }
        New-LabException @exceptionParameters
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
                -or ([System.String]::IsNullOrWhiteSpace($TemplateVHDName)))
        {
            $exceptionParameters = @{
                errorId       = 'EmptyVMTemplateVHDNameError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.EmptyVMTemplateVHDNameError)
            }
            New-LabException @exceptionParameters
        } # if

        # Get the ISO Path
        [System.String] $ISOPath = $TemplateVHD.ISO
        if (-not $ISOPath)
        {
            $exceptionParameters = @{
                errorId       = 'EmptyVMTemplateVHDISOPathError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.EmptyVMTemplateVHDISOPathError `
                        -f $TemplateVHD.Name)
            }
            New-LabException @exceptionParameters
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
                Write-LabMessage `
                    -Type Alert `
                    -Message $($LocalizedData.ISONotFoundDownloadURLMessage `
                        -f $TemplateVHD.Name, $ISOPath, $URL)
            } # if
            $exceptionParameters = @{
                errorId       = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                        -f $TemplateVHD.Name, $ISOPath)
            }
            New-LabException @exceptionParameters
        } # if

        # Get the VHD Path
        [System.String] $VHDPath = $TemplateVHD.VHD
        if (-not $VHDPath)
        {
            $exceptionParameters = @{
                errorId       = 'EmptyVMTemplateVHDPathError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.EmptyVMTemplateVHDPathError `
                        -f $TemplateVHD.Name)
            }
            New-LabException @exceptionParameters
        } # if

        # Adjust the VHD Path if required
        if (-not [System.IO.Path]::IsPathRooted($VHDPath))
        {
            $VHDPath = Join-Path `
                -Path $VHDRootPath `
                -ChildPath $VHDPath
        } # if

        # Add the template prefix to the VHD name.
        if (-not ([System.String]::IsNullOrWhitespace($TemplatePrefix)))
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
            $exceptionParameters = @{
                errorId       = 'InvalidVMTemplateVHDOSTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.InvalidVMTemplateVHDOSTypeError `
                        -f $TemplateVHD.Name, $TemplateVHD.OSType)
            }
            New-LabException @exceptionParameters
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
            $exceptionParameters = @{
                errorId       = 'InvalidVMTemplateVHDVHDFormatError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.InvalidVMTemplateVHDVHDFormatError `
                        -f $TemplateVHD.Name, $TemplateVHD.VHDFormat)
            }
            New-LabException @exceptionParameters
        }

        # Get the Template VHD Type
        $VHDType = [LabVHDType]::Dynamic
        if ($TemplateVHD.VHDType)
        {
            $VHDType = [LabVHDType]::$($TemplateVHD.VHDType)
        } # if
        if (-not $VHDType)
        {
            $exceptionParameters = @{
                errorId       = 'InvalidVMTemplateVHDVHDTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.InvalidVMTemplateVHDVHDTypeError `
                        -f $TemplateVHD.Name, $TemplateVHD.VHDType)
            }
            New-LabException @exceptionParameters
        } # if

        # Get the disk size if provided
        [System.Int64] $VHDSize = 25GB
        if ($TemplateVHD.VHDSize)
        {
            $VHDSize = (Invoke-Expression $TemplateVHD.VHDSize)
        } # if

        # Get the Template VM Generation
        [System.Int32] $Generation = 2
        if ($TemplateVHD.Generation)
        {
            $Generation = $TemplateVHD.Generation
        } # if
        if ($Generation -notin @(1, 2) )
        {
            $exceptionParameters = @{
                errorId       = 'InvalidVMTemplateVHDGenerationError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.InvalidVMTemplateVHDGenerationError `
                        -f $TemplateVHD.Name, $Generation)
            }
            New-LabException @exceptionParameters
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
