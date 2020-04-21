function New-Lab
{
    [CmdLetBinding(
        SupportsShouldProcess = $true)]
    [OutputType([XML])]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ConfigPath,

        [Parameter(
            Position=2,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $LabPath,

        [Parameter(
            Position=3,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Name,

        [Parameter(
            Position=4)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Version = '1.0',

        [Parameter(
            Position=5)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Id,

        [Parameter(
            Position=6)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Description,

        [Parameter(
            Position=7)]
        [ValidateNotNullOrEmpty()]
        [System.String] $DomainName,

        [Parameter(
            Position=8)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Email
    ) # Param

    # Determine the full Lab Path
    if (-not [System.IO.Path]::IsPathRooted($LabPath))
    {
        $LabPath = Join-Path `
            -Path Get-Location `
            -ChildPath $LabPath
    } # if

    # Does the Lab Path exist?
    if (Test-Path -Path $LabPath -Type Container)
    {
        # It does - exit if the user declines
        if (-not $PSCmdlet.ShouldProcess( 'LocalHost', `
            ($LocalizedData.ShouldOverwriteLab `
            -f $LabPath )))
        {
            return
        }
    }
    else
    {
        Write-LabMessage -Message $($LocalizedData.CreatingLabFolderMessage `
            -f 'LabPath',$LabPath)

       $null = New-Item `
            -Path $LabPath `
            -Type Directory
    } # if

    # Determine the full Lab configuration Path
    if (-not [System.IO.Path]::IsPathRooted($ConfigPath))
    {
        $ConfigPath = Join-Path `
            -Path $LabPath `
            -ChildPath $ConfigPath
    } # if

    # Does the lab configuration path already exist?
    if (Test-Path -Path $ConfigPath)
    {
        # It does - exit if the user declines
        if (-not $PSCmdlet.ShouldProcess( 'LocalHost', `
            ($LocalizedData.ShouldOverwriteLabConfig `
            -f $ConfigPath )))
        {
            return
        }
    } # if

    # Get the Config Template into a variable
    $Content = Get-Content `
        -Path $script:ConfigurationXMLTemplate

    # The XML passes the Schema check so load it.
    [XML] $Lab = New-Object System.Xml.XmlDocument
    $Lab.PreserveWhitespace = $true
    $Lab.LoadXML($Content)

    # Populate the Lab Entries
    $Lab.labbuilderconfig.name = $Name
    $Lab.labbuilderconfig.version = $Version
    $Lab.labbuilderconfig.settings.labpath = $LabPath
    if ($PSBoundParameters.ContainsKey('Id'))
    {
        $Lab.labbuilderconfig.settings.SetAttribute('Id',$Id)
    } # if
    if ($PSBoundParameters.ContainsKey('Description'))
    {
        $Lab.labbuilderconfig.description = $Description
    } # if
    if ($PSBoundParameters.ContainsKey('DomainName'))
    {
        $Lab.labbuilderconfig.settings.SetAttribute('DomainName',$DomainName)
    } # if
    if ($PSBoundParameters.ContainsKey('Email'))
    {
        $Lab.labbuilderconfig.settings.SetAttribute('Email',$Email)
    } # if

    # Save Configiration XML
    $Lab.Save($ConfigPath)

    # Create ISOFiles folder
    $null = New-Item `
        -Path (Join-Path -Path $LabPath -ChildPath 'ISOFiles')`
        -Type Directory `
        -ErrorAction SilentlyContinue

    # Create VDFFiles folder
    $null = New-Item `
        -Path (Join-Path -Path $LabPath -ChildPath 'VHDFiles')`
        -Type Directory `
        -ErrorAction SilentlyContinue

    # Copy the DSCLibrary
    $null = Copy-Item `
        -Path $script:DSCLibraryPath `
        -Destination $LabPath `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Return (Get-Lab `
        -ConfigPath $ConfigPath `
        -LabPath $LabPath)
} # New-Lab
