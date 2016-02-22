#Requires -version 5.0
#Requires -RunAsAdministrator

####################################################################################################
$moduleRoot = Split-Path `
    -Path $MyInvocation.MyCommand.Path `
    -Parent

#region localizeddata
$Culture = 'en-us'
if (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath $PSUICulture))
{
    $Culture = $PSUICulture
}
Import-LocalizedData `
    -BindingVariable LocalizedData `
    -Filename LabBuilder_LocalizedData.psd1 `
    -BaseDirectory $moduleRoot `
    -UICulture $Culture
#endregion

#region importfunctions
# Dot source any functions in the libs folder
$Libs = Get-ChildItem `
    -Path (Join-Path -Path $moduleRoot -ChildPath 'lib') `
    -Include '*.ps1' `
    -Recurse
$Libs.Foreach(
    {
        Write-Verbose -Message ($LocalizedData.ImportingLibFileMessage `
            -f $_.Fullname)
        . $_.Fullname    
    }
)
#>
#endregion

####################################################################################################
# Module Variables
####################################################################################################
[String] $Script:WorkingFolder = $ENV:Temp

# Supporting files
[String] $Script:SupportConvertWindowsImagePath = Join-Path -Path $PSScriptRoot -ChildPath 'Support\Convert-WindowsImage.ps1'
[String] $Script:SupportGertGenPath = Join-Path -Path $PSScriptRoot -ChildPath 'Support\New-SelfSignedCertificateEx.ps1'

# Virtual Networking Parameters
[Int] $Script:DefaultManagementVLan = 99

# Self-signed Certificate Parameters
[Int] $Script:SelfSignedCertKeyLength = 2048
# Warning - using KSP causes the Private Key to not be accessible to PS.
[String] $Script:SelfSignedCertProviderName = 'Microsoft Enhanced Cryptographic Provider v1.0' # 'Microsoft Software Key Storage Provider'
[String] $Script:SelfSignedCertAlgorithmName = 'RSA' # 'ECDH_P256' Or 'ECDH_P384' Or 'ECDH_P521'
[String] $Script:SelfSignedCertSignatureAlgorithm = 'SHA256' # 'SHA1'
[String] $Script:DSCEncryptionCert = 'DSCEncryption.cer'
[String] $Script:DSCCertificateFriendlyName = 'DSC Credential Encryption'
[Int] $Script:RetryConnectSeconds = 5
[Int] $Script:RetryHeartbeatSeconds = 1

# The current list of Nano Servers available with TP4.
[Array] $Script:NanoServerPackageList = @(
    @{ Name = 'Compute'; Filename = 'Microsoft-NanoServer-Compute-Package.cab' },
    @{ Name = 'OEM-Drivers'; Filename = 'Microsoft-NanoServer-OEM-Drivers-Package.cab' },
    @{ Name = 'Storage'; Filename = 'Microsoft-NanoServer-Storage-Package.cab' },
    @{ Name = 'FailoverCluster'; Filename = 'Microsoft-NanoServer-FailoverCluster-Package.cab' },
    @{ Name = 'ReverseForwarders'; Filename = 'Microsoft-OneCore-ReverseForwarders-Package.cab' },
    @{ Name = 'Guest'; Filename = 'Microsoft-NanoServer-Guest-Package.cab' },
    @{ Name = 'Containers'; Filename = 'Microsoft-NanoServer-Containers-Package.cab' },
    @{ Name = 'Defender'; Filename = 'Microsoft-NanoServer-Defender-Package.cab' },
    @{ Name = 'DCB'; Filename = 'Microsoft-NanoServer-DCB-Package.cab' },
    @{ Name = 'DNS'; Filename = 'Microsoft-NanoServer-DNS-Package.cab' },
    @{ Name = 'DSC'; Filename = 'Microsoft-NanoServer-DSC-Package.cab' },
    @{ Name = 'IIS'; Filename = 'Microsoft-NanoServer-IIS-Package.cab' },
    @{ Name = 'NPDS'; Filename = 'Microsoft-NanoServer-NPDS-Package.cab' },
    @{ Name = 'SCVMM'; Filename = 'Microsoft-Windows-Server-SCVMM-Package.cab' },
    @{ Name = 'SCVMM-Compute'; Filename = 'Microsoft-Windows-Server-SCVMM-Compute-Package.cab' }
)

####################################################################################################
# Helper functions that aren't exported - Don't obey Verb-Noun naming
####################################################################################################

####################################################################################################
# Main CmdLets
####################################################################################################
<#
.SYNOPSIS
    Loads a Lab Builder Configuration file and returns a Configuration object
.PARAMETER Path
    This is the path to the Lab Builder configuration file to load.
.EXAMPLE
    $MyLab = Get-LabConfiguration -Path c:\MyLab\LabConfig1.xml
    Loads the LabConfig1.xml configuration into variable MyLab
.OUTPUTS
    XML Object containing the Lab Configuration that was loaded.
#>
function Get-LabConfiguration {
    [CmdLetBinding()]
    [OutputType([XML])]
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Path
    ) # Param
    if (-not (Test-Path -Path $Path))
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationFileNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileNotFoundError `
                -f $Path)
        }
        ThrowException @ExceptionParameters
    } # If
    $Content = Get-Content -Path $Path -Raw
    if (-not $Content)
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationFileEmptyError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileEmptyError `
                -f $Path)
        }
        ThrowException @ExceptionParameters
    } # If
    [XML] $Config = New-Object System.Xml.XmlDocument
    $Config.PreserveWhitespace = $true
    $Config.LoadXML($Content)
    # Figure out the Config path and load it into the XML object (if we can)
    # This path is used to find any additional configuration files that might
    # be provided with config
    [String] $ConfigPath = [System.IO.Path]::GetDirectoryName($Path)
    [String] $XMLConfigPath = $Config.labbuilderconfig.settings.configpath
    if ($XMLConfigPath) {
        if (! [System.IO.Path]::IsPathRooted($XMLConfigurationPath))
        {
            # A relative path was provided in the config path so add the actual path of the
            # XML to it
            [String] $FullConfigPath = Join-Path -Path $ConfigPath -ChildPath $XMLConfigPath
        } # If
    }
    else
    {
        [String] $FullConfigPath = $ConfigPath
    }
    $Config.labbuilderconfig.settings.setattribute('fullconfigpath',$FullConfigPath)
    Return $Config
} # Get-LabConfiguration
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
    Tests the Lab Builder configuration passed to ensure it is valid and related files can be found.
.PARAMETER Configuration
    Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
    object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Test-LabConfiguration -Config $Config
   Loads a Lab Builder configuration and tests it is valid.   
.OUTPUTS
   Returns True if the configuration is valid. Throws an error if invalid.
#>
function Test-LabConfiguration {
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config
    )

    if ((-not $Config.labbuilderconfig) `
        -or (-not $Config.labbuilderconfig.settings))
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationInvalidError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationInvalidError)
        }
        ThrowException @ExceptionParameters
    }

    # Check folders exist
    [String] $LabPath = $Config.labbuilderconfig.settings.labpath
    if (-not $LabPath)
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationMissingElementError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationMissingElementError `
                -f '<settings>\<labpath>')
        }
        ThrowException @ExceptionParameters
    }

    if (-not (Test-Path -Path $LabPath))
    {
        $ExceptionParameters = @{
            errorId = 'PathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.PathNotFoundError `
                -f '<settings>\<labpath>',$LabPath)
        }
        ThrowException @ExceptionParameters
    }

    [String] $VHDParentPath = $Config.labbuilderconfig.settings.vhdparentpath
    if (-not $VHDParentPath)
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationMissingElementError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationMissingElementError `
                -f '<settings>\<vhdparentpath>')
        }
        ThrowException @ExceptionParameters
    }

    if (-not (Test-Path -Path $VHDParentPath))
    {
        $ExceptionParameters = @{
            errorId = 'PathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.PathNotFoundError `
                -f '<settings>\<vhdparentpath>',$VHDParentPath)
        }
        ThrowException @ExceptionParameters
    }

    [String] $FullConfigPath = $Config.labbuilderconfig.settings.fullconfigpath
    if (-not (Test-Path -Path $FullConfigPath)) 
    {
        $ExceptionParameters = @{
            errorId = 'PathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.PathNotFoundError `
                -f '<settings>\<fullconfigpath>',$FullConfigPath)
        }
        ThrowException @ExceptionParameters
    }
    Return $true
} # Test-LabConfiguration
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Ensures the Hyper-V features are installed onto the system.
.DESCRIPTION
   If the Hyper-V features are not installed onto this system they will be installed.
.EXAMPLE
   Install-LabHyperV
   Installs the appropriate Hyper-V features if they are not currently installed.
.OUTPUTS
   None
#>
function Install-LabHyperV {
    [CmdLetBinding()]
    Param ()

    # Install Hyper-V Components
    if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1)
    {
        # Desktop OS
        [Array] $Feature = Get-WindowsOptionalFeature -Online -FeatureName '*Hyper-V*' `
            | Where-Object -Property State -Eq 'Disabled'
        if ($Feature.Count -gt 0 )
        {
            Write-Verbose -Message ($LocalizedData.InstallingHyperVComponentsMesage `
                -f 'Desktop')
            $Feature.Foreach( { 
                Enable-WindowsOptionalFeature -Online -FeatureName $_.FeatureName
            } )
        }
    }
    Else
    {
        # Server OS
        [Array] $Feature = Get-WindowsFeature -Name Hyper-V `
            | Where-Object -Property Installed -EQ $false
        if ($Feature.Count -gt 0 )
        {
            Write-Verbose -Message ($LocalizedData.InstallingHyperVComponentsMesage `
                -f 'Desktop')
            $Feature.Foreach( {
                Install-WindowsFeature -IncludeAllSubFeature -IncludeManagementTools -Name $_.Name
            } )
        }
    }
} # Install-LabHyperV
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Initializes the system from information provided in the Lab Configuration object provided.
.DESCRIPTION
   This function should be run after loading a Lab Configuration file. It will ensure any required
   modules and files are downloaded and also that the Hyper-V system on this machine is configured
   with any required settings (MAC Addresses range) provided in the configuration object.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Initialize-LabConfiguration -Config $Config
   Loads a Lab Builder configuration and applies the base system settings.
.OUTPUTS
   None.
#>
function Initialize-LabConfiguration {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config
    )
    
    # Install Hyper-V Components
    Write-Verbose -Message ($LocalizedData.InitializingHyperVComponentsMesage)
    
    # Create the LabBuilder Management Network switch and assign VLAN
    # Used by host to communicate with Lab VMs
    [String] $ManagementSwitchName = ('LabBuilder Management {0}' `
        -f $Config.labbuilderconfig.name)
    if ($Config.labbuilderconfig.switches.ManagementVlan)
    {
        [Int32] $ManagementVlan = $Config.labbuilderconfig.switches.ManagementVlan
    }
    else
    {
        [Int32] $ManagementVlan = $Script:DefaultManagementVLan
    }
    if ((Get-VMSwitch | Where-Object -Property Name -eq $ManagementSwitchName).Count -eq 0)
    {
        $null = New-VMSwitch -Name $ManagementSwitchName -SwitchType Internal

        Write-Verbose -Message ($LocalizedData.CreatingLabManagementSwitchMessage `
            -f $ManagementSwitchName,$ManagementVlan)
    }
    # Check the Vlan ID of the adapter on the switch
    $ExistingManagementAdapter = Get-VMNetworkAdapter `
		-ManagementOS `
		-Name $ManagementSwitchName
    $ExistingVlan = (Get-VMNetworkAdapterVlan `
		-VMNetworkAdaptername $ExistingManagementAdapter.Name `
		-ManagementOS).AccessVlanId

    if ($ExistingVlan -ne $ManagementVlan)
    {
        Write-Verbose -Message ($LocalizedData.UpdatingLabManagementSwitchMessage `
            -f $ManagementSwitchName,$ManagementVlan)

        Set-VMNetworkAdapterVlan `
            -VMNetworkAdapterName $ManagementSwitchName `
            -ManagementOS `
            -Access `
            -VlanId $ManagementVlan
    }
    # Download any other resources required by this lab
    Download-LabResources -Config $Config	

} # Initialize-LabConfiguration
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Downloads any resources required by the configuration.
.DESCRIPTION
   It will ensure any required modules and files are downloaded.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Download-LabResources -Config $Config
   Loads a Lab Builder configuration and downloads any resources required by it.   
.OUTPUTS
   None.
#>
function Download-LabModule {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [String] $URL,

        [String] $Folder,
        
        [String] $RequiredVersion,

        [String] $MinimumVersion
    )

    $InstalledModules = @(Get-Module -ListAvailable)

    # Determine a query that will be used to decide if the module is already installed
    if ($RequiredVersion) {
        [ScriptBlock] $Query = `
            { ($_.Name -eq $Name) -and ($_.Version -eq $RequiredVersion) }
        $VersionMessage = $RequiredVersion                
    }
    elseif ($MinimumVersion)
    {
        [ScriptBlock] $Query = `
            { ($_.Name -eq $Name) -and ($_.Version -ge $MinimumVersion) }
        $VersionMessage = "min ${MinimumVersion}"
    }
    else
    {
        [ScriptBlock] $Query = `
            $Query = { $_.Name -eq $Name }
        $VersionMessage = 'any version'
    }

    # Is the module installed?
    if ($InstalledModules.Where($Query).Count -eq 0)
    {
        Write-Verbose -Message ($LocalizedData.ModuleNotInstalledMessage `
            -f $Name,$VersionMessage)

        # If a URL was specified, download this module via HTTP
        if ($URL)
        {
            # The module is not installed - so download it
            # This is usually for downloading modules directly from github
            $FileName = $URL.Substring($URL.LastIndexOf('/') + 1)
            $FilePath = Join-Path -Path $Script:WorkingFolder -ChildPath $FileName

            Write-Verbose -Message ($LocalizedData.DownloadingLabResourceWebMessage `
                -f $Name,$VersionMessage,$URL)

            [String] $ModulesFolder = "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\"

            DownloadAndUnzipFile `
                -URL $URL `
                -DestinationPath $ModulesFolder `
                -ErrorAction Stop

            if ($Folder)
            {
                # This zip file contains a folder that is not the name of the module so it must be
                # renamed. This is usually the case with source downloaded directly from GitHub
                $ModulePath = Join-Path -Path $ModulesFolder -ChildPath $Name
                if (Test-Path -Path $ModulePath)
                {
                    Remove-Item -Path $ModulePath -Recurse -Force
                }
                Rename-Item `
                    -Path (Join-Path -Path $ModulesFolder -ChildPath $Folder) `
                    -NewName $Name `
                    -Force
            } # If

            Write-Verbose -Message ($LocalizedData.InstalledLabResourceWebMessage `
                -f $Name,$VersionMessage,$ModulePath)
        }
        else
        {
            # Install the package via PowerShellGet from the PowerShellGallery
            # Make sure the Nuget Package provider is initialized.
            $null = Get-PackageProvider -name nuget -ForceBootStrap -Force

            # Install the module
            $Splat = [PSObject] @{ Name = $Name }
            if ($RequiredVersion)
            {
                # Is a specific module version required?
                $Splat += [PSObject] @{ RequiredVersion = $RequiredVersion }
            }
            elseif ($MinimumVersion)
            {
                # Is a specific module version minimum version?
                $Splat += [PSObject] @{ MinimumVersion = $MinimumVersion }
            }
            try
            {
                Install-Module @Splat -Force -ErrorAction Stop
            }
            catch
            {
                $ExceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f $Name,$VersionMessage,$_.Exception.Message)
                }
                ThrowException @ExceptionParameters
            }
        } # If
    } # If
} # Download-LabModule
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Downloads any resources required by the configuration.
.DESCRIPTION
   It will ensure any required modules and files are downloaded.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Download-LabResources -Config $Config
   Loads a Lab Builder configuration and downloads any resources required by it.   
.OUTPUTS
   None.
#>
function Download-LabResources {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config
    )
        
    # Downloading Lab Resources
    Write-Verbose -Message $($LocalizedData.DownloadingLabResourcesMessage)

    # Bootstrap Nuget # This needs to be a test, not a force 
    # $null = Get-PackageProvider -Name NuGet -ForceBootstrap -Force
    
    # Make sure PSGallery is trusted
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted    
    
    # Download any other resources required by this lab
    if ($Config.labbuilderconfig.resources) 
    {
        foreach ($Module in $Config.labbuilderconfig.resources.module)
        {
            if (-not $Module.Name)
            {
                $ExceptionParameters = @{
                    errorId = 'ResourceModuleNameEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceModuleNameEmptyError)
                }
                ThrowException @ExceptionParameters
            } # If
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
            Download-LabModule @Splat
        } # Foreach
    } # If
} # Download-LabResources
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Gets an array of switches from a Lab Configuration file.
.DESCRIPTION
   Takes a provided Lab Configuration file and returns the list of switches required for this Lab.
   This list is usually passed to Initialize-LabSwitch to configure the swtiches required for this
   lab.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabSwitch -Config $Config
   Loads a Lab Builder configuration and pulls the array of switches from it.
.OUTPUTS
   Returns an array of switches.
#>
function Get-LabSwitch {
    [OutputType([Array])]
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config
    )

    [Array] $Switches = @() 
    $ConfigSwitches = $Config.labbuilderconfig.SelectNodes('switches').Switch
    foreach ($ConfigSwitch in $ConfigSwitches)
    {
        # It can't be switch because if the name attrib/node is missing the name property on the
        # XML object defaults to the name of the parent. So we can't easily tell if no name was
        # specified or if they actually specified 'switch' as the name.
        if ($ConfigSwitch.Name -eq 'switch')
        {
            $ExceptionParameters = @{
                errorId = 'SwitchNameIsEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
            }
            ThrowException @ExceptionParameters
        }
        if ($ConfigSwitch.Type -notin 'Private','Internal','External','NAT')
        {
            $ExceptionParameters = @{
                errorId = 'UnknownSwitchTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                    -f $ConfigSwitch.Type,$ConfigSwitch.Name)
            }
            ThrowException @ExceptionParameters
        }
        # Assemble the list of Adapters if any are specified for this switch (only if an external
        # switch)
        if ($ConfigSwitch.Adapters)
        {
            [System.Collections.Hashtable[]] $ConfigAdapters = @()
            foreach ($Adapter in $ConfigSwitch.Adapters.Adapter)
            {
                $ConfigAdapters += @{ name = $Adapter.Name; macaddress = $Adapter.MacAddress }
            }
            if (($ConfigAdapters.Count -gt 0) -and ($ConfigSwitch.Type -ne 'External'))
            {
                $ExceptionParameters = @{
                    errorId = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.AdapterSpecifiedError `
                        -f $ConfigSwitch.Type,$ConfigSwitch.Name)
                }
                ThrowException @ExceptionParameters
            }
        }
        Else
        {
            $ConfigAdapters = $null
        }
        $Switches += [PSObject]@{
            name = $ConfigSwitch.Name;
            type = $ConfigSwitch.Type;
            vlan = $ConfigSwitch.Vlan;
            natsubnetaddress = $ConfigSwitch.NatSubnetAddress;
            adapters = $ConfigAdapters }
    }
    return $Switches
} # Get-LabSwitch
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Creates Hyper-V Virtual Switches from a provided array.
.DESCRIPTION
   Takes an array of switches that were pulled from a Lab Configuration object by calling
   Get-LabSwitch
   and ensures that they Hyper-V Virtual Switches on the system are configured to match.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER Switches
   The array of switches pulled from the Lab Configuration file using Get-LabSwitch.
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabSwitch -Config $Config
   Initialize-LabSwitch -Config $Config -Switches $Switches
   Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Initialize-LabSwitch -Config $Config
   Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Initialize-LabSwitch {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [Array] $Switches
    )

    # If swtiches was not passed, pull it.
    if (-not $Switches)
    {
        $Switches = Get-LabSwitch `
            -Config $Config
    }
    
    # Create Hyper-V Switches
    foreach ($VMSwitch in $Switches)
    {
        if ((Get-VMSwitch | Where-Object -Property Name -eq $($VMSwitch.Name)).Count -eq 0)
        {
            [String] $SwitchName = $VMSwitch.Name
            if (-not $SwitchName)
            {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                ThrowException @ExceptionParameters
            }
            [string] $SwitchType = $VMSwitch.Type
            Write-Verbose -Message $($LocalizedData.CreatingVirtualSwitchMessage `
                -f $SwitchType,$SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -NetAdapterName (`
                            Get-NetAdapter | `
                            Where-Object { $_.Status -eq 'Up' } | `
                            Select-Object -First 1 -ExpandProperty Name `
                            )
                    if ($VMSwitch.Adapters)
                    {
                        foreach ($Adapter in $VMSwitch.Adapters)
                        {
                            if ($VMSwitch.VLan)
                            {
                                # A default VLAN is assigned to this Switch so assign it to the
                                # management adapters
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress) `
                                    
                                    -Passthru | `
                                    Set-VMNetworkAdapterVlan -Access -VlanId $($Switch.Vlan)
                            }
                            Else
                            { 
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress)
                            } # If
                        } # Foreach
                    } # If
                    Break
                } # 'External'
                'Private'
                {
                    $null = New-VMSwitch -Name $SwitchName -SwitchType Private
                    Break
                } # 'Private'
                'Internal'
                {
                    $null = New-VMSwitch -Name $SwitchName -SwitchType Internal
                    if ($VMSwitch.Adapters)
                    {
                        foreach ($Adapter in $VMSwitch.Adapters)
                        {
                            if ($VMSwitch.VLan)
                            {
                                # A default VLAN is assigned to this Switch so assign it to the
                                # management adapters
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress) `
                                    -Passthru | `
                                    Set-VMNetworkAdapterVlan -Access -VlanId $($Switch.Vlan)
                            }
                            Else
                            { 
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress)
                            } # If
                        } # Foreach
                    } # If
                    Break
                } # 'Internal'
                'NAT'
                {
                    $NatSubnetAddress = $VMSwitch.NatSubnetAddress
                    if (-not $NatSubnetAddress) {
                        $ExceptionParameters = @{
                            errorId = 'NatSubnetAddressEmptyError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.NatSubnetAddressEmptyError `
                                -f $SwitchName)
                        }
                        ThrowException @ExceptionParameters
                    }
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -SwitchType NAT `
                        -NATSubnetAddress $NatSubnetAddress
                    $null = New-NetNat `
                        -Name $SwitchName `
                        -InternalIPInterfaceAddressPrefix $NatSubnetAddress
                    Break
                } # 'NAT'
                Default
                {
                    $ExceptionParameters = @{
                        errorId = 'UnknownSwitchTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                            -f $SwitchType,$SwitchName)
                    }
                    ThrowException @ExceptionParameters
                }
            } # Switch
        } # If
    } # Foreach       
} # Initialize-LabSwitch
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Removes all Hyper-V Virtual Switches provided.
.DESCRIPTION
   This cmdlet is used to remove any Hyper-V Virtual Switches that were created by
   the Initialize-LabSwitch cmdlet.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER Switches
   The array of switches pulled from the Lab Configuration file using Get-LabSwitch
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabSwitch -Config $Config
   Remove-LabSwitch -Config $Config -Switches $Switches
   Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Remove-LabSwitch -Config $Config
   Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Remove-LabSwitch {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [System.Collections.Hashtable[]] $Switches
    )

    # If swtiches was not passed, pull it.
    if (-not $Switches)
    {
        $Switches = Get-LabSwitch `
            -Config $Config
    }

    # Delete Hyper-V Switches
    foreach ($Switch in $Switches)
    {
        if ((Get-VMSwitch | Where-Object -Property Name -eq $Switch.Name).Count -ne 0)
        {
            [String] $SwitchName = $Switch.Name
            if (-not $SwitchName)
            {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                ThrowException @ExceptionParameters
            }
            [string] $SwitchType = $Switch.Type
            Write-Verbose -Message $($LocalizedData.DeleteingVirtualSwitchMessage `
                -f $SwitchType,$SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    if ($Switch.Adapters)
                    {
                        $Switch.Adapters.foreach( {
                            $null = Remove-VMNetworkAdapter -ManagementOS -Name $_.Name
                        } )
                    } # If
                    Remove-VMSwitch -Name $SwitchName
                    Break
                } # 'External'
                'Private'
                {
                    Remove-VMSwitch -Name $SwitchName
                    Break
                } # 'Private'
                'Internal'
                {
                    Remove-VMSwitch -Name $SwitchName
                    if ($Switch.Adapters)
                    {
                        $Switch.Adapters.foreach( {
                            $null = Remove-VMNetworkAdapter -ManagementOS -Name $_.Name
                        } )
                    } # If
                    Break
                } # 'Internal'
                'NAT'
                {
                    Remove-NetNAT -Name $SwitchName
                    Remove-VMSwitch -Name $SwitchName
                    Break
                } # 'Internal'

                Default
                {
                    $ExceptionParameters = @{
                        errorId = 'UnknownSwitchTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                            -f $SwitchType,$SwitchName)
                    }
                    ThrowException @ExceptionParameters
                }
            } # Switch
        } # If
    } # Foreach        
} # Remove-LabSwitch
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Gets an Array of TemplateVHDs for a Lab configuration.
.DESCRIPTION
   Takes a provided Lab Configuration file and returns the list of Template Disks
   that will be used to create the Virtual Machines in this lab. This list is usually passed to
   Initialize-LabVMTemplateVHD.
   
   It will validate the paths to the ISO folder as well as to the ISO files themselves.
   
   If any ISO files references can't be found an exception will be thrown.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config
   Loads a Lab Builder configuration and pulls the array of TemplateVHDs from it.
.OUTPUTS
   Returns an array of TemplateVHDs. It will return Null if the TemplateVHDs node does
   not exist or contains no TemplateVHD nodes.
#>
function Get-LabVMTemplateVHD {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config
    )

    # return null if the TemplateVHDs node does not exist
    if (-not $Config.labbuilderconfig.TemplateVHDs)
    {
        return
    }
    
    # Determine the ISORootPath where the ISO files should be found
    # If no path is specified then look in the same path as the config
    # If a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $ISORootPath = $Config.labbuilderconfig.TemplateVHDs.ISOPath
    if (-not $ISORootPath)
    {
        $ISORootPath = $Config.labbuilderconfig.settings.fullconfigpath
    }
    else
    {
        if (-not [System.IO.Path]::IsPathRooted($ISORootPath))
        {
            $ISORootPath = Join-Path `
                -Path $Config.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $ISORootPath
        }
    }
    if (-not (Test-Path -Path $ISORootPath -Type Container))
    {
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDISORootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                -f $ISORootPath)
        }
        ThrowException @ExceptionParameters
    }

    # Determine the VHDRootPath where the VHD files should be put
    # If no path is specified then look in the same path as the config
    # If a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $VHDRootPath = $Config.labbuilderconfig.TemplateVHDs.VHDPath
    if (-not $VHDRootPath)
    {
        $VHDRootPath = $Config.labbuilderconfig.settings.fullconfigpath
    }
    else
    {
        if (-not [System.IO.Path]::IsPathRooted($VHDRootPath))
        {
            $VHDRootPath = Join-Path `
                -Path $Config.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VHDRootPath
        }
    }
    if (-not (Test-Path -Path $VHDRootPath -Type Container))
    {
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDRootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                -f $VHDRootPath)
        }
        ThrowException @ExceptionParameters
    }

    $TemplatePrefix = $Config.labbuilderconfig.templatevhds.prefix

    # Read the list of templateVHD from the configuration file
    $TemplateVHDs = $Config.labbuilderconfig.SelectNodes('templatevhds').templatevhd
    [System.Collections.Hashtable[]] $VMTemplateVHDs = @()
    foreach ($TemplateVHD in $TemplateVHDs)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'templatevhd' as the name.
        $Name = $TemplateVHD.Name
        if (($Name -eq 'TemplateVHD') `
            -or ([String]::IsNullOrWhiteSpace($Name)))
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDNameError)
            }
            ThrowException @ExceptionParameters
        } # If
        
        # Get the ISO Path
        [String] $ISOPath = $TemplateVHD.ISO
        if (-not $ISOPath)
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDISOPathError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDISOPathError `
                    -f $TemplateVHD.Name)
            }
            ThrowException @ExceptionParameters
        }

        # Adjust the ISO Path if required
        if (-not [System.IO.Path]::IsPathRooted($ISOPath))
        {
            $ISOPath = Join-Path `
                -Path $ISORootPath `
                -ChildPath $ISOPath
        }
        
        # Does the ISO Exist?
        if (-not (Test-Path -Path $ISOPath))
        {
            $URL = $TemplateVHD.URL
            if ($URL)
            {
                Write-Host `
                    -ForegroundColor Yellow `
                    -Object $($LocalizedData.ISONotFoundDownloadURLMessage `
                        -f $TemplateVHD.Name,$ISOPath,$URL)
            }
            $ExceptionParameters = @{
                errorId = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                    -f $TemplateVHD.Name,$ISOPath)
            }
            ThrowException @ExceptionParameters            
        }
        
        # Get the VHD Path
        [String] $VHDPath = $TemplateVHD.VHD
        if (-not $VHDPath)
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDPathError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDPathError `
                    -f $TemplateVHD.Name)
            }
            ThrowException @ExceptionParameters
        }

        # Adjust the VHD Path if required
        if (-not [System.IO.Path]::IsPathRooted($VHDPath))
        {
            $VHDPath = Join-Path `
                -Path $VHDRootPath `
                -ChildPath $VHDPath
        }
        
        # Add the template prefix to the VHD name.
        if ([String]::IsNullOrWhitespace($TemplatePrefix))
        {
             $VHDPath = Join-Path `
                -Path (Split-Path -Path $VHDPath)`
                -ChildPath ("$TemplatePrefix$(Split-Path -Path $VHDPath -Leaf)")
        }
        
        # Get the Template OS Type 
        [String] $OSType = 'Server'
        if ($TemplateVHD.OSType)
        {
            $OSType = $TemplateVHD.OSType
        } # If
        if ($OSType -notin @('Server','Client','Nano') )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDOSTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDOSTypeError `
                    -f $TemplateVHD.Name,$OSType)
            }
            ThrowException @ExceptionParameters            
        }

		# Get the Template Wim Image to use
        $Edition = $null
        if ($TemplateVHD.Edition)
        {
            $Edition = $TemplateVHD.Edition
        } # If

        # Get the Template VHD Format 
        [String] $VHDFormat = 'VHDX'
        if ($TemplateVHD.VHDFormat)
        {
            $VHDFormat = $TemplateVHD.VHDFormat
        } # If
        if ($VHDFormat -notin @('VHDx','VHD') )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDVHDFormatError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDFormatError `
                    -f $TemplateVHD.Name,$VHDFormat)
            }
            ThrowException @ExceptionParameters            
        }

        # Get the Template VHD Type 
        [String] $VHDType = 'Dynamic'
        if ($TemplateVHD.VHDType)
        {
            $VHDType = $TemplateVHD.VHDType
        } # If
        if ($VHDType -notin @('Dynamic','Fixed') )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDVHDTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDTypeError `
                    -f $TemplateVHD.Name,$VHDType)
            }
            ThrowException @ExceptionParameters            
        }
        
        # Get the disk size if provided
        [Int64] $Size = 25GB
        if ($TemplateVHD.VHDSize)
        {
            $VHDSize = (Invoke-Expression $TemplateVHD.VHDSize)         
        }

        # Get the Template VM Generation 
        [int] $Generation = 2
        if ($TemplateVHD.Generation)
        {
            $Generation = $TemplateVHD.Generation
        } # If
        if ($Generation -notin @(1,2) )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDGenerationError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDGenerationError `
                    -f $TemplateVHD.Name,$Generation)
            }
            ThrowException @ExceptionParameters            
        }

        # Get the Template Packages
        if ($TemplateVHD.packages)
        {
            $Packages = $TemplateVHD.Packages
        } # If

        # Get the Template Features
        if ($TemplateVHD.features)
        {
            $Features = $TemplateVHD.Features
        } # If

		# Add template VHD to the list
            $VMTemplateVHDs += @{
                Name = $Name;
                ISOPath = $ISOPath;
                VHDPath = $VHDPath;
                OSType = $OSType;
                Edition = $Edition;
                Generation = $Generation;
                VHDFormat = $VHDFormat;
                VHDType = $VHDType;
                VHDSize = $VHDSize;
                Packages = $Packages;
                Features = $Features;
            }
     } # Foreach
    Return $VMTemplateVHDs
} # Get-LabVMTemplateVHD
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
	Scans through a list of VM Template VHDs and creates them from the ISO if missing.
.DESCRIPTION
	This function will take a list of VM Template VHDs from a configuration file or it will
    extract the list itself if it is not provided and ensure that each VHD file is available.
    
    If the VHD file is not available then it will attempt to create it from the ISO.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER VMTemplateVHDs
   The array of VMTemplateVHDs pulled from the Lab Configuration file using Get-LabVMTemplateVHD
   
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config
   Initialize-LabVMTemplateVHD -Config $Config -VMTemplateVHDs $VMTemplateVHDs
   Loads a Lab Builder configuration and pulls the array of VM Template VHDs from it and then
   ensures all the VHDs are available.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Initialize-LabVMTemplateVHD -Config $Config
   Loads a Lab Builder configuration and then ensures VM Template VHDs all the VHDs are available.
.OUTPUTS
    None. 
#>
function Initialize-LabVMTemplateVHD
{
   param
   (
        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

	    [System.Collections.Hashtable[]] $VMTemplateVHDs
    )

    # If VMTeplateVHDs array not passed, pull it from config.
    if (-not $VMTemplateVHDs)
    {
        $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config        
    }

    # If there are no VMTemplateVHDs just return
    if ($VMTemplateVHDs -eq $null)
    {
        return
    }
    
    [String] $LabPath = $Config.labbuilderconfig.settings.labpath

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [String] $Name = $VMTemplateVHD.Name
        [String] $VHDPath = $VMTemplateVHD.VHDPath
        
        if (Test-Path -Path ($VHDPath))
        {
            # The SourceVHD already exists
            Write-Verbose -Message ($LocalizedData.SkipVMTemplateVHDFileMessage `
                -f $Name,$VHDPath)

            continue
        }
        
        # Create the VHD
        Write-Verbose -Message ($LocalizedData.CreatingVMTemplateVHDMessage `
            -f $Name,$VHDPath)
            
        # Check the ISO exists.
        [String] $ISOPath = $VMTemplateVHD.ISOPath
        if (-not (Test-Path -Path $ISOPath))
        {
            $ExceptionParameters = @{
                errorId = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                    -f $Name,$ISOPath)
            }
            ThrowException @ExceptionParameters            
        }
        
        # Mount the ISO so we can read the files.
        Write-Verbose -Message ($LocalizedData.MountingVMTemplateVHDISOMessage `
                -f $Name,$ISOPath)
                
        $null = Mount-DiskImage `
            -ImagePath $ISOPath `
            -StorageType ISO `
            -Access Readonly
    
        $DiskImage = Get-DiskImage -ImagePath $ISOPath
        [String] $DriveLetter = ( Get-Volume -DiskImage $DiskImage ).DriveLetter
        [String] $ISODrive = "$([string]$DriveLetter):"

        # Determine the path to the WIM
        [String] $SourcePath = "$ISODrive\Sources\Install.WIM"
        if ($VMTemplateVHD.OSType -eq 'Nano')
        {
            $SourcePath = "$ISODrive\Nanoserver\NanoServer.WIM"
        }

        # This will have to change depending on the version
        # of Convert-WindowsImage being used. 
        [String] $VHDFormat = $VMTemplateVHD.VHDFormat       
        [String] $VHDType = $VMTemplateVHD.VHDType       
        [String] $VHDDiskLayout = 'UEFI'
        if ($VMTemplateVHD.Generation -eq 1)
        {
            $VHDDiskLayout = 'BIOS'
        }

        [String] $Edition = $VMTemplateVHD.Edition
        # If edition is not set then use Get-WindowsImage to get the name
        # of the first image in the WIM.
        if ([String]::IsNullOrWhiteSpace($Edition))
        {
            $Edition = (Get-WindowsImage `
                -ImagePath $SourcePath `
                -Index 1).ImageName
        }

        $ConvertParams = @{
            sourcepath = $SourcePath
            vhdpath = $VHDpath
            vhdformat = $VHDFormat
            # vhdtype = $VHDType
            edition = $Edition
            disklayout = $VHDDiskLayout
            erroraction = 'Stop'
        }
        
        # Set the size
        if ($VMTemplateVHD.VHDSize -ne $null)
        {
            $ConvertParams += @{
                sizebytes = $VMTemplateVHD.VHDSize
            }
        }
        
        # Are any features specified?
        if (-not [String]::IsNullOrWhitespace($VMTemplateVHD.Features))
        {
            $Features = @($VMTemplateVHD.Features -split ',')
            $ConvertParams += @{
                feature = $Features
            }
        }
        
        # Perform Nano Server package prep
        if ($VMTemplateVHD.OSType -eq 'Nano')
        {
            # Make a copy of the all the Nano packages in the VHD root folder
            # So that if any VMs need to add more packages they are accessible
            # once the ISO has been dismounted.
            [String] $VHDFolder = Split-Path `
                -Path $VHDPath `
                -Parent

            [String] $VHDPackagesFolder = Join-Path `
                -Path $VHDFolder `
                -ChildPath 'NanoServerPackages'
            
            if (-not (Test-Path -Path $VHDPackagesFolder -Type Container))
            {
                Write-Verbose -Message ($LocalizedData.CachingNanoServerPackagesMessage `
                        -f "$ISODrive\Nanoserver\Packages",$VHDPackagesFolder)
                Copy-Item `
                    -Path "$ISODrive\Nanoserver\Packages" `
                    -Destination $VHDFolder `
                    -Recurse `
                    -Force
                Rename-Item `
                    -Path "$VHDFolder\Packages" `
                    -NewName 'NanoServerPackages'
            }
                                        
            # Now specify the Nano Server packages to add.
            if (-not [String]::IsNullOrWhitespace($VMTemplateVHD.Packages))
            {
                $Packages = @()
                $NanoPackages = @($VMTemplateVHD.Packages -split ',')

                foreach ($Package in $Script:NanoServerPackageList) 
                {
                    If ($Package.Name -in $NanoPackages) 
                    {
                        $Packages += @(Join-Path -Path $LabPackagesFolder -ChildPath $Package.Filename)
                        $Packages += @(Join-Path -Path $LabPackagesFolder -ChildPath "en-us\$($Package.Filename)")
                    } # if
                } # foreach
                $ConvertParams += @{
                    package = $Packages
                }
            } # if
        } # if 
        
        Write-Verbose -Message ($LocalizedData.ConvertingWIMtoVHDMessage `
            -f $SourcePath,$VHDPath,$VHDFormat,$Edition,$VHDPartitionStyle,$VHDType)

        # Work around an issue with Convert-WindowsImage not seeing the drive
        Get-PSDrive `
            -PSProvider FileSystem  
        
        # Dot source the Convert-WindowsImage script
        # Should only be done once 
        if (-not (Test-Path -Path Function:Convert-WindowsImage))
        {
            . $Script:SupportConvertWindowsImagePath
        }
        
        # Call the Convert-WindowsImage script
        Convert-WindowsImage @ConvertParams

        # Dismount the ISO.
        Write-Verbose -Message ($LocalizedData.DismountingVMTemplateVHDISOMessage `
                -f $Name,$ISOPath)

        $null = Dismount-DiskImage `
            -ImagePath $ISOPath

    } # endfor
} # Initialize-LabVMTemplateVHD
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Gets an Array of VM Templates for a Lab configuration.
.DESCRIPTION
   Takes the provided Lab Configuration file and returns the list of Virtul Machine template machines
   that will be used to create the Virtual Machines in this lab. This list is usually passed to
   Initialize-LabVMTemplate.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER VMTemplateVHDs
   The array of VMTemplateVHDs pulled from the Lab Configuration file using Get-LabVMTemplateVHD
   
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Config $Config
   Loads a Lab Builder configuration and pulls the array of VMTemplates from it.
.OUTPUTS
   Returns an array of VM Templates.
#>
function Get-LabVMTemplate {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,
        
        [System.Collections.Hashtable[]] $VMTemplateVHDs        
    )

    [System.Collections.Hashtable[]] $VMTemplates = @()
    [String] $VHDParentPath = $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath
    
    # If VMTeplateVHDs array not passed, pull it from config.
    if (-not $VMTemplateVHDs)
    {
        $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config
    }
    
    # Get a list of all templates in the Hyper-V system matching the phrase found in the fromvm
    # config setting
    [String] $FromVM=$Config.labbuilderconfig.SelectNodes('templates').fromvm
    if ($FromVM)
    {
        $Templates = @(Get-VM -Name $FromVM)
        foreach ($Template in $Templates)
        {
            [String] $VHDFilepath = (Get-VMHardDiskDrive -VMName $Template.Name).Path
            [String] $VHDFilename = [System.IO.Path]::GetFileName($VHDFilepath)
            $VMTemplates += @{
                name = $Template.Name
                vhd = $VHDFilename
                sourcevhd = $VHDFilepath
                parentvhd = (Join-Path -Path $VHDParentPath -ChildPath $VHDFilename)
            }
        } # foreach
    } # if
    
    # Read the list of templates from the configuration file
    $Templates = $Config.labbuilderconfig.SelectNodes('templates').template
    foreach ($Template in $Templates)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'template' as the name.
        $TemplateName = $Template.Name
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
                # The template already exists - so don't add it again,
                $Found = $True
                Break
            } # If
        } # Foreach
        if (-not $Found)
        {
            # The template wasn't found in the list of templates so add it
            $VMTemplate = @{
                name = $TemplateName;
            }
            $VMTemplates += $VMTemplate
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
                $VMTemplate.sourcevhd = $VMTemplateVHD.VHDPath

                # If a VHD filename wasn't specified in the TemplateVHD
                # Just use the leaf of the SourceVHD
                if ($VMTemplateVHD.VHD)
                {
                    $VMTemplate.vhd = $VMTemplateVHD.VHD
                }
                else
                {
                    $VMTemplate.vhd = Split-Path `
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
            # If this is a relative path, add it to the config path
            if ([System.IO.Path]::IsPathRooted($SourceVHD))
            {
                $VMTemplate.sourcevhd = $SourceVHD                
            }
            else
            {
                $VMTemplate.sourcevhd = Join-Path `
                    -Path $Config.labbuilderconfig.settings.fullconfigpath `
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
            
            # If a VHD filename wasn't specified in the Template
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
            } 
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
            $VMTemplate.dynamicmemoryenabled = $Template.DynamicMemoryEnabled
        }
        elseif (-not $VMTemplate.DynamicMemoryEnabled)
        {
            $VMTemplate.dynamicmemoryenabled = 'Y'
        }
         # if
        if ($Template.ProcessorCount)
        {
            $VMTemplate.ProcessorCount = $Template.ProcessorCount
        } # if
        if ($Template.ExposeVirtualizationExtensions)
        {
            $VMTemplate.exposevirtualizationextensions = $Template.ExposeVirtualizationExtensions
        } 
        # if
        if ($Template.AdministratorPassword)
        {
            $VMTemplate.administratorpassword = $Template.AdministratorPassword
        } # if
        if ($Template.ProductKey)
        {
            $VMTemplate.productkey = $Template.ProductKey
        } # if
        if ($Template.TimeZone)
        {
            $VMTemplate.timezone = $Template.TimeZone
        } # if
        if ($Template.OSType)
        {
            $VMTemplate.ostype = $Template.OSType
        }
        elseif (-not $VMTemplate.OSType)
        {
            $VMTemplate.ostype = 'Server'
        } # if
        if ($Template.IntegrationServices)
        {
            $VMTemplate.integrationservices = $Template.IntegrationServices
        }
        else
        {
            $VMTemplate.integrationservices = $null
        } # if
        if ($Template.Packages)
        {
            $VMTemplate.packages = $Template.Packages
        }
        else
        {
            $VMTemplate.packages = $null
        } # if
    } # Foreach
    Return $VMTemplates
} # Get-LabVMTemplate
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Initializes the Virtual Machine templates used by a Lab from a provided array.
.DESCRIPTION
   Takes an array of Virtual Machine templates that were configured in the Lab Configuration
   file. The Virtual Machine templates are used to create the Virtual Machines specified in
   a Lab Configuration. The Virtual Machine template VHD files are copied to a folder where
   they will be copied to create new Virtual Machines or as parent difference disks for new
   Virtual Machines.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER VMTemplates
   The array of VM Templates pulled from the Lab Configuration file using Get-LabVMTemplate
   If not provided it will attempt to pull the list from the configuration file.
.PARAMETER VMTemplateVHDs
   The array of VM Templates pulled from the Lab Configuration file using Get-LabVMTemplate
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Config $Config
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config
   Initialize-LabVMTemplate `
    -Config $Config `
    -VMTemplates $VMTemplates `
    -VMTemplateVHDs $VMTemplateVHDs
   Initializes the Virtual Machine templates in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Initialize-LabVMTemplate -Config $Config
   Initializes the Virtual Machine templates in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Initialize-LabVMTemplate {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [System.Collections.Hashtable[]] $VMTemplates
    )
    
    # Get the VM Templates if they weren't passed
    if (-not $VMTemplates)
    {
        $VMTemplates = Get-LabVMTemplate `
            -Config $Config
    }

    [String] $LabPath = $Config.labbuilderconfig.settings.labpath
    
    # Check each Parent VHD exists in the Parent VHDs folder for the
    # Lab. If it isn't, try and copy it from the SourceVHD
    # Location.
    foreach ($VMTemplate in $VMTemplates)
    {
        if (-not (Test-Path $VMTemplate.parentvhd))
        {
            # The Parent VHD isn't in the VHD Parent folder
            # so copy it there, optimize it and mark it read-only.
            if (-not (Test-Path $VMTemplate.sourcevhd))
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
            
			Write-Verbose -Message $($LocalizedData.CopyingTemplateSourceVHDMessage `
                -f $VMTemplate.sourcevhd,$VMTemplate.parentvhd)
            Copy-Item `
                -Path $VMTemplate.sourcevhd `
                -Destination $VMTemplate.parentvhd
            Write-Verbose -Message $($LocalizedData.OptimizingParentVHDMessage `
                -f $VMTemplate.parentvhd)
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $False
            Optimize-VHD `
                -Path $VMTemplate.parentvhd `
                -Mode Full
            Write-Verbose -Message $($LocalizedData.SettingParentVHDReadonlyMessage `
                -f $VMTemplate.parentvhd)
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $True

            # If this is a Nano Server template, we need to ensure that the
            # NanoServerPackages folder is copied to our Lab folder
            if ($VMTemplate.OSType -eq 'Nano')
            {
                [String] $VHDPackagesFolder = Join-Path `
                    -Path (Split-Path -Path $VMTemplate.sourcevhd -Parent)`
                    -ChildPath 'NanoServerPackages'

                [String] $LabPackagesFolder = Join-Path `
                    -Path $LabPath `
                    -ChildPath 'NanoServerPackages'

                if (-not (Test-Path -Path $LabPackagesFolder -Type Container))
                {
                    Write-Verbose -Message ($LocalizedData.CachingNanoServerPackagesMessage `
                            -f $VHDPackagesFolder,$LabPackagesFolder)
                    Copy-Item `
                        -Path $VHDPackagesFolder `
                        -Destination $LabPath `
                        -Recurse `
                        -Force
                }
            }
        }
        Else
        {
            Write-Verbose -Message $($LocalizedData.SkipParentVHDFileMessage `
                -f $VMTemplate.Name,$VMTemplate.parentvhd)
        }
    }
} # Initialize-LabVMTemplate
####################################################################################################

####################################################################################################
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
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VMTemplates
   The array of Virtual Machine Templates pulled from the Lab Configuration file using
   Get-LabVMTemplate
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Config $Config
   Remove-LabVMTemplate -Config $Config -VMTemplates $VMTemplates
   Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Remove-LabVMTemplate -Config $Config
   Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Remove-LabVMTemplate {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [System.Collections.Hashtable[]] $VMTemplates
    )

    # Get the VM Templates if they weren't passed
    if (-not $VMTemplates)
    {
        $VMTemplates = Get-LabVMTemplate `
            -Config $Config
    }    
    foreach ($VMTemplate in $VMTemplates)
    {
        if (Test-Path $VMTemplate.parentvhd)
        {
            Set-ItemProperty -Path $VMTemplate.parentvhd -Name IsReadOnly -Value $False
            Write-Verbose -Message $($LocalizedData.DeletingParentVHDMessage `
                -f $VMTemplate.parentvhd)
            Remove-Item -Path $VMTemplate.parentvhd -Confirm:$false -Force
        }
    }
} # Remove-LabVMTemplate
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Assemble the content of the Networking DSC config file.
.DESCRIPTION
   This function creates the content that will be written to the Networking DSC Config file
   from the networking details stored in the VM object. 
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   $NetworkingDSC = Get-LabNetworkingDSCFile -Config $Config -VM $VMs[0]
   Return the Networking DSC for the first VM in the Lab c:\mylab\config.xml for DSC configuration.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.OUTPUTS
   A string containing the DSC Networking config.
#>
function Get-LabNetworkingDSCFile {
    [CmdLetBinding()]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )
    [String] $NetworkingDSCConfig = @"
Configuration Networking {
    Import-DscResource -ModuleName xNetworking -ModuleVersion 2.7.0.0  #Current as of 13-Feb-2016

"@
    [Int] $AdapterCount = 0
    foreach ($Adapter in $VM.Adapters)
    {
        $AdapterCount++
        if ($Adapter.IPv4)
        {
            if ($Adapter.IPv4.Address)
            {
$NetworkingDSCConfig += @"
    xIPAddress IPv4_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
        IPAddress      = '$($Adapter.IPv4.Address.Replace(',',"','"))'
        SubnetMask     = '$($Adapter.IPv4.SubnetMask)'
    }

"@
                if ($Adapter.IPv4.DefaultGateway)
                {
$NetworkingDSCConfig += @"
    xDefaultGatewayAddress IPv4G_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
        Address        = '$($Adapter.IPv4.DefaultGateway)'
    }

"@
                }
                Else
                {
$NetworkingDSCConfig += @"
    xDefaultGatewayAddress IPv4G_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
    }

"@
                } # If
            }
            Else
            {
$NetworkingDSCConfig += @"
    xDhcpClient IPv4DHCP_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
        State          = 'Enabled'
    }

"@

            } # If
            if ($Adapter.IPv4.DNSServer -ne $null)
            {
$NetworkingDSCConfig += @"
    xDnsServerAddress IPv4D_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
        Address        = '$($Adapter.IPv4.DNSServer.Replace(',',"','"))'
    }

"@
            } # If
        } # If
        if ($Adapter.IPv6)
        {
            if ($Adapter.IPv6.Address)
            {
$NetworkingDSCConfig += @"
    xIPAddress IPv6_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
        IPAddress      = '$($Adapter.IPv6.Address.Replace(',',"','"))'
        SubnetMask     = '$($Adapter.IPv6.SubnetMask)'
    }

"@
                if ($Adapter.IPv6.DefaultGateway)
                {
$NetworkingDSCConfig += @"
    xDefaultGatewayAddress IPv6G_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
        Address        = '$($Adapter.IPv6.DefaultGateway)'
    }

"@
                }
                Else
                {
$NetworkingDSCConfig += @"
    xDefaultGatewayAddress IPv6G_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
    }

"@
                } # If
            }
            Else
            {
$NetworkingDSCConfig += @"
    xDhcpClient IPv6DHCP_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
        State          = 'Enabled'
    }

"@

            } # If
            if ($Adapter.IPv6.DNSServer -ne $null)
            {
$NetworkingDSCConfig += @"
    xDnsServerAddress IPv6D_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
        Address        = '$($Adapter.IPv6.DNSServer.Replace(',',"','"))'
    }

"@
            } # If
        } # If
    } # Endfor
$NetworkingDSCConfig += @"
}
"@
    Return $NetworkingDSCConfig
} # Get-LabNetworkingDSCFile
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Assemble the the PowerShell commands required to create a self-signed certificate.
.DESCRIPTION
   This function creates the content that can be written into a PS1 file to create a self-signed
   certificate.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   $NetworkingDSC = Get-LabGetCertificatePs -Config $Config -VM $VMs[0]
   Return the Create Self-Signed Certificate script for the first VM in the
   Lab c:\mylab\config.xml for DSC configuration.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.OUTPUTS
   A string containing the Create Self-Signed Certificate PowerShell code.
.TODO
   Add support for using an existing certificate if one exists.
#>
function Get-LabGetCertificatePs {
    [CmdLetBinding()]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )
    [String] $CreateCertificatePs = @"
`$CertificateFriendlyName = '$($Script:DSCCertificateFriendlyName)'
`$Cert = Get-ChildItem -Path cert:\LocalMachine\My ``
    | Where-Object { `$_.FriendlyName -eq `$CertificateFriendlyName } ``
    | Select-Object -First 1
if (-not `$Cert)
{
    . `"`$(`$ENV:SystemRoot)\Setup\Scripts\New-SelfSignedCertificateEx.ps1`"
    New-SelfsignedCertificateEx ``
        -Subject 'CN=$($VM.ComputerName)' ``
        -EKU 'Document Encryption','Server Authentication','Client Authentication' ``
        -KeyUsage 'DigitalSignature, KeyEncipherment, DataEncipherment' ``
        -SAN '$($VM.ComputerName)' ``
        -FriendlyName `$CertificateFriendlyName ``
        -Exportable ``
        -StoreLocation 'LocalMachine' ``
        -StoreName 'My' ``
        -KeyLength $($Script:SelfSignedCertKeyLength) ``
        -ProviderName '$($Script:SelfSignedCertProviderName)' ``
        -AlgorithmName $($Script:SelfSignedCertAlgorithmName) ``
        -SignatureAlgorithm $($Script:SelfSignedCertSignatureAlgorithm)
    # There is a slight delay before new cert shows up in Cert:
    # So wait for it to show.
    While (-not `$Cert)
    {
        `$Cert = Get-ChildItem -Path cert:\LocalMachine\My ``
            | Where-Object { `$_.FriendlyName -eq `$CertificateFriendlyName }
    }
}
Export-Certificate ``
    -Type CERT ``
    -Cert `$Cert ``
    -FilePath `"`$(`$ENV:SystemRoot)\$Script:DSCEncryptionCert`"
"@
    Return $CreateCertificatePs
} # Get-LabGetCertificatePs
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Gets an Array of VMs from a Lab configuration.
.DESCRIPTION
   Takes the provided Lab Configuration file and returns the list of Virtul Machines
   that will be created in this lab. This list is usually passed to Initialize-LabVM.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER VMTemplates
   Contains the array of VM Templates returned by Get-LabVMTemplate from this configuration.
   If not provided it will attempt to pull the list from the configuration file.
.PARAMETER Switches
   Contains the array of Virtual Switches returned by Get-LabSwitch from this configuration.
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Config $Config
   $Switches = Get-LabSwitch -Config $Config
   $VMs = Get-LabVM -Config $Config -VMTemplates $VMTemplates -Switches $Switches
   Loads a Lab Builder configuration and pulls the array of VMs from it.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Loads a Lab Builder configuration and pulls the array of VMs from it.
.OUTPUTS
   Returns an array of VMs.
#>
function Get-LabVM {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]] $VMTemplates,

        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]] $Switches
    )

    # If the list of VMTemplates was not passed so pull it
    if (-not $VMTemplates)
    {
        $VMTemplates = Get-LabVMTemplate -Config $Config
    }

    # If the list of Switches was not passed so pull it
    if (-not $Switches)
    {
        $Switches = Get-LabSwitch -Config $Config
    }

    [System.Collections.Hashtable[]] $LabVMs = @()
    [String] $VHDParentPath = $Config.labbuilderconfig.settings.vhdparentpath
    [String] $LabPath = $Config.labbuilderconfig.settings.labpath
    $VMs = $Config.labbuilderconfig.SelectNodes('vms').vm

    foreach ($VM in $VMs) 
	{
        if ($VM.Name -eq 'VM')
		{
            $ExceptionParameters = @{
                errorId = 'VMNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMNameError)
            }
            ThrowException @ExceptionParameters
        } # If
        if (-not $VM.Template) 
		{
            $ExceptionParameters = @{
                errorId = 'VMTemplateNameEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                    -f $VM.name)
            }
            ThrowException @ExceptionParameters
        } # If

        # Find the template that this VM uses and get the VHD Path
        [String] $ParentVHDPath =''
        [Boolean] $Found = $false
        foreach ($VMTemplate in $VMTemplates) {
            if ($VMTemplate.Name -eq $VM.Template) {
                $ParentVHDPath = $VMTemplate.parentVHD
                $Found = $true
                Break
            } # If
        } # Foreach

        if (-not $Found) 
		{
            $ExceptionParameters = @{
                errorId = 'VMTemplateNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                    -f $VM.name,$VM.template)
            }
            ThrowException @ExceptionParameters
        } # If

        # Assemble the Network adapters that this VM will use
        [System.Collections.Hashtable[]] $VMAdapters = @()
        [Int] $AdapterCount = 0
        foreach ($VMAdapter in $VM.Adapters.Adapter) 
		{
            $AdapterCount++
            if ($VMAdapter.Name -eq 'adapter') 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterNameError `
                        -f $VM.name)
                }
                ThrowException @ExceptionParameters
            }
            if (-not $VMAdapter.SwitchName) 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                        -f $VM.name,$VMAdapter.name)
                }
                ThrowException @ExceptionParameters
            }
            # Check the switch is in the switch list
            [Boolean] $Found = $False
            foreach ($Switch in $Switches) 
			{
                if ($Switch.Name -eq $VMAdapter.SwitchName) 
				{
                    # The switch is found in the switch list - record the VLAN (if there is one)
                    $Found = $True
                    $SwitchVLan = $Switch.Vlan
                    Break
                } # If
            } # Foreach
            if (-not $Found) 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNotFoundError `
                        -f $VM.name,$VMAdapter.name,$VMAdapter.switchname)
                }
                ThrowException @ExceptionParameters
            } # If
            
            # Figure out the VLan - If defined in the VM use it, otherwise use the one defined in the Switch, otherwise keep blank.
            [String] $VLan = $VMAdapter.VLan
            if (-not $VLan) 
			{
                $VLan = $SwitchVLan
            } # If
            
            [String] $MACAddressSpoofing = 'Off'
            if ($VMAdapter.macaddressspoofing -eq 'On') 
			{
                $MACAddressSpoofing = 'On'
            }
            
            # Have we got any IPv4 settings?
            [System.Collections.Hashtable] $IPv4 = @{}
            if ($VMAdapter.IPv4) 
			{
                $IPv4 = @{
                    Address = $VMAdapter.IPv4.Address;
                    defaultgateway = $VMAdapter.IPv4.DefaultGateway;
                    subnetmask = $VMAdapter.IPv4.SubnetMask;
                    dnsserver = $VMAdapter.IPv4.DNSServer
                }
            }

            # Have we got any IPv6 settings?
            [System.Collections.Hashtable] $IPv6 = @{}

            if ($VMAdapter.IPv6) 
			{
                $IPv6 = @{
                    Address = $VMAdapter.IPv6.Address;
                    defaultgateway = $VMAdapter.IPv6.DefaultGateway;
                    subnetmask = $VMAdapter.IPv6.SubnetMask;
                    dnsserver = $VMAdapter.IPv6.DNSServer
                }
            }

            $VMAdapters += @{
                Name = $VMAdapter.Name;
                SwitchName = $VMAdapter.SwitchName;
                MACAddress = $VMAdapter.macaddress;
                MACAddressSpoofing = $MACAddressSpoofing;
                VLan = $VLan;
                IPv4 = $IPv4;
                IPv6 = $IPv6
            }
        } # Foreach

        # Assemble the Data Disks this VM will use
        [System.Collections.Hashtable[]] $DataVhds = @()
        [Int] $DataVhdCount = 0
        foreach ($VMDataVhd in $VM.DataVhds.DataVhd)
        {
            $DataVhdCount++
            # Load all the VHD properties and check they are valid
            [String] $Vhd = $VMDataVhd.VHD
            if (! $Vhd)
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                        -f $VM.name)
                }
                ThrowException @ExceptionParameters
            }
            # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
            # if it doesn't contain a root (e.g. c:\)
            if (! [System.IO.Path]::IsPathRooted($Vhd))
            {
                $Vhd = Join-Path -Path $LabPath -ChildPath "$($VM.Name)\Virtual Hard Disks\$Vhd"
            }
            
            # Does the VHD already exist?
            $Exists = Test-Path -Path $Vhd

            # Get the Parent VHD and check it exists if passed
            Remove-Variable -Name ParentVhd -ErrorAction SilentlyContinue
            if ($VMDataVhd.ParentVHD)
            {
                [String] $ParentVhd = $VMDataVhd.ParentVHD
                # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                # if it doesn't contain a root (e.g. c:\)
                if (! [System.IO.Path]::IsPathRooted($ParentVhd))
                {
                    $ParentVhd = Join-Path `
                        -Path $Config.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $ParentVhd
                }
                if (-not (Test-Path -Path $ParentVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskParentVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                            -f $VM.name,$ParentVhd)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Get the Source VHD and check it exists if passed
            Remove-Variable -Name SourceVhd -ErrorAction SilentlyContinue
            if ($VMDataVhd.SourceVHD)
            {
                [String] $SourceVhd = $VMDataVhd.SourceVHD
                # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                # if it doesn't contain a root (e.g. c:\)
                if (! [System.IO.Path]::IsPathRooted($SourceVhd))
                {
                    $SourceVhd = Join-Path `
                        -Path $Config.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $SourceVhd
                }
                if (! (Test-Path -Path $SourceVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                            -f $VM.name,$SourceVhd)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Get the disk size if provided
            Remove-Variable -Name Size -ErrorAction SilentlyContinue
            if ($VMDataVhd.Size)
            {
                $Size = (Invoke-Expression $VMDataVhd.size)         
            }

            [Boolean] $Shared = ($VMDataVhd.shared -eq 'Y')

            # Validate the data disk type specified
            Remove-Variable -Name Type -ErrorAction SilentlyContinue
            if ($VMDataVhd.type)
            {
                [String] $Type = $VMDataVhd.type
                switch ($type)
                {
                    'fixed'
                    {
                        break;
                    }
                    'dynamic'
                    {
                        break;
                    }
                    'differencing'
                    {
                        if (-not $ParentVhd)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDMissingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                                    -f $VM.name)
                            }
                            ThrowException @ExceptionParameters
                        }
                        if ($Shared)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskSharedDifferencingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                                    -f $VM.Name,$VHD)
                            }
                            ThrowException @ExceptionParameters                            
                        }
                    }
                    Default
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskUnknownTypeError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                                -f $VM.Name,$VHD,$type)
                        }
                        ThrowException @ExceptionParameters
                    }
                }
            }

            # Get the Support Persistent Reservations
            [Boolean] $SupportPR = ($VMDataVhd.supportPR -eq 'Y')
            if ($SupportPR -and -not $Shared)
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSupportPRError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSupportPRError `
                        -f $VM.Name,$VHD)
                }
                ThrowException @ExceptionParameters
            }

            # Get Partition Style for the new disk.
            Remove-Variable -Name PartitionStyle -ErrorAction SilentlyContinue
            if ($VMDataVhd.partitionstyle)
            {
                [String] $PartitionStyle = $VMDataVhd.partitionstyle
                if ($PartitionStyle -and ($PartitionStyle -notin 'MBR','GPT'))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskPartitionStyleError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskPartitionStyleError `
                            -f $VM.Name,$VHD,$PartitionStyle)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Get file system for the new disk.
            Remove-Variable -Name FileSystem -ErrorAction SilentlyContinue
            if ($VMDataVhd.filesystem)
            {
                [String] $FileSystem = $VMDataVhd.filesystem
                if ($FileSystem -notin 'FAT','FAT32','exFAT','NTFS','ReFS')
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskFileSystemError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskFileSystemError `
                            -f $VM.Name,$VHD,$FileSystem)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Has a file system label been provided?
            Remove-Variable -Name FileSystemLabel -ErrorAction SilentlyContinue
            if ($VMDataVhd.filesystemlabel)
            {
                [String] $FileSystemLabel = $VMDataVhd.filesystemlabel
            }
            
            # If the Partition Style, File System or File System Label has been
            # provided then ensure Partition Style and File System are set.
            if ($PartitionStyle -or $FileSystem -or $FileSystemLabel)
            {
                if (-not $PartitionStyle)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskPartitionStyleMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                            -f $VM.Name,$VHD)
                    }
                    ThrowException @ExceptionParameters
                }
                if (-not $FileSystem)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskFileSystemMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                            -f $VM.Name,$VHD)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Get the Folder to copy and check it exists if passed
            Remove-Variable -Name CopyFolders -ErrorAction SilentlyContinue
            if ($VMDataVhd.CopyFolders)
            {
                [String]$CopyFolders = $VMDataVhd.CopyFolders
                foreach ($CopyFolder in ($CopyFolders -Split ','))
                {
                    # Adjust the path to be relative to the configuration folder 
                    # if it doesn't contain a root (e.g. c:\)
                    if (-not [System.IO.Path]::IsPathRooted($CopyFolder))
                    {
                        $CopyFolder = Join-Path `
                            -Path $Config.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $CopyFolder
                    }
                    if (-not (Test-Path -Path $CopyFolder -Type Container))
                    {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskCopyFolderMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskCopyFolderMissingError `
                            -f $VM.Name,$VHD,$CopyFolder)
                        }
                    ThrowException @ExceptionParameters 
                    }                   
                }
            } 
            
            # Should the Source VHD be moved rather than copied
            Remove-Variable -Name MoveSourceVHD -ErrorAction SilentlyContinue
            if ($VMDataVhd.MoveSourceVHD)
            {
                [Boolean] $MoveSourceVHD = ($VMDataVhd.MoveSourceVHD -eq 'Y')
                if (! $SourceVHD)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDIfMoveError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                            -f $VM.Name,$VHD)
                    }
                    ThrowException @ExceptionParameters                        
                }
            }

            # If the data disk file doesn't exist then some basic parameters MUST be provided
            if (-not $Exists `
                -and ((( $Type -notin ('fixed','dynamic','differencing') ) -or $Size -eq $null -or $Size -eq 0 ) `
                -and -not $SourceVhd ))
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $VM.Name,$VHD)
                }
                ThrowException @ExceptionParameters                    
            }
                        
            # Write the values to the array
            $DataVhds += @{
                vhd = $Vhd;
                type = $Type;
                size = $Size
                sourcevhd = $SourceVHD;
                parentvhd = $ParentVHD;
                shared = $Shared;
                supportPR = $SupportPR;
                moveSourceVHD = $MoveSourceVHD;
                copyfolders = $CopyFolders;
                partitionstyle = $PartitionStyle;
                filesystem = $FileSystem;
                filesystemlabel = $FileSystemLabel;
            }
        } # Foreach

        # Does the VM have an Unattend file specified?
        [String] $UnattendFile = ''
        if ($VM.UnattendFile) 
		{
            $UnattendFile = Join-Path `
                -Path $Config.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.UnattendFile
            if (-not (Test-Path $UnattendFile)) 
			{
                $ExceptionParameters = @{
                    errorId = 'UnattendFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnattendFileMissingError `
                        -f $VM.name,$UnattendFile)
                }
                ThrowException @ExceptionParameters
            } # If
        } # If
        
        # Does the VM specify a Setup Complete Script?
        [String] $SetupComplete = ''
        if ($VM.SetupComplete) 
		{
            $SetupComplete = Join-Path `
                -Path $Config.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.SetupComplete
            if ([System.IO.Path]::GetExtension($SetupComplete).ToLower() -notin '.ps1','.cmd' )
            {
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                        -f $VM.name,$SetupComplete)
                }
                ThrowException @ExceptionParameters
            } # If
            if (-not (Test-Path $SetupComplete))
            {
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                        -f $VM.name,$SetupComplete)
                }
                ThrowException @ExceptionParameters
            } # If
        } # If

        # Load the DSC Config File setting and check it
        [String] $DSCConfigFile = ''
        if ($VM.DSC.ConfigFile) 
		{
            [String] $DSCLibraryPath = $Config.labbuilderconfig.settings.dsclibrarypath
            if ($DSCLibraryPath)
            {
                if ([System.IO.Path]::IsPathRooted($DSCLibraryPath))
                {
                    $DSCConfigFile = Join-Path `
                        -Path $DSCLibraryPath `
                        -ChildPath $VM.DSC.ConfigFile
                }
                else
                {
                    $DSCConfigFile = Join-Path `
                        -Path $Config.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $DSCLibraryPath
                    $DSCConfigFile = Join-Path `
                        -Path $DSCConfigFile `
                        -ChildPath $VM.DSC.ConfigFile
                }
            }
            if ([System.IO.Path]::GetExtension($DSCConfigFile).ToLower() -ne '.ps1' )
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                        -f $VM.name,$DSCConfigFile)
                }
                ThrowException @ExceptionParameters
            }

            if (-not (Test-Path $DSCConfigFile))
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                        -f $VM.name,$DSCConfigFile)
                }
                ThrowException @ExceptionParameters
            }
            if (-not $VM.DSC.ConfigName)
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                        -f $VM.name)
                }
                ThrowException @ExceptionParameters
            }
        }
        
        # Load the DSC Parameters
        [String] $DSCParameters = ''
        if ($VM.DSC.Parameters)
        {
            # Correct any LFs into CRLFs to ensure the new line format is the same when
            # pulled from the XML.
            $DSCParameters = ($VM.DSC.Parameters -replace "`r`n","`n") -replace "`n","`r`n"
        } # if

        # Load the DSC Parameters
        [Boolean] $DSCLogging = $False
        if ($VM.DSC.Logging -eq 'Y')
        {
            $DSCLogging = $True
        } # if

        # Get the Memory Startup Bytes (from the template or VM)
        [Int64] $MemoryStartupBytes = 1GB
        if ($VM.memorystartupbytes)
        {
            $MemoryStartupBytes = (Invoke-Expression $VM.memorystartupbytes)
        }
        elseif ($VMTemplate.memorystartupbytes)
        {
            $MemoryStartupBytes = $VMTemplate.memorystartupbytes
        } # if

        # Get the Dynamic Memory Enabled flag
        [String] $DynamicMemoryEnabled = ''
        if ($VM.DynamicMemoryEnabled)
        {
            $DynamicMemoryEnabled = $VM.DynamicMemoryEnabled
        }        
        elseif ($VMTemplate.DynamicMemoryEnabled)
        {
            $DynamicMemoryEnabled = $VMTemplate.DynamicMemoryEnabled
        } #if
        
        # Get the Memory Startup Bytes (from the template or VM)
        [Int] $ProcessorCount = 1
        if ($VM.processorcount) 
		{
            $ProcessorCount = (Invoke-Expression $VM.processorcount)
        }
        elseif ($VMTemplate.processorcount) 
		{
            $ProcessorCount = $VMTemplate.processorcount
        } # if

        # Get the Expose Virtualization Extensions flag
        [String] $ExposeVirtualizationExtensions = $null
        if ($VM.ExposeVirtualizationExtensions)
        {
            $ExposeVirtualizationExtensions = $VM.ExposeVirtualizationExtensions
        }
        elseif ($VMTemplate.ExposeVirtualizationExtensions)
		{
            $ExposeVirtualizationExtensions=$VMTemplate.ExposeVirtualizationExtensions
        } # if
        
        # Get the Integration Services flags
        if ($VM.IntegrationServices -ne $null)
        {
            $IntegrationServices = $VM.IntegrationServices
        } 
        elseif ($VMTemplate.IntegrationServices -ne $null)
        {
            $IntegrationServices = $VMTemplate.IntegrationServices
        } # if
        
        # Get the Administrator password (from the template or VM)
        [String] $AdministratorPassword = ''
        if ($VM.administratorpassword) 
		{
            $AdministratorPassword = $VM.administratorpassword
        }
        elseif ($VMTemplate.administratorpassword) 
		{
            $AdministratorPassword = $VMTemplate.administratorpassword
        } # if

        # Get the Product Key (from the template or VM)
        [String] $ProductKey = ''
        if ($VM.productkey) 
		{
            $ProductKey = $VM.productkey
        }
        elseif ($VMTemplate.productkey) 
		{
            $ProductKey = $VMTemplate.productkey
        } # If

        # Get the Timezone (from the template or VM)
        [String] $Timezone = 'Pacific Standard Time'
        if ($VM.timezone) 
		{
            $Timezone = $VM.timezone
        }
        elseif ($VMTemplate.timezone) 
		{
            $Timezone = $VMTemplate.timezone
        } # If

        # Get the OS Type
        [String] $OSType = 'Server'
        if ($VM.ostype) 
		{
            $OSType = $VM.ostype
        }
        elseif ($VMTemplate.ostype) 
		{
            $OSType = $VMTemplate.ostype
        } # if 

        # Get the Packages
        [String] $Packages = $null
        if ($VM.packages) 
		{
            $Packages = $VM.packages
        }
        elseif ($VMTemplate.packages) 
		{
            $Packages = $VMTemplate.packages
        } # if 

        # Do we have any MSU files that are listed as needing to be applied to the OS before
        # first boot up?
        [String[]] $InstallMSU = @()
        foreach ($Update in $VM.Install.MSU) 
		{
            $InstallMSU += $Update.URL
        } # Foreach

        $LabVMs += @{
            Name = $VM.name;
            ComputerName = $VM.ComputerName;
            Template = $VM.template;
            ParentVHD = $ParentVHDPath;
            UseDifferencingDisk = $VM.usedifferencingbootdisk;
            MemoryStartupBytes = $MemoryStartupBytes;
            DynamicMemoryEnabled = $DynamicMemoryEnabled;
            ProcessorCount = $ProcessorCount;
            ExposeVirtualizationExtensions = $ExposeVirtualizationExtensions;
            IntegrationServices = $IntegrationServices;
            AdministratorPassword = $AdministratorPassword;
            ProductKey = $ProductKey;
            TimeZone =$Timezone;
            Adapters = $VMAdapters;
            DataVHDs = $DataVHDs;
            UnattendFile = $UnattendFile;
            SetupComplete = $SetupComplete;
            DSCConfigFile = $DSCConfigFile;
            DSCConfigName = $VM.DSC.ConfigName;
            DSCParameters = $DSCParameters;
            DSCLogging = $DSCLogging;
            OSType = $OSType;
            Packages = $Packages;
            InstallMSU = $InstallMSU;
            VMRootPath = (Join-Path -Path $LabPath -ChildPath $VM.name);
            LabBuilderFilesPath = (Join-Path -Path $LabPath -ChildPath "$($VM.name)\LabBuilder Files");
        }
    } # Foreach        

    Return $LabVMs
} # Get-LabVM
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Download the existing self-signed certificate from a running VM.
.DESCRIPTION
   This function uses PS Remoting to connect to a running VM and download the an existing
   Self-Signed certificate file that was written to the c:\windows folder of the guest operating
   system by the SetupComplete.ps1 script on the. The certificate will be downloaded to the VM's
   Labbuilder files folder.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.PARAMETER Timeout
   The maximum amount of time that this function can take to download the certificate.
   If the timeout is reached before the process is complete an error will be thrown.
   The timeout defaults to 300 seconds.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Get-LabVMelfSignedCert -Config $Config -VM $VMs[0]
   Downloads the existing Self-signed certificate for the VM to the Labbuilder files folder of the
   VM.
.OUTPUTS
   The path to the certificate file that was downloaded.
#>
function Get-LabVMelfSignedCert
{
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM,

        [Int] $Timeout = 300
    )
    [String] $LabPath = $Config.labbuilderconfig.SelectNodes('settings').labpath
    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False

    # Load path variables
    [String] $VMRootPath = $VM.VMRootPath

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    while ((-not $Complete) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
    {
        $Session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue
        
        # Failed to connnect to the VM
        if (! $Session)
        {
            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
            return
        }

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $Complete))
        {
            # We connected OK - download the Certificate file
            while ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    $null = Copy-Item `
                        -Path "c:\windows\$Script:DSCEncryptionCert" `
                        -Destination $VMLabBuilderFiles `
                        -FromSession $Session `
                        -ErrorAction Stop
                    $Complete = $True
                }
                catch
                {
                    Write-Verbose -Message $($LocalizedData.WaitingForCertificateMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)
                        
                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # Try
            } # While
        } # If

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $Complete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            if ($Session)
            {
                Remove-PSSession -Session $Session
            }

            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
        }

        # Close the Session if it is opened and the download is complete
        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and ($Complete))
        {
            Remove-PSSession -Session $Session
        } # If
    } # While
    return (Get-Item -Path "$VMLabBuilderFiles\$($Script:DSCEncryptionCert)")        
} # Get-LabVMelfSignedCert
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Generate and download a new credential encryption certificate from a running VM.
.DESCRIPTION
   This function uses PS Remoting to connect to a running VM and upload the GetDSCEncryptionCert.ps1
   script and then run it. This wil create a new self-signed certificate that is written to the
   c:\windows folder of the guest operating system. The certificate will be downloaded to the VM's
   Labbuilder files folder.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.PARAMETER Timeout
   The maximum amount of time that this function can take to download the certificate.
   If the timeout is reached before the process is complete an error will be thrown.
   The timeout defaults to 300 seconds.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   New-LabVMSelfSignedCert -Config $Config -VM $VMs[0]
   Causes a new self-signed certificate on the VM and download it to the Labbuilder files folder
   of th VM.
.OUTPUTS
   The path to the certificate file that was downloaded.
#>
function New-LabVMSelfSignedCert
{
    [CmdLetBinding()]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM,

        [Int] $Timeout = 300
    )
    [DateTime] $StartTime = Get-Date
    [String] $LabPath = $Config.labbuilderconfig.SelectNodes('settings').labpath
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False

    # Load path variables
    [String] $VMRootPath = $VM.VMRootPath

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    # Ensure the certificate generation script has been created
    [String] $GetCertPs = Get-LabGetCertificatePs `
        -Config $Config `
        -VM $VM
        
    $null = Set-Content `
        -Path "$VMLabBuilderFiles\GetDSCEncryptionCert.ps1" `
        -Value $GetCertPs `
        -Force

    while ((-not $Complete) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
    {
        $Session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        # Failed to connnect to the VM
        if (! $Session)
        {
            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
            return
        }

        $Complete = $False

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $Complete))
        {
            # We connected OK - Upload the script
            while ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    Copy-Item `
                        -Path "$VMLabBuilderFiles\GetDSCEncryptionCert.ps1" `
                        -Destination 'c:\windows\setup\scripts\' `
                        -ToSession $Session `
                        -Force `
                        -ErrorAction Stop
                    $Complete = $True
                }
                catch
                {
                    Write-Verbose -Message $($LocalizedData.FailedToUploadCertificateCreateScriptMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # Try
            } # While
        } # If
        
        $Complete = $False

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $Complete))
        {
            # Script uploaded, run it
            while ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    Invoke-Command -Session $Session -ScriptBlock {
                        C:\Windows\Setup\Scripts\GetDSCEncryptionCert.ps1
                    }
                    $Complete = $True
                }
                catch
                {
                    Write-Verbose -Message $($LocalizedData.FailedToExecuteCertificateCreateScriptMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # Try
            } # While
        } # If

        $Complete = $False

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $Complete))
        {
            # Now download the Certificate
            while ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try {
                    $null = Copy-Item `
                        -Path "c:\windows\$($Script:DSCEncryptionCert)" `
                        -Destination $VMLabBuilderFiles `
                        -FromSession $Session `
                        -ErrorAction Stop
                    $Complete = $True
                }
                catch
                {
                    Write-Verbose -Message $($LocalizedData.FailedToDownloadCertificateMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # Try
            } # While
        } # If

        # If the process didn't complete and we're out of time throw an exception
        if ((-not $Complete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            if ($Session)
            {
                Remove-PSSession -Session $Session
            }

            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
        }

        # Close the Session if it is opened and the download is complete
        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and ($Complete))
        {
            Remove-PSSession -Session $Session
        } # If
    } # While
    return (Get-Item -Path "$VMLabBuilderFiles\$($Script:DSCEncryptionCert)")
} # New-LabVMSelfSignedCert
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Gets the Management IP Address for a running Lab VM.
.DESCRIPTION
   This function will return the IPv4 address assigned to the network adapter that
   is connected to the Management switch for the specified VM. The VM must be
   running, otherwise an error will be thrown.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   $IPAddress = Get-LabVMManagementIPAddress -Config $Config -VM $VM[0]
.OUTPUTS
   The IP Managment IP Address.
#>
function Get-LabVMManagementIPAddress {
    [CmdLetBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )
    [String] $ManagementSwitchName = ('LabBuilder Management {0}' `
        -f $Config.labbuilderconfig.name)
    [String] $IPAddress = (Get-VMNetworkAdapter -VMName $VM.Name).`
        Where({$_.SwitchName -eq $ManagementSwitchName}).`
        IPAddresses.Where({$_.Contains('.')})
    if (-not $IPAddress) {
        $ExceptionParameters = @{
            errorId = 'ManagmentIPAddressError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ManagmentIPAddressError `
                -f $ManagementSwitchName,$VM.Name)
        }
        ThrowException @ExceptionParameters
    }
    return $IPAddress
} # Get-LabVMManagementIPAddress
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
#>
function Start-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $VM
    )

    [String] $LabPath = $Config.labbuilderconfig.settings.labpath

    # The VM is now ready to be started
    if ((Get-VM -Name $VM.Name).State -eq 'Off')
    {
        Write-Verbose -Message $($LocalizedData.StartingVMMessage `
            -f $VM.Name)

        Start-VM -VMName $VM.Name
    } # If

    # We only perform this section of VM Initialization (DSC, Cert, etc) with Server OS
    if ($VM.OSType -eq 'Server')
    {
        # Has this VM been initialized before (do we have a cert for it)
        if (-not (Test-Path "$LabPath\$($VM.Name)\LabBuilder Files\$Script:DSCEncryptionCert"))
        {
            # No, so check it is initialized and download the cert.
            if (Wait-LabVMInit -VM $VM -ErrorAction Continue)
            {
                Write-Verbose -Message $($LocalizedData.CertificateDownloadStartedMessage `
                    -f $VM.Name)
                    
                if (Get-LabVMelfSignedCert -Config $Config -VM $VM)
                {
                    Write-Verbose -Message $($LocalizedData.CertificateDownloadCompleteMessage `
                        -f $VM.Name)
                }
                else
                {
                    $ExceptionParameters = @{
                        errorId = 'CertificateDownloadError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.CertificateDownloadError `
                            -f $VM.name)
                    }
                    ThrowException @ExceptionParameters
                } # If
            }
            else
            {
                $ExceptionParameters = @{
                    errorId = 'InitializationDidNotCompleteError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InitializationDidNotCompleteError `
                        -f $VM.name)
                }
                ThrowException @ExceptionParameters
            } # If
        } # If

        # Create any DSC Files for the VM
        InitializeDSC `
            -Config $Config `
            -VM $VM

        # Attempt to start DSC on the VM
        StartDSC `
            -Config $Config `
            -VM $VM
    } # If
} # Start-LabVM
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Updates the VM Data Disks to match the VM Configuration.
.DESCRIPTION
   This cmdlet will take the VM configuration provided and ensure that that data disks that are
   attached to the VM.
   
   The function will use the array of items in the DataVHDs property of the VM to create and
   attach any data disk VHDs that are missing.
   
   If the data disk VHD file exists but is not attached it will be attached to the VM. If the
   data disk VHD file does not exist then it will be created and attached. 
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Update-LabVMDataDisk -Config $Config -VM VM[0]
   This will update the data disks for the first VM in the configuration file c:\mylab\config.xml.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM.
.OUTPUTS
   None.
#>
function Update-LabVMDataDisk {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        $VM
    )

    # If there are no data VHDs just return
    if (! $VM.DataVHDs)
    {
        return
    }

    # Get the root path of the VM
    [String] $VMRootPath = $VM.VMRootPath

    # Get the Virtual Hard Disk Path
    [String] $VHDPath = Join-Path `
        -Path $VMRootPath `
        -ChildPath 'Virtual Hard Disks'

    foreach ($DataVhd in @($VM.DataVHDs))
    {
        $Vhd = $DataVhd.Vhd
        if (Test-Path -Path $Vhd)
        {
            Write-Verbose -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                -f $VM.Name,$Vhd,'Data')
                
            # Check the parameters of the VHD match
            $ExistingVhd = Get-VHD -Path $Vhd

            # Check the VHD Type
            if (($DataVhd.type) -and ($ExistingVhd.VhdType -ne $DataVhd.type))
            {
                # The type of disk can't be changed.
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDConvertError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDConvertError `
                        -f $VM.name,$Vhd,$DataVhd.type)
                }
                ThrowException @ExceptionParameters                
            }
            
            # Check the size
            if ($DataVhd.Size)
            {
                if ($ExistingVhd.Size -lt $DataVhd.Size)
                {
                    # Expand the disk
                    Write-Verbose -Message $($LocalizedData.ExpandingVMDiskMessage `
                        -f $VM.Name,$Vhd,'Data',$DataVhd.Size)

                    $null = Resize-VHD `
                        -Path $Vhd `
                        -SizeBytes $DataVhd.Size
                }
                elseif ($ExistingVhd.Size -gt $DataVhd.Size)
                {
                    # The disk size can't be reduced.
                    # This could be revisited later.
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskVHDShrinkError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskVHDShrinkError `
                            -f $VM.name,$Vhd,$DataVhd.Size)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if
        }
        else
        {
            # The data disk VHD does not exist so create it
            $SourceVhd = $DataVhd.SourceVhd
            if ($SourceVhd)
            {
                # A source VHD was specified to create the new VHD using
                if (! (Test-Path -Path $SourceVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                            -f $VM.name,$SourceVhd)
                    }
                    ThrowException @ExceptionParameters                    
                } # if
                # Should the Source VHD be copied or moved
                if ($DataVhd.MoveSourceVHD)
                {
                    Write-Verbose -Message $($LocalizedData.CreatingVMDiskByMovingSourceVHDMessage `
                        -f $VM.Name,$Vhd,$SourceVhd)

                    $null = Move-Item `
                        -Path $SourceVhd `
                        -Destination $VHDPath `
                        -Force `
                        -ErrorAction Stop
                }
                else
                {
                    Write-Verbose -Message $($LocalizedData.CreatingVMDiskByCopyingSourceVHDMessage `
                        -f $VM.Name,$Vhd,$SourceVhd)

                    $null = Copy-Item `
                        -Path $SourceVhd `
                        -Destination $VHDPath `
                        -Force `
                        -ErrorAction Stop 
                } # if
            }
            else
            {
                $Size = $DataVhd.size
                switch ($DataVhd.type)
                {
                    'fixed'
                    {
                        # Create a new Fixed VHD
                        Write-Verbose -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$Vhd,'Fixed Data')

                        $null = New-VHD `
                            -Path $Vhd `
                            -SizeBytes $Size `
                            -Fixed `
                            -ErrorAction Stop
                        break;
                    } # 'fixed'
                    'dynamic'
                    {
                        # Create a new Dynamic VHD
                        Write-Verbose -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$Vhd,'Dynamic Data')

                        $null = New-VHD `
                            -Path $Vhd `
                            -SizeBytes $Size `
                            -Dynamic `
                            -ErrorAction Stop
                        break;                            
                    } # 'dynamic'
                    'differencing'
                    {
                        # A differencing disk is specified so check the Parent VHD
                        # is specified and exists
                        $ParentVhd = $DataVhd.ParentVhd
                        if (-not $ParentVhd)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDMissingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                                    -f $VM.name)
                            }
                            ThrowException @ExceptionParameters                    
                        } # if
                        if (-not (Test-Path -Path $ParentVhd))
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                                    -f $VM.name,$ParentVhd)
                            }
                            ThrowException @ExceptionParameters                    
                        } # if
                        
                        # Create a new Differencing VHD
                        Write-Verbose -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$Vhd,"Differencing Data using Parent '$ParentVhd'")

                        $null = New-VHD `
                            -Path $Vhd `
                            -SizeBytes $Size `
                            -Differencing `
                            -ParentPath $ParentVhd `
                            -ErrorAction Stop
                        break;
                    } # 'differencing'
                    default
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskUnknownTypeError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                                -f $VM.Name,$Vhd,$DataVhd.type)
                        }
                        ThrowException @ExceptionParameters                        
                    } # default
                } # switch
            } # if     
            
            # Do folders need to be copied to this Data Disk?
            if ($DataVhd.CopyFolders -ne $null)
            {
                # Files need to be copied to this Data VHD so
                # set up a mount folder for it to be mounted to.
                # Get Path to LabBuilder files
                [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

                [String] $MountPoint = Join-Path `
                    -Path $VMLabBuilderFiles `
                    -ChildPath 'VHDMount'

                if (-not (Test-Path -Path $MountPoint -PathType Container))
                {
                    $null = New-Item `
                        -Path $MountPoint `
                        -ItemType Directory
                }
                # Yes, initialize the disk (or check it is)
                $InitializeVHDParams = @{
                    Path = $VHD
                    AccessPath = $MountPoint                        
                }
                # Are we allowed to initialize/format the disk?
                if ($DataVHD.PartitionStyle -and $DataVHD.FileSystem)
                {
                    # Yes, initialize the disk
                    $InitializeVHDParams += @{
                        PartitionStyle = $DataVHD.PartitionStyle
                        FileSystem = $DataVHD.FileSystem
                    }
                    # Set a FileSystemLabel too?
                    if ($DataVHD.FileSystemLabel)
                    {
                        $InitializeVHDParams += @{
                            FileSystemLabel = $DataVHD.FileSystemLabel
                        }
                    }
                }
                Write-Verbose -Message $($LocalizedData.InitializingVMDiskMessage `
                    -f $VM.Name,$VHD)

                InitializeVHD `
                    @InitializeVHDParams `
                    -ErrorAction Stop
                
                # Copy each folder to the VM Data Disk
                foreach ($CopyFolder in @($DataVHD.CopyFolders))
                {                    
                    Write-Verbose -Message $($LocalizedData.CopyingFoldersToVMDiskMessage `
                        -f $VM.Name,$VHD,$CopyFolder)

                    Copy-item `
                        -Path $CopyFolder `
                        -Destination $MountFolder `
                        -Recurse `
                        -Force
                }
                
                # Dismount the VM Data Disk
                Write-Verbose -Message $($LocalizedData.DismountingVMDiskMessage `
                    -f $VM.Name,$VHD)

                Dismount-VHD `
                    -Path $VHD `
                    -ErrorAction Stop
            }
            else
            {
                # No folders need to be copied but check if we
                # need to initialize the new disk.
                if ($DataVHD.PartitionStyle -and $DataVHD.FileSystem)
                {
                    $InitializeVHDParams = @{
                        Path = $VHD
                        PartitionStyle = $DataVHD.PartitionStyle
                        FileSystem = $DataVHD.FileSystem
                    }
                    if ($DataVHD.FileSystemLabel)
                    {
                        $InitializeVHDParams += @{
                            FileSystemLabel = $DataVHD.FileSystemLabel
                        }
                    } # if

                    Write-Verbose -Message $($LocalizedData.InitializingVMDiskMessage `
                        -f $VM.Name,$VHD)

                    InitializeVHD `
                        @InitializeVHDParams `
                        -ErrorAction Stop

                    # Dismount the VM Data Disk
                    Write-Verbose -Message $($LocalizedData.DismountingVMDiskMessage `
                        -f $VM.Name,$VHD)

                    Dismount-VHD `
                        -Path $VHD `
                        -ErrorAction Stop
                } # if
            } # if
        } # if

        # Get a list of disks attached to the VM
        $VMHardDiskDrives = Get-VMHardDiskDrive `
            -VMName $VM.Name

        # The data disk VHD will now exist so ensure it is attached
        if (($VMHardDiskDrives | Where-Object -Property Path -eq $Vhd).Count -eq 0)
        {
            # The data disk is not yet attached
            Write-Verbose -Message $($LocalizedData.AddingVMDiskMessage `
                -f $VM.Name,$Vhd,'Data')

            # Determine the ControllerLocation and ControllerNumber to
            # attach the VHD to.
            $ControllerLocation = ($VMHardDiskDrives | 
                Measure-Object -Property ControllerLocation -Maximum).Maximum + 1
            
            $NewHardDiskParams = @{
                VMName = $VM.Name
                Path = $Vhd
                ControllerType = 'SCSI'
                ControllerLocation = $ControllerLocation
                ControllerNumber = 0
                ErrorAction = 'Stop'
            }
            if ($DataVhd.Shared)
            {
                $NewHardDiskParams += @{
                    ShareVirtualDisk = $true
                }
                if ($DataVhd.SupportSR)
                {
                    $NewHardDiskParams += @{
                        SupportPersistentReservations = $true
                    }
                } # if
            } # if
            $Null = Add-VMHardDiskDrive @NewHardDiskParams
        } # if
    } # foreach
} # Update-LabVMDataDisk
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Updates the VM Integration Services to match the VM Configuration.
.DESCRIPTION
   This cmdlet will take the VM object provided and ensure the integration services specified
   in it are enabled.
   
   The function will use comma delimited list of integration services in the VM object passed
   and enable the integration services listed for this VM.
   
   If the IntegrationServices property of the VM is not set or set to null then ALL integration
   services will be ENABLED.
   
   If the IntegrationServices property of the VM is set but is blank then ALL integration
   services will be DISABLED.
   
   The IntegrationServices property should contain a comma delimited list of Integration Services
   that should be enabled.
   
   The currently available Integration Services are:
   - Guest Service Interface
   - Heartbeat
   - Key-Value Pair Exchange
   - Shutdown
   - Time Synchronization
   - VSS
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Update-LabVMIntegrationService -VM VM[0]
   This will update the Integration Services for the first VM in the configuration file c:\mylab\config.xml.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM.
.OUTPUTS
   None.
#>
function Update-LabVMIntegrationService {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        $VM
    )
    # Configure the Integration services
    $IntegrationServices = $VM.IntegrationServices
    if ($IntegrationServices -eq $null)
    {
        $IntegrationServices = 'Guest Service Interface,Heartbeat,Key-Value Pair Exchange,Shutdown,Time Synchronization,VSS'
    }
    $EnabledIntegrationServices = $IntegrationServices -split ','
    $ExistingIntegrationServices = Get-VMIntegrationService `
        -VMName $VM.Name `
        -ErrorAction Stop
    # Loop through listed integration services and enable them
    foreach ($ExistingIntegrationService in $ExistingIntegrationServices)
    {
        if ($ExistingIntegrationService.Name -in $EnabledIntegrationServices)
        {
            # This integration service should be enabled
            if (-not $ExistingIntegrationService.Enabled)
            {
                # It is disabled so enable it
                Enable-VMIntegrationService `
                    -VMName $VM.Name `
                    -Name $ExistingIntegrationService.Name 

                Write-Verbose -Message $($LocalizedData.EnableVMIntegrationServiceMessage `
                    -f $VM.Name,$ExistingIntegrationService.Name)
            } # if
        }
        else
        {
            # This integration service should be disabled
            if ($ExistingIntegrationService.Enabled)
            {
                # It is enabled so disable it
                Disable-VMIntegrationService `
                    -VMName $VM.Name `
                    -Name $ExistingIntegrationService.Name

                Write-Verbose -Message $($LocalizedData.DisableVMIntegrationServiceMessage `
                    -f $VM.Name,$ExistingIntegrationService.Name)
            } # if
        } # if
    } # foreach
} # Update-LabVMIntegrationService
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Creates the folder structure that will contain a Lab Virtual Machine. 
.DESCRIPTION
   Creates a standard Hyper-V Virtual Machine folder structure as well as additional folders
   for containing configuration files for DSC.
.PARAMATER vmpath
   The path to the folder where the Virtual Machine files are stored.
.EXAMPLE
   Initialize-LabVMPath -VMPath 'c:\VMs\Lab\Virtual Machine 1'
   The command will create the Virtual Machine structure for a Lab VM in the folder:
   'c:\VMs\Lab\Virtual Machine 1'
.OUTPUTS
   None.
#>
function Initialize-LabVMPath {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $VMPath
    )

    if (-not (Test-Path -Path $VMPath))
    {
        $Null = New-Item `
			-Path $VMPath `
			-ItemType Directory
    }
    if (-not (Test-Path -Path "$VMPath\Virtual Machines"))
    {
        $Null = New-Item `
			-Path "$VMPath\Virtual Machines" `
			-ItemType Directory
    }
    if (-not (Test-Path -Path "$VMPath\Virtual Hard Disks"))
    {
        $Null = New-Item `
		-Path "$VMPath\Virtual Hard Disks" `
		-ItemType Directory
    }
    if (-not (Test-Path -Path "$VMPath\LabBuilder Files"))
    {
        $Null = New-Item `
            -Path "$VMPath\LabBuilder Files" `
            -ItemType Directory
    }
    if (-not (Test-Path -Path "$VMPath\LabBuilder Files\DSC Modules"))
    {
        $Null = New-Item `
            -Path "$VMPath\LabBuilder Files\DSC Modules" `
            -ItemType Directory
    }
}
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VMs
   Array of Virtual Machines pulled from a configuration object.
.OUTPUTS
   None
#>
function Initialize-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [System.Collections.Hashtable[]] $VMs
    )
    
    # If the VMs list was not passed pull it
    if (-not $VMs)
    {
        $VMs = Get-LabVM -Config $Config
    }
    
    # If there are not VMs just return
    if (-not $VMs)
    {
        return
    }
    
    $CurrentVMs = Get-VM

    [String] $LabPath = $Config.labbuilderconfig.settings.labpath

    # Figure out the name of the LabBuilder control switch
    $ManagementSwitchName = ('LabBuilder Management {0}' -f $Config.labbuilderconfig.name)
    if ($Config.labbuilderconfig.switches.ManagementVlan)
    {
        [Int32] $ManagementVlan = $Config.labbuilderconfig.switches.ManagementVlan
    }
    else
    {
        [Int32] $ManagementVlan = $Script:DefaultManagementVLan
    }

    foreach ($VM in $VMs)
    {
        # Get the root path of the VM
        [String] $VMRootPath = $VM.VMRootPath

        # Get the Virtual Machine Path
        [String] $VMPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Machines'
            
        # Get the Virtual Hard Disk Path
        [String] $VHDPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Hard Disks'

        # Get Path to LabBuilder files
        [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -eq 0)
        {
            Write-Verbose -Message $($LocalizedData.CreatingVMMessage `
                -f $VM.Name)

            # Make sure the appropriate folders exist
            Initialize-LabVMPath `
                -VMPath $VMRootPath

            # Create the boot disk
            $VMBootDiskPath = "$VHDPath\$($VM.Name) Boot Disk.vhdx"
            if (-not (Test-Path -Path $VMBootDiskPath))
            {
                if ($VM.UseDifferencingDisk -eq 'Y')
                {
                    Write-Verbose -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Differencing Boot')

                    $Null = New-VHD -Differencing -Path $VMBootDiskPath -ParentPath $VM.ParentVHD
                }
                else
                {
                    Write-Verbose -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Boot')

                    $Null = Copy-Item `
                        -Path $VM.ParentVHD `
                        -Destination $VMBootDiskPath
                }
                
                # Create all the required initialization files for this VM
                CreateVMInitializationFiles `
                    -Config $Config `
                    -VM $VM

                # Because this is a new boot disk apply any required initialization
                InitializeBootVHD `
                    -Config $Config `
                    -VM $VM `
                    -VMBootDiskPath $VMBootDiskPath
            }
            else
            {
                Write-Verbose -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                    -f $VM.Name,$VMBootDiskPath,'Boot')
            } # If

            $null = New-VM `
                -Name $VM.Name `
                -MemoryStartupBytes $VM.MemoryStartupBytes `
                -Generation 2 `
                -Path $LabPath `
                -VHDPath $VMBootDiskPath
            # Remove the default network adapter created with the VM because we don't need it
            Remove-VMNetworkAdapter `
                -VMName $VM.Name `
                -Name 'Network Adapter'
        }

        # Set the processor count if different to default and if specified in config file
        if ($VM.ProcessorCount)
        {
            if ($VM.ProcessorCount -ne (Get-VM -Name $VM.Name).ProcessorCount)
            {
                Set-VM `
                    -Name $VM.Name `
                    -ProcessorCount $VM.ProcessorCount
            } # If
        } # If
        
        # Enable/Disable Dynamic Memory
        if ($VM.DynamicMemoryEnabled)
        {
            [Boolean] $DynamicMemoryEnabled = ($VM.DynamicMemoryEnabled -ne 'N')
            if ($DynamicMemoryEnabled -ne (Get-VMMemory -VMName $VM.Name).DynamicMemoryEnabled)
            {
                Set-VMMemory `
                    -VMName $VM.Name `
                    -DynamicMemoryEnabled:$DynamicMemoryEnabled
            } # If
        } # If

        
        # If the ExposeVirtualizationExtensions is configured then try and set this on 
        # Virtual Processor. Only supported in certain builds on Windows 10/Server 2016 TP4.
        if ($VM.ExposeVirtualizationExtensions)
        {
            [Boolean] $ExposeVirtualizationExtensions = ($VM.ExposeVirtualizationExtensions -eq 'Y') 
            if ($ExposeVirtualizationExtensions -ne (Get-VMProcessor -VMName $VM.Name).ExposeVirtualizationExtensions)
            {
                Set-VMProcessor `
                    -VMName $VM.Name `
                    -ExposeVirtualizationExtensions:$ExposeVirtualizationExtensions                
            }   
        }

        # Enable/Disable the Integration Services
        Update-LabVMIntegrationService `
            -VM $VM
        
        # Update the data disks for the VM
        Update-LabVMDataDisk `
            -Config $Config `
            -VM $VM        
            
        # Create/Update the Management Network Adapter
        if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $ManagementSwitchName).Count -eq 0)
        {
            Write-Verbose -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                -f $VM.Name,$ManagementSwitchName,'Management')

            Add-VMNetworkAdapter -VMName $VM.Name -SwitchName $ManagementSwitchName -Name $ManagementSwitchName
        }
        $VMNetworkAdapter = Get-VMNetworkAdapter `
            -VMName $VM.Name `
            -Name $ManagementSwitchName
        $null = $VMNetworkAdapter | Set-VMNetworkAdapterVlan -Access -VlanId $ManagementVlan

        Write-Verbose -Message $($LocalizedData.SettingVMNetworkAdapterVlanMessage `
            -f $VM.Name,$ManagementSwitchName,'Management',$ManagementVlan)

        # Create any network adapters
        foreach ($VMAdapter in $VM.Adapters)
        {
            if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $VMAdapter.Name).Count -eq 0)
            {
                Write-Verbose -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                    -f $VM.Name,$VMAdapter.SwitchName,$VMAdapter.Name)

                Add-VMNetworkAdapter `
                    -VMName $VM.Name `
                    -SwitchName $VMAdapter.SwitchName `
                    -Name $VMAdapter.Name
            } # If

            $VMNetworkAdapter = Get-VMNetworkAdapter -VMName $VM.Name -Name $VMAdapter.Name
            $Vlan = $VMAdapter.VLan
            if ($VLan)
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapterVlan -Access -VlanId $Vlan

                Write-Verbose -Message $($LocalizedData.SettingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'',$Vlan)
            }
            else
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapterVlan -Untagged

                Write-Verbose -Message $($LocalizedData.ClearingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'')
            } # If

            if ($VMAdapter.MACAddress)
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -StaticMacAddress $VMAdapter.MACAddress
            }
            else
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -DynamicMacAddress
            } # If

            # Enable Device Naming
            if ((Get-Command -Name Set-VMNetworkAdapter).Parameters.ContainsKey('DeviceNaming'))
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -DeviceNaming On
            }
            if ($VMAdapter.MACAddressSpoofing -ne $VMNetworkAdapter.MACAddressSpoofing)
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -MacAddressSpoofing $VMAdapter.MACAddressSpoofing
            }                
        } # Foreach

        Start-LabVM `
            -Config $Config `
            -VM $VM
    } # Foreach
} # Initialize-LabVM
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
#>
function Remove-LabVM {
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]] $VMs,

        [Switch] $RemoveVHDs
    )
    
    # If VMs not passed then pull them from the config
    if (-not $VMs)
    {
        $VMs = Get-LabVM -Config $Config
    }
    
    $CurrentVMs = Get-VM

    # Get the LabPath
    [String] $LabPath = $Config.labbuilderconfig.settings.labpath
    
    foreach ($VM in $VMs)
    {
        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -ne 0)
        {
            # If the VM is running we need to shut it down.
            if ((Get-VM -Name $VM.Name).State -eq 'Running')
            {
                Write-Verbose -Message $($LocalizedData.StoppingVMMessage `
                    -f $VM.Name)

                Stop-VM -Name $VM.Name
                # Wait for it to completely shut down and report that it is off.
                Wait-LabVMOff -VM $VM
            }

            Write-Verbose -Message $($LocalizedData.RemovingVMMessage `
                -f $VM.Name)

            # Should we also delete the VHDs from the VM?
            if ($RemoveVHDs)
            {
                Write-Verbose -Message $($LocalizedData.DeletingVMAllDisksMessage `
                    -f $VM.Name)

                $null = Get-VMHardDiskDrive -VMName $VM.Name | Select-Object -Property Path | Remove-Item
            }
            
            # Now delete the actual VM
            Get-VM -Name $VM.Name | Remove-VM -Confirm:$false

            Write-Verbose -Message $($LocalizedData.RemovedVMMessage `
                -f $VM.Name)
        }
        else
        {
            Write-Verbose -Message $($LocalizedData.VMNotFoundMessage `
                -f $VM.Name)
        }
    }
    Return $true
}
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Waits for a VM to complete setup.
.DESCRIPTION
   When a VM starts up for the first time various scripts are run that prepare the Virtual Machine
   to be managed as part of a Lab. This function will wait for these scripts to complete.
   It determines if the setup has been completed by using PowerShell remoting to connect to the
   VM and downloading the c:\windows\Setup\Scripts\InitialSetupCompleted.txt file. If this file
   does not exist then the initial setup has not been completed.
   
   The cmdlet will wait for a maximum of 300 seconds for this process to be completed.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.PARAMETER Timeout
   The maximum amount of time that this function will wait for the setup to complete.
   If the timeout is reached before the process is complete an error will be thrown.
   The timeout defaults to 300 seconds.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Wait-LabVMInit -VM $VMs[0]
   Waits for the initial setup to complete on the first VM in the config.xml.
.OUTPUTS
   The path to the local copy of the Initial Setup complete file in the Labbuilder files folder
   for this VM.
#>
function Wait-LabVMInit
{
    [CmdLetBinding()]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM,

        [Int] $Timeout = 300
    )

    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False

    # Get the root path of the VM
    [String] $VMRootPath = $VM.VMRootPath

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    # Make sure the VM has started
    Wait-LabVMStart -VM $VM
    
    [String] $InitialSetupCompletePath = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'InitialSetupCompleted.txt'

    # Check the initial setup on this VM hasn't already completed
    if (Test-Path -Path $InitialSetupCompletePath)
    {
        Write-Verbose -Message $($LocalizedData.InitialSetupIsAlreadyCompleteMessaage `
            -f $VM.Name)
        return $InitialSetupCompletePath 
    }
    
    while ((-not $Complete) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
    {
        # Connect to the VM
        $Session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        # Failed to connnect to the VM
        if (! $Session)
        {
            $ExceptionParameters = @{
                errorId = 'InitialSetupCompleteError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.InitialSetupCompleteError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
            return            
        }

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $Complete))
        {
            # We connected OK - Download the script
            while ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    $null = Copy-Item `
                        -Path "c:\windows\Setup\Scripts\InitialSetupCompleted.txt" `
                        -Destination $VMLabBuilderFiles `
                        -FromSession $Session `
                        -Force `
                        -ErrorAction Stop
                    $Complete = $True
                }
                catch
                {
                    Write-Verbose -Message $($LocalizedData.WaitingForInitialSetupCompleteMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)                                
                    Start-Sleep `
                        -Seconds $Script:RetryConnectSeconds
                } # Try
            } # While
        } # If

        # If the process didn't complete and we're out of time throw an exception
        if ((-not $Complete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            if ($Session)
            {
                Remove-PSSession `
                    -Session $Session
            }

            $ExceptionParameters = @{
                errorId = 'InitialSetupCompleteError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.InitialSetupCompleteError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
        }

        # Close the Session if it is opened
        if (($Session) `
            -and ($Session.State -eq 'Opened'))
        {
            Remove-PSSession `
                -Session $Session
        } # If
    } # While
    return $InitialSetupCompletePath
} # Wait-LabVMInit
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.PARAMETER VM
   The VM that should be waited for start up to complete.
.EXAMPLE
   Example of how to use this cmdlet
.OUTPUTS
   None.
#>
function Wait-LabVMStart {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )
    $Heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name Heartbeat
    while ($Heartbeat.PrimaryStatusDescription -ne 'OK')
    {
        $Heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name Heartbeat
        Start-Sleep -Seconds $Script:RetryHeartbeatSeconds
    } # while
} # Wait-LabVMStart
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.PARAMETER VM
   The VM that should be waited for turn off to complete.
.EXAMPLE
   Example of how to use this cmdlet
.OUTPUTS
   None.
#>
function Wait-LabVMOff {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )
    $RunningVM = Get-VM -Name $VM.Name
    while ($RunningVM.State -ne 'Off')
    {
        $RunningVM = Get-VM -Name $VM.Name
        Start-Sleep -Seconds $Script:RetryHeartbeatSeconds
    } # while
} # Wait-LabVMOff
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Connects to a running VM.
.DESCRIPTION
   This cmdlet will connect to a running VM using PSRemoting. A PSSession object will be returned
   if the connection was successful.
   
   If the connection fails, it will be retried until the ConnectTimeout is reached. If the
   ConnectTimeout is reached and a connection has not been established then a ConnectionError 
   exception will be thrown.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   $Session = Connect-LabVM -VM $VMs[0]
   Connect to the first VM in the Lab c:\mylab\config.xml for DSC configuration.
.PARAMETER VM
   The VM Object referring to the VM to connect to.
.PARAMETER ConnectTimeout
   The number of seconds the connection will attempt to be established for. Defaults to 300 seconds.
.OUTPUTS
   The PSSession object of the remote connect or null if the connection failed.
#>
function Connect-LabVM
{
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM,
        
        [Int] $ConnectTimeout = 300
    )

    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [PSCredential] $AdminCredential = CreateCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword
    [Boolean] $FatalException = $False
    
    while (($Session -eq $null) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $ConnectTimeout `
        -and -not $FatalException)
    {
        try
        {                
            # Get the Management IP Address of the VM
            # We repeat this because the IP Address will only be assiged 
            # once the VM is fully booted.
            $IPAddress = Get-LabVMManagementIPAddress `
                -Config $Config `
                -VM $VM
            
            # Add the IP Address to trusted hosts if not already in it
            # This could be avoided if able to use SSL or if PS Direct is used.
            # Also, don't add if TrustedHosts is already *
            $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
            if (($TrustedHosts -notlike "*$IPAddress*") -and ($TrustedHosts -ne '*'))
            {
                Set-Item `
                    -Path WSMAN::localhost\Client\TrustedHosts `
                    -Value "$TrustedHosts,$IPAddress" `
                    -Force
                Write-Verbose -Message $($LocalizedData.AddingIPAddressToTrustedHostsMessage `
                    -f $VM.Name,$IPAddress)
            }
        
            Write-Verbose -Message $($LocalizedData.ConnectingVMMessage `
                -f $VM.Name)

            # TODO: Convert to PS Direct once supported for this cmdlet.
            $Session = New-PSSession `
                -ComputerName $IPAddress `
                -Credential $AdminCredential `
                -ErrorAction Stop
        }
        catch
        {
            if (-not $IPAddress)
            {
                Write-Verbose -Message $($LocalizedData.WaitingForIPAddressAssignedMessage `
                    -f $VM.Name,$Script:RetryConnectSeconds)                                
            }
            else
            {
                Write-Verbose -Message $($LocalizedData.ConnectingVMFailedMessage `
                    -f $VM.Name,$Script:RetryConnectSeconds,$_.Exception.Message)
            }
            Start-Sleep -Seconds $Script:RetryConnectSeconds
        } # Try
    } # While
    
    # If a fatal exception occured or the connection just couldn't be established
    # then throw an exception so it can be caught by the calling code.
    if ($FatalException -or ($Session -eq $null))
    {
        # The connection failed so throw an error
        $ExceptionParameters = @{
            errorId = 'RemotingConnectionError'
            errorCategory = 'ConnectionError'
            errorMessage = $($LocalizedData.RemotingConnectionError `
                -f $VM.Name)
        }
        ThrowException @ExceptionParameters
    }
    Return $Session
} # Connect-LabVM
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
#>
Function Install-Lab {
    [CmdLetBinding()]
    param
    (
        [parameter(Mandatory)]
        [String] $Path,

        [Switch] $CheckEnvironment
    ) # Param

    [XML] $Config = Get-LabConfiguration -Path $Path
    
    # Make sure everything is OK to install the lab
    if (-not (Test-LabConfiguration -Config $Config))
    {
        return
    }
       
    if ($CheckEnvironment)
    {
        Install-LabHyperV
    }

    Initialize-LabConfiguration `
        -Config $Config

    $Switches = Get-LabSwitch `
        -Config $Config
    Initialize-LabSwitch `
        -Config $Config `
        -Switches $Switches

    $VMTemplateVHDs = Get-LabVMTemplateVHD `
        -Config $Config
    Initialize-LabVMTemplateVHD `
        -Config $Config `
        -VMTemplateVHDs $VMTemplateVHDs

    $VMTemplates = Get-LabVMTemplate `
        -Config $Config
    Initialize-LabVMTemplate `
        -Config $Config `
        -VMTemplates $VMTemplates

    $VMs = Get-LabVM `
        -Config $Config `
        -VMTemplates $VMTemplates `
        -Switches $Switches
    Initialize-LabVM `
        -Config $Config `
        -VMs $VMs 
} # Install-Lab
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
#>
Function Uninstall-Lab {
    [CmdLetBinding()]
    param
    (
        [parameter(Mandatory)]
        [String] $Path,

        [Switch] $RemoveSwitches,

        [Switch] $RemoveTemplates,

        [Switch] $RemoveVHDs
    ) # Param

    [XML] $Config = Get-LabConfiguration -Path $Path

    # Make sure everything is OK to install the lab
    if (-not (Test-LabConfiguration -Config $Config))
    {
        return
    }

    $VMTemplates = Get-LabVMTemplate -Config $Config

    $Switches = Get-LabSwitch -Config $Config

    $VMs = Get-LabVM -Config $Config -VMTemplates $VMTemplates -Switches $Switches
    if ($RemoveVHDs)
    {
        $null = Remove-LabVM -Config $Config -VMs $VMs -RemoveVHDs
    }
    else
    {
        $null = Remove-LabVM -Config $Config -VMs $VMs
    } # If

    if ($RemoveTemplates)
    {
        $null = Remove-LabVMTemplate -Config $Config -VMTemplates $VMTemplates
    } # If

    if ($RemoveSwitches)
    {
        $null = Remove-LabSwitch -Config $Config -Switches $Switches
    } # If
} # Uninstall-Lab
####################################################################################################



####################################################################################################
# DSC Config Files
####################################################################################################
[DSCLocalConfigurationManager()]
Configuration ConfigLCM {
    Param (
        [String] $ComputerName,
        [String] $Thumbprint
    )
    Node $ComputerName {
        Settings {
            RefreshMode = 'Push'
            ConfigurationMode = 'ApplyAndAutoCorrect'
            CertificateId = $Thumbprint
            ConfigurationModeFrequencyMins = 15
            RefreshFrequencyMins = 30
            RebootNodeIfNeeded = $True
            ActionAfterReboot = 'ContinueConfiguration'
        } 
    }
}
####################################################################################################

