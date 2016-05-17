<#
.SYNOPSIS
    Gets an array of Module Resources from a Lab.
.DESCRIPTION
    Takes a provided Lab and returns the list of module resources required for this Lab.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of Module names.

    Only Module Resources matching names in this list will be pulled into the returned in the array.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $ResourceModules = Get-LabResourceModule -Lab $Lab
    Loads a Lab and pulls the array of Module Resources from it.
.OUTPUTS
    Returns an array of LabModuleResource objects.
#>
function Get-LabResourceModule {
    [OutputType([LabResourceModule[]])]
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
        [String[]] $Name
    )

    [LabResourceModule[]] $ResourceModules = @()
    if ($Lab.labbuilderconfig.resources) 
    {
        foreach ($Module in $Lab.labbuilderconfig.resources.module)
        {
            $ModuleName = $Module.Name
            if ($Name -and ($ModuleName -notin $Name))
            {
                # A names list was passed but this Module wasn't included
                continue
            } # if

            if ($ModuleName -eq 'module')
            {
                $ExceptionParameters = @{
                    errorId = 'ResourceModuleNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceModuleNameIsEmptyError)
                }
                ThrowException @ExceptionParameters
            } # if
            $ResourceModule = [LabResourceModule]::New($ModuleName)
            $ResourceModule.URL = $Module.URL
            $ResourceModule.Folder = $Module.Folder
            $ResourceModule.MinimumVersion = $Module.MinimumVersion
            $ResourceModule.RequiredVersion = $Module.RequiredVersion
            $ResourceModules += @( $ResourceModule )
        } # foreach
    } # if
    return $ResourceModules
} # Get-LabResourceModule

<#
.SYNOPSIS
    Downloads the Resource Modules from a provided array.
.DESCRIPTION
    Takes an array of LabResourceModule objects ane ensures the Resource Modules are available in
    the PowerShell Modules folder. If they are not they will be downloaded.
.PARAMETER Lab
    Contains Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of Module names.

    Only Module Resources matching names in this list will be pulled into the returned in the array.
.PARAMETER ResourceModules
    The array of Resource Modules pulled from the Lab using Get-LabResourceModule.

    If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $ResourceModules = Get-LabResourceModule -Lab $Lab
    Initialize-LabResourceModule -Lab $Lab -ResourceModules $ResourceModules
    Initializes the Resource Modules in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Initialize-LabResourceModule -Lab $Lab
    Initializes the Resource Modules in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Initialize-LabResourceModule {
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
        [LabResourceModule[]] $ResourceModules
    )

    # if resource modules was not passed, pull it.
    if (-not $PSBoundParameters.ContainsKey('resourcemodules'))
    {
        $ResourceModules = Get-LabResourceModule `
            @PSBoundParameters
    }

    if ($ResourceModules)
    {
        foreach ($Module in $ResourceModules)
        {
            $Splat = [PSObject] @{ Name = $Module.Name }
            if ($Module.URL)
            {
                $Splat += [PSObject] @{ URL = $Module.URL }
            }
            if ($Module.Folder)
            {
                $Splat += [PSObject] @{ Folder = $Module.Folder }
            }
            if ($Module.RequiredVersion)
            {
                $Splat += [PSObject] @{ RequiredVersion = $Module.RequiredVersion }
            }
            if ($Module.MiniumVersion)
            {
                $Splat += [PSObject] @{ MiniumVersion = $Module.MiniumVersion }
            }

            WriteMessage -Message $($LocalizedData.DownloadingResourceModuleMessage `
                -f $Name,$URL)

            DownloadResourceModule @Splat
        } # foreach
    } # if
} # Initialize-LabResourceModule


<#
.SYNOPSIS
    Gets an array of MSU Resources from a Lab.
.DESCRIPTION
    Takes a provided Lab and returns the list of MSU resources required for this Lab.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of MSU names.

    Only MSU Resources matching names in this list will be pulled into the returned in the array.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $ResourceMSU = Get-LabResourceMSU $Lab
    Loads a Lab and pulls the array of MSU Resources from it.
.OUTPUTS
    Returns an array of LabMSUResource objects.
#>
function Get-LabResourceMSU {
    [OutputType([LabResourceMSU[]])]
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
        [String[]] $Name
    )

    [LabResourceMSU[]] $ResourceMSUs = @()
    if ($Lab.labbuilderconfig.resources) 
    {
        foreach ($MSU in $Lab.labbuilderconfig.resources.msu)
        {
            $MSUName = $MSU.Name
            if ($Name -and ($MSUName -notin $Name))
            {
                # A names list was passed but this MSU wasn't included
                continue
            } # if

            if ($MSUName -eq 'msu')
            {
                $ExceptionParameters = @{
                    errorId = 'ResourceMSUNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceMSUNameIsEmptyError)
                }
                ThrowException @ExceptionParameters
            } # if
            $ResourceMSU = [LabResourceMSU]::New($MSUName,$MSU.URL)
            $Path = $MSU.Path
            if ($Path)
            {
                if (-not [System.IO.Path]::IsPathRooted($Path))
                {
                    $Path = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.resourcepathfull `
                        -ChildPath $Path
                }
            }
            else
            {
                $Path = $Lab.labbuilderconfig.settings.resourcepathfull
            }
            $FileName = Join-Path `
                -Path $Path `
                -ChildPath $MSU.URL.Substring($MSU.URL.LastIndexOf('/') + 1)
            $ResourceMSU.Path = $Path
            $ResourceMSU.Filename = $Filename
            $ResourceMSUs += @( $ResourceMSU )
        } # foreach
    } # if
    return $ResourceMSUs
} # Get-LabResourceMSU


<#
.SYNOPSIS
    Downloads the Resource MSU packages from a provided array.
.DESCRIPTION
    Takes an array of LabResourceMSU objects and ensures the MSU packages are available in the
    Lab Resources folder. If they are not they will be downloaded.
.PARAMETER Lab
    Contains Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of MSU packages names.

    Only MSU packages matching names in this list will be pulled into the returned in the array.
.PARAMETER ResourceMSUs
    The array of ResourceMSU objects pulled from the Lab using Get-LabResourceModule.

    If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $ResourceMSUs = Get-LabResourceMSU -Lab $Lab
    Initialize-LabResourceMSU -Lab $Lab -ResourceMSUs $ResourceMSUs
    Initializes the Resource MSUs in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Initialize-LabResourceMSU -Lab $Lab
    Initializes the Resource MSUs in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Initialize-LabResourceMSU {
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
        [LabResourceMSU[]] $ResourceMSUs
    )

    # if resource MSUs was not passed, pull it.
    if (-not $PSBoundParameters.ContainsKey('resourcemsus'))
    {
        $ResourceMSUs = Get-LabResourceMSU `
            @PSBoundParameters
    }

    if ($ResourceMSUs)
    {
        foreach ($MSU in $ResourceMSUs)
        {
            if (-not (Test-Path -Path $MSU.Filename))
            {
                WriteMessage -Message $($LocalizedData.DownloadingResourceMSUMessage `
                    -f $MSU.Name,$MSU.URL)

                DownloadAndUnzipFile `
                    -URL $MSU.URL `
                    -DestinationPath (Split-Path -Path $MSU.Filename)
            } # if
        } # foreach
    } # if
} # Initialize-LabResourceMSU


<#
.SYNOPSIS
    Gets an array of ISO Resources from a Lab.
.DESCRIPTION
    Takes a provided Lab and returns the list of ISO resources required for this Lab.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of ISO names.

    Only ISO Resources matching names in this list will be pulled into the returned in the array.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $ResourceISO = Get-LabResourceISO $Lab
    Loads a Lab and pulls the array of ISO Resources from it.
.OUTPUTS
    Returns an array of LabISOResource objects.
#>
function Get-LabResourceISO {
    [OutputType([LabResourceISO[]])]
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
        [String[]] $Name
    )

    # Determine the ISORootPath where the ISO files should be found
    # if no path is specified then look in the same path as the config
    # if a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $ISORootPath = $Lab.labbuilderconfig.Resources.ISOPath
    if ($ISORootPath)
    {
        if (-not [System.IO.Path]::IsPathRooted($ISORootPath))
        {
            $ISORootPath = Join-Path `
                -Path $Lab.labbuilderconfig.settings.resourcepathfull `
                -ChildPath $ISORootPath
        } # if
    }
    else
    {
        $ISORootPath = $Lab.labbuilderconfig.settings.resourcepathfull
    } # if

    [LabResourceISO[]] $ResourceISOs = @()
    if ($Lab.labbuilderconfig.resources)
    {
        foreach ($ISO in $Lab.labbuilderconfig.resources.iso)
        {
            $ISOName = $ISO.Name
            if ($Name -and ($ISOName -notin $Name))
            {
                # A names list was passed but this ISO wasn't included
                continue
            } # if

            if ($ISOName -eq 'iso')
            {
                $ExceptionParameters = @{
                    errorId = 'ResourceISONameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceISONameIsEmptyError)
                }
                ThrowException @ExceptionParameters
            } # if
            $ResourceISO = [LabResourceISO]::New($ISOName)
            $Path = $ISO.Path
            if ($Path)
            {
                if (-not [System.IO.Path]::IsPathRooted($Path))
                {
                    $Path = Join-Path `
                        -Path $ISORootPath `
                        -ChildPath $Path
                } # if
            }
            else
            {
                # A Path is not provided
                $ExceptionParameters = @{
                    errorId = 'ResourceISOPathIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceISOPathIsEmptyError `
                        -f $ISOName)
                }
                ThrowException @ExceptionParameters
            }
            if ($ISO.URL)
            {
                $ResourceISO.URL = $ISO.URL
            } # if
            $ResourceISO.Path = $Path
            $ResourceISOs += @( $ResourceISO )
        } # foreach
    } # if
    return $ResourceISOs
} # Get-LabResourceISO


<#
.SYNOPSIS
    Downloads the Resource ISO packages from a provided array.
.DESCRIPTION
    Takes an array of LabResourceISO objects and ensures the MSU packages are available in the
    Lab Resources folder. If they are not they will be downloaded.
.PARAMETER Lab
    Contains Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of ISO packages names.

    Only ISO packages matching names in this list will be pulled into the returned in the array.
.PARAMETER ResourceISOs
    The array of ResourceISO objects pulled from the Lab using Get-LabResourceISO.

    If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $ResourceISOs = Get-LabResourceISO -Lab $Lab
    Initialize-LabResourceISO -Lab $Lab -ResourceISOs $ResourceISOs
    Initializes the Resource ISOs in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Initialize-LabResourceISO -Lab $Lab
    Initializes the Resource ISOs in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Initialize-LabResourceISO {
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
        [LabResourceISO[]] $ResourceISOs
    )

    # if resource ISOs was not passed, pull it.
    if (-not $PSBoundParameters.ContainsKey('resourceisos'))
    {
        $ResourceMSUs = Get-LabResourceISO `
            @PSBoundParameters
    } # if

    if ($ResourceISOs)
    {
        foreach ($ResourceISO in $ResourceISOs)
        {
            if (-not (Test-Path -Path $ResourceISO.Path))
            {
                # The Resource ISO does not exist
                if (-not ($ResourceISO.URL))
                {
                    $ExceptionParameters = @{
                        errorId = 'ResourceISOFileNotFoundAndNoURLError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ResourceISOFileNotFoundAndNoURLError `
                            -f $ISOName,$Path)
                    }
                    ThrowException @ExceptionParameters
                } # if

                $URLLeaf = [System.IO.Path]::GetFileName($ResourceISO.URL)
                $URLExtension = [System.IO.Path]::GetExtension($URLLeaf)
                if ($URLExtension -in @('.zip','.iso'))
                {
                    WriteMessage -Message $($LocalizedData.DownloadingResourceISOMessage `
                        -f $ResourceISO.Name,$ResourceISO.URL)

                    DownloadAndUnzipFile `
                        -URL $ResourceISO.URL `
                        -DestinationPath (Split-Path -Path $ResourceISO.Path)
                }
                elseif ([String]::IsNullOrEmpty($URLExtension))
                {
                    WriteMessage `
                        -Type Alert `
                        -Message $($LocalizedData.ISONotFoundDownloadURLMessage `
                            -f $ResourceISO.Name,$ResourceISO.Path,$ResourceISO.URL)
                } # if
                if (-not (Test-Path -Path $ResourceISO.Path))
                {
                    $ExceptionParameters = @{
                        errorId = 'ResourceISOFileNotDownloadedError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ResourceISOFileNotDownloadedError `
                            -f $ResourceISO.Name,$ResourceISO.Path,$ResourceISO.URL)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if
        } # foreach
    } # if
} # Initialize-LabResourceISO
