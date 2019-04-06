function Get-Lab
{
    [CmdLetBinding()]
    [OutputType([XML])]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ConfigPath,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [System.String] $LabPath,

        [Parameter(
            Position=3)]
        [Switch] $SkipXMLValidation
    ) # Param

    # If a relative path to the config has been specified
    # then convert it to absolute path
    if (-not [System.IO.Path]::IsPathRooted($ConfigPath))
    {
        $ConfigPath = Join-Path `
            -Path (Get-Location).Path `
            -ChildPath $ConfigPath
    } # if

    if (-not (Test-Path -Path $ConfigPath))
    {
        $exceptionParameters = @{
            errorId = 'ConfigurationFileNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileNotFoundError `
                -f $ConfigPath)
        }
        New-LabException @exceptionParameters
    } # if

    $Content = Get-Content -Path $ConfigPath -Raw
    if (-not $Content)
    {
        $exceptionParameters = @{
            errorId = 'ConfigurationFileEmptyError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileEmptyError `
                -f $ConfigPath)
        }
        New-LabException @exceptionParameters
    } # if

    if (-not $SkipXMLValidation)
    {
        # Validate the XML
        Assert-ValidConfigurationXMLSchema `
            -ConfigPath $ConfigPath `
            -ErrorAction Stop
    }

    # The XML passes the Schema check so load it.
    $Lab = New-Object -TypeName System.Xml.XmlDocument
    $Lab.PreserveWhitespace = $true
    $Lab.LoadXML($Content)

    # Check the Required Windows Build
    $RequiredWindowsBuild = $Lab.labbuilderconfig.settings.requiredwindowsbuild
    if ($RequiredWindowsBuild -and `
        ($Script:CurrentBuild -lt $RequiredWindowsBuild))
    {
        $exceptionParameters = @{
            errorId = 'RequiredBuildNotMetError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.RequiredBuildNotMetError `
                -f $Script:CurrentBuild,$RequiredWindowsBuild)
        }
        New-LabException @exceptionParameters
    } # if

    # Figure out the Config path and load it into the XML object (if we can)
    # This path is used to find any additional configuration files that might
    # be provided with config
    [System.String] $ConfigPath = [System.IO.Path]::GetDirectoryName($ConfigPath)
    [System.String] $XMLConfigPath = $Lab.labbuilderconfig.settings.configpath
    if ($XMLConfigPath) {
        if (-not [System.IO.Path]::IsPathRooted($XMLConfigurationPath))
        {
            # A relative path was provided in the config path so add the actual path of the
            # XML to it
            [System.String] $FullConfigPath = Join-Path `
                -Path $ConfigPath `
                -ChildPath $XMLConfigPath
        } # if
    }
    else
    {
        [System.String] $FullConfigPath = $ConfigPath
    }
    $Lab.labbuilderconfig.settings.setattribute('fullconfigpath',$FullConfigPath)

    # if the LabPath was passed as a parameter, set it in the config
    if ($LabPath)
    {
        $Lab.labbuilderconfig.settings.SetAttribute('labpath',$LabPath)
    }
    else
    {
        [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    }

    # Get the VHDParentPathFull - if it isn't supplied default
    [System.String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpath
    if (-not $VHDParentPath)
    {
        $VHDParentPath = 'Virtual Hard Disk Templates'
    }
    # if the resulting parent path is not rooted make the root the Lab Path
    if (-not ([System.IO.Path]::IsPathRooted($VHDParentPath)))
    {
        $VHDParentPath = Join-Path `
            -Path $LabPath `
            -ChildPath $VHDParentPath
    } # if
    $Lab.labbuilderconfig.settings.setattribute('vhdparentpathfull',$VHDParentPath)

    # Get the DSCLibraryPathFull - if it isn't supplied default
    [System.String] $DSCLibraryPath = $Lab.labbuilderconfig.settings.dsclibrarypath
    if (-not $DSCLibraryPath)
    {
        $DSCLibraryPath = 'DSCLibrary'
    } # if
    # if the resulting parent path is not rooted make the root the Full config path
    if (-not [System.IO.Path]::IsPathRooted($DSCLibraryPath))
    {
        $DSCLibraryPath = Join-Path `
            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
            -ChildPath $DSCLibraryPath
    } # if
    $Lab.labbuilderconfig.settings.setattribute('dsclibrarypathfull',$DSCLibraryPath)

    # Get the ResourcePathFull - if it isn't supplied default
    [System.String] $ResourcePath = $Lab.labbuilderconfig.settings.resourcepath
    if (-not $ResourcePath)
    {
        $ResourcePath = 'Resource'
    } # if
    # if the resulting Resource path is not rooted make the root the Lab Path
    if (-not [System.IO.Path]::IsPathRooted($ResourcePath))
    {
        $ResourcePath = Join-Path `
            -Path $LabPath `
            -ChildPath $ResourcePath
    } # if
    $Lab.labbuilderconfig.settings.setattribute('resourcepathfull',$ResourcePath)

    # Determine the ModulePath where alternate Lab PowerShell Modules can be found.
    # If a path is specified but it is relative, make it relative to the lab path.
    # Otherwise use it as is.
    [System.String] $ModulePath = $Lab.labbuilderconfig.settings.modulepath
    if ($ModulePath)
    {
        if (-not [System.IO.Path]::IsPathRooted($ModulePath))
        {
            $ModulePath = Join-Path `
                -Path $LabPath `
                -ChildPath $ModulePath
        } # if
        # If the path is not included in the PSModulePath add it
        if (-not $env:PSModulePath.ToLower().Contains($ModulePath.ToLower() + ';'))
        {
            $env:PSModulePath = "$ModulePath;" + $env:PSModulePath
        } # if
    } # if

    Return $Lab
} # Get-Lab
