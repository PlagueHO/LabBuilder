#Requires -version 5.0

####################################################################################################
# Localization Strings
data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
FileDownloadError=Error downloading {0} from '{1}'; {2}.
FileExtractError=Error extracting {0}; {1}.
ConfigurationFileNotFoundError=Configuration file {0} is not found.
ConfigurationFileEmptyError=Configuration file {0} is empty.
ConfigurationInvalidError=Configuration is invalid.
ConfigurationMissingElementError=Element '{0}' is missing or empty in the configuration.
PathNotFoundError={0} path '{1}' is not found.
ResourceModuleNameEmptyError=Resource Module Name is missing or empty.
ModuleNotAvailableError=Error installing Module '{0}' ({1}); {2}.
SwitchNameIsEmptyError=Switch name is empty.
UnknownSwitchTypeError=Unknown switch type '{0}' specified for switch '{1}'.
AdapterSpecifiedError=Adapter specified on '{0}' swtich '{1}'.
EmptyTemplateNameError=Template Name is missing or empty.
EmptyTemplateVHDError=VHD in Template '{0}' is empty.
TemplateSourceVHDNotFoundError=The Template Source VHD '{0}' in Template '{1}' could not be found.
DSCModuleDownloadError=Module '{2}' required by DSC Config File '{0}' in VM '{1}' could not be found or downloaded.					
DSCModuleNotFoundError=Module '{2}' required by DSC Config File '{0}' in VM '{1}' could not be found in the module path.
CertificateCreateError=The self-signed certificate for VM '{0}' could not be created and downloaded.
DSCConfigMetaMOFCreateError=A Meta MOF File was not created by the DSC LCM Config for VM '{0}'.
DSCConfigMoreThanOneNodeError=A single Node element cannot be found in the DSC Config File '{0}' in VM '{1}'.
DSCConfigMOFCreateError=A MOF File was not created by the DSC Config File '{0}' in VM '{1}'.
NetworkAdapterNotFoundError=VM Network Adapter '{0}' could not be found attached to VM '{1}'.
NetworkAdapterBlankMacError=VM Network Adapter '{0}' attached to VM '{1}' has a blank MAC Address.
InstallingHyperVComponentsMesage=Installing {0} Hyper-V Components.
InitializingHyperVComponentsMesage=Initializing Hyper-V Components.
DownloadingLabResourcesMessage=Downloading Lab Resources.
CreatingLabManagementSwitchMessage=Creating Lab Management Switch {0} on Vlan {1}.
UpdatingLabManagementSwitchMessage=Updating Lab Management Switch {0} to Vlan {1}.
ModuleNotInstalledMessage=Module {0} ({1}) is not installed.
DownloadingLabResourceWebMessage=Downloading Module {0} ({1}) from '{2}'.
InstallingLabResourceWebMessage=Installing Module {0} ({1}) to Modules Folder '{2}'.
InstalledLabResourceWebMessage=Installed Module {0} ({1}) to '{2}'.
CreatingVirtualSwitchMessage=Creating {0} Virtual Switch '{1}'.
DeleteingVirtualSwitchMessage=Deleting {0} Virtual Switch '{1}'.
CopyingTemplateSourceVHDMessage=Copying template source VHD '{0}' to '{1}'.
OptimizingTemplateVHDMessage=Optimizing template VHD '{0}'.
SettingTemplateVHDReadonlyMessage=Setting template VHD '{0}' as readonly.
SkippingTemplateVHDFileMessage=Skipping template VHD file '{0}' because it already exists.
DeletingTemplateVHDMessage=Deleting Template VHD '{0}'.
DSCConfigIdentifyModulesMessage=Identifying Modules used by DSC Config File '{0}' in VM '{1}'.
DSCConfigSearchingForModuleMessage=Searching for Module '{2}' required by DSC Config File '{0}' in VM '{1}'.
DSCConfigInstallingModuleMessage=Installing Module '{2}' required by DSC Config File '{0}' in VM '{1}'.
DSCConfigSavingModuleMessage=Saving Module '{2}' required by DSC Config File '{0}' in VM '{1}' to LabBuilder files.
DSCConfigCreatingLCMMOFMessage=Creating DSC LCM Config file '{0}' in VM '{1}'.
DSCConfigCreatingMOFMessage=Creating DSC Config file '{0}' in VM '{1}'.
DSCConfigMOFCreatedMessage=DSC MOF File '{0}' for VM '{1}'. was created successfully.
'@
}

####################################################################################################
# Module Variables
####################################################################################################
# This is the URL to the WMF Production Preview
[String]$Script:WorkingFolder = $ENV:Temp
[String]$Script:WMF5DownloadURL = 'http://download.microsoft.com/download/3/F/D/3FD04B49-26F9-4D9A-8C34-4533B9D5B020/Win8.1AndW2K12R2-KB3066437-x64.msu'
[String]$Script:WMF5InstallerFilename = ($Script:WMF5DownloadURL).Substring(($Script:WMF5DownloadURL).LastIndexOf('/') + 1)
[String]$Script:WMF5InstallerPath = Join-Path -Path $Script:WorkingFolder -ChildPath $Script:WMF5InstallerFilename
[String]$Script:CertGenDownloadURL = 'https://gallery.technet.microsoft.com/scriptcenter/Self-signed-certificate-5920a7c6/file/101251/1/New-SelfSignedCertificateEx.zip'
[String]$Script:CertGenZipFilename = ($Script:CertGenDownloadURL).Substring(($Script:CertGenDownloadURL).LastIndexOf('/') + 1)
[String]$Script:CertGenZipPath = Join-Path -Path $Script:WorkingFolder -ChildPath $Script:CertGenZipFilename
[String]$Script:CertGenPS1Filename = 'New-SelfSignedCertificateEx.ps1'
[String]$Script:CertGenPS1Path = Join-Path -Path $Script:WorkingFolder -ChildPath $Script:CertGenPS1Filename
[Int]$Script:DefaultManagementVLan = 99
[String]$Script:DefaultMacAddressMinimum = '00155D010600'
[String]$Script:DefaultMacAddressMaximum = '00155D0106FF'
[Int]$Script:SelfSignedCertKeyLength = 2048
[String]$Script:SelfSignedCertProviderName = 'Microsoft Software Key Storage Provider' # 'Microsoft Enhanced Cryptographic Provider v1.0'
[String]$Script:SelfSignedCertAlgorithmName = 'RSA' # 'ECDH_P256' Or 'ECDH_P384' Or 'ECDH_P521'
[String]$Script:SelfSignedCertSignatureAlgorithm = 'SHA256' # 'SHA1'
[String]$Script:DSCEncryptionCert = 'DSCEncryption.cer'
[String]$Script:DSCCertificateFriendlyName = 'DSC Credential Encryption'

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
    If (-not (Test-Path -Path $Script:WMF5InstallerPath))
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
            $errorId = 'FileDownloadError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            $errorMessage = $($LocalizedData.FileDownloadError) `
                -f 'WMF 5.0 Installer',$Script:WMF5DownloadURL,$_.Exception.Message
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null
            
            $PSCmdlet.ThrowTerminatingError($errorRecord)
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
    If (-not (Test-Path -Path $Script:CertGenZipPath))
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
            $errorId = 'FileDownloadError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            $errorMessage = $($LocalizedData.FileDownloadError) `
                -f 'Certificate Generator',$Script:CertGenDownloadURL,$_.Exception.Message
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            $PSCmdlet.ThrowTerminatingError($errorRecord)        
        }
    } # If
    If (-not (Test-Path -Path $Script:CertGenPS1Path))
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
            $errorId = 'FileExtractError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            $errorMessage = $($LocalizedData.FileExtractError) `
                -f 'Certificate Generator',$_.Exception.Message
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            $PSCmdlet.ThrowTerminatingError($errorRecord)        
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
        [Parameter(
            Mandatory=$True,
            Position=0)]
        [ValidateNotNullOrEmpty()]	
        [String]$DSCConfigFile
    )
    [String[]]$Modules = $Null
    [String]$Content = Get-Content -Path $DSCConfigFile
    $Regex = "Import\-DscResource\s(?:\-ModuleName\s)?'?`"?([A-Za-z0-9]+)`"?'?"
    $Matches = [regex]::matches($Content, $Regex, 'IgnoreCase')
    Foreach ($Match in $Matches)
    {
        If ($Match.Groups[1].Value -ne 'PSDesiredStateConfiguration')
        {
            $Modules += $Match.Groups[1].Value
        } # If
    } # Foreach
    # Add the xNetworking DSC Resource because it is always used
    $Modules += 'xNetworking'
    Return $Modules
} # Get-ModulesInDSCConfig
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
        [parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [String]$Path
    ) # Param
    If (-not (Test-Path -Path $Path))
    {
        $errorId = 'ConfigurationFileNotFoundError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.ConfigurationFileNotFoundError) `
            -f $Path
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)        
    } # If
    $Content = Get-Content -Path $Path -Raw
    If (-not $Content)
    {
        $errorId = 'ConfigurationFileEmptyError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.ConfigurationFileEmptyError) `
            -f $Path
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)        
    } # If
    [XML]$Configuration = New-Object -TypeName XML
    $Configuration.LoadXML($Content)
    # Figure out the Config path and load it into the XML object (if we can)
    # This path is used to find any additional configuration files that might
    # be provided with config
    [String]$ConfigPath = [System.IO.Path]::GetDirectoryName($Path)
    [String]$XMLConfigPath = $Configuration.labbuilderconfig.settings.configpath
    If ($XMLConfigPath) {
        If ($XMLConfigPath.Substring(0,1) -eq '.')
        {
            # A relative path was provided in the config path so add the actual path of the XML to it
            [String]$FullConfigPath = Join-Path -Path $ConfigPath -ChildPath $XMLConfigPath
        } # If
    }
    Else
    {
        [String]$FullConfigPath = $ConfigPath
    }
    $Configuration.labbuilderconfig.settings.setattribute('fullconfigpath',$FullConfigPath)
    Return $Configuration
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
   Test-LabConfiguration -Configuration $Config
   Loads a Lab Builder configuration and tests it is valid.   
.OUTPUTS
   Returns True if the configuration is valid. Throws an error if invalid.
#>
function Test-LabConfiguration {
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration
    )

    If ((-not $Configuration.labbuilderconfig) `
        -or (-not $Configuration.labbuilderconfig.settings))
    {
        $errorId = 'ConfigurationInvalidError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.ConfigurationInvalidError)
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)        
    }

    # Check folders exist
    [String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath
    If (-not $VMPath)
    {
        $errorId = 'ConfigurationMissingElementError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.ConfigurationMissingElementError) `
            -f '<settings>\<vmpath>'
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)      
    }

    If (-not (Test-Path -Path $VMPath))
    {
        $errorId = 'PathNotFoundError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.PathNotFoundError) `
            -f '<settings>\<vmpath>',$VMPath
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)      
    }

    [String]$VHDParentPath = $Configuration.labbuilderconfig.settings.vhdparentpath
    If (-not $VHDParentPath)
    {
        $errorId = 'ConfigurationMissingElementError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.ConfigurationMissingElementError) `
            -f '<settings>\<vhdparentpath>'
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)      
    }

    If (-not (Test-Path -Path $VHDParentPath))
    {
        $errorId = 'PathNotFoundError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.PathNotFoundError) `
            -f '<settings>\<vhdparentpath>',$VHDParentPath
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)      
    }

    [String]$FullConfigPath = $Configuration.labbuilderconfig.settings.fullconfigpath
    If (-not (Test-Path -Path $FullConfigPath)) 
    {
        $errorId = 'PathNotFoundError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.PathNotFoundError) `
            -f '<settings>\<fullconfigpath>',$FullConfigPath
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)      
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
    If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1)
    {
        # Desktop OS
        [Array]$Feature = Get-WindowsOptionalFeature -Online -FeatureName '*Hyper-V*' `
            | Where-Object -Property State -Eq 'Disabled'
        If ($Feature.Count -gt 0 )
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
        [Array]$Feature = Get-WindowsFeature -Name Hyper-V `
            | Where-Object -Property Installed -EQ $false
        If ($Feature.Count -gt 0 )
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
   Initialize-LabConfiguration -Configuration $Config
   Loads a Lab Builder configuration and applies the base system settings.
.OUTPUTS
   None.
#>
function Initialize-LabConfiguration {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration
    )
    
    # Install Hyper-V Components
    Write-Verbose -Message ($LocalizedData.InitializingHyperVComponentsMesage)
    
    [String]$MacAddressMinimum = $Configuration.labbuilderconfig.settings.macaddressminimum
    If (-not $MacAddressMinimum)
    {
        $MacAddressMinimum = $Script:DefaultMacAddressMinimum
    }

    [String]$MacAddressMaximum = $Configuration.labbuilderconfig.settings.macaddressmaximum
    If (-not $MacAddressMaximum)
    {
        $MacAddressMaximum = $Script:DefaultMacAddressMaximum
    }

    Set-VMHost -MacAddressMinimum $MacAddressMinimum -MacAddressMaximum $MacAddressMaximum

    # Create the LabBuilder Management Network switch and assign VLAN
    # Used by host to communicate with Lab VMs
    $ManagementSwitchName = ('LabBuilder Management {0}' -f $Configuration.labbuilderconfig.name)
    if ($Configuration.labbuilderconfig.switches.ManagementVlan)
	{
		[Int32]$ManagementVlan = $Configuration.labbuilderconfig.switches.ManagementVlan
	}
	else
	{
		[Int32]$ManagementVlan = $Script:DefaultManagementVLan
	}
    if ((Get-VMSwitch | Where-Object -Property Name -eq $ManagementSwitchName).Count -eq 0)
    {
        $null = New-VMSwitch -Name $ManagementSwitchName -SwitchType Internal

        Write-Verbose -Message ($LocalizedData.CreatingLabManagementSwitchMessage `
            -f $ManagementSwitchName,$ManagementVlan)
    }
	# Check the Vlan ID of the adapter on the switch
    $ExistingManagementAdapter = Get-VMNetworkAdapter -ManagementOS -Name $ManagementSwitchName
    $ExistingVlan = (Get-VMNetworkAdapterVlan -VMNetworkAdapter $ExistingManagementAdapter).AccessVlanId
	if ($ExistingVlan -ne $ManagementVlan)
	{
        Write-Verbose -Message ($LocalizedData.UpdatingLabManagementSwitchMessage `
            -f $ManagementSwitchName,$ManagementVlan)

        $ExistingManagementAdapter | Set-VMNetworkAdapterVlan -Access -VlanId $ManagementVlan
	}
    
    # Download the New-SelfSignedCertificateEx.ps1 script
    Download-CertGenerator

    # Download WMF 5.0 in case any VMs need it	
    Download-WMF5Installer

    # Download any other resources required by this lab
    Download-LabResources -Configuration $Configuration	

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
   Download-LabResources -Configuration $Config
   Loads a Lab Builder configuration and downloads any resources required by it.   
.OUTPUTS
   None.
#>
function Download-LabModule {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [String]$URL,

        [String]$Folder,
        
        [String]$RequiredVersion,

        [String]$MinimumVersion
    )

    $InstalledModules = @(Get-Module -ListAvailable)

    # Determine a query that will be used to decide if the module is already installed
    if ($RequiredVersion) {
        [ScriptBlock]$Query = `
            { ($_.Name -eq $Name) -and ($_.Version -eq $RequiredVersion) }
        $VersionMessage = $RequiredVersion                
    }
    elseif ($MinimumVersion)
    {
        [ScriptBlock]$Query = `
            { ($_.Name -eq $Name) -and ($_.Version -ge $MinimumVersion) }
        $VersionMessage = "min ${MinimumVersion}"
    }
    else
    {
        [ScriptBlock]$Query = `
            $Query = { $_.Name -eq $Name }
        $VersionMessage = 'any version'
    }

    # Is the module installed?
    If ($InstalledModules.Where($Query).Count -eq 0)
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
                $errorId = 'FileDownloadError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                $errorMessage = $($LocalizedData.FileDownloadError) `
                    -f "Module Resource ${Name}",$URL,$_.Exception.Message
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)        
            } # Try

            [String]$ModulesFolder = "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\"

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
                $errorId = 'FileExtractError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.FileExtractError) `
                    -f "Module Resource ${Name}",$_.Exception.Message
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)        
            } # Try
            If ($Folder)
            {
                # This zip file contains a folder that is not the name of the module so it must be
                # renamed. This is usually the case with source downloaded directly from GitHub
                $ModulePath = Join-Path -Path $ModulesFolder -ChildPath $($Name)
                If (Test-Path -Path $ModulePath)
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
                $errorId = 'ModuleNotAvailableError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.ModuleNotAvailableError) `
                    -f $Name,$VersionMessage,$_.Exception.Message
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        } # If
    } # If
}
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
   Download-LabResources -Configuration $Config
   Loads a Lab Builder configuration and downloads any resources required by it.   
.OUTPUTS
   None.
#>
function Download-LabResources {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration
    )
    
    # Downloading Lab Resources
    Write-Verbose -Message $($LocalizedData.DownloadingLabResourcesMessage)
    
    # Download any other resources required by this lab
    If ($Configuration.labbuilderconfig.resources) 
    {
        Foreach ($Module in $Configuration.labbuilderconfig.resources.module)
        {
            if (-not $Module.Name)
            {
                $errorId = 'ResourceModuleNameEmptyError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.ResourceModuleNameEmptyError)
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)
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
   This list is usually passed to Initialize-LabSwitches to configure the swtiches required for this
   lab.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabSwitches -Configuration $Config
   Loads a Lab Builder configuration and pulls the array of switches from it.
.OUTPUTS
   Returns an array of switches.
#>
function Get-LabSwitches {
    [OutputType([Array])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration
    )

    [Array]$Switches = @() 
    $ConfigSwitches = $Configuration.labbuilderconfig.SelectNodes('switches').Switch
    Foreach ($ConfigSwitch in $ConfigSwitches)
    {
        # It can't be switch because if the name attrib/node is missing the name property on the
        # XML object defaults to the name of the parent. So we can't easily tell if no name was
        # specified or if they actually specified 'switch' as the name.
        If ($ConfigSwitch.Name -eq 'switch')
        {
            $errorId = 'SwitchNameIsEmptyError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        If ($ConfigSwitch.Type -notin 'Private','Internal','External')
        {
            $errorId = 'UnknownSwitchTypeError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                -f $ConfigSwitch.Type,$ConfigSwitch.Name)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        # Assemble the list of Adapters if any are specified for this switch (only if an external
        # switch)
        If ($ConfigSwitch.Adapters)
        {
            [System.Collections.Hashtable[]]$ConfigAdapters = @()
            Foreach ($Adapter in $ConfigSwitch.Adapters.Adapter)
            {
                $ConfigAdapters += @{ name = $Adapter.Name; macaddress = $Adapter.MacAddress }
            }
            If (($ConfigAdapters.Count -gt 0) -and ($ConfigSwitch.Type -ne 'External'))
            {
                $errorId = 'AdapterSpecifiedError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.AdapterSpecifiedError `
                    -f $ConfigSwitch.Type,$ConfigSwitch.Name)
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null
    
                $PSCmdlet.ThrowTerminatingError($errorRecord)
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
            adapters = $ConfigAdapters }
    }
    return $Switches
} # Get-LabSwitches
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Creates Hyper-V Virtual Switches from a provided array.
.DESCRIPTION
   Takes an array of switches that were pulled from a Lab Configuration object by calling
   Get-LabSwitches
   and ensures that they Hyper-V Virtual Switches on the system are configured to match.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER Switches
   The array of switches pulled from the Lab Configuration file using Get-LabSwitches
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabSwitches -Configuration $Config
   Initialize-LabSwitches -Configuration $Config -Switches $Switches
   Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Initialize-LabSwitches {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [Array]$Switches
    )

    # Create Hyper-V Switches
    Foreach ($VMSwitch in $Switches)
    {
        If ((Get-VMSwitch | Where-Object -Property Name -eq $($VMSwitch.Name)).Count -eq 0)
        {
            [String]$SwitchName = $VMSwitch.Name
            If (-not $SwitchName)
            {
                $errorId = 'SwitchNameIsEmptyError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
            [string]$SwitchType = $VMSwitch.Type
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
                    If ($VMSwitch.Adapters)
                    {
                        Foreach ($Adapter in $VMSwitch.Adapters)
                        {
                            If ($VMSwitch.VLan)
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
                    If ($VMSwitch.Adapters)
                    {
                        Foreach ($Adapter in $VMSwitch.Adapters)
                        {
                            If ($VMSwitch.VLan)
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
                Default
                {
                    $errorId = 'UnknownSwitchTypeError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    $errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f $SwitchType,$SwitchName)
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null

                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            } # Switch
        } # If
    } # Foreach       
} # Initialize-LabSwitches
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Removes all Hyper-V Virtual Switches provided.
.DESCRIPTION
   This cmdlet is used to remove any Hyper-V Virtual Switches that were created by
   the Initialize-LabSwitches cmdlet.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER Switches
   The array of switches pulled from the Lab Configuration file using Get-LabSwitches
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabSwitches -Configuration $Config
   Remove-LabSwitches -Configuration $Config -Switches $Switches
   Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Remove-LabSwitches {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]]$Switches
    )

    # Delete Hyper-V Switches
    Foreach ($Switch in $Switches)
    {
        If ((Get-VMSwitch | Where-Object -Property Name -eq $Switch.Name).Count -ne 0)
        {
            [String]$SwitchName = $Switch.Name
            If (-not $SwitchName)
            {
                $errorId = 'UnknownSwitchTypeError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
            [string]$SwitchType = $Switch.Type
            Write-Verbose -Message $($LocalizedData.DeleteingVirtualSwitchMessage `
                -f $SwitchType,$SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    If ($Switch.Adapters)
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
                    If ($Switch.Adapters)
                    {
                        $Switch.Adapters.foreach( {
                            $null = Remove-VMNetworkAdapter -ManagementOS -Name $_.Name
                        } )
                    } # If
                    Break
                } # 'Internal'
                Default
                {
                    $errorId = 'UnknownSwitchTypeError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    $errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f $SwitchType,$SwitchName)
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null

                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            } # Switch
        } # If
    } # Foreach        
} # Remove-LabSwitches
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Gets an Array of VM Templates for a Lab configuration.
.DESCRIPTION
   Takes a provided Lab Configuration file and returns the list of Virtul Machine template machines
   that will be used to create the Virtual Machines in this lab. This list is usually passed to
   Initialize-LabVMTemplates.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabVMTemplates -Configuration $Config
   Loads a Lab Builder configuration and pulls the array of VMTemplates from it.
.OUTPUTS
   Returns an array of VM Templates.
#>
function Get-LabVMTemplates {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration
    )

    [System.Collections.Hashtable[]]$VMTemplates = @()
    [String]$VHDParentPath = $Configuration.labbuilderconfig.SelectNodes('settings').vhdparentpath
    
    # Get a list of all templates in the Hyper-V system matching the phrase found in the fromvm
    # config setting
    [String]$FromVM=$Configuration.labbuilderconfig.SelectNodes('templates').fromvm
    If ($FromVM)
    {
        $Templates = @(Get-VM -Name $FromVM)
        Foreach ($Template in $Templates)
        {
            [String]$VHDFilepath = (Get-VMHardDiskDrive -VMName $Template.Name).Path
            [String]$VHDFilename = [System.IO.Path]::GetFileName($VHDFilepath)
            $VMTemplates += @{
                name = $Template.Name
                vhd = $VHDFilename
                sourcevhd = $VHDFilepath
                templatevhd = "$VHDParentPath\$VHDFilename"
            }
        } # Foreach
    } # If
    
    # Read the list of templates from the configuration file
    $Templates = $Configuration.labbuilderconfig.SelectNodes('templates').template
    Foreach ($Template in $Templates)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'template' as the name.
        If ($Template.Name -eq 'template')
        {
            $errorId = 'EmptyTemplateNameError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.EmptyTemplateNameError)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            $PSCmdlet.ThrowTerminatingError($errorRecord)
        } # If
        If ($Template.SourceVHD)
        {
            # A Source VHD file was specified - does it exist?
            If (-not (Test-Path -Path $Template.SourceVHD))
            {
                $errorId = 'TemplateSourceVHDNotFoundError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                    -f $Template.Name,$Template.SourceVHD)
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)
            } # If
        } # If
        
        # Get the Template Default Startup Bytes
        [Int64]$MemortStartupBytes = 0
        If ($Template.MemoryStartupBytes)
        {
            $MemortStartupBytes = (Invoke-Expression $Template.MemoryStartupBytes)
        } # If

        # Get the Template Default Data VHD Size
        [Int64]$DataVHDSize = 0
        If ($Template.DataVHDSize)
        {
            $DataVHDSize = (Invoke-Expression $Template.DataVHDSize)
        } # If
                
        # Does the template already exist in the list?
        [Boolean]$Found = $False
        Foreach ($VMTemplate in $VMTemplates)
        {
            If ($VMTemplate.Name -eq $Template.Name)
            {
                # The template already exists - so don't add it again, but update the VHD path
                # if provided
                If ($Template.VHD)
                {
                    $VMTemplate.VHD = $Template.VHD
                    $VMTemplate.TemplateVHD = "$VHDParentPath\$([System.IO.Path]::GetFileName($Template.VHD))"
                } # If
                # Check that we do end up with a VHD filename in the template
                If (-not $VMTemplate.VHD)
                {
                    $errorId = 'EmptyTemplateVHDError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    $errorMessage = $($LocalizedData.EmptyTemplateVHDError `
                        -f $VMTemplate.Name)
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null

                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                } # If
                If ($Template.SourceVHD)
                {
                    $VMTemplate.SourceVHD = $Template.SourceVHD
                }
                $VMTemplate.InstallISO = $Template.InstallISO
                $VMTemplate.Edition = $Template.Edtion
                $VMTemplate.AllowCreate = $Template.AllowCreate
                # Write any template specific default VM attributes
                If ($MemortStartupBytes)
                {
                    $VMTemplate.MemoryStartupBytes = $MemortStartupBytes
                } # If
                If ($Templates.ProcessorCount)
                {
                    $VMTemplate.ProcessorCount = $Template.ProcessorCount
                } # If
                If ($DataVHDSize)
                {
                    $VMTemplate.DataVHDSize = $DataVHDSize
                } # If
                If ($Templates.AdministratorPassword)
                {
                    $VMTemplate.AdministratorPassword = $Template.AdministratorPassword
                } # If
                If ($Templates.ProductKey)
                {
                    $VMTemplate.ProductKey = $Template.ProductKey
                } # If
                If ($Templates.TimeZone)
                {
                    $VMTemplate.TimeZone = $Template.TimeZone
                } # If
                If ($Templates.OSType)
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
        If (-not $Found)
        {
            # Check that we do end up with a VHD filename in the template
            If (-not $Template.VHD)
            {
                $errorId = 'EmptyTemplateVHDError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.EmptyTemplateVHDError `
                    -f $Template.Name)
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)
            } # If

            # The template wasn't found in the list of templates so add it
            $VMTemplates += @{
                name = $Template.Name;
                vhd = $Template.VHD;
                sourcevhd = $Template.SourceVHD;
                templatevhd = "$VHDParentPath\$([System.IO.Path]::GetFileName($Template.VHD))";
                installiso = $Template.InstallISO;
                edition = $Template.Edition;
                allowcreate = $Template.AllowCreate;
                memorystartupbytes = $MemoryStartupBytes;
                processorcount = $Template.ProcessorCount;
                datavhdsize = $Template.DataVHDSize;
                administratorpassword = $Template.AdministratorPassword;
                productkey = $Template.ProductKey;
                timezone = $Template.TimeZone;
                ostype = If ($Template.OSType) { $Template.OSType } Else { 'Server' };
            }
        } # If
    } # Foreach
    Return $VMTemplates
} # Get-LabVMTemplates
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
   The array of VM Templates pulled from the Lab Configuration file using Get-LabVMTemplates
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplates -Configuration $Config
   Initialize-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates
   Initializes the Virtual Machine templates in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Initialize-LabVMTemplates {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]]$VMTemplates
    )
    
    Foreach ($VMTemplate in $VMTemplates)
    {
        If (-not (Test-Path $VMTemplate.templatevhd))
        {
            # The template VHD isn't in the VHD Parent folder - so copy it there after optimizing it
            If (-not (Test-Path $VMTemplate.sourcevhd))
            {
                # The source VHD does not exist - so try and create it from the ISO
                # This feature is not yet supported so will throw an error
                $errorId = 'TemplateSourceVHDNotFoundError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                    -f $VMTemplate.name,$VMTemplate.sourcevhd)
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)
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
            Write-Verbose -Message $($LocalizedData.SkippingTemplateVHDFileMessage `
                -f $VMTemplate.templatevhd)
        }
    }
} # Initialize-LabVMTemplates
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
   Get-LabVMTemplates
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplates -Configuration $Config
   Remove-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates
   Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Remove-LabVMTemplates {
    [CmdLetBinding()]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]]$VMTemplates
    )
    
    Foreach ($VMTemplate in $VMTemplates) {
        If (Test-Path $VMTemplate.templatevhd) {
            Set-ItemProperty -Path $VMTemplate.templatevhd -Name IsReadOnly -Value $False
            Write-Verbose -Message $($LocalizedData.DeletingTemplateVHDMessage `
                -f $VMTemplate.templatevhd)
            Remove-Item -Path $VMTemplate.templatevhd -Confirm:$false -Force
        }
    }
} # Remove-LabVMTemplates
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
   $VMs = Get-LabVM -Configuration $Config
   Set-LabVMDSCMOFFile -Configuration $Config -VM $VMs[0]
   Prepare the first VM in the Lab c:\mylab\config.xml for DSC configuration.
.OUTPUTS
   None.
#>
function Set-LabVMDSCMOFFile {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable]$VM
    )

    [String]$DSCMOFFile = ''
    [String]$DSCMOFMetaFile = ''
    [String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath
  
    # Load path variables
    [String]$VMRootPath = Join-Path `
        -Path $VMPath `
        -ChildPath $VM.Name
    
    # Make sure the appropriate folders exist
    Create-LabVMPath -VMPath $VMRootPath
    
    # Get Path to LabBuilder files
    [String]$VMLabBuilderFiles = Join-Path `
        -Path $VMRootPath `
        -ChildPath 'LabBuilder Files'

    If (-not $VM.DSCConfigFile)
    {
        # This VM doesn't have a DSC Configuration
        return
    }

    # Make sure all the modules required to create the MOF file are installed
    $InstalledModules = Get-Module -ListAvailable
    Write-Verbose -Message $($LocalizedData.DSCConfigIdentifyModulesMessage `
        -f $VM.DSCConfigFile,$VM.Name)

    $DSCModules = Get-ModulesInDSCConfig -DSCConfigFile $($VM.DSCConfigFile)
    Foreach ($ModuleName in $DSCModules)
    {
        If (($InstalledModules | Where-Object -Property Name -EQ $ModuleName).Count -eq 0)
        {
            # The Module isn't available on this computer, so try and install it
            Write-Verbose -Message $($LocalizedData.DSCConfigSearchingForModuleMessage `
                -f $VM.DSCConfigFile,$VM.Name,$ModuleName)

            $NewModule = Find-Module -Name $ModuleName
            If ($NewModule)
            {
                Write-Verbose -Message $($LocalizedData.DSCConfigInstallingModuleMessage `
                    -f $VM.DSCConfigFile,$VM.Name,$ModuleName)

                Try
                {
                    $NewModule | Install-Module
                }
                Catch
                {
                    $errorId = 'DSCModuleDownloadError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    $errorMessage = $($LocalizedData.DSCModuleDownloadError `
                        -f $VM.DSCConfigFile,$VM.Name,$ModuleName)
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null
    
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            }
            Else
            {
                $errorId = 'DSCModuleDownloadError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorMessage = $($LocalizedData.DSCModuleDownloadError `
                    -f $VM.DSCConfigFile,$VM.Name,$ModuleName)
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        } # If

        Write-Verbose -Message $($LocalizedData.DSCConfigSavingModuleMessage `
            -f $VM.DSCConfigFile,$VM.Name,$ModuleName)

        # Find where the module is actually stored
        [String]$ModulePath = ''
        Foreach ($Path in $ENV:PSModulePath.Split(';'))
        {
            $ModulePath = Join-Path `
                -Path $Path `
                -ChildPath $ModuleName
            If (Test-Path -Path $ModulePath)
            {
                Break
            } # If
        } # Foreach
        If (-not (Test-Path -Path $ModulePath))
        {
            $errorId = 'DSCModuleNotFoundError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.DSCModuleNotFoundError `
                -f $VM.DSCConfigFile,$VM.Name,$ModuleName)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        Copy-Item `
            -Path $ModulePath `
            -Destination (Join-Path -Path $VMLabBuilderFiles -ChildPath 'DSC Modules\') `
            -Recurse -Force
    } # Foreach

    if (-not (Get-LabVMCertificate -Configuration $Configuration -VM $VM))
    {
        $errorId = 'CertificateCreateError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.CertificateCreateError `
            -f $VM.Name)
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
    
    # Remove any old self-signed certifcates for this VM
    Get-ChildItem -Path cert:\LocalMachine\My `
        | Where-Object { $_.FriendlyName -eq $Script:DSCCertificateFriendlyName } `
        | Remove-Item
    
    # Add the VM Self-Signed Certificate to the Local Machine store and get the Thumbprint	
    [String]$CertificateFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath $Script:DSCEncryptionCert
    $Certificate = Import-Certificate `
        -FilePath $CertificateFile `
        -CertStoreLocation 'Cert:LocalMachine\My'
    [String]$CertificateThumbprint = $Certificate.Thumbprint

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
    If (-not (Test-Path -Path $DSCMOFMetaFile))
    {
        $errorId = 'DSCConfigMetaMOFCreateError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.DSCConfigMetaMOFCreateError `
            -f $VM.Name)
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    } # If

    # A DSC Config File was provided so create a MOF File out of it.
    Write-Verbose -Message $($LocalizedData.DSCConfigCreatingMOFMessage `
        -f $VM.DSCConfigFile,$VM.Name)
    
    # Now create the Networking DSC Config file
    [String]$NetworkingDSCConfig = Get-LabNetworkingDSCFile `
        -Configuration $Configuration -VM $VM
    [String]$NetworkingDSCFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'DSCNetworking.ps1'
    $null = Set-Content `
        -Path $NetworkingDSCFile `
        -Value $NetworkingDSCConfig
    . $NetworkingDSCFile
    [String]$DSCFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'DSC.ps1'
    [String]$DSCContent = Get-Content `
        -Path $VM.DSCConfigFile `
        -Raw
    
    If (-not ($DSCContent -match 'Networking Network {}'))
    {
        # Add the Networking Configuration item to the base DSC Config File
        # Find the location of the line containing "Node $AllNodes.NodeName {"
        [String]$Regex = '\s*Node\s.*{.*'
        $Matches = [regex]::matches($DSCContent, $Regex, 'IgnoreCase')
        If ($Matches.Count -eq 1)
        {
            $DSCContent = $DSCContent.Insert($Matches[0].Index+$Matches[0].Length,"`r`nNetworking Network {}`r`n")
        }
        Else
        {
            $errorId = 'DSCConfigMoreThanOneNodeError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.DSCConfigMoreThanOneNodeError `
                -f $VM.DSCConfigFile,$VM.Name)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null
    
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        } # If
    } # If
    
    # Save the DSC Content
    $null = Set-Content `
        -Path $DSCFile `
        -Value $DSCContent `
        -Force

    # Hook the Networking DSC File into the main DSC File
    . $DSCFile

    [String]$DSCConfigName = $VM.DSCConfigName
    
    # Generate the Configuration Nodes data that always gets passed to the DSC configuration.
    [String]$ConfigurationData = @"
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
    [String]$ConfigurationFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'DSCConfigData.psd1'
    If (Test-Path -Path $ConfigurationFile)
    {
        $null = Remove-Item `
            -Path $ConfigurationFile `
            -Force
    }
    Set-Content -Path $ConfigurationFile -Value $ConfigurationData
        
    # Generate the MOF file from the configuration
    & "$DSCConfigName" -OutputPath $($ENV:Temp) -ConfigurationData $ConfigurationFile
    If (-not (Test-Path -Path $DSCMOFFile))
    {
        $errorId = 'DSCConfigMOFCreateError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.DSCConfigMOFCreateError `
            -f $VM.DSCConfigFile,$VM.Name)
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
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
        -Destination (Join-Path -Path $VMLabBuilderFiles -ChildPath "$($VM.ComputerName).mof") `
        -Force

    If (-not $VM.DSCMOFFile)
    {
        # Remove Temporary files created by DSC
        $null = Remove-Item `
            -Path $DSCMOFFile `
            -Force
    }

    If (Test-Path -Path $DSCMOFMetaFile)
    {
        $null = Copy-Item `
            -Path $DSCMOFMetaFile `
            -Destination (Join-Path -Path $VMLabBuilderFiles -ChildPath "$($VM.ComputerName).meta.mof") `
            -Force
        If (-not $VM.DSCMOFFile)
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
   $VMs = Get-LabVM -Configuration $Config
   Set-LabVMDSCMOFFile -Configuration $Config -VM $VMs[0]
   Prepare the first VM in the Lab c:\mylab\config.xml for DSC start up.
.OUTPUTS
   None.
#>
function Set-LabVMDSCStartFile {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable]$VM
    )

    [String]$DSCStartPs = ''
    [String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath

    # Relabel the Network Adapters so that they match what the DSC Networking config will use
    # This is because unfortunately the Hyper-V Device Naming feature doesn't work.
    [String] $ManagementSwitchName = ('LabBuilder Management {0}' -f $Configuration.labbuilderconfig.name)
    $Adapters = @(($VM.Adapters).Name)
    $Adapters += @($ManagementSwitchName)

    # Do the other adapters    
    Foreach ($Adapter in $Adapters)
    {
        $NetAdapter = Get-VMNetworkAdapter -VMName $($VM.Name) -Name $Adapter
        If (-not $NetAdapter)
        {
            $errorId = 'NetworkAdapterNotFoundError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.NetworkAdapterNotFoundError `
                -f $Adapter,$VM.Name)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null
    
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        } # If
        $MacAddress = $NetAdapter.MacAddress
        If (-not $MacAddress)
        {
            $errorId = 'NetworkAdapterBlankMacError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.NetworkAdapterBlankMacError `
                -f $Adapter,$VM.Name)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null
    
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        } # If
        $DSCStartPs += @"
Get-NetAdapter | Where-Object { `$_.MacAddress.Replace('-','') -eq '$MacAddress' } | Rename-NetAdapter -NewName '$($Adapter)'

"@
    } # Foreach

    # Enable DSC logging (as long as it hasn't been already)
    [String] $Logging = ($VM.DSCLogging).ToString() 
    $DSCStartPs += @"
`$Result = & "wevtutil.exe" get-log "Microsoft-Windows-Dsc/Analytic"
If (-not (`$Result -like '*enabled: true*')) {
    & "wevtutil.exe" set-log "Microsoft-Windows-Dsc/Analytic" /q:true /e:$Logging
}
`$Result = & "wevtutil.exe" get-log "Microsoft-Windows-Dsc/Debug"
If (-not (`$Result -like '*enabled: true*')) {
    & "wevtutil.exe" set-log "Microsoft-Windows-Dsc/Debug" /q:true /e:$Logging
}

"@

    # Start the actual DSC Configuration
    $DSCStartPs += @"
Set-DscLocalConfigurationManager -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" -Verbose  *>> `"$($ENV:SystemRoot)\Setup\Scripts\DSC.log`"
Start-DSCConfiguration -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" -Force -Verbose  *>> `"$($ENV:SystemRoot)\Setup\Scripts\DSC.log`"

"@
    $null = Set-Content -Path "$VMPath\$($VM.Name)\LabBuilder Files\StartDSC.ps1" -Value $DSCStartPs -Force

    $DSCStartPsDebug = @"
Set-DscLocalConfigurationManager -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" -Verbose
Start-DSCConfiguration -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" -Force -Debug -Wait -Verbose
"@
    $null = Set-Content -Path "$VMPath\$($VM.Name)\LabBuilder Files\StartDSCDebug.ps1" -Value $DSCStartPsDebug -Force
} # Set-LabVMDSCStartFile
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
function Initialize-LabVMDSC {
    [CmdLetBinding()]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable]$VM
    )

    # Are there any DSC Settings to manage?
    Set-LabVMDSCMOFFile -Configuration $Configuration -VM $VM

    # Generate the DSC Start up Script file
    Set-LabVMDSCStartFile -Configuration $Configuration -VM $VM
} # Initialize-LabVMDSC
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
function Start-LabVMDSC {
    [CmdLetBinding()]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable]$VM,

        [Int]$Timeout = 300
    )
    [String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath
    [DateTime]$StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession]$Session = $null
    [PSCredential]$AdmininistratorCredential = New-Object System.Management.Automation.PSCredential ('Administrator', (ConvertTo-SecureString $VM.AdministratorPassword -AsPlainText -Force))
    [String]$ManagementSwitchName = ('LabBuilder Management {0}' -f $Configuration.labbuilderconfig.name)
    [Boolean]$Complete = $False
    [Boolean]$ConfigCopyComplete = $False
    [Boolean]$ModuleCopyComplete = $False
    
    While ((-not $Complete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
        While (-not ($Session) -or ($Session.State -ne 'Opened')) {
            # Try and connect to the remote VM for up to $Timeout (5 minutes) seconds.
            Try {
                Write-Verbose "Attempting connection to $($VM.ComputerName) ..."
                [String]$IPAddress = (Get-VMNetworkAdapter -VMName $VM.Name).Where({$_.SwitchName -eq $ManagementSwitchName}).IPAddresses.Where({$_.Contains('.')})
                If (-not $IPAddress) {
                    Throw "An IPv4 address for an adapter connected to the $ManagementSwitchName for $($VM.ComputerName) could not be identified."
                }
                $Session = New-PSSession -ComputerName $IPAddress -Credential $AdmininistratorCredential -ErrorAction Stop
            } Catch {
                Write-Verbose "Connection to $($VM.ComputerName) failed - retrying in 5 seconds ..."
                Start-Sleep 5
            }
        } # While

        If (($Session) -and ($Session.State -eq 'Opened') -and (-not $ConfigCopyComplete)) {
            # We are connected OK - upload the MOF files
            While ((-not $ConfigCopyComplete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
                Try {
                    Write-Verbose "Copying DSC MOF Files to $($VM.ComputerName) ..."
                    $null = Copy-Item `
                        -Path "$VMPath\$($VM.Name)\LabBuilder Files\$($VM.ComputerName).mof" `
                        -Destination c:\Windows\Setup\Scripts `
                        -ToSession $Session -Force -ErrorAction Stop
                    If (Test-Path -Path "$VMPath\$($VM.Name)\LabBuilder Files\$($VM.ComputerName).meta.mof") {
                        $null = Copy-Item `
                            -Path "$VMPath\$($VM.Name)\LabBuilder Files\$($VM.ComputerName).meta.mof" `
                            -Destination c:\Windows\Setup\Scripts `
                            -ToSession $Session -Force -ErrorAction Stop
                    } # If
                    $null = Copy-Item `
                        -Path "$VMPath\$($VM.Name)\LabBuilder Files\StartDSC.ps1" `
                        -Destination c:\Windows\Setup\Scripts `
                        -ToSession $Session -Force -ErrorAction Stop
                    $null = Copy-Item `
                        -Path "$VMPath\$($VM.Name)\LabBuilder Files\StartDSCDebug.ps1" `
                        -Destination c:\Windows\Setup\Scripts `
                        -ToSession $Session -Force -ErrorAction Stop
                    $ConfigCopyComplete = $True
                } Catch {
                    Write-Verbose "Copying DSC MOF Files to $($VM.ComputerName) failed - retrying in 5 seconds ..."
                    Start-Sleep 5
                } # Try
            } # While
        } # If

        # If the copy didn't complete and we're out of time, exit with a failure.
        If ((-not $ConfigCopyComplete) -and (((Get-Date) - $StartTime).Seconds) -ge $TimeOut) {
            Remove-PSSession -Session $Session
            Return $False
        } # If

        # Now Upload any required modules
        If (($Session) -and ($Session.State -eq 'Opened') -and (-not $ModuleCopyComplete)) {
            $DSCModules = Get-ModulesInDSCConfig -DSCConfigFile $($VM.DSCConfigFile)
            Foreach ($ModuleName in $DSCModules) {
                Try {
                    Write-Verbose "Copying DSC Module $ModuleName Files to $($VM.ComputerName) ..."
                    $null = Copy-Item `
                        -Path "$VMPath\$($VM.Name)\LabBuilder Files\DSC Modules\$ModuleName\" `
                        -Destination "$($env:ProgramFiles)\WindowsPowerShell\Modules\" `
                        -ToSession $Session -Force -Recurse -ErrorAction Stop
                } Catch {
                    Write-Verbose "Copying DSC Module $ModuleName Files to $($VM.ComputerName) failed - retrying in 5 seconds ..."
                    Start-Sleep 5
                } # Try
            } # Foreach
            $ModuleCopyComplete = $True
        } # If

        If ((-not $ModuleCopyComplete) -and (((Get-Date) - $StartTime).Seconds) -ge $TimeOut) {
            # Timed out
            Remove-PSSession -Session $Session
            Write-Warning "DSC Initialization of VM $($VM.ComputerName) failed to complete ..."
            Return $False
        }

        # Finally, Start DSC up!
        If (($Session) -and ($Session.State -eq 'Opened') -and ($ConfigCopyComplete) -and ($ModuleCopyComplete)) {
            Write-Verbose "Starting DSC on VM $($VM.ComputerName) ..."
            Invoke-Command -Session $Session { c:\windows\setup\scripts\StartDSC.ps1 }
            $Complete = $True
        } # If
    } # While

    Return $Complete
} # Start-LabVMDSC
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
function Get-LabUnattendFile {
    [CmdLetBinding()]
    [OutputType([String])]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable]$VM
    )
    If ($VM.UnattendFile) {
        [String]$UnattendContent = Get-Content -Path $VM.UnattendFile
    } Else {
        [String]$DomainName = $Configuration.labbuilderconfig.settings.domainname
        [String]$Email = $Configuration.labbuilderconfig.settings.email
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
            <ProductKey>$($VM.ProductKey)</ProductKey>
        </component>

"@
        If ($VM.OSType -eq 'Client') {
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
   $VMs = Get-LabVM -Configuration $Config
   $NetworkingDSC = Get-LabNetworkingDSCFile -Configuration $Config -VM $VMs[0]
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
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable]$VM
    )
    [String]$NetworkingDSCConfig = @"
Configuration Networking {
    Import-DscResource -ModuleName xNetworking

"@
    [Int]$AdapterCount = 0
    Foreach ($Adapter in $VM.Adapters)
    {
        $AdapterCount++
        If ($Adapter.IPv4)
        {
            If ($Adapter.IPv4.Address)
            {
$NetworkingDSCConfig += @"
    xIPAddress IPv4_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
        IPAddress      = '$($Adapter.IPv4.Address.Replace(',',"','"))'
        SubnetMask     = '$($Adapter.IPv4.SubnetMask)'
    }

"@
                If ($Adapter.IPv4.DefaultGateway)
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
            } # If
            If ($Adapter.IPv4.DNSServer -ne $null)
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
        If ($Adapter.IPv6)
        {
            If ($Adapter.IPv6.Address)
            {
$NetworkingDSCConfig += @"
    xIPAddress IPv6_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
        IPAddress      = '$($Adapter.IPv6.Address.Replace(',',"','"))'
        SubnetMask     = '$($Adapter.IPv6.SubnetMask)'
    }

"@
                If ($Adapter.IPv6.DefaultGateway)
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
            } # If
            If ($Adapter.IPv6.DNSServer -ne $null)
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
   $VMs = Get-LabVM -Configuration $Config
   $NetworkingDSC = Get-LabGetCertificatePs -Configuration $Config -VM $VMs[0]
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
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML] $Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable] $VM
    )
    [String]$CreateCertificatePs = @"
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
function Set-LabVMInitializationFiles {
    [CmdLetBinding()]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable]$VM,
        [Parameter(
            Mandatory,
            Position=2)]
        [String]$VMBootDiskPath
    )

    # Mount the VMs Boot VHD so that files can be loaded into it
    [String]$MountPoint = Join-Path -Path $ENV:Temp -ChildPath ([System.IO.Path]::GetRandomFileName())
    Write-Verbose "Mounting VM $($VM.Name) Boot Disk VHDx $VMBootDiskPath ..."
    $null = New-Item -Path $MountPoint -ItemType Directory
    $null = Mount-WindowsImage -ImagePath $VMBootDiskPath -Path $MountPoint -Index 1 | Out-Null

    # Copy the WMF 5.0 Installer to the VM in case it is needed
    # This contains a bug at the moment - waiting for MS to resolve
    # Write-Verbose "Applying VM $($VM.Name) WMF 5.0 ..."
    # Add-WindowsPackage -PackagePath $Script:WMF5InstallerPath -Path $MountPoint | Out-Null

    # Apply any additional MSU Updates
    Foreach ($URL in $VM.InstallMSU) {
        $MSUFilename = $URL.Substring($URL.LastIndexOf('/') + 1)
        $MSUPath = Join-Path -Path $Script:WorkingFolder -ChildPath $MSUFilename
        If (-not (Test-Path -Path $MSUPath)) {
            Invoke-WebRequest -Uri $URL -OutFile $MSUPath
        } # If
        # Once downloaded apply the update
        $null = Add-WindowsPackage -PackagePath $MSUPath -Path $MountPoint
    } # Foreach

    # Create the scripts folder where setup scripts will be put
    $null = New-Item -Path "$MountPoint\Windows\Setup\Scripts" -ItemType Directory

    # Generate and apply an unattended setup file
    [String]$UnattendFile = Get-LabUnattendFile -Configuration $Configuration -VM $VM
    Write-Verbose "Applying VM $($VM.Name) Unattend File ..."
    $null = Set-Content `
        -Path "$MountPoint\Windows\Panther\Unattend.xml" `
        -Value $UnattendFile -Force
    $null = Set-Content `
        -Path "$VMPath\$($VM.Name)\LabBuilder Files\Unattend.xml" `
        -Value $UnattendFile -Force
    [String]$SetupCompleteCmd = ''
    [String]$GetCertPs = Get-LabGetCertificatePs -Configuration $Configuration -VM $VM
    [String]$SetupCompletePs = @"
Add-Content -Path "C:\WINDOWS\Setup\Scripts\SetupComplete.log" -Value 'SetupComplete.ps1 Script Started...' -Encoding Ascii
$GetCertPs
Add-Content -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" -Value 'Self-signed certificate created and saved to C:\Windows\$Script:DSCEncryptionCert ...' -Encoding Ascii
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Add-Content -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" -Value 'Windows Remoting Enabled ...' -Encoding Ascii
"@
    If ($VM.SetupComplete) {
        [String]$SetupComplete = $VM.SetupComplete
        If (-not (Test-Path -Path $SetupComplete)) {
            Throw "SetupComplete Script file $SetupComplete could not be found for VM $($VM.Name)."
        }
        [String]$Extension = [System.IO.Path]::GetExtension($SetupComplete)
        Switch ($Extension.ToLower()) {
            '.ps1' {
                $SetupCompletePs += Get-Content -Path $SetupComplete
                Break
            } # 'ps1'
            '.cmd' {
                $SetupCompleteCmd += Get-Content -Path $SetupComplete
                Break
            } # 'cmd'
        } # Switch
    } # If

    # Write out the CMD Setup Complete File
    Write-Verbose "Applying VM $($VM.Name) Setup Complete CMD File ..."
    $SetupCompleteCmd = @"
@echo SetupComplete.cmd Script Started... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
$SetupCompleteCmd
powerShell.exe -ExecutionPolicy Unrestricted -Command `"%SYSTEMROOT%\Setup\Scripts\SetupComplete.ps1`"
@echo SetupComplete.cmd Script Finished... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
@echo Initial Setup Completed - this file indicates that setup has completed. >> %SYSTEMROOT%\Setup\Scripts\InitialSetupCompleted.txt
"@
    $null = Set-Content `
        -Path "$MountPoint\Windows\Setup\Scripts\SetupComplete.cmd" `
        -Value $SetupCompleteCmd -Force
    $null = Set-Content `
        -Path "$VMPath\$($VM.Name)\LabBuilder Files\SetupComplete.cmd" `
        -Value $SetupCompleteCmd -Force

    # Write out the PowerShell Setup Complete file
    Write-Verbose "Applying VM $($VM.Name) Setup Complete PowerShell File ..."
    $SetupCompletePs = @"
Add-Content -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" -Value 'SetupComplete.ps1 Script Started...' -Encoding Ascii
$SetupCompletePs
Add-Content -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" -Value 'SetupComplete.ps1 Script Finished...' -Encoding Ascii
"@

    $null = Set-Content `
        -Path "$MountPoint\Windows\Setup\Scripts\SetupComplete.ps1" `
        -Value $SetupCompletePs -Force
    $null = Set-Content `
        -Path "$VMPath\$($VM.Name)\LabBuilder Files\SetupComplete.ps1" `
        -Value $SetupCompletePs -Force

    Copy-Item `
        -Path $Script:CertGenPS1Path `
        -Destination "$MountPoint\Windows\Setup\Scripts\$($Script:CertGenPS1Filename)"`
        -Force
        
    # Dismount the VHD in preparation for boot
    Write-Verbose "Dismounting VM $($VM.Name) Boot Disk VHDx $VMBootDiskPath ..."
    $null = Dismount-WindowsImage -Path $MountPoint -Save
    $null = Remove-Item -Path $MountPoint -Recurse -Force
} # Set-LabVMInitializationFiles
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
function Get-LabVMs {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]]$VMTemplates,

        [Parameter(
            Mandatory,
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]]$Switches
    )

    [System.Collections.Hashtable[]]$LabVMs = @()
    [String]$VHDParentPath = $Configuration.labbuilderconfig.settings.vhdparentpath
    $VMs = $Configuration.labbuilderconfig.SelectNodes('vms').vm

    Foreach ($VM in $VMs) {
        If ($VM.Name -eq 'VM') {
            throw "The VM name cannot be 'VM' or empty."
        } # If
        If (-not $VM.Template) {
            throw "The template name in VM $($VM.Name) cannot be empty."
        } # If

        # Find the template that this VM uses and get the VHD Path
        [String]$TemplateVHDPath =''
        [Boolean]$Found = $false
        Foreach ($VMTemplate in $VMTemplates) {
            If ($VMTemplate.Name -eq $VM.Template) {
                $TemplateVHDPath = $VMTemplate.templatevhd
                $Found = $true
                Break
            } # If
        } # Foreach
        If (-not $Found) {
            throw "The template $($VM.Template) specified in VM $($VM.Name) could not be found."
        } # If
        # Check the VHD File path in the template is not empty
        If (-not $TemplateVHDPath) {
            throw "The template VHD path set in template $($VM.Template) cannot be empty."
        } # If

        # Assemble the Network adapters that this VM will use
        [System.Collections.Hashtable[]]$VMAdapters = @()
        [Int]$AdapterCount = 0
        Foreach ($VMAdapter in $VM.Adapters.Adapter) {
            $AdapterCount++
            If ($VMAdapter.Name -eq 'adapter') {
                Throw "The Adapter Name in VM $($VM.Name) cannot be 'adapter' or empty."
            }
            If (-not $VMAdapter.SwitchName) {
                Throw "The Switch Name specified in adapter $($VMAdapter.Name) specified in VM ($VM.Name) cannot be empty."
            }
            # Check the switch is in the switch list
            [Boolean]$Found = $False
            Foreach ($Switch in $Switches) {
                If ($Switch.Name -eq $VMAdapter.SwitchName) {
                    # The switch is found in the switch list - record the VLAN (if there is one)
                    $Found = $True
                    $SwitchVLan = $Switch.Vlan
                    Break
                } # If
            } # Foreach
            If (-not $Found) {
                throw "The switch $($VMAdapter.SwitchName) specified in VM ($VM.Name) could not be found in Switches."
            } # If
            
            # Figure out the VLan - If defined in the VM use it, otherwise use the one defined in the Switch, otherwise keep blank.
            [String]$VLan = $VMAdapter.VLan
            If (-not $VLan) {
                $VLan = $SwitchVLan
            } # If

            # Have we got any IPv4 settings?
            [System.Collections.Hashtable]$IPv4 = @{}
            If ($VMAdapter.IPv4) {
                $IPv4 = @{
                    Address = $VMAdapter.IPv4.Address;
                    defaultgateway = $VMAdapter.IPv4.DefaultGateway;
                    subnetmask = $VMAdapter.IPv4.SubnetMask;
                    dnsserver = $VMAdapter.IPv4.DNSServer
                }
            }

            # Have we got any IPv6 settings?
            [System.Collections.Hashtable]$IPv6 = @{}
            If ($VMAdapter.IPv6) {
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
                VLan = $VLan;
                IPv4 = $IPv4;
                IPv6 = $IPv6
            }
        } # Foreach

        # Does the VM have an Unattend file specified?
        [String]$UnattendFile = ''
        If ($VM.UnattendFile) {
            $UnattendFile = Join-Path `
                -Path $Configuration.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.UnattendFile
            If (-not (Test-Path $UnattendFile)) {
                Throw "The Unattend File $UnattendFile specified in VM $($VM.Name) can not be found."
            } # If
        } # If
        
        # Does the VM specify a Setup Complete Script?
        [String]$SetupComplete = ''
        If ($VM.SetupComplete) {
            $SetupComplete = Join-Path `
                -Path $Configuration.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.SetupComplete
            If (-not (Test-Path $SetupComplete)) {
                Throw "The Setup Complete File $SetupComplete specified in VM $($VM.Name) can not be found."
            } # If
            If ([System.IO.Path]::GetExtension($SetupComplete).ToLower() -notin '.ps1','.cmd' ) {
                Throw "The Setup Complete File $SetupComplete specified in VM $($VM.Name) must be either a PS1 or CMD file."
            } # If
        } # If

        # Load the DSC Config File setting and check it
        [String]$DSCConfigFile = ''
        If ($VM.DSC.ConfigFile) {
            $DSCConfigFile = Join-Path `
                -Path $Configuration.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.DSC.ConfigFile
            If (-not (Test-Path $DSCConfigFile)) {
                Throw "The DSC Config File $DSCConfigFile specified in VM $($VM.Name) can not be found."
            }
            If ([System.IO.Path]::GetExtension($DSCConfigFile).ToLower() -ne '.ps1' ) {
                Throw "The DSC Config File $DSCConfigFile specified in VM $($VM.Name) must be a PS1 file."
            }
            If (-not $VM.DSC.ConfigName) {
                Throw "The DSC Config Name specified in VM $($VM.Name) is empty."
            }
        }
        
        # Load the DSC Parameters
        [String]$DSCParameters = ''
        If ($VM.DSC.Parameters) {
            $DSCParameters = $VM.DSC.Parameters
        } # If

        # Load the DSC Parameters
        [BOolean]$DSCLogging = $False
        If ($VM.DSC.Logging -eq 'Y') {
            $DSCLogging = $True
        } # If

        # Get the Memory Startup Bytes (from the template or VM)
        [Int64]$MemoryStartupBytes = 1GB
        If ($VMTemplate.memorystartupbytes) {
            $MemoryStartupBytes = $VMTemplate.memorystartupbytes
        } # If
        If ($VM.memorystartupbytes) {
            $MemoryStartupBytes = (Invoke-Expression $VM.memorystartupbytes)
        } # If
        
        # Get the Memory Startup Bytes (from the template or VM)
        [Int]$ProcessorCount = 1
        If ($VMTemplate.processorcount) {
            $ProcessorCount = $VMTemplate.processorcount
        } # If
        If ($VM.processorcount) {
            $ProcessorCount = (Invoke-Expression $VM.processorcount)
        } # If

        # Get the data VHD Size (from the template or VM)
        [Int64]$DataVHDSize = 0
        If ($VMTemplate.datavhdsize) {
            $DataVHDSize = $VMTemplate.datavhdsize
        } # If
        If ($VM.DataVHDSize) {
            $DataVHDSize = (Invoke-Expression $VM.DataVHDSize)
        } # If
        
        # Get the Administrator password (from the template or VM)
        [String]$AdministratorPassword = ''
        If ($VMTemplate.administratorpassword) {
            $AdministratorPassword = $VMTemplate.administratorpassword
        } # If
        If ($VM.administratorpassword) {
            $AdministratorPassword = $VM.administratorpassword
        } # If

        # Get the Product Key (from the template or VM)
        [String]$ProductKey = ''
        If ($VMTemplate.productkey) {
            $ProductKey = $VMTemplate.productkey
        } # If
        If ($VM.productkey) {
            $ProductKey = $VM.productkey
        } # If

        # Get the Timezone (from the template or VM)
        [String]$Timezone = 'Pacific Standard Time'
        If ($VMTemplate.timezone) {
            $Timezone = $VMTemplate.timezone
        } # If
        If ($VM.timezone) {
            $Timezone = $VM.timezone
        } # If

        # Get the OS Type
        If ($VMTemplate.ostype) {
            $OSType = $VMTemplate.ostype
        } Else {
            $OSType = 'Server'
        } # If

        # Do we have any MSU files that are listed as needing to be applied to the OS before
        # first boot up?
        [String[]]$InstallMSU = @()
        Foreach ($Update in $VM.Install.MSU) {
            $InstallMSU += $Update.URL
        } # Foreach

        $LabVMs += @{
            Name = $VM.name;
            ComputerName = $VM.ComputerName;
            Template = $VM.template;
            TemplateVHD = $TemplateVHDPath;
            UseDifferencingDisk = $VM.usedifferencingbootdisk;
            MemoryStartupBytes = $MemoryStartupBytes;
            ProcessorCount = $ProcessorCount;
            AdministratorPassword = $AdministratorPassword;
            ProductKey = $ProductKey;
            TimeZone =$Timezone;
            Adapters = $VMAdapters;
            DataVHDSize = $DataVHDSize;
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
} # Get-LabVMs
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
function Get-LabVMSelfSignedCert {
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable]$VM,

        [Int]$Timeout = 300
    )
    [String]$VMPath = $Configuration.labbuilderconfig.SelectNodes('settings').vmpath
    [DateTime]$StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession]$Session = $null
    [PSCredential]$AdmininistratorCredential = New-Object System.Management.Automation.PSCredential ('Administrator', (ConvertTo-SecureString $VM.AdministratorPassword -AsPlainText -Force))
    [String]$ManagementSwitchName = ('LabBuilder Management {0}' -f $Configuration.labbuilderconfig.name)
    [Boolean]$Complete = $False
    While ((-not $Complete)  -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
        While (-not ($Session) -or ($Session.State -ne 'Opened')) {
            # Try and connect to the remote VM for up to $Timeout (5 minutes) seconds.
            Try {
                Write-Verbose "Attempting connection to $($VM.ComputerName) ..."
                [String]$IPAddress = (Get-VMNetworkAdapter -VMName $VM.Name).Where({$_.SwitchName -eq $ManagementSwitchName}).IPAddresses.Where({$_.Contains('.')})
                If (-not $IPAddress) {
                    Throw "An IPv4 address for an adapter connected to the $ManagementSwitchName for $($VM.ComputerName) could not be identified."
                }
                $Session = New-PSSession -ComputerName $IPAddress -Credential $AdmininistratorCredential -ErrorAction Stop
            } Catch {
                Write-Verbose "Connection to $($VM.ComputerName) failed - retrying in 5 seconds ..."
                Start-Sleep 5
            } # Try
        } # While

        If (($Session) -and ($Session.State -eq 'Opened') -and (-not $Complete)) {
            # We connected OK - download the Certificate file
            While ((-not $Complete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
                Try {
                    Copy-Item -Path "c:\windows\$Script:DSCEncryptionCert" -Destination "$VMPath\$($VM.Name)\LabBuilder Files\" -FromSession $Session -ErrorAction Stop
                    $Complete = $True
                } Catch {
                    Write-Verbose "Waiting for Certificate file on $($VM.ComputerName) ..."
                    Start-Sleep 5
                } # Try
            } # While
        } # If

        # Close the Session if it is opened and the download is complete
        If (($Session) -and ($Session.State -eq 'Opened') -and ($Complete)) {
            Remove-PSSession -Session $Session
        } # If
    } # While
    Return $Complete

} # Get-LabVMSelfSignedCert
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Download a credential encryption certificate from a running VM.
.DESCRIPTION
   This function uses remoting to download a credential encryption certificate
   from a running VM for use in encrypting DSC credentials. It will be saved
   as a .CER file in the LabBuilder files folder of the VM.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Configuration $Config
   Get-LabVMCertificate -Configuration $Configuration -VM $VM[0]
.OUTPUTS
   The path to the certificate file that was downloaded.
#>
function Get-LabVMCertificate {
    [CmdLetBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [System.Collections.Hashtable]$VM,

        [Int]$Timeout = 300
    )
    [DateTime]$StartTime = Get-Date
    [String]$VMPath = $Configuration.labbuilderconfig.SelectNodes('settings').vmpath
    [System.Management.Automation.Runspaces.PSSession]$Session = $null
    [PSCredential]$AdmininistratorCredential = New-Object System.Management.Automation.PSCredential ('Administrator', (ConvertTo-SecureString $VM.AdministratorPassword -AsPlainText -Force))
    [String]$ManagementSwitchName = ('LabBuilder Management {0}' -f $Configuration.labbuilderconfig.name)

    # Load path variables
    [String]$VMRootPath = Join-Path `
        -Path $VMPath `
        -ChildPath $VM.Name

    # Get Path to LabBuilder files
    [String]$VMLabBuilderFiles = Join-Path `
        -Path $VMRootPath `
        -ChildPath 'LabBuilder Files'

    [Boolean]$Complete = $False

    While ((-not $Complete)  -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
        While (-not ($Session) -or ($Session.State -ne 'Opened')) {
            # Try and connect to the remote VM for up to $Timeout (5 minutes) seconds.
            Try {
                Write-Verbose "Attempting connection to $($VM.ComputerName) ..."
                [String]$IPAddress = (Get-VMNetworkAdapter -VMName $VM.Name).Where({$_.SwitchName -eq $ManagementSwitchName}).IPAddresses.Where({$_.Contains('.')})
                If (-not $IPAddress) {
                    Throw "An IPv4 address for an adapter connected to the $ManagementSwitchName for $($VM.ComputerName) could not be identified."
                }
                $Session = New-PSSession -ComputerName $IPAddress -Credential $AdmininistratorCredential -ErrorAction Stop
            } Catch {
                Write-Verbose "Connection to $($VM.ComputerName) failed - retrying in 5 seconds ..."
                Start-Sleep 5
            } # Try
        } # While

        [String]$GetCertPs = Get-LabGetCertificatePs -Configuration $Configuration -VM $VM
        $null = Set-Content `
            -Path "$VMLabBuilderFiles\GetDSCEncryptionCert.ps1" `
            -Value $GetCertPs `
            -Force

        $Complete = $False

        If (($Session) -and ($Session.State -eq 'Opened') -and (-not $Complete)) {
            # We connected OK - Upload the script
            While ((-not $Complete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
                Try {
                    Copy-Item `
                        -Path "$VMLabBuilderFiles\GetDSCEncryptionCert.ps1" `
                        -Destination 'c:\windows\setup\scripts\' `
                        -ToSession $Session -Force -ErrorAction Stop
                    $Complete = $True
                } Catch {
                    Write-Verbose "Waiting to upload certificate create script file to $($VM.ComputerName) ..."
                    Start-Sleep 5
                } # Try
            } # While
        } # If
        
        $Complete = $False

        If (($Session) -and ($Session.State -eq 'Opened') -and (-not $Complete)) {
            # Script uploaded, run it
            While ((-not $Complete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
                Try {
                    Invoke-Command -Session $Session -ScriptBlock {
                        C:\Windows\Setup\Scripts\GetDSCEncryptionCert.ps1
                    }
                    $Complete = $True
                } Catch {
                    Write-Verbose "Waiting to upload certificate create script file to $($VM.ComputerName) ..."
                    Start-Sleep 5
                } # Try
            } # While
        } # If

        $Complete = $False

        If (($Session) -and ($Session.State -eq 'Opened') -and (-not $Complete)) {
            # Now download the Certificate
            While ((-not $Complete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
                Try {
                    $null = Copy-Item `
                        -Path "c:\windows\$($Script:DSCEncryptionCert)" `
                        -Destination "$VMLabBuilderFiles" `
                        -FromSession $Session `
                        -ErrorAction Stop
                    $Complete = $True
                } Catch {
                    Write-Verbose "Waiting for Certificate file on $($VM.ComputerName) ..."
                    Start-Sleep 5
                } # Try
            } # While
        } # If

        # Close the Session if it is opened and the download is complete
        If (($Session) -and ($Session.State -eq 'Opened') -and ($Complete)) {
            Remove-PSSession -Session $Session
        } # If
    } # While

    if ($Complete)
    {
        return (Get-Item -Path "$VMLabBuilderFiles\$($Script:DSCEncryptionCert)")
    }
} # Get-LabVMCertificate
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
    [OutputType([Boolean])]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        $VM
    )

    [String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath

    # The VM is now ready to be started
    If ((Get-VM -Name $VM.Name).State -eq 'Off') {
        Write-Verbose "VM $($VM.Name) is starting ..."

        Start-VM -VMName $VM.Name
    } # If

    # We only perform this section of VM Initialization (DSC, Cert, etc) with Server OS
    If ($VM.OSType -eq 'Server') {
        # Has this VM been initialized before (do we have a cer for it)
        If (-not (Test-Path "$VMPath\$($VM.Name)\LabBuilder Files\$Script:DSCEncryptionCert")) {
            # No, so check it is initialized and download the cert.
            If (Wait-LabVMInit -VM $VM) {
                Write-Verbose "Attempting to download certificate for VM $($VM.Name) ..."
                If (Get-LabVMSelfSignedCert -Configuration $Configuration -VM $VM) {
                    Write-Verbose "Certificate for VM $($VM.Name) was downloaded successfully ..."
                } Else {
                    Write-Verbose "Certificate for VM $($VM.Name) could not be downloaded ..."
                } # If
            } Else {
                Write-Verbose "Initialization for VM $($VM.Name) did not complete ..."
            } # If
        } # If

        # Create any DSC Files for the VM
        $null = Initialize-LabVMDSC -Configuration $Configuration -VM $VM

        # Attempt to start DSC on the VM
        $null = Start-LabVMDSC -Configuration $Configuration -VM $VM
    } # If
    Return $True
} # Start-LabVM
####################################################################################################

####################################################################################################
<#
.SYNOPSIS
   Creates the folder structure that will contain a Lab Virtual Machine. 
.DESCRIPTION
   Creates a standard Hyper-V Virtual Machine folder structure as well as additional folders
   for containing configuration files for DSC.
.EXAMPLE
   Create-LabVMPath -VMPath 'c:\VMs\Lab\Virtual Machine 1'
   The command will create the Virtual Machine structure for a Lab VM in the folder:
   'c:\VMs\Lab\Virtual Machine 1'
.OUTPUTS
   None.
#>
function Create-LabVMPath {
    [CmdLetBinding()]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [String] $VMPath
    )

    If (-not (Test-Path -Path $VMPath)) {
        $Null = New-Item -Path $VMPath -ItemType Directory
    }
    If (-not (Test-Path -Path "$VMPath\Virtual Machines")) {
        $Null = New-Item -Path "$VMPath\Virtual Machines" -ItemType Directory
    }
    If (-not (Test-Path -Path "$VMPath\Virtual Hard Disks")) {
        $Null = New-Item -Path "$VMPath\Virtual Hard Disks" -ItemType Directory
    }
    If (-not (Test-Path -Path "$VMPath\LabBuilder Files")) {
        $Null = New-Item -Path "$VMPath\LabBuilder Files" -ItemType Directory
    }
    If (-not (Test-Path -Path "$VMPath\LabBuilder Files\DSC Modules")) {
        $Null = New-Item -Path "$VMPath\LabBuilder Files\DSC Modules" -ItemType Directory
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
function Initialize-LabVMs {
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]]$VMs
    )
    
    $CurrentVMs = Get-VM
    [String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath

	# Figure out the name of the LabBuilder control switch
    $ManagementSwitchName = ('LabBuilder Management {0}' -f $Configuration.labbuilderconfig.name)
    if ($Configuration.labbuilderconfig.switches.ManagementVlan)
	{
		[Int32]$ManagementVlan = $Configuration.labbuilderconfig.switches.ManagementVlan
	}
	else
	{
		[Int32]$ManagementVlan = $Script:DefaultManagementVLan
	}

    Foreach ($VM in $VMs) {
        If (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -eq 0) {
            Write-Verbose "Creating VM $($VM.Name) ..."

            # Make sure the appropriate folders exist
            Create-LabVMPath -VMPath "$VMPath\$($VM.Name)"

            # Create the boot disk
            $VMBootDiskPath = "$VMPath\$($VM.Name)\Virtual Hard Disks\$($VM.Name) Boot Disk.vhdx"
            If (-not (Test-Path -Path $VMBootDiskPath)) {
                If ($VM.UseDifferencingDisk -eq 'Y') {
                    Write-Verbose "VM $($VM.Name) differencing boot disk $VMBootDiskPath being created ..."
                    $Null = New-VHD -Differencing -Path $VMBootDiskPath -ParentPath $VM.TemplateVHD
                } Else {
                    Write-Verbose "VM $($VM.Name) boot disk $VMBootDiskPath being created ..."
                    $Null = Copy-Item -Path $VM.TemplateVHD -Destination $VMBootDiskPath
                }

                # Because this is a new boot disk assign any required initialization files to it (Unattend.xml etc).
                Set-LabVMInitializationFiles -Configuration $Configuration -VMBootDiskPath $VMBootDiskPath -VM $VM
            } Else {
                Write-Verbose "VM $($VM.Name) boot disk $VMBootDiskPath already exists..."
            } # If

            $null = New-VM `
                -Name $VM.Name `
                -MemoryStartupBytes $VM.MemoryStartupBytes `
                -Generation 2 -Path $VMPath `
                -VHDPath $VMBootDiskPath
            # Remove the default network adapter created with the VM because we don't need it
            Remove-VMNetworkAdapter -VMName $VM.Name -Name 'Network Adapter'
        }

        # Set the processor count if different to default and if specified in config file
        If ($VM.ProcessorCount) {
            If ($VM.ProcessorCount -ne (Get-VM -Name $VM.Name).ProcessorCount) {
                Set-VM -Name $VM.Name -ProcessorCount $VM.ProcessorCount
            } # If
        } # If

        # Do we need to add a data disk?
        If ($VM.DataVHDSize -and ($VM.DataVHDSize -gt 0)) {
            [String]$VMDataDiskPath = "$VMPath\$($VM.Name)\Virtual Hard Disks\$($VM.Name) Data Disk.vhdx"
            # Does the disk already exist?
            If (Test-Path -Path $VMDataDiskPath) {
                Write-Verbose "VM $($VM.Name) data disk $VMDataDiskPath already exists ..."
                # Does the disk need to shrink or grow?
                If ((Get-VHD -Path $VMDataDiskPath).Size -lt $VM.DataVHDSize) {
                    Write-Verbose "VM $($VM.Name) Data Disk $VMDataDiskPath expanding to $($VM.DataVHDSize) ..."
                    $null = Resize-VHD -Path $VMDataDiskPath -SizeBytes $VM.DataVHDSize
                } Elseif ((Get-VHD -Path $VMDataDiskPath).Size -gt $VM.DataVHDSize) {
                    Throw "VM $($VM.Name) Data Disk $VMDataDiskPath cannot be shrunk to $($VM.DataVHDSize) ..."
                }
            } Else {
                # Create a new VHD
                Write-Verbose "VM $($VM.Name) data disk $VMDataDiskPath is being created ..."
                $null = New-VHD -Path $VMDataDiskPath -SizeBytes $VM.DataVHDSize -Dynamic
            } # If
            # Does the disk already exist in the VM
            If ((Get-VMHardDiskDrive -VMName $VM.Name | Where-Object -Property Path -EQ $VMDataDiskPath).Count -EQ 0) {
                Write-Verbose "VM $($VM.Name) data disk $VMDataDiskPath is being added to VM ..."
                $Null = Add-VMHardDiskDrive -VMName $VM.Name -Path $VMDataDiskPath -ControllerType SCSI -ControllerLocation 1 -ControllerNumber 0
            } # If
        } # If
            
        # Create/Update the Management Network Adapter
		if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $ManagementSwitchName).Count -eq 0) {
			Write-Verbose "VM $($VM.Name) management network adapter $ManagementSwitchName is being added ..."
			Add-VMNetworkAdapter -VMName $VM.Name -SwitchName $ManagementSwitchName -Name $ManagementSwitchName
		}
        $VMNetworkAdapter = Get-VMNetworkAdapter -VMName $VM.Name -Name $ManagementSwitchName
        $null = $VMNetworkAdapter | Set-VMNetworkAdapterVlan -Access -VlanId $ManagementVlan
        Write-Verbose "VM $($VM.Name) management network adapter $ManagementSwitchName VLAN has been set to $ManagementVlan ..."

        # Create any network adapters
		Foreach ($VMAdapter in $VM.Adapters) {
            If ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $VMAdapter.Name).Count -eq 0) {
                Write-Verbose "VM $($VM.Name) network adapter $($VMAdapter.Name) is being added ..."
                Add-VMNetworkAdapter -VMName $VM.Name -SwitchName $VMAdapter.SwitchName -Name $VMAdapter.Name
            } # If
            $VMNetworkAdapter = Get-VMNetworkAdapter -VMName $VM.Name -Name $VMAdapter.Name
            $Vlan = $VMAdapter.VLan
            If ($VLan) {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapterVlan -Access -VlanId $Vlan
                Write-Verbose "VM $($VM.Name) network adapter $($VMAdapter.Name) VLAN has been set to $Vlan ..."
            } Else {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapterVlan -Untagged
                Write-Verbose "VM $($VM.Name) network adapter $($VMAdapter.Name) VLAN has been cleared ..."
            } # If
            If ($VMAdapter.MACAddress) {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -StaticMacAddress $VMAdapter.MACAddress
            } Else {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -DynamicMacAddress
            } # If
            # Enable Device Naming
            if ((Get-Command -Name Set-VMNetworkAdapter).Parameters.ContainsKey('DeviceNaming')) {
				$null = $VMNetworkAdapter | Set-VMNetworkAdapter -DeviceNaming On
			}
        } # Foreach

        $null = Start-LabVM -Configuration $Config -VM $VM
    } # Foreach
    Return $True
} # Initialize-LabVMs
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
function Remove-LabVMs {
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [XML]$Configuration,

        [Parameter(
            Mandatory,
            position=1)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]]$VMs,

        [Switch]$RemoveVHDs
    )
    
    $CurrentVMs = Get-VM
    [String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath
    
    Foreach ($VM in $VMs) {
        If (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -ne 0) {
            # If the VM is running we need to shut it down.
            If ((Get-VM -Name $VM.Name).State -eq 'Running') {
                Write-Verbose "Stopping VM $($VM.Name) ..."
                Stop-VM -Name $VM.Name
                # Wait for it to completely shut down and report that it is off.
                Wait-LabVMOff -VM $VM | Out-Null
            }
            Write-Verbose "Removing VM $($VM.Name) ..."

            # Should we also delete the VHDs from the VM?
            If ($RemoveVHDs) {
                Write-Verbose "Deleting VM $($VM.Name) hard drive(s) ..."
                Get-VMHardDiskDrive -VMName $VM.Name | Select-Object -Property Path | Remove-Item
            }
            
            # Now delete the actual VM
            Get-VM -Name $VMs.Name | Remove-VM -Confirm:$false

            Write-Verbose "Removed VM $($VM.Name) ..."
        } Else {
            Write-Verbose "VM $($VM.Name) is not in Hyper-V ..."
        }
    }
    Return $true
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
function Wait-LabVMInit {
    [OutputType([Boolean])]
    [CmdLetBinding()]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [System.Collections.Hashtable]$VM,

        [Int]$Timeout = 300
    )

    [DateTime]$StartTime = Get-Date
    [Boolean]$Found = $False
    [System.Management.Automation.Runspaces.PSSession]$Session = $null
    [PSCredential]$AdmininistratorCredential = New-Object System.Management.Automation.PSCredential ('Administrator', (ConvertTo-SecureString $VM.AdministratorPassword -AsPlainText -Force))
    [String]$ManagementSwitchName = ('LabBuilder Management {0}' -f $Configuration.labbuilderconfig.name)

    # Make sure the VM has started
    Wait-LabVMStart -VM $VM

    [Boolean]$Complete = $False
    While ((-not $Complete)  -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
        While (-not ($Session) -or ($Session.State -ne 'Opened')) {
            # Try and connect to the remote VM for up to $Timeout (5 minutes) seconds.
            Try {
                Write-Verbose "Attempting connection to $($VM.ComputerName) ..."
                [String]$IPAddress = (Get-VMNetworkAdapter -VMName $VM.Name).Where({$_.SwitchName -eq $ManagementSwitchName}).IPAddresses.Where({$_.Contains('.')})
                If (-not $IPAddress) {
                    Throw "An IPv4 address for an adapter connected to the $ManagementSwitchName for $($VM.ComputerName) could not be identified."
                }
                $Session = New-PSSession -ComputerName $IPAddress -Credential $AdmininistratorCredential -ErrorAction Stop
            } Catch {
                Write-Verbose "Connection to $($VM.ComputerName) failed - retrying in 5 seconds ..."
                Start-Sleep 5
            } # Try
        } # While

        If (($Session) -and ($Session.State -eq 'Opened') -and (-not $Complete)) {
            # We connected OK - check for init file
            While ((-not $Complete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
                Try {
                    $Complete = Invoke-Command -Session $Session {Test-Path "$($ENV:SystemRoot)\Setup\Scripts\InitialSetupCompleted.txt" } -ErrorAction Stop
                } Catch {
                    Write-Verbose "Waiting for Certificate file on $($VM.ComputerName) ..."
                    Start-Sleep 5
                } # Try
            } # While
        } # If

        # Close the Session if it is opened
        If (($Session) -and ($Session.State -eq 'Opened')) {
            Remove-PSSession -Session $Session
        } # If
    } # While

    Return $Complete
} # Wait-LabVMInit
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
function Wait-LabVMStart {
    [OutputType([Boolean])]
    [CmdLetBinding()]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [System.Collections.Hashtable]$VM
    )
    $Heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name Heartbeat
    while ($Heartbeat.PrimaryStatusDescription -ne 'OK')
    {
        $Heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name Heartbeat
        Start-Sleep 1
    } # while

    Return $True
} # Wait-LabVMStart
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
function Wait-LabVMOff {
    [OutputType([Boolean])]
    [CmdLetBinding()]
    param (
        [Parameter(
            Mandatory,
            Position=0)]
        [System.Collections.Hashtable]$VM
    )
    $RunningVM = Get-VM -Name $VM.Name
    while ($RunningVM.State -ne 'Off')
    {
        $RunningVM = Get-VM -Name $VM.Name
        Start-Sleep 1
    } # while

    Return $True
} # Wait-LabVMOff
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
    param (
        [parameter(
            Mandatory,
            Position=0)]
        [String]$Path,

        [Switch]$CheckEnvironment
    ) # Param

    [XML]$Config = Get-LabConfiguration -Path $Path
    
    # Make sure everything is OK to install the lab
    if (-not (Test-LabConfiguration -Configuration $Config)) {
        return
    }
       
    If ($CheckEnvironment) {
        Install-LabHyperV
    }

    Initialize-LabConfiguration -Configuration $Config

    $Switches = Get-LabSwitches -Configuration $Config
    Initialize-LabSwitches -Configuration $Config -Switches $Switches

    $VMTemplates = Get-LabVMTemplates -Configuration $Config
    Initialize-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates

    $VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
    Initialize-LabVMs -Configuration $Config -VMs $VMs
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
    param (
        [parameter(
            Mandatory,
            Position=0)]
        [String]$Path,

        [Switch]$RemoveSwitches,

        [Switch]$RemoveTemplates,

        [Switch]$RemoveVHDs
    ) # Param

    [XML]$Config = Get-LabConfiguration -Path $Path

    # Make sure everything is OK to install the lab
    if (-not (Test-LabConfiguration -Configuration $Config)) {
        return
    }

    $VMTemplates = Get-LabVMTemplates -Configuration $Config

    $Switches = Get-LabSwitches -Configuration $Config

    $VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
    If ($RemoveVHDs) {
        Remove-LabVMs -Configuration $Config -VMs $VMs -RemoveVHDs | Out-Null
    } Else {
        Remove-LabVMs -Configuration $Config -VMs $VMs | Out-Null
    } # If

    If ($RemoveTemplates) {
        Remove-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates | Out-Null
    } # If

    If ($RemoveSwitches) {
        Remove-LabSwitches -Configuration $Config -Switches $Switches | Out-Null
    } # If
} # Uninstall-Lab
####################################################################################################

####################################################################################################
# DSC Config Files
####################################################################################################
[DSCLocalConfigurationManager()]
Configuration ConfigLCM {
    Param (
        [String]$ComputerName,
        [String]$Thumbprint
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
    Get-LabConfiguration,Test-LabConfiguration, `
    Install-LabHyperV,Initialize-LabConfiguration,Download-LabResources, `
    Get-LabSwitches,Initialize-LabSwitches,Remove-LabSwitches, `
    Get-LabVMTemplates,Initialize-LabVMTemplates,Remove-LabVMTemplates, `
    Get-LabVMs,Initialize-LabVMs,Remove-LabVMs, `
    Set-LabVMDSCMOFFile,Set-LabVMDSCStartFile,Initialize-LabVMDSC, `
    Get-LabUnattendFile, Set-LabVMInitializationFiles, `
    Start-LabVM, Wait-LabVMStart, Wait-LabVMOff, Wait-LabVMInit, `
    Get-LabVMSelfSignedCert, `
    Install-Lab,Uninstall-Lab
####################################################################################################
