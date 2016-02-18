#Requires -version 5.0

####################################################################################################
#region localizeddata
$Culture = 'en-us'
if (Test-Path "${PSScriptRoot}\${PSUICulture}")
{
    $Culture = $PSUICulture
}
Import-LocalizedData `
    -BindingVariable LocalizedData `
    -Filename LabBuilder_LocalizedData.psd1 `
    -BaseDirectory $PSScriptRoot `
    -UICulture $Culture
#endregion

####################################################################################################
# Module Variables
####################################################################################################
# This is the URL to the WMF 5.0 RTM
[String] $Script:WorkingFolder = $ENV:Temp

# Supporting files
[String] $Script:WMF5DownloadURL = 'https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/W2K12R2-KB3094174-x64.msu'
[String] $Script:WMF5InstallerFilename = ($Script:WMF5DownloadURL).Substring(($Script:WMF5DownloadURL).LastIndexOf('/') + 1)
[String] $Script:WMF5InstallerPath = Join-Path -Path $Script:WorkingFolder -ChildPath $Script:WMF5InstallerFilename
[String] $Script:SupportConvertWindowsImagePath = Join-Path -Path $PSScriptRoot -ChildPath 'Support\Convert-WindowsImage.ps1'
[String] $Script:CertGenDownloadURL = 'https://gallery.technet.microsoft.com/scriptcenter/Self-signed-certificate-5920a7c6/file/101251/1/New-SelfSignedCertificateEx.zip'
[String] $Script:CertGenZipFilename = ($Script:CertGenDownloadURL).Substring(($Script:CertGenDownloadURL).LastIndexOf('/') + 1)
[String] $Script:CertGenZipPath = Join-Path -Path $Script:WorkingFolder -ChildPath $Script:CertGenZipFilename
[String] $Script:CertGenPS1Filename = 'New-SelfSignedCertificateEx.ps1'
[String] $Script:CertGenPS1Path = Join-Path -Path $Script:WorkingFolder -ChildPath $Script:CertGenPS1Filename

# Virtual Networking Parameters
[Int] $Script:DefaultManagementVLan = 99
[String] $Script:DefaultMacAddressMinimum = '00155D010600'
[String] $Script:DefaultMacAddressMaximum = '00155D0106FF'

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
# Helper functions that aren't exported
####################################################################################################
<#
.SYNOPSIS
   Returns True if running as Administrator
#>
function Test-Admin()
{
    # Get the ID and security principal of the current user account
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
  
    # Get the security principal for the Administrator role
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
  
    # Check to see if we are currently running "as Administrator"
    Return ($myWindowsPrincipal.IsInRole($adminRole))
}
####################################################################################################
<#
.SYNOPSIS
   Download the latest Windows Management Framework 5.0 Installer to the Working Folder
#>
function Download-WMF5Installer()
{
    [CmdletBinding()]
    Param ()

    # Only downloads for Win8.1/WS2K12R2
    if (-not (Test-Path -Path $Script:WMF5InstallerPath))
    {
        try
        {
            Invoke-WebRequest `
                -Uri $Script:WMF5DownloadURL `
                -OutFile $Script:WMF5InstallerPath `
                -ErrorAction Stop
        }
        catch
        {
            $ExceptionParameters = @{
                errorId = 'FileDownloadError'
                errorCategory = 'InvalidOperation'
                errorMessage = $($LocalizedData.FileDownloadError `
                    -f 'WMF 5.0 Installer',$Script:WMF5DownloadURL,$_.Exception.Message)
            }
            New-LabException @ExceptionParameters
        }
    }
} # Download-WMF5Installer
####################################################################################################
<#
.SYNOPSIS
   Download the Certificate Generator script from TechNet Script Center to the Working Folder
#>
function Download-CertGenerator()
{
    [CmdletBinding()]
    Param ()
    if (-not (Test-Path -Path $Script:CertGenZipPath))
    {
        try
        {
            Invoke-WebRequest `
                -Uri $Script:CertGenDownloadURL `
                -OutFile $Script:CertGenZipPath `
                -ErrorAction Stop
        }
        catch
        {
            $ExceptionParameters = @{
                errorId = 'FileDownloadError'
                errorCategory = 'InvalidOperation'
                errorMessage = $($LocalizedData.FileDownloadError `
                    -f 'Certificate Generator',$Script:CertGenDownloadURL,$_.Exception.Message)
            }
            New-LabException @ExceptionParameters
        }
    } # If
    if (-not (Test-Path -Path $Script:CertGenPS1Path))
    {
        try	
        {
            Expand-Archive `
                -Path $Script:CertGenZipPath `
                -DestinationPath $Script:WorkingFolder `
                -ErrorAction Stop
        }
        catch
        {
            $ExceptionParameters = @{
                errorId = 'FileExtractError'
                errorCategory = 'InvalidOperation'
                errorMessage = $($LocalizedData.FileExtractError `
                    -f 'Certificate Generator',$_.Exception.Message)
            }
            New-LabException @ExceptionParameters
        }
    } # If
} # Download-CertGenerator
####################################################################################################
<#
.SYNOPSIS
    Get a list of all Resources imported in a DSC Config
.DESCRIPTION
    Uses RegEx to pull a list of Resources that are imported in a DSC Configuration using the
    Import-DSCResource cmdlet
    
    The xNetworking will always be included and the PSDesiredConfigration will always be excluded.
.PARAMETER DSCConfigFile
    Contains the path to the DSC Config file to extract resource module names from
.EXAMPLE
    Get-ModulesInDSCConfig -DSCConfigFile c:\mydsc\Server01.ps1
    Return the DSC Resource module list from file c:\mydsc\server01.ps1
.OUTPUTS
    An array of strings containing resource module names
#>
function Get-ModulesInDSCConfig()
{
    [CmdletBinding()]
    [OutputType([String[]])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]	
        [String] $DSCConfigFile
    )
    [String[]] $Modules = $Null
    [String] $Content = Get-Content -Path $DSCConfigFile
    $Regex = "Import\-DscResource\s(?:\-ModuleName\s)?'?`"?([A-Za-z0-9._-]+)`"?'?"
    $Matches = [regex]::matches($Content, $Regex, 'IgnoreCase')
    foreach ($Match in $Matches)
    {
        if ($Match.Groups[1].Value -ne 'PSDesiredStateConfiguration')
        {
            $Modules += $Match.Groups[1].Value
        } # If
    } # Foreach
    # Add the xNetworking DSC Resource because it is always used
    $Modules += 'xNetworking'
    Return $Modules
} # Get-ModulesInDSCConfig
####################################################################################################
<#
.SYNOPSIS
    Generates a credential object from a username and password.
#>
function New-Credential()
{
    [CmdletBinding()]
    [OutputType([PSCredential])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]	
        [String] $Username,
        
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]	
        [String] $Password
    )
    [PSCredential] $Credential = New-Object `
        -TypeName System.Management.Automation.PSCredential `
        -ArgumentList ($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))
    return $Credential
} # New-Credential
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
        New-LabException @ExceptionParameters
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
        New-LabException @ExceptionParameters
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
        New-LabException @ExceptionParameters
    }

    # Check folders exist
    [String] $VMPath = $Config.labbuilderconfig.settings.vmpath
    if (-not $VMPath)
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationMissingElementError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationMissingElementError `
                -f '<settings>\<vmpath>')
        }
        New-LabException @ExceptionParameters
    }

    if (-not (Test-Path -Path $VMPath))
    {
        $ExceptionParameters = @{
            errorId = 'PathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.PathNotFoundError `
                -f '<settings>\<vmpath>',$VMPath)
        }
        New-LabException @ExceptionParameters
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
        New-LabException @ExceptionParameters
    }

    if (-not (Test-Path -Path $VHDParentPath))
    {
        $ExceptionParameters = @{
            errorId = 'PathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.PathNotFoundError `
                -f '<settings>\<vhdparentpath>',$VHDParentPath)
        }
        New-LabException @ExceptionParameters
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
        New-LabException @ExceptionParameters
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
    
    [String] $MacAddressMinimum = $Config.labbuilderconfig.settings.macaddressminimum
    if (-not $MacAddressMinimum)
    {
        $MacAddressMinimum = $Script:DefaultMacAddressMinimum
    }

    [String] $MacAddressMaximum = $Config.labbuilderconfig.settings.macaddressmaximum
    if (-not $MacAddressMaximum)
    {
        $MacAddressMaximum = $Script:DefaultMacAddressMaximum
    }

    Set-VMHost -MacAddressMinimum $MacAddressMinimum -MacAddressMaximum $MacAddressMaximum

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
    # Download the New-SelfSignedCertificateEx.ps1 script
    Download-CertGenerator

    # Download WMF 5.0 in case any VMs need it	
    Download-WMF5Installer

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

            Try
            {
                Invoke-WebRequest `
                    -Uri $($URL) `
                    -OutFile $FilePath `
                    -ErrorAction Stop
            }
            Catch
            {
                $ExceptionParameters = @{
                    errorId = 'FileDownloadError'
                    errorCategory = 'InvalidOperation'
                    errorMessage = $($LocalizedData.FileDownloadError `
                        -f "Module Resource ${Name}",$URL,$_.Exception.Message)
                }
                New-LabException @ExceptionParameters
            } # Try

            [String] $ModulesFolder = "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\"

            Write-Verbose -Message ($LocalizedData.InstallingLabResourceWebMessage `
                -f $Name,$VersionMessage,$ModulesFolder)

            # Extract this straight into the modules folder
            Try
            {
                Expand-Archive `
                    -Path $FilePath `
                    -DestinationPath $ModulesFolder `
                    -Force `
                    -ErrorAction Stop
            }
            Catch
            {
                $ExceptionParameters = @{
                    errorId = 'FileExtractError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.FileExtractError `
                    -f "Module Resource ${Name}",$_.Exception.Message)
                }
                New-LabException @ExceptionParameters
            } # Try
            if ($Folder)
            {
                # This zip file contains a folder that is not the name of the module so it must be
                # renamed. This is usually the case with source downloaded directly from GitHub
                $ModulePath = Join-Path -Path $ModulesFolder -ChildPath $($Name)
                if (Test-Path -Path $ModulePath)
                {
                    Remove-Item -Path $ModulePath -Recurse -Force
                }
                Rename-Item `
                    -Path (Join-Path -Path $ModulesFolder -ChildPath $($Folder)) `
                    -NewName $($Name) `
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
                New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
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
            New-LabException @ExceptionParameters
        }
        if ($ConfigSwitch.Type -notin 'Private','Internal','External','NAT')
        {
            $ExceptionParameters = @{
                errorId = 'UnknownSwitchTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                    -f $ConfigSwitch.Type,$ConfigSwitch.Name)
            }
            New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
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
                        New-LabException @ExceptionParameters
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
                    New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
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
                    New-LabException @ExceptionParameters
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
        New-LabException @ExceptionParameters
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
        New-LabException @ExceptionParameters
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
            New-LabException @ExceptionParameters
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
            New-LabException @ExceptionParameters
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
            New-LabException @ExceptionParameters            
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
            New-LabException @ExceptionParameters
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
            New-LabException @ExceptionParameters            
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
            New-LabException @ExceptionParameters            
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
            New-LabException @ExceptionParameters            
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
            New-LabException @ExceptionParameters            
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
                errorId = 'TemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.TemplateVHDISOPathNotFoundError `
                    -f $Name,$ISOPath)
            }
            New-LabException @ExceptionParameters            
        }
        
        # Mount the ISO so we can read the files.
        Write-Verbose -Message ($LocalizedData.MountingVMTemplateVHDISOMessage `
                -f $Name,$ISOPath)

        $null = Mount-DiskImage `
            -ImagePath $ISOPath `
            -StorageType ISO `
            -Access Readonly
    
        [String] $DriveLetter = ( Get-DiskImage -ImagePath $ISOPath | Get-Volume ).DriveLetter
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
            # once the ISO has been dismounted
            [String] $VHDFolder = Split-Path `
                -Path $VHDPath `
                -Parent

            [String] $PackagesFolder = Join-Path `
                -Path $VHDFolder `
                -ChildPath 'NanoServerPackages'
            if (-not (Test-Path -Path $PackagesFolder -Type Container))
            {
                Copy-Item `
                    -Path "$ISODrive\Nanoserver\Packages" `
                    -Destination $VHDFolder `
                    -Recurse `
                    -Force
                Rename-Item `
                    -Path "$VHDFolder\Packages" `
                    -NewName $PackagesFolder
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
                        $Packages += @(Join-Path -Path $PackagesFolder -ChildPath $Package.Filename)
                        $Packages += @(Join-Path -Path $PackagesFolder -ChildPath "en-us\$($Package.Filename)")
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

        # Mount the ISO so we can read the files.
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
        [XML] $Config
    )

    [System.Collections.Hashtable[]] $VMTemplates = @()
    [String] $VHDParentPath = $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath
    
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
                templatevhd = "$VHDParentPath\$VHDFilename"
            }
        } # Foreach
    } # If
    
    # Read the list of templates from the configuration file
    $Templates = $Config.labbuilderconfig.SelectNodes('templates').template
    foreach ($Template in $Templates)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'template' as the name.
        if ($Template.Name -eq 'template')
        {
            $ExceptionParameters = @{
                errorId = 'EmptyTemplateNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyTemplateNameError)
            }
            New-LabException @ExceptionParameters
        } # If
        [String] $SourceVHD = $Template.SourceVHD
        if ($SourceVHD)
        {
            # If this is a relative path, add it to the config path
            if (-not [System.IO.Path]::IsPathRooted($SourceVHD))
            {
                $SourceVHD = Join-Path `
                    -Path $Config.labbuilderconfig.settings.fullconfigpath `
                    -ChildPath $SourceVHD
            }

            # A Source VHD file was specified - does it exist?
            if (-not (Test-Path -Path $SourceVHD))
            {
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $Template.Name,$SourceVHD)
                }
                New-LabException @ExceptionParameters
            } # If
        } # If
        
        # Get the Template Default Startup Bytes
        [Int64] $MemoryStartupBytes = 0
        if ($Template.MemoryStartupBytes)
        {
            $MemoryStartupBytes = (Invoke-Expression $Template.MemoryStartupBytes)
        } # if

        # Does the template already exist in the list?
        [Boolean] $Found = $False
        foreach ($VMTemplate in $VMTemplates)
        {
            if ($VMTemplate.Name -eq $Template.Name)
            {
                # The template already exists - so don't add it again, but update the VHD path
                # if provided
                if ($Template.VHD)
                {
                    $VMTemplate.VHD = $Template.VHD
                    $VMTemplate.TemplateVHD = `
                        "$VHDParentPath\$([System.IO.Path]::GetFileName($Template.VHD))"
                } # If
                # Check that we do end up with a VHD filename in the template
                if (-not $VMTemplate.VHD)
                {
                    $ExceptionParameters = @{
                        errorId = 'EmptyTemplateVHDError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.EmptyTemplateVHDError `
                            -f $VMTemplate.Name)
                    }
                    New-LabException @ExceptionParameters
                } # If
                
                if ($SourceVHD)
                {
                    $VMTemplate.SourceVHD = $SourceVHD
                }
                $VMTemplate.InstallISO = $Template.InstallISO
                $VMTemplate.Edition = $Template.Edition
                $VMTemplate.AllowCreate = $Template.AllowCreate
                # Write any template specific default VM attributes
                if ($MemoryStartupBytes)
                {
                    $VMTemplate.MemoryStartupBytes = $MemoryStartupBytes
                } # If
                if ($Template.DynamicMemoryEnabled)
                {
                    $VMTemplate.DynamicMemoryEnabled = $Template.DynamicMemoryEnabled
                }
                if ($Template.ProcessorCount)
                {
                    $VMTemplate.ProcessorCount = $Template.ProcessorCount
                } # If
                if ($Template.ExposeVirtualizationExtensions)
                {
                    $VMTemplate.ExposeVirtualizationExtensions = $Template.ExposeVirtualizationExtensions
                }
                if ($Template.IntegrationServices)
                {
                    $VMTemplate.IntegrationServices = $Template.IntegrationServices
                }
                else
                {
                    $VMTemplate.IntegrationServices = $null
                }
                if ($Template.AdministratorPassword)
                {
                    $VMTemplate.AdministratorPassword = $Template.AdministratorPassword
                } # If
                if ($Template.ProductKey)
                {
                    $VMTemplate.ProductKey = $Template.ProductKey
                } # If
                if ($Template.TimeZone)
                {
                    $VMTemplate.TimeZone = $Template.TimeZone
                } # If
                if ($Template.OSType)
                {
                    $VMTemplate.OSType = $Template.OSType
                }
                Else
                {
                    $VMTemplate.OSType = 'Server'
                }

                $Found = $True
                Break
            } # If
        } # Foreach
        if (-not $Found)
        {
            # Check that we do end up with a VHD filename in the template
            if (-not $Template.VHD)
            {
                $ExceptionParameters = @{
                    errorId = 'EmptyTemplateVHDError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyTemplateVHDError `
                        -f $Template.Name)
                }
                New-LabException @ExceptionParameters
            } # If

            # The template wasn't found in the list of templates so add it
            $VMTemplates += @{
                name = $Template.Name;
                vhd = $Template.VHD;
                sourcevhd = $SourceVHD;
                templatevhd = "$VHDParentPath\$([System.IO.Path]::GetFileName($Template.VHD))";
                edition = $Template.Edition;
                allowcreate = $Template.AllowCreate;
                memorystartupbytes = $MemoryStartupBytes;
                dynamicmemoryenabled = if ($Template.DynamicMemoryEnabled)
                    {
                        $Template.DynamicMemoryEnabled
                    }
                    else
                    {
                        'Y'
                    };
                processorcount = $Template.ProcessorCount;
                exposevirtualizationextensions = if ($Template.ExposeVirtualizationExtensions)
                    {
						$Template.ExposeVirtualizationExtensions
					}
                    else
                    {
                        $null
                    };
                administratorpassword = $Template.AdministratorPassword;
                productkey = $Template.ProductKey;
                timezone = $Template.TimeZone;
                ostype = if ($Template.OSType)
                    {
                        $Template.OSType
                    }
                    else
                    {
                        'Server'
                    };
                 integrationservices = $Template.IntegrationServices;
            }
        } # If
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
    
    # Check each template exists in the templates folder for the
    # Lab. If it isn't, try and copy it from the SourceVHD
    # Location.
    foreach ($VMTemplate in $VMTemplates)
    {
        if (-not (Test-Path $VMTemplate.templatevhd))
        {
            # The template VHD isn't in the VHD Parent folder
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
                New-LabException @ExceptionParameters                
			}
            
			Write-Verbose -Message $($LocalizedData.CopyingTemplateSourceVHDMessage `
                -f $VMTemplate.sourcevhd,$VMTemplate.templatevhd)
            Copy-Item -Path $VMTemplate.sourcevhd -Destination $VMTemplate.templatevhd
            Write-Verbose -Message $($LocalizedData.OptimizingTemplateVHDMessage `
                -f $VMTemplate.templatevhd)
            Set-ItemProperty -Path $VMTemplate.templatevhd -Name IsReadOnly -Value $False
            Optimize-VHD -Path $VMTemplate.templatevhd -Mode Full
            Write-Verbose -Message $($LocalizedData.SettingTemplateVHDReadonlyMessage `
                -f $VMTemplate.templatevhd)
            Set-ItemProperty -Path $VMTemplate.templatevhd -Name IsReadOnly -Value $True
        }
        Else
        {
            Write-Verbose -Message $($LocalizedData.SkipTemplateVHDFileMessage `
                -f $VMTemplate.Name,$VMTemplate.templatevhd)
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
        if (Test-Path $VMTemplate.templatevhd)
        {
            Set-ItemProperty -Path $VMTemplate.templatevhd -Name IsReadOnly -Value $False
            Write-Verbose -Message $($LocalizedData.DeletingTemplateVHDMessage `
                -f $VMTemplate.templatevhd)
            Remove-Item -Path $VMTemplate.templatevhd -Confirm:$false -Force
        }
    }
} # Remove-LabVMTemplate
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   This function prepares all the files and modules necessary for a VM to be configured using
   Desired State Configuration (DSC).
.DESCRIPTION
   This funcion performs the following tasks in preparation for starting Desired State
   Configuration on a Virtual Machine:
     1. Ensures the folder structure for the Virtual Machine DSC files is available.
     2. Gets a list of all Modules required by the DSC configuration to be applied.
     3. Download and Install any missing DSC modules required for the DSC configuration.
     4. Copy all modules required for the DSC configuration to the VM folder.
     5. Cause a self-signed cetficiate to be created and downloaded on the Lab VM.
     6. Create a Networking DSC configuration file and ensure the DSC config file calss it.
     7. Create the MOF file from the config and an LCM config.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Set-LabVMDSCMOFFile -Config $Config -VM $VMs[0]
   Prepare the first VM in the Lab c:\mylab\config.xml for DSC configuration.
.OUTPUTS
   None.
#>
function Set-LabVMDSCMOFFile {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )

    [String] $DSCMOFFile = ''
    [String] $DSCMOFMetaFile = ''
  
    # Get the root path of the VM
    [String] $VMRootPath = Get-LabVMRootPath `
        -Config $Config `
        -VM $VM

    # Make sure the appropriate folders exist
    Initialize-LabVMPath `
        -VMPath $VMRootPath
    
    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = Get-LabVMFilesPath `
        -Config $Config `
        -VM $VM

    if (-not $VM.DSCConfigFile)
    {
        # This VM doesn't have a DSC Configuration
        return
    }

    # Make sure all the modules required to create the MOF file are installed
    $InstalledModules = Get-Module -ListAvailable
    Write-Verbose -Message $($LocalizedData.DSCConfigIdentifyModulesMessage `
        -f $VM.DSCConfigFile,$VM.Name)

    $DSCModules = Get-ModulesInDSCConfig -DSCConfigFile $($VM.DSCConfigFile)
    foreach ($ModuleName in $DSCModules)
    {
        if (($InstalledModules | Where-Object -Property Name -EQ $ModuleName).Count -eq 0)
        {
            # The Module isn't available on this computer, so try and install it
            Write-Verbose -Message $($LocalizedData.DSCConfigSearchingForModuleMessage `
                -f $VM.DSCConfigFile,$VM.Name,$ModuleName)

            $NewModule = Find-Module -Name $ModuleName
            if ($NewModule)
            {
                Write-Verbose -Message $($LocalizedData.DSCConfigInstallingModuleMessage `
                    -f $VM.DSCConfigFile,$VM.Name,$ModuleName)

                Try
                {
                    $NewModule | Install-Module
                }
                Catch
                {
                    $ExceptionParameters = @{
                        errorId = 'DSCModuleDownloadError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCModuleDownloadError `
                            -f $VM.DSCConfigFile,$VM.Name,$ModuleName)
                    }
                    New-LabException @ExceptionParameters
                }
            }
            Else
            {
                $ExceptionParameters = @{
                    errorId = 'DSCModuleDownloadError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCModuleDownloadError `
                        -f $VM.DSCConfigFile,$VM.Name,$ModuleName)
                }
                New-LabException @ExceptionParameters
            }
        } # If

        Write-Verbose -Message $($LocalizedData.DSCConfigSavingModuleMessage `
            -f $VM.DSCConfigFile,$VM.Name,$ModuleName)

        # Find where the module is actually stored
        [String] $ModulePath = ''
        foreach ($Path in $ENV:PSModulePath.Split(';'))
        {
            $ModulePath = Join-Path `
                -Path $Path `
                -ChildPath $ModuleName
            if (Test-Path -Path $ModulePath)
            {
                Break
            } # If
        } # Foreach
        if (-not (Test-Path -Path $ModulePath))
        {
            $ExceptionParameters = @{
                errorId = 'DSCModuleNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCModuleNotFoundError `
                    -f $VM.DSCConfigFile,$VM.Name,$ModuleName)
            }
            New-LabException @ExceptionParameters
        }
        Copy-Item `
            -Path $ModulePath `
            -Destination (Join-Path -Path $VMLabBuilderFiles -ChildPath 'DSC Modules\') `
            -Recurse -Force
    } # Foreach

    if (-not (New-LabVMSelfSignedCert -Config $Config -VM $VM))
    {
        $ExceptionParameters = @{
            errorId = 'CertificateCreateError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.CertificateCreateError `
                -f $VM.Name)
        }
        New-LabException @ExceptionParameters
    }
    
    # Remove any old self-signed certifcates for this VM
    Get-ChildItem -Path cert:\LocalMachine\My `
        | Where-Object { $_.FriendlyName -eq $Script:DSCCertificateFriendlyName } `
        | Remove-Item
    
    # Add the VM Self-Signed Certificate to the Local Machine store and get the Thumbprint	
    [String] $CertificateFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath $Script:DSCEncryptionCert
    $Certificate = Import-Certificate `
        -FilePath $CertificateFile `
        -CertStoreLocation 'Cert:LocalMachine\My'
    [String] $CertificateThumbprint = $Certificate.Thumbprint

    # Set the predicted MOF File name
    $DSCMOFFile = Join-Path `
        -Path $ENV:Temp `
        -ChildPath "$($VM.ComputerName).mof"
    $DSCMOFMetaFile = ([System.IO.Path]::ChangeExtension($DSCMOFFile,'meta.mof'))
        
    # Generate the LCM MOF File
    Write-Verbose -Message $($LocalizedData.DSCConfigCreatingLCMMOFMessage `
        -f $DSCMOFMetaFile,$VM.Name)

    $null = ConfigLCM `
        -OutputPath $($ENV:Temp) `
        -ComputerName $($VM.ComputerName) `
        -Thumbprint $CertificateThumbprint
    if (-not (Test-Path -Path $DSCMOFMetaFile))
    {
        $ExceptionParameters = @{
            errorId = 'DSCConfigMetaMOFCreateError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.DSCConfigMetaMOFCreateError `
                -f $VM.Name)
        }
        New-LabException @ExceptionParameters
    } # If

    # A DSC Config File was provided so create a MOF File out of it.
    Write-Verbose -Message $($LocalizedData.DSCConfigCreatingMOFMessage `
        -f $VM.DSCConfigFile,$VM.Name)
    
    # Now create the Networking DSC Config file
    [String] $NetworkingDSCConfig = Get-LabNetworkingDSCFile `
        -Config $Config -VM $VM
    [String] $NetworkingDSCFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'DSCNetworking.ps1'
    $null = Set-Content `
        -Path $NetworkingDSCFile `
        -Value $NetworkingDSCConfig
    . $NetworkingDSCFile
    [String] $DSCFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'DSC.ps1'
    [String] $DSCContent = Get-Content `
        -Path $VM.DSCConfigFile `
        -Raw
    
    if (-not ($DSCContent -match 'Networking Network {}'))
    {
        # Add the Networking Configuration item to the base DSC Config File
        # Find the location of the line containing "Node $AllNodes.NodeName {"
        [String] $Regex = '\s*Node\s.*{.*'
        $Matches = [regex]::matches($DSCContent, $Regex, 'IgnoreCase')
        if ($Matches.Count -eq 1)
        {
            $DSCContent = $DSCContent.`
                Insert($Matches[0].Index+$Matches[0].Length,"`r`nNetworking Network {}`r`n")
        }
        Else
        {
            $ExceptionParameters = @{
                errorId = 'DSCConfigMoreThanOneNodeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCConfigMoreThanOneNodeError `
                    -f $VM.DSCConfigFile,$VM.Name)
            }
            New-LabException @ExceptionParameters
        } # If
    } # If
    
    # Save the DSC Content
    $null = Set-Content `
        -Path $DSCFile `
        -Value $DSCContent `
        -Force

    # Hook the Networking DSC File into the main DSC File
    . $DSCFile

    [String] $DSCConfigName = $VM.DSCConfigName
    
	Write-Verbose "DSC Config name = $DSCConfigname"

    # Generate the Configuration Nodes data that always gets passed to the DSC configuration.
    [String] $ConfigData = @"
@{
    AllNodes = @(
        @{
            NodeName = '$($VM.ComputerName)'
            CertificateFile = '$CertificateFile'
            Thumbprint = '$CertificateThumbprint' 
            LocalAdminPassword = '$($VM.administratorpassword)'
            $($VM.DSCParameters)
        }
    )
}
"@
    # Write it to a temp file
    [String] $ConfigFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'DSCConfigData.psd1'
    if (Test-Path -Path $ConfigFile)
    {
        $null = Remove-Item `
            -Path $ConfigFile `
            -Force
    }
    Set-Content -Path $ConfigFile -Value $ConfigData
        
    # Generate the MOF file from the configuration
    $null = & "$DSCConfigName" -OutputPath $($ENV:Temp) -ConfigData $ConfigFile
    if (-not (Test-Path -Path $DSCMOFFile))
    {
        $ExceptionParameters = @{
            errorId = 'DSCConfigMOFCreateError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.DSCConfigMOFCreateError `
                -f $VM.DSCConfigFile,$VM.Name)
        }
        New-LabException @ExceptionParameters
    } # If

    # Remove the VM Self-Signed Certificate from the Local Machine Store
    $null = Remove-Item `
        -Path "Cert:LocalMachine\My\$CertificateThumbprint" `
        -Force

    Write-Verbose -Message $($LocalizedData.DSCConfigMOFCreatedMessage `
        -f $VM.DSCConfigFile,$VM.Name)

    # Copy the files to the LabBuilder Files folder
    $null = Copy-Item `
        -Path $DSCMOFFile `
        -Destination (Join-Path `
            -Path $VMLabBuilderFiles `
            -ChildPath "$($VM.ComputerName).mof") `
        -Force

    if (-not $VM.DSCMOFFile)
    {
        # Remove Temporary files created by DSC
        $null = Remove-Item `
            -Path $DSCMOFFile `
            -Force
    }

    if (Test-Path -Path $DSCMOFMetaFile)
    {
        $null = Copy-Item `
            -Path $DSCMOFMetaFile `
            -Destination (Join-Path `
                -Path $VMLabBuilderFiles `
                -ChildPath "$($VM.ComputerName).meta.mof") `
            -Force
        if (-not $VM.DSCMOFFile)
        {
            # Remove Temporary files created by DSC
            $null = Remove-Item `
                -Path $DSCMOFMetaFile `
                -Force
        }
    } # If
} # Set-LabVMDSCMOFFile
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   This function prepares the PowerShell scripts used for starting up DSC on a VM.
.DESCRIPTION
   Two PowerShell scripts will be created by this function in the LabBuilder Files
   folder of the VM:
     1. StartDSC.ps1 - the script that is called automatically to start up DSC.
     2. StartDSCDebug.ps1 - a debug script that will start up DSC in debug mode.
   These scripts will contain code to perform the following operations:
     1. Configure the names of the Network Adapters so that they will match the 
        names in the DSC Configuration files.
     2. Enable/Disable DSC Event Logging.
     3. Apply Configuration to the Local Configuration Manager.
     4. Start DSC.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Set-LabVMDSCMOFFile -Config $Config -VM $VMs[0]
   Prepare the first VM in the Lab c:\mylab\config.xml for DSC start up.
.OUTPUTS
   None.
#>
function Set-LabVMDSCStartFile {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )

    [String] $DSCStartPs = ''

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = Get-LabVMFilesPath `
        -Config $Config `
        -VM $VM
        
    # Relabel the Network Adapters so that they match what the DSC Networking config will use
    # This is because unfortunately the Hyper-V Device Naming feature doesn't work.
    [String] $ManagementSwitchName = `
        ('LabBuilder Management {0}' -f $Config.labbuilderconfig.name)
    $Adapters = @(($VM.Adapters).Name)
    $Adapters += @($ManagementSwitchName)

    foreach ($Adapter in $Adapters)
    {
        $NetAdapter = Get-VMNetworkAdapter -VMName $($VM.Name) -Name $Adapter
        if (-not $NetAdapter)
        {
            $ExceptionParameters = @{
                errorId = 'NetworkAdapterNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.NetworkAdapterNotFoundError `
                    -f $Adapter,$VM.Name)
            }
            New-LabException @ExceptionParameters
        } # If
        $MacAddress = $NetAdapter.MacAddress
        if (-not $MacAddress)
        {
            $ExceptionParameters = @{
                errorId = 'NetworkAdapterBlankMacError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.NetworkAdapterBlankMacError `
                    -f $Adapter,$VM.Name)
            }
            New-LabException @ExceptionParameters
        } # If
        $DSCStartPs += @"
Get-NetAdapter ``
    | Where-Object { `$_.MacAddress.Replace('-','') -eq '$MacAddress' } ``
    | Rename-NetAdapter -NewName '$($Adapter)'

"@
    } # Foreach

    # Enable DSC logging (as long as it hasn't been already)
    [String] $Logging = ($VM.DSCLogging).ToString() 
    $DSCStartPs += @"
`$Result = & "wevtutil.exe" get-log "Microsoft-Windows-Dsc/Analytic"
if (-not (`$Result -like '*enabled: true*')) {
    & "wevtutil.exe" set-log "Microsoft-Windows-Dsc/Analytic" /q:true /e:$Logging
}
`$Result = & "wevtutil.exe" get-log "Microsoft-Windows-Dsc/Debug"
if (-not (`$Result -like '*enabled: true*')) {
    & "wevtutil.exe" set-log "Microsoft-Windows-Dsc/Debug" /q:true /e:$Logging
}

"@

    # Start the actual DSC Configuration
    $DSCStartPs += @"
Set-DscLocalConfigurationManager ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" ``
    -Verbose  *>> `"$($ENV:SystemRoot)\Setup\Scripts\DSC.log`"
Start-DSCConfiguration ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" ``
    -Force ``
    -Verbose  *>> `"$($ENV:SystemRoot)\Setup\Scripts\DSC.log`"

"@
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'StartDSC.ps1') `
        -Value $DSCStartPs -Force

    $DSCStartPsDebug = @"
Set-DscLocalConfigurationManager ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" ``
    -Verbose
Start-DSCConfiguration ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" ``
    -Force -Debug -Wait ``
    -Verbose
"@
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'StartDSCDebug.ps1') `
        -Value $DSCStartPsDebug -Force
} # Set-LabVMDSCStartFile
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   This function prepares all files require to configure a VM using Desired State
   Configuration (DSC).
.DESCRIPTION
   Calling this function will cause the LabBuilder folder to be populated/updated
   with all files required to configure a Virtual Machine with DSC.
   This includes:
     1. Required DSC Resouce Modules.
     2. DSC Credential Encryption certificate.
     3. DSC Configuration files.
     4. DSC MOF Files for general config and for LCM config.
     5. Start up scripts.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Initialize-LabVMDSC -Config $Config -VM $VMs[0]
   Prepares all files required to start up Desired State Configuration for the
   first VM in the Lab c:\mylab\config.xml for DSC start up.
.OUTPUTS
   None.
#>
function Initialize-LabVMDSC {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )

    # Are there any DSC Settings to manage?
    Set-LabVMDSCMOFFile -Config $Config -VM $VM

    # Generate the DSC Start up Script file
    Set-LabVMDSCStartFile -Config $Config -VM $VM
} # Initialize-LabVMDSC
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Uploads prepared Modules and MOF files to a VM and starts up Desired State
   Configuration (DSC) on it.
.DESCRIPTION
   This function will perform the following tasks:
     1. Connect to the VM via remoting.
     2. Upload the DSC and LCM MOF files to the c:\windows\setup\scripts folder of the VM.
     3. Upload DSC Start up scripts to the c:\windows\setup\scripts folder of the VM.
     4. Upload all required modules to the c:\program files\WindowsPowerShell\Modules\ folder
        of the VM.
     5. Invoke the StartDSC.ps1 script on the VM to start DSC processing.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.PARAMETER Timeout
   The maximum amount of time that this function can take to perform DSC start-up.
   If the timeout is reached before the process is complete an error will be thrown.
   The timeout defaults to 300 seconds.   
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Start-LabVMDSC -Config $Config -VM $VMs[0]
   Starts up Desired State Configuration for the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
   None.
#>
function Start-LabVMDSC {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM,

        [Int] $Timeout = 300
    )
    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False
    [Boolean] $ConfigCopyComplete = $False
    [Boolean] $ModuleCopyComplete = $False
    
    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = Get-LabVMFilesPath `
        -Config $Config `
        -VM $VM

    While ((-not $Complete) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
    {
        # Connect to the VM
        $Session = Connect-LabVM -VM $VM -ErrorAction Continue
        
        # Failed to connnect to the VM
        if (! $Session)
        {
            $ExceptionParameters = @{
                errorId = 'DSCInitializationError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.DSCInitializationError `
                    -f $VM.Name)
            }
            New-LabException @ExceptionParameters            
            return
        }
        
        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $ConfigCopyComplete))
        {
            $CopyParameters = @{
                Destination = 'c:\Windows\Setup\Scripts'
                ToSession = $Session
                Force = $True
                ErrorAction = 'Stop'
            }

            # Connection has been made OK, upload the DSC files
            While ((-not $ConfigCopyComplete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                Try
                {
                    Write-Verbose -Message $($LocalizedData.CopyingFilesToVMMessage `
                        -f $VM.Name,'DSC')

                    $null = Copy-Item `
                        @CopyParameters `
                        -Path (Join-Path `
                            -Path $VMLabBuilderFiles `
                            -ChildPath "$($VM.ComputerName).mof")
                    if (Test-Path `
                        -Path "$VMLabBuilderFiles\$($VM.ComputerName).meta.mof")
                    {
                        $null = Copy-Item `
                            @CopyParameters `
                            -Path (Join-Path `
                                -Path $VMLabBuilderFiles `
                                -ChildPath "$($VM.ComputerName).meta.mof")
                    } # If
                    $null = Copy-Item `
                        @CopyParameters `
                        -Path (Join-Path `
                            -Path $VMLabBuilderFiles `
                            -ChildPath 'StartDSC.ps1')
                    $null = Copy-Item `
                        @CopyParameters `
                        -Path (Join-Path `
                            -Path $VMLabBuilderFiles `
                            -ChildPath 'StartDSCDebug.ps1')
                    $ConfigCopyComplete = $True
                }
                Catch
                {
                    Write-Verbose -Message $($LocalizedData.CopyingFilesToVMFailedMessage `
                        -f $VM.Name,'DSC',$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # Try
            } # While
        } # If

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $ConfigCopyComplete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            if ($Session)
            {
                Remove-PSSession -Session $Session
            }

            $ExceptionParameters = @{
                errorId = 'DSCInitializationError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.DSCInitializationError `
                    -f $VM.Name)
            }
            New-LabException @ExceptionParameters
        } # If

        # Upload any required modules to the VM
        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $ModuleCopyComplete))
        {
            $DSCModules = Get-ModulesInDSCConfig -DSCConfigFile $($VM.DSCConfigFile)
            foreach ($ModuleName in $DSCModules)
            {
                try
                {
                    Write-Verbose -Message $($LocalizedData.CopyingFilesToVMMessage `
                        -f $VM.Name,"DSC Module $ModuleName")

                    $null = Copy-Item `
                        -Path (Join-Path `
                            -Path $VMLabBuilderFiles `
                            -ChildPath "DSC Modules\$ModuleName\") `
                        -Destination "$($env:ProgramFiles)\WindowsPowerShell\Modules\" `
                        -ToSession $Session `
                        -Force `
                        -Recurse `
                        -ErrorAction Stop
                }
                catch
                {
                    Write-Verbose -Message $($LocalizedData.CopyingFilesToVMFailedMessage `
                        -f $VM.Name,"DSC Module $ModuleName",$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # Try
            } # Foreach
            $ModuleCopyComplete = $True
        } # If

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $ModuleCopyComplete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            if ($Session)
            {
                Remove-PSSession -Session $Session
            }

            $ExceptionParameters = @{
                errorId = 'DSCInitializationError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.DSCInitializationError `
                    -f $VM.Name)
            }
            New-LabException @ExceptionParameters
        }

        # Finally, Start DSC up!
        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and ($ConfigCopyComplete) `
            -and ($ModuleCopyComplete))
        {
            Write-Verbose -Message $($LocalizedData.StartingDSCMessage `
                -f $VM.Name)

            Invoke-Command -Session $Session { c:\windows\setup\scripts\StartDSC.ps1 }
            $Complete = $True
        } # If
    } # While
} # Start-LabVMDSC
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Assembles the content of a Unattend XML file that should be used to initialize
   Windows on the specified VM.
.DESCRIPTION
   This function will return the content of a standard Windows Unattend XML file
   that can be written to an VHD containing a copy of Windows that is still in
   OOBE mode.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Get-LabUnattendFile -Config $Config -VM $VMs[0]
   Returns the content of the Unattend File for the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
   The content of the Unattend File for the VM.
#>
function Get-LabUnattendFile {
    [CmdLetBinding()]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )
    if ($VM.UnattendFile)
    {
        [String] $UnattendContent = Get-Content -Path $VM.UnattendFile
    }
    Else
    {
        [String] $DomainName = $Config.labbuilderconfig.settings.domainname
        [String] $Email = $Config.labbuilderconfig.settings.email
        $UnattendContent = [String] @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="offlineServicing">
        <component name="Microsoft-Windows-LUA-Settings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <EnableLUA>false</EnableLUA>
        </component>
    </settings>
    <settings pass="generalize">
        <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipRearm>1</SkipRearm>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0409:00000409</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipAutoActivation>true</SkipAutoActivation>
        </component>
        <component name="Microsoft-Windows-SQMApi" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <CEIPEnabled>0</CEIPEnabled>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$($VM.ComputerName)</ComputerName>
        </component>
"@
		

        if ($VM.OSType -eq 'Client')
        {
            $UnattendContent += @"
            <component name="Microsoft-Windows-Deployment" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <RunSynchronous>
                    <RunSynchronousCommand wcm:action="add">
                        <Order>1</Order>
                        <Path>net user administrator /active:yes</Path>
                    </RunSynchronousCommand>
                </RunSynchronous>
            </component>

"@
        } # If
        $UnattendContent += @"
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <UserAccounts>
               <AdministratorPassword>
                  <Value>$($VM.AdministratorPassword)</Value>
                  <PlainText>true</PlainText>
               </AdministratorPassword>
            </UserAccounts>
            <RegisteredOrganization>$($DomainName)</RegisteredOrganization>
            <RegisteredOwner>$($Email)</RegisteredOwner>
            <DisableAutoDaylightTimeSet>false</DisableAutoDaylightTimeSet>
            <TimeZone>$($VM.TimeZone)</TimeZone>
        </component>
        <component name="Microsoft-Windows-ehome-reg-inf" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="NonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RestartEnabled>true</RestartEnabled>
        </component>
        <component name="Microsoft-Windows-ehome-reg-inf" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="NonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RestartEnabled>true</RestartEnabled>
        </component>
    </settings>
</unattend>
"@
    }
    Return $UnattendContent
} # Get-LabUnattendFile
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
   Prepares the the files for initializing a new VM.
.DESCRIPTION
   This function creates the following files in the LabBuilder Files for the a VM in preparation
   for them to be applied to the VM VHD before it is booted up for the first time:
     1. Unattend.xml - a Windows Unattend.xml file.
     2. SetupComplete.cmd - the command file that gets run after the Windows OOBE is complete.
     3. SetupComplete.ps1 - this PowerShell script file that is run at the the end of the
                            SetupComplete.cmd.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Set-LabVMInitializationFiles -Config $Config -VM $VMs[0]
   Prepare the first VM in the Lab c:\mylab\config.xml for initial boot.
.OUTPUTS
   None.
#>
function Set-LabVMInitializationFiles {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = Get-LabVMFilesPath `
        -Config $Config `
        -VM $VM
    
    # Generate an unattended setup file
    [String] $UnattendFile = Get-LabUnattendFile -Config $Config -VM $VM       
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'Unattend.xml') `
        -Value $UnattendFile -Force

    # Assemble the SetupComplete.* scripts.
    [String] $GetCertPs = Get-LabGetCertificatePs -Config $Config -VM $VM
    [String] $SetupCompleteCmd = ''
    [String] $SetupCompletePs = @"
Add-Content ``
    -Path "C:\WINDOWS\Setup\Scripts\SetupComplete.log" ``
    -Value 'SetupComplete.ps1 Script Started...' ``
    -Encoding Ascii
$GetCertPs
Add-Content ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'Certificate identified and saved to C:\Windows\$Script:DSCEncryptionCert ...' ``
    -Encoding Ascii
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Add-Content ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'Windows Remoting Enabled ...' ``
    -Encoding Ascii
"@
    if ($VM.SetupComplete)
    {
        [String] $SetupComplete = $VM.SetupComplete
        if (-not (Test-Path -Path $SetupComplete))
        {
            $ExceptionParameters = @{
                errorId = 'SetupCompleteScriptMissingError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.SetupCompleteScriptMissingError `
                    -f $VM.name,$SetupComplete)
            }
            New-LabException @ExceptionParameters
        }
        [String] $Extension = [System.IO.Path]::GetExtension($SetupComplete)
        Switch ($Extension.ToLower())
        {
            '.ps1'
            {
                $SetupCompletePs += Get-Content -Path $SetupComplete
                Break
            } # 'ps1'
            '.cmd'
            {
                $SetupCompleteCmd += Get-Content -Path $SetupComplete
                Break
            } # 'cmd'
        } # Switch
    } # If

    # Write out the CMD Setup Complete File
    $SetupCompleteCmd = @"
@echo SetupComplete.cmd Script Started... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log`r
$SetupCompleteCmd
Timeout 30
powerShell.exe -ExecutionPolicy Unrestricted -Command `"%SYSTEMROOT%\Setup\Scripts\SetupComplete.ps1`" `r
@echo SetupComplete.cmd Script Finished... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
@echo Initial Setup Completed - this file indicates that setup has completed. >> %SYSTEMROOT%\Setup\Scripts\InitialSetupCompleted.txt
"@
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.cmd') `
        -Value $SetupCompleteCmd -Force

    # Write out the PowerShell Setup Complete file
    $SetupCompletePs = @"
Add-Content ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'SetupComplete.ps1 Script Started...' ``
    -Encoding Ascii
$SetupCompletePs
Add-Content ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'SetupComplete.ps1 Script Finished...' ``
    -Encoding Ascii
"@
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.ps1') `
        -Value $SetupCompletePs -Force

} # Set-LabVMInitializationFiles
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Initialized a VM VHD for first boot by applying any required files to the image.
.DESCRIPTION
   This function mounts a VM boot VHD image and applies the following files from the
   LabBuilder Files folder to it:
     1. Unattend.xml - a Windows Unattend.xml file.
     2. SetupComplete.cmd - the command file that gets run after the Windows OOBE is complete.
     3. SetupComplete.ps1 - this PowerShell script file that is run at the the end of the
                            SetupComplete.cmd.
   The files should have already been prepared by the Set-LabVMInitializationFiles function.
   The VM VHD image should contain an installed copy of Windows still in OOBE mode.
   
   This function also applies downloads and applies and optional MSU update files from
   a web site if specified in the VM declaration in the configuration.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Initialize-LabVMImage `
       -Config $Config `
       -VM $VMs[0] `
       -VMBootDiskPath $BootVHD[0]
   Prepare the boot VHD in for the first VM in the Lab c:\mylab\config.xml for initial boot.
.OUTPUTS
   None.
#>

function Initialize-LabVMImage {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM,

        [Parameter(Mandatory)]
        [String] $VMBootDiskPath
    )

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = Get-LabVMFilesPath `
        -Config $Config `
        -VM $VM

    # Mount the VMs Boot VHD so that files can be loaded into it
    Write-Verbose -Message $($LocalizedData.MountingVMBootDiskMessage `
        -f $VM.Name,$VMBootDiskPath)
      
    [String] $MountPoint = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'Mount'

    if (! (Test-Path -Path $MountPoint -PathType Container))
    {
        $null = New-Item `
            -Path $MountPoint `
            -ItemType Directory
    }
    $null = Mount-WindowsImage `
        -ImagePath $VMBootDiskPath `
        -Path $MountPoint `
        -Index 1

    # Copy the WMF 5.0 Installer to the VM in case it is needed
    # Write-Verbose -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
    #    -f $VM.Name,'MSU','WMF 5.0')
    # $null = Add-WindowsPackage -PackagePath $Script:WMF5InstallerPath -Path $MountPoint

    # Apply any additional MSU Updates
    foreach ($URL in $VM.InstallMSU)
    {
        $MSUFilename = $URL.Substring($URL.LastIndexOf('/') + 1)
        $MSUPath = Join-Path `
			-Path $Script:WorkingFolder `
			-ChildPath $MSUFilename

        if (-not (Test-Path -Path $MSUPath))
        {
            Write-Verbose -Message $($LocalizedData.DownloadingVMBootDiskFileMessage `
                -f $VM.Name,'MSU',$URL)
            Invoke-WebRequest `
				-Uri $URL `
				-OutFile $MSUPath
        } # If

        # Once downloaded apply the update
        Write-Verbose -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
            -f $VM.Name,'MSU',$URL)
        $null = Add-WindowsPackage `
			-PackagePath $MSUPath `
			-Path $MountPoint
    } # Foreach

    # Create the scripts folder where setup scripts will be put
    $null = New-Item `
		-Path "$MountPoint\Windows\Setup\Scripts" `
		-ItemType Directory

    # Apply an unattended setup file
    Write-Verbose -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Unattend','Unattend.xml')

    if (! (Test-Path -Path "$MountPoint\Windows\Panther" -PathType Container))
    {
        Write-Verbose -Message $($LocalizedData.CreatingVMBootDiskPantherFolderMessage `
            -f $VM.Name)

        $null = New-Item `
            -Path "$MountPoint\Windows\Panther" `
            -ItemType Directory
    }
    $null = Copy-Item `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'Unattend.xml') `
        -Destination "$MountPoint\Windows\Panther\Unattend.xml" `
        -Force

    # Apply the CMD Setup Complete File
    Write-Verbose -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Setup Complete CMD','SetupComplete.cmd')
    $null = Copy-Item `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.cmd') `
        -Destination "$MountPoint\Windows\Setup\Scripts\SetupComplete.cmd" `
        -Force

    # Apply the PowerShell Setup Complete file
    Write-Verbose -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Setup Complete PowerShell','SetupComplete.ps1')
    $null = Copy-Item `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.ps1') `
        -Destination "$MountPoint\Windows\Setup\Scripts\SetupComplete.ps1" `
        -Force


    # Apply the Certificate Generator script
    Write-Verbose -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Certificate Create Script',$Script:CertGenPS1Filename)
    $null = Copy-Item `
        -Path $Script:CertGenPS1Path `
        -Destination "$MountPoint\Windows\Setup\Scripts\$($Script:CertGenPS1Filename)"`
        -Force
        
    # Dismount the VHD in preparation for boot
    Write-Verbose -Message $($LocalizedData.DismountingVMBootDiskMessage `
        -f $VM.Name,$VMBootDiskPath)
    $null = Dismount-WindowsImage -Path $MountPoint -Save
    $null = Remove-Item -Path $MountPoint -Recurse -Force
} # Initialize-LabVMImage
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
    [String] $VMPath = $Config.labbuilderconfig.settings.vmpath
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
            New-LabException @ExceptionParameters
        } # If
        if (-not $VM.Template) 
		{
            $ExceptionParameters = @{
                errorId = 'VMTemplateNameEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                    -f $VM.name)
            }
            New-LabException @ExceptionParameters
        } # If

        # Find the template that this VM uses and get the VHD Path
        [String] $TemplateVHDPath =''
        [Boolean] $Found = $false
        foreach ($VMTemplate in $VMTemplates) {
            if ($VMTemplate.Name -eq $VM.Template) {
                $TemplateVHDPath = $VMTemplate.templatevhd
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
            New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
            }
            if (-not $VMAdapter.SwitchName) 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                        -f $VM.name,$VMAdapter.name)
                }
                New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
            }
            # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
            # if it doesn't contain a root (e.g. c:\)
            if (! [System.IO.Path]::IsPathRooted($Vhd))
            {
                $Vhd = Join-Path -Path $VMPath -ChildPath "$($VM.Name)\Virtual Hard Disks\$Vhd"
            }
            
            # Does the VHD already exist?
            $Exists = Test-Path -Path $Vhd

            # Get the Parent VHD and check it exists if passed
            [String] $ParentVhd = $VMDataVhd.ParentVHD
            if ($ParentVhd)
            {
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
                    New-LabException @ExceptionParameters
                }
            }

            # Get the Source VHD and check it exists if passed
            [String] $SourceVhd = $VMDataVhd.SourceVHD
            if ($SourceVhd)
            {
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
                    New-LabException @ExceptionParameters
                }
            }

            # Get the disk size if provided
            [Int64] $Size = $null
            if ($VMDataVhd.Size)
            {
                $Size = (Invoke-Expression $VMDataVhd.size)         
            }

            [Boolean] $Shared = ($VMDataVhd.shared -eq 'Y')

            # Validate the data disk type specified
            [String] $Type = $VMDataVhd.type
            if ($type)
            {
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
                            New-LabException @ExceptionParameters
                        }
                        if ($Shared)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskSharedDifferencingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                                    -f $VM.Name,$VHD)
                            }
                            New-LabException @ExceptionParameters                            
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
                        New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
            }
            
            # Should the Source VHD be moved rather than copied
            [Boolean] $MoveSourceVHD = ($VMDataVhd.MoveSourceVHD -eq 'Y')
            if ($MoveSourceVHD)
            {
                if (! $SourceVHD)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDIfMoveError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                            -f $VM.Name,$VHD)
                    }
                    New-LabException @ExceptionParameters                        
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
                New-LabException @ExceptionParameters                    
            }
            
            $DataVhds += @{
                vhd = $Vhd;
                type = $Type;
                size = $Size
                sourcevhd = $SourceVHD;
                parentvhd = $ParentVHD;
                shared = $Shared;
                supportPR = $SupportPR;
                moveSourceVHD = $MoveSourceVHD;
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
                New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
            } # If
            if (-not (Test-Path $SetupComplete))
            {
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                        -f $VM.name,$SetupComplete)
                }
                New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
            }

            if (-not (Test-Path $DSCConfigFile))
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                        -f $VM.name,$DSCConfigFile)
                }
                New-LabException @ExceptionParameters
            }
            if (-not $VM.DSC.ConfigName)
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                        -f $VM.name)
                }
                New-LabException @ExceptionParameters
            }
        }
        
        # Load the DSC Parameters
        [String] $DSCParameters = ''
        if ($VM.DSC.Parameters)
        {
            # Correct any LFs into CRLFs to ensure the new line format is the same when
            # pulled from the XML.
            $DSCParameters = ($VM.DSC.Parameters -replace "`r`n","`n") -replace "`n","`r`n"
        } # If

        # Load the DSC Parameters
        [Boolean] $DSCLogging = $False
        if ($VM.DSC.Logging -eq 'Y')
        {
            $DSCLogging = $True
        } # If

        # Get the Memory Startup Bytes (from the template or VM)
        [Int64] $MemoryStartupBytes = 1GB
        if ($VMTemplate.memorystartupbytes)
        {
            $MemoryStartupBytes = $VMTemplate.memorystartupbytes
        } # If
        if ($VM.memorystartupbytes)
        {
            $MemoryStartupBytes = (Invoke-Expression $VM.memorystartupbytes)
        } # If

        # Get the Dynamic Memory Enabled flag
        [String] $DynamicMemoryEnabled = ''
        if ($VMTemplate.DynamicMemoryEnabled)
        {
            $DynamicMemoryEnabled = $VMTemplate.DynamicMemoryEnabled
        }
        if ($VM.DynamicMemoryEnabled)
        {
            $DynamicMemoryEnabled = $VM.DynamicMemoryEnabled
        } # If        
        
        # Get the Memory Startup Bytes (from the template or VM)
        [Int] $ProcessorCount = 1
        if ($VMTemplate.processorcount) 
		{
            $ProcessorCount = $VMTemplate.processorcount
        } # If
        if ($VM.processorcount) 
		{
            $ProcessorCount = (Invoke-Expression $VM.processorcount)
        } # If

        # Get the Expose Virtualization Extensions flag
        [String] $ExposeVirtualizationExtensions = $null
        if ($VMTemplate.ExposeVirtualizationExtensions)
			{
			$ExposeVirtualizationExtensions=$VMTemplate.ExposeVirtualizationExtensions
			} # If

        if ($VM.ExposeVirtualizationExtensions)
        {
            $ExposeVirtualizationExtensions = $VM.ExposeVirtualizationExtensions
        } # If
        
        # Get the Integration Services flags
        if ($VMTemplate.IntegrationServices -ne $null)
        {
            $IntegrationServices = $VMTemplate.IntegrationServices
        }
        if ($VM.IntegrationServices -ne $null)
        {
            $IntegrationServices = $VM.IntegrationServices
        } # If
        
        # Get the Administrator password (from the template or VM)
        [String] $AdministratorPassword = ''
        if ($VMTemplate.administratorpassword) 
		{
            $AdministratorPassword = $VMTemplate.administratorpassword
        } # If
        if ($VM.administratorpassword) 
		{
            $AdministratorPassword = $VM.administratorpassword
        } # If

        # Get the Product Key (from the template or VM)
        [String] $ProductKey = ''
        if ($VMTemplate.productkey) 
		{
            $ProductKey = $VMTemplate.productkey
        } # If
        if ($VM.productkey) 
		{
            $ProductKey = $VM.productkey
        } # If

        # Get the Timezone (from the template or VM)
        [String] $Timezone = 'Pacific Standard Time'
        if ($VMTemplate.timezone) 
		{
            $Timezone = $VMTemplate.timezone
        } # If
        if ($VM.timezone) 
		{
            $Timezone = $VM.timezone
        } # If

        # Get the OS Type
        if ($VMTemplate.ostype) 
		{
            $OSType = $VMTemplate.ostype
        } 
		Else 
		{
            $OSType = 'Server'
        } # If

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
            TemplateVHD = $TemplateVHDPath;
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
            InstallMSU = $InstallMSU;
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
    [String] $VMPath = $Config.labbuilderconfig.SelectNodes('settings').vmpath
    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False

    # Load path variables
    [String] $VMRootPath = Join-Path `
        -Path $VMPath `
        -ChildPath $VM.Name

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = Join-Path `
        -Path $VMRootPath `
        -ChildPath 'LabBuilder Files'


    while ((-not $Complete) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
    {
        $Session = Connect-LabVM -VM $VM -ErrorAction Continue
        
        # Failed to connnect to the VM
        if (! $Session)
        {
            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            New-LabException @ExceptionParameters
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
            New-LabException @ExceptionParameters
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
    [String] $VMPath = $Config.labbuilderconfig.SelectNodes('settings').vmpath
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False

    # Load path variables
    [String] $VMRootPath = Join-Path `
        -Path $VMPath `
        -ChildPath $VM.Name

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = Join-Path `
        -Path $VMRootPath `
        -ChildPath 'LabBuilder Files'

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
        $Session = Connect-LabVM -VM $VM -ErrorAction Continue

        # Failed to connnect to the VM
        if (! $Session)
        {
            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            New-LabException @ExceptionParameters
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
            New-LabException @ExceptionParameters
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
        New-LabException @ExceptionParameters
    }
    return $IPAddress
} # Get-LabVMManagementIPAddress
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Gets the path to the LabBuilder root folder that a VM uses.
.DESCRIPTION
   This function will return the path where all files can be found
   for the specified VM.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   $Path = Get-LabVMRootPath -Config $Config -VM $VM[0]
.OUTPUTS
   The Path to the LabBuilder Files.
#>
function Get-LabVMRootPath {
    [CmdLetBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )
    [String] $VMPath = $Config.labbuilderconfig.settings.vmpath 
    [String] $VMRootPath = Join-Path `
        -Path $VMPath `
        -ChildPath $VM.Name
    return $VMRootPath
} # Get-LabVMRootPath
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Gets the path to the LabBuilder files folder that a VM uses.
.DESCRIPTION
   This function will return the path that LabBuilder specific files can be found
   for the specified VM.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   $Path = Get-LabVMFilesPath -Config $Config -VM $VM[0]
.OUTPUTS
   The Path to the LabBuilder Files.
#>
function Get-LabVMFilesPath {
    [CmdLetBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )
    [String] $VMRootPath = Get-LabVMRootPath `
        -Config $Config `
        -VM $VM
    [String] $VMFilesPath = Join-Path `
        -Path $VMRootPath `
        -ChildPath 'LabBuilder Files'
    return $VMFilesPath
} # Get-LabVMFilesPath
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

    [String] $VMPath = $Config.labbuilderconfig.settings.vmpath

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
        if (-not (Test-Path "$VMPath\$($VM.Name)\LabBuilder Files\$Script:DSCEncryptionCert"))
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
                    New-LabException @ExceptionParameters
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
                New-LabException @ExceptionParameters
            } # If
        } # If

        # Create any DSC Files for the VM
        Initialize-LabVMDSC `
            -Config $Config `
            -VM $VM

        # Attempt to start DSC on the VM
        Start-LabVMDSC `
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
   $Path = Get-LabVMRootPath -Config $Config -VM $VM[0]
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
    [String] $VMRootPath = Get-LabVMRootPath `
        -Config $Config `
        -VM $VM

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
                New-LabException @ExceptionParameters                
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
                    New-LabException @ExceptionParameters
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
                    New-LabException @ExceptionParameters                    
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
                            New-LabException @ExceptionParameters                    
                        } # if
                        if (-not (Test-Path -Path $ParentVhd))
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                                    -f $VM.name,$ParentVhd)
                            }
                            New-LabException @ExceptionParameters                    
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
                        New-LabException @ExceptionParameters                        
                    } # default
                } # switch
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
   $Path = Get-LabVMRootPath -Config $Config -VM $VM[0]
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
                    -f $VM.Name,$IntegrationService.Name)
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
        [String] $VMRootPath = Get-LabVMRootPath `
            -Config $Config `
            -VM $VM

        # Get the Virtual Machine Path
        [String] $VMPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Machines'
            
        # Get the Virtual Hard Disk Path
        [String] $VHDPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Hard Disks'

        # Get Path to LabBuilder files
        [String] $VMLabBuilderFiles = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'LabBuilder Files'

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

                    $Null = New-VHD -Differencing -Path $VMBootDiskPath -ParentPath $VM.TemplateVHD
                }
                else
                {
                    Write-Verbose -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Boot')

                    $Null = Copy-Item `
                        -Path $VM.TemplateVHD `
                        -Destination $VMBootDiskPath
                }

                # Create all the required initialization files for this VM
                Set-LabVMInitializationFiles `
                    -Config $Config `
                    -VM $VM

                # Because this is a new boot disk apply any required initialization
                Initialize-LabVMImage `
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
                -Path $VMPath `
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
    [String] $VMPath = $Config.labbuilderconfig.settings.vmpath
    
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
    [Boolean] $Found = $False
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False

    # Load path variables
    [String] $VMRootPath = Join-Path `
        -Path $VMPath `
        -ChildPath $VM.Name

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = Join-Path `
        -Path $VMRootPath `
        -ChildPath 'LabBuilder Files'

    # Make sure the VM has started
    Wait-LabVMStart -VM $VM
    
    [String] $InitialSetupCompletePath = Join-Path -Path $VMLabBuilderFiles -ChildPath 'InitialSetupCompleted.txt'
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
        $Session = Connect-LabVM -VM $VM -ErrorAction Continue

        # Failed to connnect to the VM
        if (! $Session)
        {
            $ExceptionParameters = @{
                errorId = 'InitialSetupCompleteError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.InitialSetupCompleteError `
                    -f $VM.Name)
            }
            New-LabException @ExceptionParameters
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
                errorId = 'InitialSetupCompleteError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.InitialSetupCompleteError `
                    -f $VM.Name)
            }
            New-LabException @ExceptionParameters
        }

        # Close the Session if it is opened
        if (($Session) `
            -and ($Session.State -eq 'Opened'))
        {
            Remove-PSSession -Session $Session
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
   
   If the connection is attempted but an Access Denied error occurs a ConnectionError exception
   will be thrown immediately and the connection will not be retried. 
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
    [PSCredential] $AdminCredential = New-Credential `
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
            $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
            if (($TrustedHosts -notlike "*$IPAddress*"))
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
            if ($_.Exception.ErrorCode -eq 5)
            {
                Write-Verbose -Message $($LocalizedData.ConnectingVMAccessDeniedMessage `
                    -f $VM.Name)
                $FatalException = $True
            }
            else
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
            }
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
        New-LabException @ExceptionParameters
    }
    Return $Session
} # Connect-LabVM
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Throws a custom exception.
.DESCRIPTION
   This cmdlet throw a terminating or non-terminating exception. 
.EXAMPLE
    $ExceptionParameters = @{
        errorId = 'ConnectionFailure'
        errorCategory = 'ConnectionError'
        errorMessage = 'Could not connect'
    }
    New-LabException @ExceptionParameters
    Throw a ConnectionError exception with the message 'Could not connect'.
.PARAMETER errorId
   The Id of the exception.
.PARAMETER errorCategory
   The category of the exception. It must be a valid [System.Management.Automation.ErrorCategory]
   value.
.PARAMETER errorMessage
   The exception message.
.PARAMETER terminate
   THis switch will cause the exception to terminate the cmdlet.
.OUTPUTS
   None
#>

function New-LabException
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [String] $errorId,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorCategory] $errorCategory,

        [Parameter(Mandatory)]
        [String] $errorMessage,
        
        [Switch]
        $terminate
    )

    $exception = New-Object -TypeName System.Exception `
        -ArgumentList $errorMessage
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $errorId, $errorCategory, $null

    if ($Terminate)
    {
        # This is a terminating exception.
        throw $errorRecord
    }
    else
    {
        # Note: Although this method is called ThrowTerminatingError, it doesn't terminate.
        $PSCmdlet.ThrowTerminatingError($errorRecord)
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
} # Build-Lab
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

####################################################################################################
# Export the Module Cmdlets
Export-ModuleMember -Function `
    Get-LabConfiguration, `
    Test-LabConfiguration, `
    Install-LabHyperV, `
    Initialize-LabConfiguration, `
    Get-LabSwitch, `
    Initialize-LabSwitch, `
    Remove-LabSwitch, `
    Get-LabVMTemplateVHD, `
    Initialize-LabVMTemplateVHD, `
    Remove-LabVMTemplateVHD, `
    Get-LabVMTemplate, `
    Initialize-LabVMTemplate, `
    Remove-LabVMTemplate, `
    Get-LabVM, `
    Initialize-LabVM, `
    Remove-LabVM, `
    Start-LabVM, `
    Wait-LabVMStart, `
    Wait-LabVMOff, `
    Wait-LabVMInit, `
    Install-Lab, `
    Uninstall-Lab
####################################################################################################
