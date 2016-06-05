<#
.SYNOPSIS
    Loads a Lab Builder Configuration file and returns a Lab object
.DESCRIPTION
    Takes the path to a valid LabBuilder Configiration XML file and loads it.

    It will perform simple validation on the XML file and throw an exception
    if any of the validation tests fail.

    At load time it will also add temporary configuration attributes to the in
    memory configuration that are used by other LabBuilder functions. So loading
    XML Configurartion without using this function is not advised.
.PARAMETER ConfigPath
    This is the path to the Lab Builder configuration file to load.
.PARAMETER LabPath
    This is an optional path that is used to Override the LabPath in the config
    file passed.
.EXAMPLE
    $MyLab = Get-Lab -ConfigPath c:\MyLab\LabConfig1.xml
    Loads the LabConfig1.xml configuration and returns Lab object.
.OUTPUTS
    The Lab object representing the Lab Configuration that was loaded.
#>
function Get-Lab {
    [CmdLetBinding()]
    [OutputType([XML])]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

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
        $ExceptionParameters = @{
            errorId = 'ConfigurationFileNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileNotFoundError `
                -f $ConfigPath)
        }
        ThrowException @ExceptionParameters
    } # if

    $Content = Get-Content -Path $ConfigPath -Raw
    if (-not $Content)
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationFileEmptyError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileEmptyError `
                -f $ConfigPath)
        }
        ThrowException @ExceptionParameters
    } # if

    if (-not $SkipXMLValidation)
    {
        # Validate the XML
        ValidateConfigurationXMLSchema `
            -ConfigPath $ConfigPath `
            -ErrorAction Stop
    }

    # The XML passes the Schema check so load it.
    [XML] $Lab = New-Object System.Xml.XmlDocument
    $Lab.PreserveWhitespace = $true
    $Lab.LoadXML($Content)

    # Check the Required Windows Build
    $RequiredWindowsBuild = $Lab.labbuilderconfig.settings.requiredwindowsbuild
    if ($RequiredWindowsBuild -and `
        ($Script:CurrentBuild -lt $RequiredWindowsBuild))
    {
        $ExceptionParameters = @{
            errorId = 'RequiredBuildNotMetError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.RequiredBuildNotMetError `
                -f $Script:CurrentBuild,$RequiredWindowsBuild)
        }
        ThrowException @ExceptionParameters
    } # if

    # Figure out the Config path and load it into the XML object (if we can)
    # This path is used to find any additional configuration files that might
    # be provided with config
    [String] $ConfigPath = [System.IO.Path]::GetDirectoryName($ConfigPath)
    [String] $XMLConfigPath = $Lab.labbuilderconfig.settings.configpath
    if ($XMLConfigPath) {
        if (-not [System.IO.Path]::IsPathRooted($XMLConfigurationPath))
        {
            # A relative path was provided in the config path so add the actual path of the
            # XML to it
            [String] $FullConfigPath = Join-Path `
                -Path $ConfigPath `
                -ChildPath $XMLConfigPath
        } # if
    }
    else
    {
        [String] $FullConfigPath = $ConfigPath
    }
    $Lab.labbuilderconfig.settings.setattribute('fullconfigpath',$FullConfigPath)

    # if the LabPath was passed as a parameter, set it in the config
    if ($LabPath)
    {
        $Lab.labbuilderconfig.settings.SetAttribute('labpath',$LabPath)
    }
    else
    {
        [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    }

    # Get the VHDParentPathFull - if it isn't supplied default
    [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpath
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
    [String] $DSCLibraryPath = $Lab.labbuilderconfig.settings.dsclibrarypath
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
    [String] $ResourcePath = $Lab.labbuilderconfig.settings.resourcepath
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
    [String] $ModulePath = $Lab.labbuilderconfig.settings.modulepath
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


<#
.SYNOPSIS
    Creates a new Lab Builder Configuration file and Lab folder.
.DESCRIPTION
    This function will take a path to a new Lab folder and a path or filename
    for a new Lab Configuration file and creates them using the standard XML
    template.

    It will also copy the DSCLibrary folder as well as the create an empty
    ISOFiles and VHDFiles folder in the Lab folder.

    After running this function the VMs, VMTemplates, Switches and VMTemplateVHDs
    in the new Lab Configuration file would normally be customized to for the new
    Lab.
.PARAMETER ConfigPath
    This is the path to the Lab Builder configuration file to create. If it is
    not rooted the configuration file is created in the LabPath folder.
.PARAMETER LabPath
    This is a required path of the new Lab to create.
.PARAMETER Name
    This is a required name of the Lab that gets added to the new Lab Configration
    file.
.PARAMETER Version
    This is a required version of the Lab that gets added to the new Lab Configration
    file.
.PARAMETER Id
    This is the optional Lab Id that gets set in the new Lab Configuration
    file.
.PARAMETER Description
    This is the optional Lab description that gets set in the new Lab Configuration
    file.
.PARAMETER DomainName
    This is the optional Lab domain name that gets set in the new Lab Configuration
    file.
.PARAMETER Email
    This is the optional Lab email address that gets set in the new Lab Configuration
    file.
.EXAMPLE
    $MyLab = New-Lab `
        -ConfigPath c:\MyLab\LabConfig1.xml `
        -LabPath c:\MyLab `
        -LabName 'MyLab' `
        -LabVersion '1.2'
    Creates a new Lab Configration file LabConfig1.xml and also a Lab folder
    c:\MyLab and populates it with default DSCLibrary file and supporting folders.
.OUTPUTS
    The Lab object representing the new Lab Configuration that was created.
#>
function New-Lab {
    [CmdLetBinding(
        SupportsShouldProcess = $true)]
    [OutputType([XML])]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [Parameter(
            Position=2,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [Parameter(
            Position=4)]
        [ValidateNotNullOrEmpty()]
        [String] $Version = '1.0',

        [Parameter(
            Position=5)]
        [ValidateNotNullOrEmpty()]
        [String] $Id,

        [Parameter(
            Position=6)]
        [ValidateNotNullOrEmpty()]
        [String] $Description,

        [Parameter(
            Position=7)]
        [ValidateNotNullOrEmpty()]
        [String] $DomainName,

        [Parameter(
            Position=8)]
        [ValidateNotNullOrEmpty()]
        [String] $Email
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
        WriteMessage -Message $($LocalizedData.CreatingLabFolderMessage `
            -f 'LabPath',$LabPath)

        New-Item `
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
        -Path $Script:ConfigurationXMLTemplate

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
    New-Item `
        -Path (Join-Path -Path $LabPath -ChildPath 'ISOFiles')`
        -Type Directory `
        -ErrorAction SilentlyContinue

    # Create VDFFiles folder
    New-Item `
        -Path (Join-Path -Path $LabPath -ChildPath 'VHDFiles')`
        -Type Directory `
        -ErrorAction SilentlyContinue

    # Copy the DSCLibrary
    Copy-Item `
        -Path $Script:DSCLibraryPath `
        -Destination $LabPath `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Return (Get-Lab `
        -ConfigPath $ConfigPath `
        -LabPath $LabPath)
} # New-Lab


<#
.SYNOPSIS
    Installs or Update a Lab.
.DESCRIPTION
    This cmdlet will install an entire Hyper-V lab environment defined by the
    LabBuilder configuration file provided.

    If components of the Lab already exist, they will be updated if they differ
    from the settings in the Configuration file.

    The Hyper-V component can also be optionally installed if it is not.
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to install the Lab to - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to install.
.PARAMETER CheckEnvironment
    Whether or not to check if Hyper-V is installed and install it if missing.
.PARAMETER Force
    This will force the Lab to be installed, automatically suppressing any confirmations.
.EXAMPLE
    Install-Lab -ConfigPath c:\mylab\config.xml
    Install the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Install-Lab
    Install the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
    None
#>
Function Install-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=4)]
        [Switch] $CheckEnvironment,

        [Parameter(
            Position=5)]
        [Switch] $Force
    ) # Param

    begin
    {
        # Create a splat array containing force if it is set
        $ForceSplat = @{}
        if ($PSBoundParameters.ContainsKey('Force'))
        {
            $ForceSplat = @{ Force = $true }
        } # if

        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('CheckEnvironment')
        $null = $PSBoundParameters.Remove('Force')

        if ($CheckEnvironment)
        {
            # Check Hyper-V
            InstallHyperV `
                -ErrorAction Stop
        } # if

        # Ensure WS-Man is enabled
        EnableWSMan `
            @ForceSplat `
            -ErrorAction Stop

        # Install Package Providers
        InstallPackageProviders `
            @ForceSplat `
            -ErrorAction Stop

        # Register Package Sources
        RegisterPackageSources `
            @ForceSplat `
            -ErrorAction Stop

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters `
                -ErrorAction Stop
        } # if
    } # begin

    process
    {
        # Initialize the core Lab components
        # Check Lab Folder structure
        WriteMessage -Message $($LocalizedData.InitializingLabFoldersMesage)

        # Check folders are defined
        [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
        if (-not (Test-Path -Path $LabPath))
        {
            WriteMessage -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'LabPath',$LabPath)

            $null = New-Item `
                -Path $LabPath `
                -Type Directory
        }

        [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
        if (-not (Test-Path -Path $VHDParentPath))
        {
            WriteMessage -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'VHDParentPath',$VHDParentPath)

            $null = New-Item `
                -Path $VHDParentPath `
                -Type Directory
        }

        [String] $ResourcePath = $Lab.labbuilderconfig.settings.resourcepathfull
        if (-not (Test-Path -Path $ResourcePath))
        {
            WriteMessage -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'ResourcePath',$ResourcePath)

            $null = New-Item `
                -Path $ResourcePath `
                -Type Directory
        }

        # Install Hyper-V Components
        WriteMessage -Message $($LocalizedData.InitializingHyperVComponentsMesage)

        # Create the LabBuilder Management Network switch and assign VLAN
        # Used by host to communicate with Lab VMs
        [String] $ManagementSwitchName = GetManagementSwitchName `
            -Lab $Lab
        if ($Lab.labbuilderconfig.switches.ManagementVlan)
        {
            [Int32] $ManagementVlan = $Lab.labbuilderconfig.switches.ManagementVlan
        }
        else
        {
            [Int32] $ManagementVlan = $Script:DefaultManagementVLan
        }
        if ((Get-VMSwitch | Where-Object -Property Name -eq $ManagementSwitchName).Count -eq 0)
        {
            $null = New-VMSwitch `
                -SwitchType Internal `
                -Name $ManagementSwitchName `
                -ErrorAction Stop

            WriteMessage -Message $($LocalizedData.CreatingLabManagementSwitchMessage `
                -f $ManagementSwitchName,$ManagementVlan)
        }
        # Check the Vlan ID of the adapter on the switch
        $ExistingManagementAdapter = Get-VMNetworkAdapter `
            -ManagementOS `
            -Name $ManagementSwitchName `
            -ErrorAction Stop
        $ExistingVlan = (Get-VMNetworkAdapterVlan `
            -VMNetworkAdaptername $ExistingManagementAdapter.Name `
            -ManagementOS).AccessVlanId

        if ($ExistingVlan -ne $ManagementVlan)
        {
            WriteMessage -Message $($LocalizedData.UpdatingLabManagementSwitchMessage `
                -f $ManagementSwitchName,$ManagementVlan)

            Set-VMNetworkAdapterVlan `
                -VMNetworkAdapterName $ManagementSwitchName `
                -ManagementOS `
                -Access `
                -VlanId $ManagementVlan `
                -ErrorAction Stop
        }

        # Download any Resource Modules required by this Lab
        $ResourceModules = Get-LabResourceModule `
            -Lab $Lab
        Initialize-LabResourceModule `
            -Lab $Lab `
            -ResourceModules $ResourceModules `
            -ErrorAction Stop

        # Download any Resource MSUs required by this Lab
        $ResourceMSUs = Get-LabResourceMSU `
            -Lab $Lab
        Initialize-LabResourceMSU `
            -Lab $Lab `
            -ResourceMSUs $ResourceMSUs `
            -ErrorAction Stop

        # Initialize the Switches
        $Switches = Get-LabSwitch `
            -Lab $Lab
        Initialize-LabSwitch `
            -Lab $Lab `
            -Switches $Switches `
            -ErrorAction Stop

        # Initialize the VM Template VHDs
        $VMTemplateVHDs = Get-LabVMTemplateVHD `
            -Lab $Lab
        Initialize-LabVMTemplateVHD `
            -Lab $Lab `
            -VMTemplateVHDs $VMTemplateVHDs `
            -ErrorAction Stop

        # Initialize the VM Templates
        $VMTemplates = Get-LabVMTemplate `
            -Lab $Lab
        Initialize-LabVMTemplate `
            -Lab $Lab `
            -VMTemplates $VMTemplates `
            -ErrorAction Stop

        # Initialize the VMs
        $VMs = Get-LabVM `
            -Lab $Lab `
            -VMTemplates $VMTemplates `
            -Switches $Switches
        Initialize-LabVM `
            -Lab $Lab `
            -VMs $VMs `
            -ErrorAction Stop

        WriteMessage -Message $($LocalizedData.LabInstallCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath)
    } # process
    end
    {
    } # end
} # Install-Lab


<#
.SYNOPSIS
    Update a Lab.
.DESCRIPTION
    This cmdlet will update the existing Hyper-V lab environment defined by the
    LabBuilder configuration file provided.

    If components of the Lab are missing they will be added.

    If components of the Lab already exist, they will be updated if they differ
    from the settings in the Configuration file.
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to update the Lab in - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to update.
.EXAMPLE
    Update-Lab -ConfigPath c:\mylab\config.xml
    Update the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Update-Lab
    Update the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
    None
#>
Function Update-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    ) # Param

    begin
    {
        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters
        } # if
    } # begin

    process
    {
        Install-Lab `
            @PSBoundParameters

        WriteMessage -Message $($LocalizedData.LabUpdateCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)
    } # process

    end
    {
    } # end
} # Update-Lab


<#
.SYNOPSIS
     Uninstall the components of an existing Lab.
.DESCRIPTION
    This function will attempt to remove the components of the lab specified
    in the provided LabBuilder configuration file.

    It will always remove any Lab Virtual Machines, but can also optionally
    remove:
    Switches
    VM Templates
    VM Template VHDs
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to uninstall the Lab from - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to uninstall.
.PARAMETER RemoveSwitch
    Causes the switches defined by this to be removed.
.PARAMETER RemoveVMTemplate
    Causes the VM Templates created by this to be be removed.
.PARAMETER RemoveVMFolder
    Causes the VM folder created to contain the files for any the
    VMs in this Lab to be removed.
.PARAMETER RemoveVMTemplateVHD
    Causes the VM Template VHDs that are used in this lab to be
    deleted.
.PARAMETER RemoveLabFolder
    Causes the entire folder containing this Lab to be deleted.
.EXAMPLE
    Uninstall-Lab `
        -ConfigPath c:\mylab\config.xml `
        -RemoveSwitch`
        -RemoveVMTemplate `
        -RemoveVMFolder `
        -RemoveVMTemplateVHD `
        -RemoveLabFolder
    Completely uninstall all components in the lab defined in the
    c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Uninstall-Lab `
        -RemoveSwitch`
        -RemoveVMTemplate `
        -RemoveVMFolder `
        -RemoveVMTemplateVHD `
        -RemoveLabFolder
    Completely uninstall all components in the lab defined in the
    c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
    None
#>
Function Uninstall-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab",
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=4)]
        [Switch] $RemoveSwitch,

        [Parameter(
            Position=5)]
        [Switch] $RemoveVMTemplate,

        [Parameter(
            Position=6)]
        [Switch] $RemoveVMFolder,

        [Parameter(
            Position=7)]
        [Switch] $RemoveVMTemplateVHD,

        [Parameter(
            Position=8)]
        [Switch] $RemoveLabFolder
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('RemoveSwitch')
        $null = $PSBoundParameters.Remove('RemoveVMTemplate')
        $null = $PSBoundParameters.Remove('RemoveVMFolder')
        $null = $PSBoundParameters.Remove('RemoveVMTemplateVHD')
        $null = $PSBoundParameters.Remove('RemoveLabFolder')

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters
        } # if
    } # begin

    process
    {
        if ($PSCmdlet.ShouldProcess( 'LocalHost', `
            ($LocalizedData.ShouldUninstallLab `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
        {
            # Remove the VMs
            $VMSplat = @{}
            if ($RemoveVMFolder)
            {
                $VMSplat += @{ RemoveVMFolder = $true }
            } # if
            $null = Remove-LabVM `
                -Lab $Lab `
                @VMSplat

            # Remove the VM Templates
            if ($RemoveVMTemplate)
            {
                if ($PSCmdlet.ShouldProcess( 'LocalHost', `
                    ($LocalizedData.ShouldRemoveVMTemplate `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabVMTemplate `
                        -Lab $Lab
                } # if
            } # if

            # Remove the VM Switches
            if ($RemoveSwitch)
            {
                if ($PSCmdlet.ShouldProcess( 'LocalHost', `
                    ($LocalizedData.ShouldRemoveSwitch `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabSwitch `
                        -Lab $Lab
                } # if
            } # if

            # Remove the VM Template VHDs
            if ($RemoveVMTemplateVHD)
            {
                if ($PSCmdlet.ShouldProcess( 'LocalHost', `
                    ($LocalizedData.ShouldRemoveVMTemplateVHD `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabVMTemplateVHD `
                        -Lab $Lab
                } # if
            } # if

            # Remove the Lab Folder
            if ($RemoveLabFolder)
            {
                if (Test-Path -Path $Lab.labbuilderconfig.settings.labpath)
                {
                    if ($PSCmdlet.ShouldProcess( 'LocalHost', `
                        ($LocalizedData.ShouldRemoveLabFolder `
                        -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                    {
                        Remove-Item `
                            -Path $Lab.labbuilderconfig.settings.labpath `
                            -Recurse `
                            -Force
                    } # if
                } # if
            } # if

            # Remove the LabBuilder Management Network switch
            [String] $ManagementSwitchName = GetManagementSwitchName `
                -Lab $Lab
            if ((Get-VMSwitch | Where-Object -Property Name -eq $ManagementSwitchName).Count -ne 0)
            {
                $null = Remove-VMSwitch `
                    -Name $ManagementSwitchName

                WriteMessage -Message $($LocalizedData.RemovingLabManagementSwitchMessage `
                    -f $ManagementSwitchName)
            }

            WriteMessage -Message $($LocalizedData.LabUninstallCompleteMessage `
                -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )
        } # if
    } # process

    end
    {
    } # end
} # Uninstall-Lab


<#
.SYNOPSIS
    Starts an existing Lab.
.DESCRIPTION
    This cmdlet will start all the Hyper-V virtual machines definied in a Lab
    configuration.

    It will use the Bootorder attribute (if defined) for any VMs to determine
    the order they should be booted in. If a Bootorder is not specified for a
    machine, it will be booted after all machines with a defined boot order.

    The lower the Bootorder value for a machine the earlier it will be started
    in the start process.

    Machines will be booted in series, with each machine starting once the
    previous machine has completed startup and has a management IP address.

    If a Virtual Machine in the Lab is already running, it will be ignored
    and the next machine in series will be started.

    If more than one Virtual Machine shares the same Bootorder value, then
    these machines will be booted in parallel, with the boot process only
    continuing onto the next Bootorder when all these machines are booted.

    If a Virtual Machine specified in the configuration is not found an
    exception will be thrown.

    If a Virtual Machine takes longer than the StartupTimeout then an exception
    will be thown but the Start process will continue.

    If a Bootorder of 0 is specifed then the Virtual Machine will not be booted at
    all. This is useful for things like Root CA VMs that only need to started when
    the Lab is created.
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to install the Lab to - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to start.
.PARAMETER StartupTimeout
    The maximum number of seconds that the process will wait for a VM to startup.
    Defaults to 90 seconds.
.EXAMPLE
    Start-Lab -ConfigPath c:\mylab\config.xml
    Start the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Start-Lab
    Start the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
    None
#>
Function Start-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=4)]
        [Int] $StartupTimeout = $Script:StartupTimeout
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('StartupTimeout')

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters
        } # if
    } # begin

    process
    {
        # Get the VMs
        $VMs = Get-LabVM `
            -Lab $Lab

        # Get the bootorders by lowest first and ignoring 0 and call
        $BootOrders = @( ($VMs |
            Where-Object -FilterScript { ($_.Bootorder -gt 0) } ).Bootorder )
        $BootPhases = @( ($Bootorders |
            Sort-Object -Unique) )

        # Step through each of these "Bootphases" waiting for them to complete
        foreach ($BootPhase in $BootPhases)
        {
            # Process this "Bootphase"
            WriteMessage -Message $($LocalizedData.StartingBootPhaseVMsMessage `
                -f $BootPhase)

            # Get all VMs in this "Bootphase"
            $BootVMs = @( $VMs |
                Where-Object -FilterScript { ($_.BootOrder -eq $BootPhase) } )

            [DateTime] $StartPhase = Get-Date
            [boolean] $PhaseComplete = $False
            [boolean] $PhaseAllBooted = $True
            [int] $VMCount = $BootVMs.Count
            [int] $VMNumber = 0

            # Loop through all the VMs in this "Bootphase" repeatedly
            # until timeout occurs or PhaseComplete is marked as complete
            while (-not $PhaseComplete `
                -and ((Get-Date) -lt $StartPhase.AddSeconds($StartupTimeout)))
            {
                # Get the VM to boot/check
                $VM = $BootVMs[$VMNumber]
                $VMName = $VM.Name

                # Get the actual Hyper-V VM object
                $VMObject = Get-VM `
                    -Name $VMName `
                    -ErrorAction SilentlyContinue
                if (-not $VMObject)
                {
                    # if the VM does not exist then throw a non-terminating exception
                    $ExceptionParameters = @{
                        errorId = 'VMDoesNotExistError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDoesNotExistError `
                            -f $VMName)

                    }
                    ThrowException @ExceptionParameters
                } # if

                # Start the VM if it is off
                if ($VMObject.State -eq 'Off')
                {
                    WriteMessage -Message $($LocalizedData.StartingVMMessage `
                        -f $VMName)
                    Start-VM `
                        -VM $VMObject
                } # if

                # Use the allocation of a Management IP Address as an indicator
                # the machine has booted
                $ManagementIP = GetVMManagementIPAddress `
                    -Lab $Lab `
                    -VM $VM `
                    -ErrorAction SilentlyContinue
                if (-not ($ManagementIP))
                {
                    # It has not booted
                    $PhaseAllBooted = $False
                } # if
                $VMNumber++
                if ($VMNumber -eq $VMCount)
                {
                    # We have stepped through all VMs in this Phase so check
                    # if all have booted, otherwise reset the loop.
                    if ($PhaseAllBooted)
                    {
                        # if we have gone through all VMs in this "Bootphase"
                        # and they're all marked as booted then we can mark
                        # this phase as complete and allow moving on to the next one
                        WriteMessage -Message $($LocalizedData.AllBootPhaseVMsStartedMessage `
                            -f $BootPhase)
                        $PhaseComplete = $True
                    }
                    else
                    {
                        $PhaseAllBooted = $True
                    } # if
                    # Reset the VM Loop
                    $VMNumber = 0
                } # if
            } # while

            # Did we timeout?
            if (-not ($PhaseComplete))
            {
                # Yes, throw an exception
                $ExceptionParameters = @{
                    errorId = 'BootPhaseVMsTimeoutError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.BootPhaseStartVMsTimeoutError `
                        -f $BootPhase)

                }
                ThrowException @ExceptionParameters
            } # if
        } # foreach

        WriteMessage -Message $($LocalizedData.LabStartCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)
    } # process

    end
    {
    } # end
} # Start-Lab


<#
.SYNOPSIS
    Stop an existing Lab.
.DESCRIPTION
    This cmdlet will stop all the Hyper-V virtual machines definied in a Lab
    configuration.

    It will use the Bootorder attribute (if defined) for any VMs to determine
    the order they should be shutdown in. If a Bootorder is not specified for a
    machine, it will be shutdown before all machines with a defined boot order.

    The higher the Bootorder value for a machine the earlier it will be shutdown
    in the stop process.

    The Virtual Machines will be shutdown in REVERSE Bootorder.

    Machines will be shutdown in series, with each machine shutting down once the
    previous machine has completed shutdown.

    If a Virtual Machine in the Lab is already shutdown, it will be ignored
    and the next machine in series will be shutdown.

    If more than one Virtual Machine shares the same Bootorder value, then
    these machines will be shutdown in parallel, with the shutdown process only
    continuing onto the next Bootorder when all these machines are shutdown.

    If a Virtual Machine specified in the configuration is not found an
    exception will be thrown.

    If a Virtual Machine takes longer than the ShutdownTimeout then an exception
    will be thown but the Stop process will continue.
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to install the Lab to - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to start.
.PARAMETER ShutdownTimeout
    The maximum number of seconds that the process will wait for a VM to shutdown.
    Defaults to 30 seconds.
.EXAMPLE
    Stop-Lab -ConfigPath c:\mylab\config.xml
    Stop the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Stop-Lab
    Stop the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
    None
#>
Function Stop-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters
        } # if
    } # begin

    process
    {
        # Get the VMs
        $VMs = Get-LabVM `
            -Lab $Lab

        # Get the bootorders by highest first and ignoring 0
        $BootOrders = @( ($VMs |
            Where-Object -FilterScript { ($_.Bootorder -gt 0) } ).Bootorder )
        $BootPhases = @( ($Bootorders |
            Sort-Object -Unique -Descending) )

        # Step through each of these "Bootphases" waiting for them to complete
        foreach ($BootPhase in $BootPhases)
        {
            # Process this "Bootphase"
            WriteMessage -Message $($LocalizedData.StoppingBootPhaseVMsMessage `
                -f $BootPhase)

            # Get all VMs in this "Bootphase"
            $BootVMs = @( $VMs |
                Where-Object -FilterScript { ($_.BootOrder -eq $BootPhase) } )

            [DateTime] $StartPhase = Get-Date
            [boolean] $PhaseComplete = $False
            [boolean] $PhaseAllStopped = $True
            [int] $VMCount = $BootVMs.Count
            [int] $VMNumber = 0

            # Loop through all the VMs in this "Bootphase" repeatedly
            while (-not $PhaseComplete)
            {
                # Get the VM to boot/check
                $VM = $BootVMs[$VMNumber]
                $VMName = $VM.Name

                # Get the actual Hyper-V VM object
                $VMObject = Get-VM `
                    -Name $VMName `
                    -ErrorAction SilentlyContinue
                if (-not $VMObject)
                {
                    # if the VM does not exist then throw a non-terminating exception
                    $ExceptionParameters = @{
                        errorId = 'VMDoesNotExistError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDoesNotExistError `
                            -f $VMName)

                    }
                    ThrowException @ExceptionParameters
                } # if

                # Shutodwn the VM if it is off
                if ($VMObject.State -eq 'Running')
                {
                    WriteMessage -Message $($LocalizedData.StoppingVMMessage `
                        -f $VMName)
                    $null = Stop-VM `
                        -VM $VMObject `
                        -Force `
                        -ErrorAction Continue
                } # if

                # Determine if the VM has stopped.
                if ((Get-VM -VMName $VMName).State -ne 'Off')
                {
                    # It has not stopped
                    $PhaseAllStopped = $False
                } # if
                $VMNumber++
                if ($VMNumber -eq $VMCount)
                {
                    # We have stepped through all VMs in this Phase so check
                    # if all have stopped, otherwise reset the loop.
                    if ($PhaseAllStopped)
                    {
                        # if we have gone through all VMs in this "Bootphase"
                        # and they're all marked as stopped then we can mark
                        # this phase as complete and allow moving on to the next one
                        WriteMessage -Message $($LocalizedData.AllBootPhaseVMsStoppedMessage `
                            -f $BootPhase)
                        $PhaseComplete = $True
                    }
                    else
                    {
                        $PhaseAllStopped = $True
                    } # if
                    # Reset the VM Loop
                    $VMNumber = 0
                } # if
            } # while
        } # foreach

        WriteMessage -Message $($LocalizedData.LabStopCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)
    } # process

    end
    {
    } # end
} # Stop-Lab