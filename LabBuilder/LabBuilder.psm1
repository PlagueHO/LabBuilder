#Requires -version 5.0
#Requires -RunAsAdministrator

$moduleRoot = Split-Path `
    -Path $MyInvocation.MyCommand.Path `
    -Parent

#region LocalizedData
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


#region ImportFunctions
# Dot source any functions in the libs folder
$Libs = Get-ChildItem `
    -Path (Join-Path -Path $moduleRoot -ChildPath 'lib') `
    -Include '*.ps1' `
    -Recurse
$Libs.Foreach(
    {
        Write-Verbose -Message $($LocalizedData.ImportingLibFileMessage `
            -f $_.Fullname)
        . $_.Fullname
    }
)
#endregion


#region LabBuilderTypes
<#
.SYNOPSIS
    Declares types and classes used by LabBuilder cmdlets.
#>
Enum LabOStype {
    Server = 1
    Nano = 2
    Client = 3
} # Enum LabOStype

Enum LabVHDType {
    Fixed = 1
    Dynamic = 2
    Differencing = 3
} # Enum LabVHDType

Enum LabVHDFormat {
    VHD = 1
    VHDx = 2
} # Enum LabVHDFormat

Enum LabSwitchType {
    Private = 1
    Internal = 2
    External = 3
    NAT = 4
} # Enum LabSwitchType

Enum LabPartitionStyle {
    MBR = 1
    GPT = 2
} # Enum LabPartitionStyle

Enum LabFileSystem {
    FAT32 = 1
    exFAT = 2
    NTFS = 3
    ReFS = 4
} # Enum LabFileSystem

Enum LabCertificateSource {
    Guest = 1
    Host = 2
} # Enum LabCertificateSource

class LabResourceModule:System.ICloneable {
    [String] $Name
    [String] $URL
    [String] $Folder
    [String] $MinimumVersion
    [String] $RequiredVersion

    LabResourceModule() {}

    LabResourceModule($Name) {
        $this.Name = $Name
    } # Constructor

    [Object] Clone () {
        $New = [LabResourceModule]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabResourceModule

class LabResourceMSU:System.ICloneable {
    [String] $Name
    [String] $URL
    [String] $Path
    [String] $Filename

    LabResourceMSU() {}

    LabResourceMSU($Name) {
        $this.Name = $Name
    } # Constructor

    LabResourceMSU($Name,$URL) {
        $this.Name = $Name
        $this.URL = $URL
    } # Constructor

    [Object] Clone () {
        $New = [LabResourceMSU]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabResourceMSU

class LabResourceISO:System.ICloneable {
    [String] $Name
    [String] $URL
    [String] $Path

    LabResourceISO() {}

    LabResourceISO($Name) {
        $this.Name = $Name
    } # Constructor

    [Object] Clone () {
        $New = [LabResourceISO]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabResourceISO

class LabSwitchAdapter:System.ICloneable {
    [String] $Name
    [String] $MACAddress
    [Byte] $Vlan

    LabSwitchAdapter() {}

    LabSwitchAdapter($Name) {
        $this.Name = $Name
    } # Constructor

    LabSwitchAdapter($Name,$Type) {
        $this.Name = $Name
        $this.Type = $Type
    } # Constructor

    [Object] Clone () {
        $New = [LabSwitchAdapter]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabSwitchAdapter

class LabVMAdapterIPv4:System.ICloneable {
    [String] $Address
    [String] $DefaultGateway
    [Byte] $SubnetMask
    [String] $DNSServer

    LabVMAdapterIPv4() {}

    LabVMAdapterIPv4($Address,$SubnetMask) {
        $this.Address = $Address
        $this.SubnetMask = $SubnetMask
    } # Constructor
    
    [Object] Clone () {
        $New = [LabVMAdapterIPv4]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabVMAdapterIPv4

class LabVMAdapterIPv6:System.ICloneable {
    [String] $Address
    [String] $DefaultGateway
    [Byte] $SubnetMask
    [String] $DNSServer

    LabVMAdapterIPv6() {}

    LabVMAdapterIPv6($Address,$SubnetMask) {
        $this.Address = $Address
        $this.SubnetMask = $SubnetMask
    } # Constructor

    [Object] Clone () {
        $New = [LabVMAdapterIPv6]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabVMAdapterIPv6

class LabVMAdapter:System.ICloneable {
    [String] $Name
    [String] $SwitchName
    [String] $MACAddress
    [Boolean] $MACAddressSpoofing
    [Byte] $Vlan
    [LabVMAdapterIPv4] $IPv4
    [LabVMAdapterIPv6] $IPv6

    LabVMAdapter() {}

    LabVMAdapter($Name) {
        $this.Name = $Name
    } # Constructor
    
    [Object] Clone () {
        $New = [LabVMAdapter]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabVMAdapter

class LabDataVHD:System.ICloneable {
    [String] $VHD
    [LabVHDType] $VHDType
    [Uint64] $Size
    [String] $SourceVHD
    [String] $ParentVHD
    [Boolean] $MoveSourceVHD
    [String] $CopyFolders
    [LabFileSystem] $FileSystem
    [LabPartitionStyle] $PartitionStyle
    [String] $FileSystemLabel
    [Boolean] $Shared = $False
    [Boolean] $SupportPR = $False

    LabDataVHD() {}
    
    LabDataVHD($VHD) {
        $this.VHD = $VHD
    } # Constructor

    [Object] Clone () {
        $New = [LabDataVHD]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabDataVHD

class LabDVDDrive:System.ICloneable {
    [String] $ISO
    [String] $Path

    LabDVDDrive() {}
    
    LabDVDDrive($ISO) {
        $this.ISO = $ISO
    } # Constructor

    [Object] Clone () {
        $New = [LabDVDDrive]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabDVDDrive

class LabVMTemplateVHD:System.ICloneable {
    [String] $Name
    [String] $ISOPath
    [String] $VHDPath
    [LabOStype] $OSType = [LabOStype]::Server
    [String] $Edition
    [Byte] $Generation = 2
    [LabVHDFormat] $VHDFormat = [LabVHDFormat]::VHDx
    [LabVHDType] $VHDType = [LabVHDType]::Dynamic 
    [Uint64] $VHDSize = 0
    [String[]] $Packages
    [String[]] $Features

    LabVMTemplateVHD() {}
    
    LabVMTemplateVHD($Name) {
        $this.Name = $Name
    } # Constructor

    [Object] Clone () {
        $New = [LabVMTemplateVHD]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabVMTemplateVHD

class LabVMTemplate:System.ICloneable {
    [String] $Name
    [String] $VHD
    [String] $SourceVHD
    [String] $ParentVHD
    [String] $TemplateVHD
    [Uint64] $MemoryStartupBytes = 1GB
    [Boolean] $DynamicMemoryEnabled = $True
    [Boolean] $ExposeVirtualizationExtensions = $False
    [Byte] $ProcessorCount = 1
    [String] $AdministratorPassword
    [String] $ProductKey
    [String] $Timezone="Pacific Standard Time"
    [LabOStype] $OSType = [LabOStype]::Server
    [String[]] $IntegrationServices = @('Guest Service Interface','Heartbeat','Key-Value Pair Exchange','Shutdown','Time Synchronization','VSS') 
    [String[]] $Packages

    LabVMTemplate() {}
    
    LabVMTemplate($Name) {
        $this.Name = $Name
    } # Constructor

    [Object] Clone () {
        $New = [LabVMTemplate]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabVMTemplate

class LabSwitch:System.ICloneable {
    [String] $Name
    [LabSwitchType] $Type
    [Byte] $VLAN
    [String] $NATSubnetAddress
    [String] $BindingAdapterName
    [String] $BindingAdapterMac
    [LabSwitchAdapter[]] $Adapters

    LabSwitch() {}
    
    LabSwitch($Name) {
        $this.Name = $Name
    } # Constructor

    LabSwitch($Name,$Type) {
        $this.Name = $Name
        $this.Type = $Type
    } # Constructor

    [Object] Clone () {
        $New = [LabSwitch]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabSwitch

class LabDSC:System.ICloneable {
    [String] $ConfigName
    [String] $ConfigFile
    [String] $Parameters
    [Boolean] $Logging = $False

    LabDSC() {}
    
    LabDSC($ConfigName) {
        $this.ConfigName = $ConfigName
    } # Constructor

    LabDSC($ConfigName,$ConfigFile) {
        $this.ConfigName = $ConfigName
        $this.ConfigFile = $ConfigFile
    } # Constructor
    
    [Object] Clone () {
        $New = [LabDSC]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabDSC

class LabVM:System.ICloneable {
    [String] $Name
    [String] $Template
    [String] $ComputerName
    [Byte] $ProcessorCount
    [Uint64] $MemoryStartupBytes = 1GB
    [Boolean] $DynamicMemoryEnabled = $True
    [Boolean] $ExposeVirtualizationExtensions = $True
    [String] $ParentVHD
    [Boolean] $UseDifferencingDisk = $True
    [String] $AdministratorPassword
    [String] $ProductKey
    [String] $Timezone="Pacific Standard Time"
    [LabOStype] $OSType = [LabOStype]::Server
    [String] $UnattendFile
    [String] $SetupComplete
    [String[]] $Packages
    [Int] $BootOrder
    [String[]] $IntegrationServices = @('Guest Service Interface','Heartbeat','Key-Value Pair Exchange','Shutdown','Time Synchronization','VSS')
    [LabVMAdapter[]] $Adapters
    [LabDataVHD[]] $DataVHDs
    [LabDVDDrive[]] $DVDDrives
    [LabDSC] $DSC
    [String] $VMRootPath
    [String] $LabBuilderFilesPath
    [LabCertificateSource] $CertificateSource = [LabCertificateSource]::Guest

    LabVM() {}
    
    LabVM($Name) {
        $this.Name = $Name
    } # Constructor

    LabVM($Name,$ComputerName) {
        $this.Name = $Name
        $this.ComputerName = $ComputerName
    } # Constructor

    [Object] Clone () {
        $New = [LabVM]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabVM

class LabDSCModule:System.ICloneable {
    [String] $ModuleName
    [String] $ModuleVersion

    LabDSCModule() {}
    
    LabDSCModule($ModuleName) {
        $this.ModuleName = $ModuleName
    } # Constructor

    LabDSCModule($ModuleName,$ModuleVersion) {
        $this.ModuleName = $ModuleName
        $this.ModuleVersion = $ModuleVersion
    } # Constructor

    [Object] Clone () {
        $New = [LabDSCModule]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $New.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $New
    } # Clone
} # class LabDSCModule
#endregion


#region ModuleVariables
[String] $Script:WorkingFolder = $ENV:Temp

# Supporting files
[String] $Script:SupportConvertWindowsImagePath = Join-Path -Path $PSScriptRoot -ChildPath 'Support\Convert-WindowsImage.ps1'
[String] $Script:SupportGertGenPath = Join-Path -Path $PSScriptRoot -ChildPath 'Support\New-SelfSignedCertificateEx.ps1'

# DSC Library
[String] $Script:DSCLibraryPath = Join-Path -Path $PSScriptRoot -ChildPath 'DSCLibrary'

# Virtual Networking Parameters
[Int] $Script:DefaultManagementVLan = 99

# Self-signed Certificate Parameters
[Int] $Script:SelfSignedCertKeyLength = 2048
# Warning - using KSP causes the Private Key to not be accessible to PS.
[String] $Script:SelfSignedCertProviderName = 'Microsoft Enhanced Cryptographic Provider v1.0' # 'Microsoft Software Key Storage Provider'
[String] $Script:SelfSignedCertAlgorithmName = 'RSA' # 'ECDH_P256' Or 'ECDH_P384' Or 'ECDH_P521'
[String] $Script:SelfSignedCertSignatureAlgorithm = 'SHA256' # 'SHA1'
[String] $Script:DSCEncryptionCert = 'DSCEncryption.cer'
[String] $Script:DSCEncryptionPfxCert = 'DSCEncryption.pfx'
[String] $Script:DSCCertificateFriendlyName = 'DSC Credential Encryption'
[String] $Script:DSCCertificatePassword = 'E3jdNkd903mDn43NEk2nbDENjw'
[Int] $Script:RetryConnectSeconds = 5
[Int] $Script:RetryHeartbeatSeconds = 1
[Int] $Script:StartupTimeout = 90

# XML Stuff
[String] $Script:ConfigurationXMLSchema = Join-Path -Path $PSScriptRoot -ChildPath 'schema\labbuilderconfig-schema.xsd'
[String] $Script:ConfigurationXMLTemplate = Join-Path -Path $PSScriptRoot -ChildPath 'template\labbuilderconfig-template.xml'

#region LabResourceFunctions
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

            Write-Verbose -Message $($LocalizedData.DownloadingResourceModuleMessage `
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
                Write-Verbose -Message $($LocalizedData.DownloadingResourceMSUMessage `
                    -f $MSU.Name,$MSU.URL)

                DownloadAndUnzipFile `
                    -URL $MSU.URL `
                    -DestinationPath (Split-Path -Path $MSU.Filename)
            } # if
        } # foreach
    } # if
} # Initialize-LabResourceMSU
#endregion


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
                        -Path $Lab.labbuilderconfig.settings.resourcepathfull `
                        -ChildPath $Path
                } # if

                if (-not (Test-Path -Path $Path))
                {
                    $ExceptionParameters = @{
                        errorId = 'ResourceISOFileNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ResourceISOFileNotFoundError `
                            -f $Path)
                    }
                    ThrowException @ExceptionParameters
                } # if
            }
            else
            {
                $Path = $Lab.labbuilderconfig.settings.resourcepathfull
                if ($ISO.URL)
                {
                    $Path = Join-Path `
                        -Path $Path `
                        -ChildPath $ISO.URL.Substring($ISO.URL.LastIndexOf('/') + 1)
                } # if
            } # if
            $ResourceISO.URL = $ISO.URL
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
    }

    if ($ResourceISOs)
    {
        foreach ($ResourceISO in $ResourceISOs)
        {
            if (-not (Test-Path -Path $ResourceISO.Path))
            {
                Write-Verbose -Message $($LocalizedData.DownloadingResourceISOMessage `
                    -f $ResourceISO.Name,$ResourceISO.URL)

                DownloadAndUnzipFile `
                    -URL $ResourceISO.URL `
                    -DestinationPath (Split-Path -Path $ResourceISO.Path)
            } # if
        } # foreach
    } # if
} # Initialize-LabResourceISO
#endregion


#region LabSwitchFunctions
<#
.SYNOPSIS
    Gets an array of switches from a Lab.
.DESCRIPTION
    Takes a provided Lab and returns the array of LabSwitch objects required for this Lab.
    This list is usually passed to Initialize-LabSwitch to configure the switches required for this lab.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of Switch names.

    Only Switches matching names in this list will be pulled into the returned in the array.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $Switches = Get-LabSwitch -Lab $Lab
    Loads a Lab and pulls the array of switches from it.
.OUTPUTS
    Returns an array of LabSwitch objects.
#>
function Get-LabSwitch {
    [OutputType([LabSwitch[]])]
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

    [String] $LabId = $Lab.labbuilderconfig.settings.labid 
    [LabSwitch[]] $Switches = @() 
    $ConfigSwitches = $Lab.labbuilderconfig.Switches.Switch

    foreach ($ConfigSwitch in $ConfigSwitches)
    {
        # It can't be switch because if the name attrib/node is missing the name property on the
        # XML object defaults to the name of the parent. So we can't easily tell if no name was
        # specified or if they actually specified 'switch' as the name.
        $SwitchName = $ConfigSwitch.Name
        if ($Name -and ($SwitchName -notin $Name))
        {
            # A names list was passed but this swtich wasn't included
            continue
        } # if

        if ($SwitchName -eq 'switch')
        {
            $ExceptionParameters = @{
                errorId = 'SwitchNameIsEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
            }
            ThrowException @ExceptionParameters
        }

        # Convert the switch type string to a LabSwitchType
        $SwitchType = [LabSwitchType]::$($ConfigSwitch.Type)

        # If the SwitchType string doesn't match any enum value it will be
        # set to null.
        if (-not $SwitchType)
        {
            $ExceptionParameters = @{
                errorId = 'UnknownSwitchTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                    -f $ConfigSwitch.Type,$SwitchName)
            }
            ThrowException @ExceptionParameters
        } # if

        # if a LabId is set for the lab, prepend it to the Switch name as long as it isn't
        # an external switch.
        if ($LabId -and ($SwitchType -ne [LabSwitchType]::External))
        {
            $SwitchName = "$LabId $SwitchName"
        } # if

        # Assemble the list of Mangement OS Adapters if any are specified for this switch
        # Only Intenal and External switches are allowed Management OS adapters.
        if ($ConfigSwitch.Adapters)
        {
            [LabSwitchAdapter[]] $ConfigAdapters = @()
            foreach ($Adapter in $ConfigSwitch.Adapters.Adapter)
            {
                $AdapterName = $Adapter.Name
                # if a LabId is set for the lab, prepend it to the adapter name.
                # But only if it is not an External switch.
                if ($LabId -and ($SwitchType -ne [LabSwitchType]::External))
                {
                    $AdapterName = "$LabId $AdapterName"
                }

                $ConfigAdapter = [LabSwitchAdapter]::New($AdapterName)
                $ConfigAdapter.MACAddress = $Adapter.MacAddress
                $ConfigAdapters += @( $ConfigAdapter )
            } # foreach
            if (($ConfigAdapters.Count -gt 0) `
                -and ($SwitchType -notin [LabSwitchType]::External,[LabSwitchType]::Internal))
            {
                $ExceptionParameters = @{
                    errorId = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.AdapterSpecifiedError `
                        -f $SwitchType,$SwitchName)
                }
                ThrowException @ExceptionParameters
            } # if
        }
        else
        {
            $ConfigAdapters = $null
        } # if

        # Create the new Switch object
        [LabSwitch] $NewSwitch = [LabSwitch]::New($SwitchName,$SwitchType)
        $NewSwitch.VLAN = $ConfigSwitch.VLan
        $NewSwitch.NATSubnetAddress = $ConfigSwitch.NatSubnetAddress
        $NewSwitch.BindingAdapterName = $ConfigSwitch.BindingAdapterName
        $NewSwitch.BindingAdapterMac = $ConfigSwitch.BindingAdapterMac
        $NewSwitch.Adapters = $ConfigAdapters
        $Switches += @( $NewSwitch )
    } # foreach
    return $Switches
} # Get-LabSwitch


<#
.SYNOPSIS
    Creates Hyper-V Virtual Switches from a provided array of LabSwitch objects.
.DESCRIPTION
    Takes an array of LabSwitch objectsthat were pulled from a Lab object by calling
    Get-LabSwitch and ensures that they Hyper-V Virtual Switches on the system
    are configured to match.
.PARAMETER Lab
    Contains Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of Switch names.

    Only Switches matching names in this list will be initialized.
.PARAMETER Switches
    The array of LabSwitch objects pulled from the Lab using Get-LabSwitch.

    If not provided it will attempt to pull the array from the Lab object provided.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $Switches = Get-LabSwitch -Lab $Lab
    Initialize-LabSwitch -Lab $Lab -Switches $Switches
    Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Initialize-LabSwitch -Lab $Lab
    Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Initialize-LabSwitch {
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
        [LabSwitch[]] $Switches
    )


    # if switches was not passed, pull it.
    if (-not $PSBoundParameters.ContainsKey('switches'))
    {
        [LabSwitch[]] $Switches = Get-LabSwitch `
            @PSBoundParameters
    }
    
    # Create Hyper-V Switches
    foreach ($VMSwitch in $Switches)
    {
        if ($Name -and ($VMSwitch.name -notin $Name))
        {
            # A names list was passed but this swtich wasn't included
            continue
        } # if
        
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
            [LabSwitchType] $SwitchType = $VMSwitch.Type
            Write-Verbose -Message $($LocalizedData.CreatingVirtualSwitchMessage `
                -f $SwitchType,$SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    # Determine which Physical Adapter to bind this switch to
                    if ($VMSwitch.BindingAdapterMac)
                    {
                        $BindingAdapter = Get-NetAdapter `
                            -Physical | Where-Object {
                            ($_.MacAddress -replace '-','') -eq $VMSwitch.BindingAdapterMac
                        }
                        $ErrorDetail="with a MAC address '$($VMSwitch.BindingAdapterMac)' "
                    }
                    elseif ($VMSwitch.BindingAdapterName)
                    {
                        $BindingAdapter = Get-NetAdapter `
                            -Physical `
                            -Name $VMSwitch.BindingAdapterName `
                            -ErrorAction SilentlyContinue
                        $ErrorDetail="with a name '$($VMSwitch.BindingAdapterName)' "
                    }
                    else
                    {
                        $BindingAdapter = Get-NetAdapter | `
                            Where-Object {
                                ($_.Status -eq 'Up') `
                                -and (-not $_.Virtual) `
                            } | Select-Object -First 1
                        $ErrorDetail=''
                    } # if
                    # Check that a Binding Adapter was found
                    if (-not $BindingAdapter)
                    {
                        $ExceptionParameters = @{
                            errorId = 'BindingAdapterNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.BindingAdapterNotFoundError `
                                -f $SwitchName,$ErrorDetail)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                    
					# Check this adapter is not already bound to a switch
                    $VMSwitchNames = (Get-VMSwitch | Where-Object{$_.SwitchType -eq 'External'}).Name
					$MacAddress = @()
					ForEach ($VmSwitchName in $VmSwitchNames)
					{
						$MacAddress += `
							(Get-VMNetworkAdapter `
                            -ManagementOS `
                            -Name $VmSwitchName -ErrorAction SilentlyContinue).MacAddress
						
					}

                    $UsedAdapters = @((Get-NetAdapter -Physical | ? {
                        ($_.MacAddress -replace '-','') -in $MacAddress
                        }).Name)

                    if ($BindingAdapter.Name -in $UsedAdapters)
                    {
                        $ExceptionParameters = @{
                            errorId = 'BindingAdapterUsedError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.BindingAdapterUsedError `
                                -f $SwitchName,$BindingAdapter.Name)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                    # Create the swtich
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -NetAdapterName ($BindingAdapter.Name)
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
                                    -Name $Adapter.Name `
                                    -StaticMacAddress $Adapter.MacAddress `
                                    
                                    -Passthru | `
                                    Set-VMNetworkAdapterVlan `
                                        -Access `
                                        -VlanId $($VMSwitch.Vlan)
                            }
                            else
                            { 
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $Adapter.Name `
                                    -StaticMacAddress $Adapter.MacAddress
                            } # if
                        } # foreach
                    } # if
                    break
                } # 'External'
                'Private'
                {
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -SwitchType Private
                    Break
                } # 'Private'
                'Internal'
                {
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -SwitchType Internal
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
                                    Set-VMNetworkAdapterVlan `
                                        -Access `
                                        -VlanId $($VMSwitch.Vlan)
                            }
                            Else
                            { 
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress)
                            } # if
                        } # foreach
                    } # if
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
        } # if
    } # foreach
} # Initialize-LabSwitch


<#
.SYNOPSIS
    Removes all Hyper-V Virtual Switches provided.
.DESCRIPTION
    This cmdlet is used to remove any Hyper-V Virtual Switches that were created by
    the Initialize-LabSwitch cmdlet.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of Switch names.

    Only Switches matching names in this list will be removed.
.PARAMETER Switches
    The array of LabSwitch objects pulled from the Lab using Get-LabSwitch.

    If not provided it will attempt to pull the array from the Lab object.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $Switches = Get-LabSwitch -Lab $Lab
    Remove-LabSwitch -Lab $Lab -Switches $Switches
    Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Remove-LabSwitch -Lab $Lab
    Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Remove-LabSwitch {
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
        [LabSwitch[]] $Switches
    )

    # if switches were not passed so pull them
    if (-not $PSBoundParameters.ContainsKey('switches'))
    {
        [LabSwitch[]] $Switches = Get-LabSwitch `
            @PSBoundParameters
    }

    # Delete Hyper-V Switches
    foreach ($VMSwitch in $Switches)
    {
        if ($Name -and ($VMSwitch.name -notin $Name))
        {
            # A names list was passed but this swtich wasn't included
            continue
        } # if

        if ((Get-VMSwitch | Where-Object -Property Name -eq $VMSwitch.Name).Count -ne 0)
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
            [LabSwitchType] $SwitchType = $VMSwitch.Type
            Write-Verbose -Message $($LocalizedData.DeleteingVirtualSwitchMessage `
                -f $SwitchType,$SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    if ($VMSwitch.Adapters)
                    {
                        $VMSwitch.Adapters.foreach( {
                            $null = Remove-VMNetworkAdapter `
                                -ManagementOS `
                                -Name $_.Name
                        } )
                    } # if
                    Remove-VMSwitch `
                        -Name $SwitchName
                    Break
                } # 'External'
                'Private'
                {
                    Remove-VMSwitch `
                        -Name $SwitchName
                    Break
                } # 'Private'
                'Internal'
                {
                    Remove-VMSwitch `
                        -Name $SwitchName
                    if ($VMSwitch.Adapters)
                    {
                        $VMSwitch.Adapters.foreach( {
                            $null = Remove-VMNetworkAdapter `
                                -ManagementOS `
                                -Name $_.Name
                        } )
                    } # if
                    Break
                } # 'Internal'
                'NAT'
                {
                    Remove-NetNAT `
                        -Name $SwitchName
                    Remove-VMSwitch `
                        -Name $SwitchName
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
        } # if
    } # foreach
} # Remove-LabSwitch
#endregion


#region LabVMTemplateVHDFunctions
<#
.SYNOPSIS
    Gets an Array of TemplateVHDs for a Lab.
.DESCRIPTION
    Takes a provided Lab and returns the list of Template Disks that will be used to 
    create the Virtual Machines in this lab. This list is usually passed to
    Initialize-LabVMTemplateVHD.

    It will validate the paths to the ISO folder as well as to the ISO files themselves.

    If any ISO files references can't be found an exception will be thrown.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM Template VHD names.

    Only VM Template VHDs matching names in this list will be returned in the array.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
    Loads a Lab and pulls the array of TemplateVHDs from it.
.OUTPUTS
    Returns an array of LabVMTemplateVHD objects.
    It will return Null if the TemplateVHDs node does not exist or contains no TemplateVHD nodes.
#>
function Get-LabVMTemplateVHD {
    [OutputType([LabVMTemplateVHD[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter (
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name
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
    [String] $ISORootPath = $Lab.labbuilderconfig.TemplateVHDs.ISOPath
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
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDISORootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                -f $ISORootPath)
        }
        ThrowException @ExceptionParameters
    } # if

    # Determine the VHDRootPath where the VHD files should be put
    # if no path is specified then look in the same path as the config
    # if a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $VHDRootPath = $Lab.labbuilderconfig.TemplateVHDs.VHDPath
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
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDRootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                -f $VHDRootPath)
        }
        ThrowException @ExceptionParameters
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
            -or ([String]::IsNullOrWhiteSpace($TemplateVHDName)))
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDNameError)
            }
            ThrowException @ExceptionParameters
        } # if
        
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
                Write-Output `
                    -ForegroundColor Yellow `
                    -Object $($LocalizedData.ISONotFoundDownloadURLMessage `
                        -f $TemplateVHD.Name,$ISOPath,$URL)
            } # if
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
        } # if

        # Adjust the VHD Path if required
        if (-not [System.IO.Path]::IsPathRooted($VHDPath))
        {
            $VHDPath = Join-Path `
                -Path $VHDRootPath `
                -ChildPath $VHDPath
        } # if
        
        # Add the template prefix to the VHD name.
        if ([String]::IsNullOrWhitespace($TemplatePrefix))
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
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDOSTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDOSTypeError `
                    -f $TemplateVHD.Name,$TemplateVHD.OSType)
            }
            ThrowException @ExceptionParameters
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
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDVHDFormatError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDFormatError `
                    -f $TemplateVHD.Name,$TemplateVHD.VHDFormat)
            }
            ThrowException @ExceptionParameters
        }

        # Get the Template VHD Type 
        $VHDType = [LabVHDType]::Dynamic
        if ($TemplateVHD.VHDType)
        {
            $VHDType = [LabVHDType]::$($TemplateVHD.VHDType)
        } # if
        if (-not $VHDType)
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDVHDTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDTypeError `
                    -f $TemplateVHD.Name,$TemplateVHD.VHDType)
            }
            ThrowException @ExceptionParameters
        } # if
        
        # Get the disk size if provided
        [Int64] $Size = 25GB
        if ($TemplateVHD.VHDSize)
        {
            $VHDSize = (Invoke-Expression $TemplateVHD.VHDSize)
        } # if

        # Get the Template VM Generation 
        [int] $Generation = 2
        if ($TemplateVHD.Generation)
        {
            $Generation = $TemplateVHD.Generation
        } # if
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


<#
.SYNOPSIS
    Scans through an array of LabVMTemplateVHD objects and creates them from the ISO if missing.
.DESCRIPTION
    This function will take an array of LabVMTemplateVHD objects from a Lab or it will
    extract the arrays itself if it is not provided and ensure that each VHD file is available.

    If the VHD file is not available then it will attempt to create it from the ISO.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM Template VHD names.

    Only VM Template VHDs matching names in this list will be initialized.
.PARAMETER VMTemplateVHDs
    The array of LabVMTemplateVHD objects pulled from the Lab using Get-LabVMTemplateVHD

    If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
    Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs
    Loads a Lab and pulls the array of VM Template VHDs from it and then
    ensures all the VHDs are available.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Initialize-LabVMTemplateVHD -Lab $Lab
    Loads a Lab and then ensures VM Template VHDs all the VHDs are available.
.OUTPUTS
    None.
#>
function Initialize-LabVMTemplateVHD
{
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
            @PSBoundParameters
    } # if

    # if there are no VMTemplateVHDs just return
    if ($null -eq $VMTemplateVHDs)
    {
        return
    } # if

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Is an alternate path to DISM specified?
    if ($Lab.labbuilderconfig.settings.DismPath)
    {
        $DismPath = Join-Path `
            -Path $Lab.labbuilderconfig.settings.DismPath `
            -ChildPath 'dism.exe'
        if (-not (Test-Path -Path $DismPath))
        {
            $ExceptionParameters = @{
                errorId = 'FileNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.FileNotFoundError `
                -f 'alternate DISM.EXE',$DismPath)
            }
            ThrowException @ExceptionParameters
        }
    }

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [String] $TemplateVHDName = $VMTemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        [String] $VHDPath = $VMTemplateVHD.VHDPath
        
        if (Test-Path -Path ($VHDPath))
        {
            # The SourceVHD already exists
            Write-Verbose -Message $($LocalizedData.SkipVMTemplateVHDFileMessage `
                -f $TemplateVHDName,$VHDPath)

            continue
        } # if
        
        # Create the VHD
        Write-Verbose -Message $($LocalizedData.CreatingVMTemplateVHDMessage `
            -f $TemplateVHDName,$VHDPath)
            
        # Check the ISO exists.
        [String] $ISOPath = $VMTemplateVHD.ISOPath
        if (-not (Test-Path -Path $ISOPath))
        {
            $ExceptionParameters = @{
                errorId = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                    -f $TemplateVHDName,$ISOPath)
            }
            ThrowException @ExceptionParameters
        } # if

        # Mount the ISO so we can read the files.
        Write-Verbose -Message $($LocalizedData.MountingVMTemplateVHDISOMessage `
                -f $TemplateVHDName,$ISOPath)

        $null = Mount-DiskImage `
            -ImagePath $ISOPath `
            -StorageType ISO `
            -Access Readonly

        # Refresh the PS Drive list to make sure the new drive can be detected
        Get-PSDrive `
            -PSProvider FileSystem

        $DiskImage = Get-DiskImage -ImagePath $ISOPath
        $Volume = Get-Volume -DiskImage $DiskImage
        if (-not $Volume)
        {
            $ExceptionParameters = @{
                errorId = 'VolumeNotAvailableAfterMountError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VolumeNotAvailableAfterMountError `
                -f $ISOPath)
            }
            ThrowException @ExceptionParameters
        }
        [String] $DriveLetter = $Volume.DriveLetter
        if (-not $DriveLetter)
        {
            $ExceptionParameters = @{
                errorId = 'DriveLetterNotAssignedError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DriveLetterNotAssignedError `
                -f $ISOPath)
            }
            ThrowException @ExceptionParameters
        }
        [String] $ISODrive = "$([string]$DriveLetter):"

        # Determine the path to the WIM
        [String] $SourcePath = "$ISODrive\Sources\Install.WIM"
        if ($VMTemplateVHD.OSType -eq [LabOStype]::Nano)
        {
            $SourcePath = "$ISODrive\Nanoserver\NanoServer.WIM"
        } # if

        # This will have to change depending on the version
        # of Convert-WindowsImage being used.
        [String] $VHDFormat = $VMTemplateVHD.VHDFormat
        [String] $VHDType = $VMTemplateVHD.VHDType
        [String] $VHDDiskLayout = 'UEFI'
        if ($VMTemplateVHD.Generation -eq 1)
        {
            $VHDDiskLayout = 'BIOS'
        } # if

        [String] $Edition = $VMTemplateVHD.Edition
        # if edition is not set then use Get-WindowsImage to get the name
        # of the first image in the WIM.
        if ([String]::IsNullOrWhiteSpace($Edition))
        {
            $Edition = (Get-WindowsImage `
                -ImagePath $SourcePath `
                -Index 1).ImageName
        } # if

        $ConvertParams = @{
            sourcepath = $SourcePath
            vhdpath = $VHDpath
            vhdformat = $VHDFormat
            # Convert-WindowsImage doesn't support creating different VHDTypes
            # vhdtype = $VHDType
            edition = $Edition
            disklayout = $VHDDiskLayout
            erroraction = 'Stop'
        }

        # Set the size
        if ($null -ne $VMTemplateVHD.VHDSize)
        {
            $ConvertParams += @{
                sizebytes = $VMTemplateVHD.VHDSize
            }
        } # if

        # Are any features specified?
        if (-not [String]::IsNullOrWhitespace($VMTemplateVHD.Features))
        {
            $Features = @($VMTemplateVHD.Features -split ',')
            $ConvertParams += @{
                feature = $Features
            }
        } # if

        # Is an alternate path to DISM specified?
        if ($DismPath)
        {
            $ConvertParams += @{
                DismPath = $DismPath
            }
        }

        # Perform Nano Server package prep
        if ($VMTemplateVHD.OSType -eq [LabOStype]::Nano)
        {
            # Make a copy of the all the Nano packages in the VHD root folder
            # So that if any VMs need to add more packages they are accessible
            # once the ISO has been dismounted.
            [String] $VHDFolder = Split-Path `
                -Path $VHDPath `
                -Parent

            [String] $NanoPackagesFolder = Join-Path `
                -Path $VHDFolder `
                -ChildPath 'NanoServerPackages'

            if (-not (Test-Path -Path $NanoPackagesFolder -Type Container))
            {
                Write-Verbose -Message $($LocalizedData.CachingNanoServerPackagesMessage `
                        -f "$ISODrive\Nanoserver\Packages",$NanoPackagesFolder)
                Copy-Item `
                    -Path "$ISODrive\Nanoserver\Packages" `
                    -Destination $VHDFolder `
                    -Recurse `
                    -Force
                Rename-Item `
                    -Path "$VHDFolder\Packages" `
                    -NewName 'NanoServerPackages'
            } # if
        } # if

        # Do we need to add any packages?
        if (-not [String]::IsNullOrWhitespace($VMTemplateVHD.Packages))
        {
            $Packages = @()

            # Get the list of Lab Resource MSUs
            $ResourceMSUs = Get-LabResourceMSU `
                -Lab $Lab

            try
            {
                foreach ($Package in @($VMTemplateVHD.Packages -split ','))
                {
                    if (([System.IO.Path]::GetExtension($Package) -eq '.cab') `
                        -and ($VMTemplateVHD.OSType -eq [LabOSType]::Nano))
                    {
                        # This is a Nano Server .CAB pacakge
                        # Generate the path to the Nano Package
                        $PackagePath = Join-Path `
                            -Path $NanoPackagesFolder `
                            -ChildPath $Package
                        # Does it exist?
                        if (-not (Test-Path -Path $PackagePath))
                        {
                            $ExceptionParameters = @{
                                errorId = 'NanoPackageNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.NanoPackageNotFoundError `
                                -f $PackagePath)
                            }
                            ThrowException @ExceptionParameters
                        }
                        $Packages += @( $PackagePath )

                        # Generate the path to the Nano Language Package
                        $PackageLangPath = Join-Path `
                            -Path $NanoPackagesFolder `
                            -ChildPath "en-us\$Package"
                        # Does it exist?
                        if (-not (Test-Path -Path $PackageLangPath))
                        {
                            $ExceptionParameters = @{
                                errorId = 'NanoPackageNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.NanoPackageNotFoundError `
                                -f $PackageLangPath)
                            }
                            ThrowException @ExceptionParameters
                        }
                        $Packages += @( $PackageLangPath )
                    }
                    else
                    {
                        # Tihs is a ResourceMSU type package
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
                            $ExceptionParameters = @{
                                errorId = 'PackageMSUNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.PackageMSUNotFoundError `
                                -f $Package,$PackagePath)
                            }
                            ThrowException @ExceptionParameters
                        } # if
                        $Packages += @( $PackagePath )
                    }
                } # foreach
                $ConvertParams += @{
                    Package = $Packages
                }
            }
            catch
            {
                # Dismount Disk Image before throwing exception
                $null = Dismount-DiskImage `
                    -ImagePath $ISOPath

                Throw $_
            } # try
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
        } # if

        try
        {
            # Call the Convert-WindowsImage script
            Convert-WindowsImage @ConvertParams
        } # try
        catch
        {
            $ExceptionParameters = @{
                errorId = 'ConvertWindowsImageError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.ConvertWindowsImageError `
                    -f $ISOPath,$SourcePath,$Edition,$VHDFormat,$_.Exception.Message)
            }
            ThrowException @ExceptionParameters
        } # catch
        finally
        {
            # Dismount the ISO.
            Write-Verbose -Message $($LocalizedData.DismountingVMTemplateVHDISOMessage `
                    -f $TemplateVHDName,$ISOPath)

            $null = Dismount-DiskImage `
                -ImagePath $ISOPath
        } # finally
    } # endfor
} # Initialize-LabVMTemplateVHD


<#
.SYNOPSIS
    Scans through an array of LabVMTemplateVHD objects and removes them if they exist.
.DESCRIPTION
    This function will take an array of LabVMTemplateVHD objects from a Lab or it will
    extract the list itself if it is not provided and remove the VHD file if it exists.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM Template VHD names.
    
    Only VM Template VHDs matching names in this list will be removed.
.PARAMETER VMTemplateVHDs
    The array of LabVMTemplateVHD objects from the Lab using Get-LabVMTemplateVHD.

    If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
    Remove-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs
    Loads a Lab and pulls the array of VM Template VHDs from it and then
    ensures all the VM template VHDs are deleted.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Remove-LabVMTemplateVHD -Lab $Lab
    Loads a Lab and then ensures the VM template VHDs are deleted.
.OUTPUTS
    None.
#>
function Remove-LabVMTemplateVHD
{
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
           @PSBoundParameters
    } # if

    # if there are no VMTemplateVHDs just return
    if ($null -eq $VMTemplateVHDs)
    {
        return
    } # if

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [String] $TemplateVHDName = $VMTemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        [String] $VHDPath = $VMTemplateVHD.VHDPath
        
        if (Test-Path -Path ($VHDPath))
        {
            Remove-Item `
                -Path $VHDPath `
                -Force
            Write-Verbose -Message $($LocalizedData.DeletingVMTemplateVHDFileMessage `
                -f $TemplateVHDName,$VHDPath)
        } # if
    } # endfor
} # Remove-LabVMTemplateVHD


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

            Write-Verbose -Message $($LocalizedData.CopyingTemplateSourceVHDMessage `
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
                    Write-Verbose -Message $($LocalizedData.MountingTemplateBootDiskMessage `
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
                            Write-Verbose -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
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
                            Write-Verbose -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
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
                        Write-Verbose -Message $($LocalizedData.ApplyingTemplateBootDiskFileMessage `
                            -f $VMTemplate.Name,$Package,$PackagePath)

                        $null = Add-WindowsPackage `
                            -PackagePath $PackagePath `
                            -Path $MountPoint
                    } # foreach

                    # Dismount the VHD
                    Write-Verbose -Message $($LocalizedData.DismountingTemplateBootDiskMessage `
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
        }
        Else
        {
            Write-Verbose -Message $($LocalizedData.SkipParentVHDFileMessage `
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
                Write-Verbose -Message $($LocalizedData.CachingNanoServerPackagesMessage `
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
            Write-Verbose -Message $($LocalizedData.DeletingParentVHDMessage `
                -f $VMTemplate.ParentVhd)
            Remove-Item `
                -Path $VMTemplate.ParentVhd `
                -Confirm:$false `
                -Force
        } # if
    } # foreach
} # Remove-LabVMTemplate
#region


#region LabVMFunctions
<#
.SYNOPSIS
    Gets an Array of LabVM objects from a Lab.
.DESCRIPTION
    Takes the provided Lab and returns the list of VM objects that will be created in this lab.
    This list is usually passed to Initialize-LabVM.
.PARAMETER Lab
    Contains the Lab Builder Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM names.

    Only VMs matching names in this list will be returned in the array.
.PARAMETER VMTemplates
    Contains the array of LabVMTemplate objects returned by Get-LabVMTemplate from this Lab.

    If not provided it will attempt to pull the list from the Lab.
.PARAMETER Switches
    Contains the array of LabVMSwitch objects returned by Get-LabSwitch from this Lab.

    If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplates = Get-LabVMTemplate -Lab $Lab
    $Switches = Get-LabSwitch -Lab $Lab
    $VMs = Get-LabVM `
        -Lab $Lab `
        -VMTemplates $VMTemplates `
        -Switches $Switches
    Loads a Lab and pulls the array of VMs from it.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    Loads a Lab and pulls the array of VMs from it.
.OUTPUTS
    Returns an array of LabVM objects.
#>
function Get-LabVM {
    [OutputType([LabVM[]])]
    [CmdLetBinding()]
    param (
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
        [LabSwitch[]] $Switches
    )

    # if VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        [LabVMTemplate[]] $VMTemplates = Get-LabVMTemplate `
            -Lab $Lab
    }

    # if Switches array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('Switches'))
    {
        [LabSwitch[]] $Switches = Get-LabSwitch `
            -Lab $Lab
    }

    [LabVM[]] $LabVMs = @()
    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
    [String] $LabId = $Lab.labbuilderconfig.settings.labid 
    $VMs = $Lab.labbuilderconfig.vms.vm

    foreach ($VM in $VMs)
    {
        $VMName = $VM.Name
        if ($Name -and ($VMName -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if

        if ($VMName -eq 'VM')
        {
            $ExceptionParameters = @{
                errorId = 'VMNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMNameError)
            }
            ThrowException @ExceptionParameters
        } # if

        # if a LabId is set for the lab, prepend it to the VM name.
        if ($LabId)
        {
            $VMName = "$LabId $VMName"
        }

        if (-not $VM.Template) 
        {
            $ExceptionParameters = @{
                errorId = 'VMTemplateNameEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                    -f $VMName)
            }
            ThrowException @ExceptionParameters
        } # if

        # Find the template that this VM uses and get the VHD Path
        [String] $ParentVHDPath = ''
        [Boolean] $Found = $false
        foreach ($VMTemplate in $VMTemplates) {
            if ($VMTemplate.Name -eq $VM.Template) {
                $ParentVHDPath = $VMTemplate.ParentVHD
                $Found = $true
                Break
            } # if
        } # foreach

        if (-not $Found) 
        {
            $ExceptionParameters = @{
                errorId = 'VMTemplateNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                    -f $VMName,$VM.template)
            }
            ThrowException @ExceptionParameters
        } # if

        # Assemble the Network adapters that this VM will use
        [LabVMAdapter[]] $VMAdapters = @()
        [Int] $AdapterCount = 0
        foreach ($VMAdapter in $VM.Adapters.Adapter) 
        {
            $AdapterCount++
            $AdapterName = $VMAdapter.Name 
            $AdapterSwitchName = $VMAdapter.SwitchName
            if ($AdapterName -eq 'adapter') 
            {
                $ExceptionParameters = @{
                    errorId = 'VMAdapterNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterNameError `
                        -f $VMName)
                }
                ThrowException @ExceptionParameters
            }
            
            if (-not $AdapterSwitchName) 
            {
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                        -f $VMName,$AdapterName)
                }
                ThrowException @ExceptionParameters
            }

            # if a LabId is set for the lab, prepend it to the adapter name
            # name and switch name.
            if ($LabId)
            {
                $AdapterName = "$LabId $AdapterName"
                $AdapterSwitchName = "$LabId $AdapterSwitchName"
            }

            # Check the switch is in the switch list
            [Boolean] $Found = $False
            foreach ($Switch in $Switches) 
            {
                # Match the switch name to the Adapter Switch Name or
                # the LabId and Adapter Switch Name
                if ($Switch.Name -eq $AdapterSwitchName) `
                {
                    # The switch is found in the switch list - record the VLAN (if there is one)
                    $Found = $True
                    $SwitchVLan = $Switch.Vlan
                    Break
                } # if
                elseif ($Switch.Name -eq $VMAdapter.SwitchName)
                {
                    # The switch is found in the switch list - record the VLAN (if there is one)
                    $Found = $True
                    $SwitchVLan = $Switch.Vlan
                    $AdapterSwitchName = $VMAdapter.SwitchName
                    Break
                }
            } # foreach
            if (-not $Found) 
            {
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNotFoundError `
                        -f $VMName,$AdapterName,$AdapterSwitchName)
                }
                ThrowException @ExceptionParameters
            } # if

            # Figure out the VLan - If defined in the VM use it, otherwise use the one defined in the Switch, otherwise keep blank.
            [String] $VLan = $VMAdapter.VLan
            if (-not $VLan) 
            {
                $VLan = $SwitchVLan
            } # if

            [Boolean] $MACAddressSpoofing = ($VMAdapter.macaddressspoofing -eq 'On') 

            # Have we got any IPv4 settings?
            Remove-Variable -Name IPv4 -ErrorAction SilentlyContinue
            if ($VMAdapter.IPv4) 
            {
                $IPv4 = [LabVMAdapterIPv4]::New($VMAdapter.IPv4.Address,$VMAdapter.IPv4.SubnetMask)
                $IPv4.defaultgateway = $VMAdapter.IPv4.DefaultGateway
                $IPv4.dnsserver = $VMAdapter.IPv4.DNSServer
            }

            # Have we got any IPv6 settings?
            Remove-Variable -Name IPv6 -ErrorAction SilentlyContinue
            if ($VMAdapter.IPv6)
            {
                $IPv6 = [LabVMAdapterIPv6]::New($VMAdapter.IPv6.Address,$VMAdapter.IPv6.SubnetMask)
                $IPv6.defaultgateway = $VMAdapter.IPv6.DefaultGateway
                $IPv6.dnsserver = $VMAdapter.IPv6.DNSServer
            }

            $NewVMAdapter = [LabVMAdapter]::New($AdapterName)
            $NewVMAdapter.SwitchName = $AdapterSwitchName
            $NewVMAdapter.MACAddress = $VMAdapter.macaddress
            $NewVMAdapter.MACAddressSpoofing = $MACAddressSpoofing
            $NewVMAdapter.VLan = $VLan
            $NewVMAdapter.IPv4 = $IPv4
            $NewVMAdapter.IPv6 = $IPv6
            $VMAdapters += @( $NewVMAdapter )
        } # foreach

        # Assemble the Data Disks this VM will use
        [LabDataVHD[]] $DataVhds = @()
        [Int] $DataVhdCount = 0
        foreach ($VMDataVhd in $VM.DataVhds.DataVhd)
        {
            $DataVhdCount++

            # Load all the VHD properties and check they are valid
            [String] $Vhd = $VMDataVhd.Vhd
            if (-not $VMDataVhd.Vhd)
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                        -f $VMName)
                }
                ThrowException @ExceptionParameters
            } # if

            # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
            # if it doesn't contain a root (e.g. c:\)
            if (-not [System.IO.Path]::IsPathRooted($Vhd))
            {
                $Vhd = Join-Path `
                    -Path $LabPath `
                    -ChildPath "$($VMName)\Virtual Hard Disks\$Vhd"
            } # if

            # Does the VHD already exist?
            $Exists = Test-Path `
                -Path $Vhd

            # Create the new Data VHD object
            $NewDataVHD = [LabDataVHD]::New($Vhd)

            # Get the Parent VHD and check it exists if passed
            if ($VMDataVhd.ParentVHD)
            {
                $NewDataVHD.ParentVhd = $VMDataVhd.ParentVHD
                # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                # if it doesn't contain a root (e.g. c:\)
                if (-not [System.IO.Path]::IsPathRooted($NewDataVHD.ParentVhd))
                {
                    $NewDataVHD.ParentVhd = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $NewDataVHD.ParentVhd
                }
                if (-not (Test-Path -Path $NewDataVHD.ParentVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskParentVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                            -f $VMName,$NewDataVHD.ParentVhd)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if

            # Get the Source VHD and check it exists if passed
            if ($VMDataVhd.SourceVHD)
            {
                $NewDataVHD.SourceVhd = $VMDataVhd.SourceVHD
                # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                # if it doesn't contain a root (e.g. c:\)
                if (-not [System.IO.Path]::IsPathRooted($NewDataVHD.SourceVhd))
                {
                    $NewDataVHD.SourceVhd = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $NewDataVHD.SourceVhd
                } # if
                if (-not (Test-Path -Path $NewDataVHD.SourceVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                            -f $VMName,$NewDataVHD.SourceVhd)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if

            # Get the disk size if provided
            if ($VMDataVhd.Size)
            {
                $NewDataVHD.Size = (Invoke-Expression $VMDataVhd.Size)
            } # if

            # Get the Shared flag
            $NewDataVHD.Shared = ($VMDataVhd.Shared -eq 'Y')

            # Get the Support Persistent Reservations
            $NewDataVHD.SupportPR = ($VMDataVhd.SupportPR -eq 'Y')
            if ($NewDataVHD.SupportPR -and -not $NewDataVHD.Shared)
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSupportPRError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSupportPRError `
                        -f $VMName,$VHD)
                }
                ThrowException @ExceptionParameters
            } # if

            # Validate the data disk type specified
            if ($VMDataVhd.Type)
            {
                switch ($VMDataVhd.Type)
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
                        if (-not $NewDataVHD.ParentVhd)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDMissingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                                    -f $VMName)
                            }
                            ThrowException @ExceptionParameters
                        } # if
                        if ($NewDataVHD.Shared)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskSharedDifferencingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                                    -f $VMName,$VHD)
                            }
                            ThrowException @ExceptionParameters
                        } # if
                    }
                    Default
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskUnknownTypeError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                                -f $VMName,$VHD,$VMDataVhd.Type)
                        }
                        ThrowException @ExceptionParameters
                    }
                } # switch
                $NewDataVHD.VHDType = [LabVHDType]::$($VMDataVhd.Type)
            } # if

            # Get Partition Style for the new disk.
            if ($VMDataVhd.PartitionStyle)
            {
                $PartitionStyle = [LabPartitionStyle]::$($VMDataVhd.PartitionStyle)
                if (-not $PartitionStyle)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskPartitionStyleError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskPartitionStyleError `
                            -f $VMName,$VHD,$VMDataVhd.PartitionStyle)
                    }
                    ThrowException @ExceptionParameters
                } # if
                $NewDataVHD.PartitionStyle = $PartitionStyle
            } # if

            # Get file system for the new disk.
            if ($VMDataVhd.FileSystem)
            {
                $FileSystem = [LabFileSystem]::$($VMDataVhd.FileSystem)
                if (-not $FileSystem)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskFileSystemError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskFileSystemError `
                            -f $VMName,$VHD,$VMDataVhd.FileSystem)
                    }
                    ThrowException @ExceptionParameters
                } # if
                $NewDataVHD.FileSystem = $FileSystem
            } # if

            # Has a file system label been provided?
            if ($VMDataVhd.FileSystemLabel)
            {
                $NewDataVHD.FileSystemLabel = $VMDataVhd.FileSystemLabel
            } # if

            # if the Partition Style, File System or File System Label has been
            # provided then ensure Partition Style and File System are set.
            if ($NewDataVHD.PartitionStyle `
                -or $NewDataVHD.FileSystem `
                -or $NewDataVHD.FileSystemLabel)
            {
                if (-not $NewDataVHD.PartitionStyle)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskPartitionStyleMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                            -f $VMName,$VHD)
                    }
                    ThrowException @ExceptionParameters
                } # if
                if (-not $NewDataVHD.FileSystem)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskFileSystemMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                            -f $VMName,$VHD)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if

            # Get the Folder to copy and check it exists if passed
            if ($VMDataVhd.CopyFolders)
            {
                foreach ($CopyFolder in ($VMDataVhd.CopyFolders -Split ','))
                {
                    # Adjust the path to be relative to the configuration folder 
                    # if it doesn't contain a root (e.g. c:\)
                    if (-not [System.IO.Path]::IsPathRooted($CopyFolder))
                    {
                        $CopyFolder = Join-Path `
                            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $CopyFolder
                    } # if
                    if (-not (Test-Path -Path $CopyFolder -Type Container))
                    {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskCopyFolderMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskCopyFolderMissingError `
                            -f $VMName,$VHD,$CopyFolder)
                        }
                    ThrowException @ExceptionParameters 
                    }
                } # foreach
                $NewDataVHD.CopyFolders = $VMDataVhd.CopyFolders
            } # if

            # Should the Source VHD be moved rather than copied
            if ($VMDataVhd.MoveSourceVHD)
            {
                $NewDataVHD.MoveSourceVHD = ($VMDataVhd.MoveSourceVHD -eq 'Y')
                if (-not $NewDataVHD.SourceVHD)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDIfMoveError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                            -f $VMName,$VHD)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if

            # if the data disk file doesn't exist then some basic parameters MUST be provided
            if (-not $Exists `
                -and ( ( ( -not $NewDataVHD.VhdType ) -or ( $NewDataVHD.Size -eq 0) ) `
                -and -not $NewDataVHD.SourceVhd ) )
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $VMName,$VHD)
                }
                ThrowException @ExceptionParameters
            } # if

            $DataVHDs += @( $NewDataVHD )
        } # foreach

        # Assemble the DVD Drives this VM will use
        [LabDVDDrive[]] $DVDDrives = @()
        [Int] $DVDDriveCount = 0
        foreach ($VMDVDDrive in $VM.DVDDrives.DVDDrive)
        {
            $DVDDriveCount++

            # Create the new DVD Drive object
            $NewDVDDrive = [LabDVDDRive]::New()

            # Load all the DVD Drive properties and check they are valid
            if ($VMDVDDrive.ISO)
            {
                # Look the ISO up in the ISO Resources
                # Pull the list of Resource ISOs available if not already pulled from Lab.
                if (-not $ResourceISOs)
                {
                    $ResourceISOs = Get-LabResourceISO `
                        -Lab $Lab
                } # if

                # Lookup the Resource ISO record
                $ResourceISO = $ResourceISOs | Where-Object -Property Name -eq $VMDVDDrive.ISO
                if (-not $ResourceISO)
                {
                    # The ISO Resource was not found
                    $ExceptionParameters = @{
                        errorId = 'VMDVDDriveISOResourceNotFOundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDVDDriveISOResourceNotFOundError `
                            -f $VMName,$VMDVDDrive.ISO)
                    }
                    ThrowException @ExceptionParameters
                } # if
                # The ISO resource was found so populate the ISO details
                $NewDVDDrive.ISO = $VMDVDDrive.ISO
                $NewDVDDrive.Path = $ResourceISO.Path
            } # if

            $DVDDrives += @( $NewDVDDrive )
        } # foreach

        # Does the VM have an Unattend file specified?
        [String] $UnattendFile = ''
        if ($VM.UnattendFile)
        {
            if ([System.IO.Path]::IsPathRooted($VM.UnattendFile))
            {
                $UnattendFile = $VM.UnattendFile
            }
            else
            {
                $UnattendFile = Join-Path `
                    -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                    -ChildPath $VM.UnattendFile
            } # if
            if (-not (Test-Path $UnattendFile)) 
            {
                $ExceptionParameters = @{
                    errorId = 'UnattendFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnattendFileMissingError `
                        -f $VMName,$UnattendFile)
                }
                ThrowException @ExceptionParameters
            } # if
        } # if
        
        # Does the VM specify a Setup Complete Script?
        [String] $SetupComplete = ''
        if ($VM.SetupComplete) 
        {
            if ([System.IO.Path]::IsPathRooted($VM.SetupComplete))
            {
                $SetupComplete = $VM.SetupComplete
            }
            else
            {
                $SetupComplete = Join-Path `
                    -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                    -ChildPath $VM.SetupComplete
            } # if
            if ([System.IO.Path]::GetExtension($SetupComplete).ToLower() -notin '.ps1','.cmd' )
            {
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                        -f $VMName,$SetupComplete)
                }
                ThrowException @ExceptionParameters
            } # if
            if (-not (Test-Path $SetupComplete))
            {
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                        -f $VMName,$SetupComplete)
                }
                ThrowException @ExceptionParameters
            } # if
        } # if

        # Create the Lab DSC object
        $LabDSC = [LabDSC]::New($VM.DSC.ConfigName)

        # Load the DSC Config File setting and check it
        [String] $LabDSC.ConfigFile = ''
        if ($VM.DSC.ConfigFile) 
        {
            if (-not [System.IO.Path]::IsPathRooted($VM.DSC.ConfigFile))
            {
                $LabDSC.ConfigFile = Join-Path `
                    -Path $Lab.labbuilderconfig.settings.dsclibrarypathfull `
                    -ChildPath $VM.DSC.ConfigFile
            }
            else
            {
                $LabDSC.ConfigFile = $VM.DSC.ConfigFile
            } # if

            if ([System.IO.Path]::GetExtension($LabDSC.ConfigFile).ToLower() -ne '.ps1' )
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                        -f $VMName,$LabDSC.ConfigFile)
                }
                ThrowException @ExceptionParameters
            } # if

            if (-not (Test-Path $LabDSC.ConfigFile))
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                        -f $VMName,$LabDSC.ConfigFile)
                }
                ThrowException @ExceptionParameters
            } # if
            if (-not $VM.DSC.ConfigName)
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                        -f $VMName)
                }
                ThrowException @ExceptionParameters
            } # if
        } # if

        # Load the DSC Parameters
        [String] $LabDSC.Parameters = ''
        if ($VM.DSC.Parameters)
        {
            # Correct any LFs into CRLFs to ensure the new line format is the same when
            # pulled from the XML.
            $LabDSC.Parameters = ($VM.DSC.Parameters -replace "`r`n","`n") -replace "`n","`r`n"
        } # if

        # Load the DSC Parameters
        [Boolean] $LabDSC.Logging = ($VM.DSC.Logging -eq 'Y')

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
        [Boolean] $DynamicMemoryEnabled = $True
        if ($VM.DynamicMemoryEnabled)
        {
            $DynamicMemoryEnabled = ($VM.DynamicMemoryEnabled -eq 'Y')
        }
        elseif ($VMTemplate.DynamicMemoryEnabled)
        {
            $DynamicMemoryEnabled = $VMTemplate.DynamicMemoryEnabled
        } # if
        
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

        [Boolean] $UseDifferencingDisk = $True
        if ($VM.UseDifferencingDisk -eq 'N')
        {
            $UseDifferencingDisk = $False
        } # if

        # Get the Integration Services flags
        if ($null -ne $VM.IntegrationServices)
        {
            $IntegrationServices = $VM.IntegrationServices
        } 
        elseif ($null -ne $VMTemplate.IntegrationServices)
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
        } # if

        # Get the Timezone (from the template or VM)
        [String] $Timezone = 'Pacific Standard Time'
        if ($VM.timezone) 
        {
            $Timezone = $VM.timezone
        }
        elseif ($VMTemplate.timezone) 
        {
            $Timezone = $VMTemplate.timezone
        } # if

        # Get the OS Type
        $OSType = [LabOStype]::Server
        if ($VM.OSType)
        {
            $OSType = $VM.OSType
        }
        elseif ($VMTemplate.OSType)
        {
            $OSType = $VMTemplate.OSType
        } # if

        # Get the Bootorder
        [Byte] $Bootorder = [Byte]::MaxValue
        if ($VM.bootorder)
        {
            $Bootorder = $VM.bootorder
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

        # Get the Certificate Source
        $CertificateSource = [LabCertificateSource]::Guest
        if ($OSType -eq [LabOSType]::Nano)
        {
            # Nano Server can't generate certificates so must always be set to Host
            $CertificateSource = [LabCertificateSource]::Host
        }
        elseif ($VM.CertificateSource)
        {
            $CertificateSource = $VM.CertificateSource
        } # if

        $LabVM = [LabVM]::New($VMName,$VM.ComputerName)
        $LabVM.Template = $VM.Template
        $LabVM.ParentVHD = $ParentVHDPath
        $LabVM.UseDifferencingDisk = $UseDifferencingDisk
        $LabVM.MemoryStartupBytes = $MemoryStartupBytes
        $LabVM.DynamicMemoryEnabled = $DynamicMemoryEnabled
        $LabVM.ProcessorCount = $ProcessorCount
        $LabVM.ExposeVirtualizationExtensions = $ExposeVirtualizationExtensions
        $LabVM.IntegrationServices = $IntegrationServices
        $LabVM.AdministratorPassword = $AdministratorPassword
        $LabVM.ProductKey = $ProductKey
        $LabVM.TimeZone =$Timezone
        $LabVM.UnattendFile = $UnattendFile
        $LabVM.SetupComplete = $SetupComplete
        $LabVM.OSType = $OSType
        $LabVM.Adapters = $VMAdapters
        $LabVM.DataVHDs = $DataVHDs
        $LabVM.DVDDrives = $DVDDrives
        $LabVM.Packages = $Packages
        $LabVM.Bootorder = $Bootorder
        $LabVM.DSC = $LabDSC
        $LabVM.VMRootPath = (Join-Path -Path $LabPath -ChildPath $VMName)
        $LabVM.LabBuilderFilesPath = (Join-Path -Path $LabPath -ChildPath "$VMName\LabBuilder Files")
        $LabVM.CertificateSource = $CertificateSource
        $LabVMs += @( $LabVM )
    } # foreach

    Return $LabVMs
} # Get-LabVM


<#
.SYNOPSIS
    Initializes the Virtual Machines used by a Lab from a provided array.
.DESCRIPTION
    Takes an array of LabVM objects that were configured in the Lab.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM names.

    Only VMs matching names in this list will be initialized.
.PARAMETER VMs
    An array of LabVM objects pulled from a Lab object.

    If not provided it will attempt to pull the list from the Lab object.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVs -Lab $Lab
    Initialize-LabVM `
        -Lab $Lab `
        -VMs $VMs
    Initializes the Virtual Machines in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Initialize-LabVMs -Lab $Lab
    Initializes the Virtual Machines in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Initialize-LabVM {
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
        [LabVM[]] $VMs
    )
    
    # if VMs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMs'))
    {
        [LabVM[]] $VMs = Get-LabVM `
            @PSBoundParameters
    } # if
    
    # if there are not VMs just return
    if (-not $VMs)
    {
        return
    } # if
    
    $CurrentVMs = Get-VM

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Figure out the name of the LabBuilder control switch
    $ManagementSwitchName = GetManagementSwitchName `
        -Lab $Lab
    if ($Lab.labbuilderconfig.switches.ManagementVlan)
    {
        [Int32] $ManagementVlan = $Lab.labbuilderconfig.switches.ManagementVlan
    }
    else
    {
        [Int32] $ManagementVlan = $Script:DefaultManagementVLan
    } # if

    foreach ($VM in $VMs)
    {
        if ($Name -and ($VM.Name -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if
        
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
            InitializeVMPaths `
                -VMPath $VMRootPath

            # Create the boot disk
            $VMBootDiskPath = "$VHDPath\$($VM.Name) Boot Disk.vhdx"
            if (-not (Test-Path -Path $VMBootDiskPath))
            {
                if ($VM.UseDifferencingDisk)
                {
                    Write-Verbose -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Differencing Boot')

                    $Null = New-VHD `
                        -Differencing `
                        -Path $VMBootDiskPath `
                        -ParentPath $VM.ParentVHD
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
                    -Lab $Lab `
                    -VM $VM

                # Because this is a new boot disk apply any required initialization
                InitializeBootVHD `
                    -Lab $Lab `
                    -VM $VM `
                    -VMBootDiskPath $VMBootDiskPath
            }
            else
            {
                Write-Verbose -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                    -f $VM.Name,$VMBootDiskPath,'Boot')
            } # if

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
            } # if
        } # if
        
        # Enable/Disable Dynamic Memory
        if ($VM.DynamicMemoryEnabled -ne (Get-VMMemory -VMName $VM.Name).DynamicMemoryEnabled)
        {
            Set-VMMemory `
                -VMName $VM.Name `
                -DynamicMemoryEnabled:$($VM.DynamicMemoryEnabled)
        } # if

        # if the ExposeVirtualizationExtensions is configured then try and set this on 
        # Virtual Processor. Only supported in certain builds on Windows 10/Server 2016 TP4.
        if ($VM.ExposeVirtualizationExtensions -ne (Get-VMProcessor -VMName $VM.Name).ExposeVirtualizationExtensions)
        {
            Set-VMProcessor `
                -VMName $VM.Name `
                -ExposeVirtualizationExtensions:$VM.ExposeVirtualizationExtensions
        } # if

        # Enable/Disable the Integration Services
        UpdateVMIntegrationServices `
            -VM $VM

        # Update the data disks for the VM
        UpdateVMDataDisks `
            -Lab $Lab `
            -VM $VM

        # Update the DVD Drives for the VM
        UpdateVMDVDDrives `
            -Lab $Lab `
            -VM $VM

        # Create/Update the Management Network Adapter
        if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $ManagementSwitchName).Count -eq 0)
        {
            Write-Verbose -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                -f $VM.Name,$ManagementSwitchName,'Management')

            Add-VMNetworkAdapter `
                -VMName $VM.Name `
                -SwitchName $ManagementSwitchName `
                -Name $ManagementSwitchName
        }
        $VMNetworkAdapter = Get-VMNetworkAdapter `
            -VMName $VM.Name `
            -Name $ManagementSwitchName
        $null = $VMNetworkAdapter |
            Set-VMNetworkAdapterVlan `
                -Access `
                -VlanId $ManagementVlan

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
            } # if

            $VMNetworkAdapter = Get-VMNetworkAdapter `
                -VMName $VM.Name `
                -Name $VMAdapter.Name
            if ($VMAdapter.VLan)
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapterVlan `
                        -Access `
                        -VlanId $VMAdapter.VLan

                Write-Verbose -Message $($LocalizedData.SettingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'',$VMAdapter.VLan)
            }
            else
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapterVlan `
                        -Untagged

                Write-Verbose -Message $($LocalizedData.ClearingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'')
            } # if

            if ([String]::IsNullOrWhitespace($VMAdapter.MACAddress))
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -DynamicMacAddress
            }
            else
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -StaticMacAddress $VMAdapter.MACAddress
            } # if

            # Enable Device Naming
            if ((Get-Command -Name Set-VMNetworkAdapter).Parameters.ContainsKey('DeviceNaming'))
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -DeviceNaming On
            } # if
            if ($VMAdapter.MACAddressSpoofing -ne $VMNetworkAdapter.MACAddressSpoofing)
            {
                $MACAddressSpoofing = if ($VMAdapter.MACAddressSpoofing) {'On'} else {'Off'}
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -MacAddressSpoofing $MACAddressSpoofing
            } # if
        } # foreach

        Install-LabVM `
            -Lab $Lab `
            -VM $VM
    } # foreach
} # Initialize-LabVM


<#
.SYNOPSIS
    Removes all Lab Virtual Machines.
.DESCRIPTION
    This cmdlet is used to remove any Virtual Machines that were created as part of this
    Lab.

    It can also optionally delete the folder and all files created as part of this Lab
    Virutal Machine.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM names.

    Only VMs matching names in this list will be removed.
.PARAMETER VMs
    The array of LabVM objects pulled from the Lab using Get-LabVM.

    If not provided it will attempt to pull the list from the Lab object.
.PARAMETER RemoveVMFolder
    Causes the folder created to contain the Virtual Machine in this lab to be deleted.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplates = Get-LabVMTemplate -Lab $Lab
    $VMs = Get-LabVs -Lab $Lab -VMTemplates $VMTemplates
    Remove-LabVM -Lab $Lab -VMs $VMs
    Removes any Virtual Machines configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Remove-LabVM -Lab $Lab
    Removes any Virtual Machines configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Remove-LabVM {
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
        [LabVM[]] $VMs,

        [Parameter(
            Position=4)]
        [Switch] $RemoveVMFolder
    )
    
    # if VMs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMs'))
    {
        $null = $PSBoundParameters.Remove('RemoveVMFolder')
        [LabVM[]] $VMs = Get-LabVM `
            @PSBoundParameters
    } # if

    $CurrentVMs = Get-VM

    # Get the LabPath
    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    
    foreach ($VM in $VMs)
    {
        if ($Name -and ($VM.Name -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if

        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -ne 0)
        {
            # if the VM is running we need to shut it down.
            if ((Get-VM -Name $VM.Name).State -eq 'Running')
            {
                Write-Verbose -Message $($LocalizedData.StoppingVMMessage `
                    -f $VM.Name)

                Stop-VM `
                    -Name $VM.Name
                # Wait for it to completely shut down and report that it is off.
                WaitVMOff `
                    -VM $VM
            }

            Write-Verbose -Message $($LocalizedData.RemovingVMMessage `
                -f $VM.Name)
           
            # Now delete the actual VM
            Get-VM `
                -Name $VM.Name | Remove-VM -Force -Confirm:$False

            Write-Verbose -Message $($LocalizedData.RemovedVMMessage `
                -f $VM.Name)
        }
        else
        {
            Write-Verbose -Message $($LocalizedData.VMNotFoundMessage `
                -f $VM.Name)
        }
    }
    # Should we remove the VM Folder?
    if ($RemoveVMFolder)
    {
        if (Test-Path -Path $VM.VMRootPath)
        {
            Write-Verbose -Message $($LocalizedData.DeletingVMFolderMessage `
                -f $VM.Name)

            Remove-Item `
                -Path $VM.VMRootPath `
                -Recurse `
                -Force
        }
    }
} # Remove-LabVM



<#
.SYNOPSIS
   Starts a Lab VM and ensures it has been Initialized.
.DESCRIPTION
   This cmdlet is used to start up a Lab VM for the first time.
   
   It will start the VM if it is off.
   
   If the VM is a Server OS or Nano Server then it will also perform an initial setup:
    - It will ensure that initial setup has been completed and a self-signed certificate has
      been created by the VM and downloaded to the LabBuilder folder.   

    - It will also ensure DSC is configured for the VM.
.PARAMETER VM
   The LabVM Object referring to the VM to start to.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
   $Session = Install-LabVM -VM $VMs[0]
   Start up the first VM in the Lab c:\mylab\config.xml and initialize it.
.OUTPUTS
   None.
#>
function Install-LabVM {
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
        [LabVM] $VM
    )

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # The VM is now ready to be started
    if ((Get-VM -Name $VM.Name).State -eq 'Off')
    {
        Write-Verbose -Message $($LocalizedData.StartingVMMessage `
            -f $VM.Name)

        Start-VM -VMName $VM.Name
    } # if

    # We only perform this section of VM Initialization (DSC, Cert, etc) with Server OS
    if ($VM.OSType -in ([LabOStype]::Server,[LabOStype]::Nano))
    {
        # Has this VM been initialized before (do we have a cert for it)
        if (-not (Test-Path "$LabPath\$($VM.Name)\LabBuilder Files\$Script:DSCEncryptionCert"))
        {
            # No, so check it is initialized and download the cert if required
            if (WaitVMInitializationComplete -VM $VM -ErrorAction Continue)
            {
                Write-Verbose -Message $($LocalizedData.CertificateDownloadStartedMessage `
                    -f $VM.Name)

                if ($VM.CertificateSource -eq [LabCertificateSource]::Guest)
                {
                    if (GetSelfSignedCertificate -Lab $Lab -VM $VM)
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
                    } # if
                } # if
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
            } # if
        } # if

        # Create any DSC Files for the VM
        InitializeDSC `
            -Lab $Lab `
            -VM $VM

        # Attempt to start DSC on the VM
        StartDSC `
            -Lab $Lab `
            -VM $VM
    } # if
} # Install-LabVM



<#
.SYNOPSIS
   Connects to a running Lab VM.
.DESCRIPTION
   This cmdlet will connect to a running VM using PSRemoting. A PSSession object will be returned
   if the connection was successful.
   
   If the connection fails, it will be retried until the ConnectTimeout is reached. If the
   ConnectTimeout is reached and a connection has not been established then a ConnectionError 
   exception will be thrown.
   
   The IP Address to this VM will be added to the WSMan TrustedHosts list if it isn't already
   added or if it isn't set to '*'.
.PARAMETER VM
   The LabVM Object referring to the VM to connect to.
.PARAMETER ConnectTimeout
   The number of seconds the connection will attempt to be established for.

   Defaults to 300 seconds.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
   $Session = Connect-LabVM -VM $VMs[0]
   Connect to the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
   The PSSession object of the remote connect or null if the connection failed.
#>
function Connect-LabVM
{
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [LabVM] $VM,
        
        [Parameter(
            Position=2)]
        [Int] $ConnectTimeout = 300
    )

    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [PSCredential] $AdminCredential = CreateCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword
    [Boolean] $FatalException = $False
    
    while (($null -eq $Session) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $ConnectTimeout `
        -and -not $FatalException)
    {
        try
        {
            # Get the Management IP Address of the VM
            # We repeat this because the IP Address will only be assiged 
            # once the VM is fully booted.
            $IPAddress = GetVMManagementIPAddress `
                -Lab $Lab `
                -VM $VM

            # Add the IP Address to trusted hosts if not already in it
            # This could be avoided if able to use SSL or if PS Direct is used.
            # Also, don't add if TrustedHosts is already *
            $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
            if (($TrustedHosts -notlike "*$IPAddress*") -and ($TrustedHosts -ne '*'))
            {
                if ([String]::IsNullOrWhitespace($TrustedHosts))
                {
                    $TrustedHosts = $IPAddress
                }
                else
                {
                    $TrustedHosts = "$TrustedHosts,$IPAddress"
                }
                Set-Item `
                    -Path WSMAN::localhost\Client\TrustedHosts `
                    -Value $TrustedHosts `
                    -Force
                Write-Verbose -Message $($LocalizedData.AddingIPAddressToTrustedHostsMessage `
                    -f $VM.Name,$IPAddress)
            }
        
            Write-Verbose -Message $($LocalizedData.ConnectingVMMessage `
                -f $VM.Name,$IPAddress)

            $Session = New-PSSession `
                -Name 'LabBuilder' `
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

    # if a fatal exception occured or the connection just couldn't be established
    # then throw an exception so it can be caught by the calling code.
    if ($FatalException -or ($null -eq $Session))
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


<#
.SYNOPSIS
   Disconnects from a running Lab VM.
.DESCRIPTION
   This cmdlet will disconnect a session from a running VM using PSRemoting.
   
   The IP Address to this VM will be removed from the WSMan TrustedHosts list 
   if it exists in it.
.PARAMETER VM
   The LabVM Object referring to the VM to disconnect from.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
   Disconnect-LabVM -VM $VMs[0]
   Disconnect from the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
   None
#>
function Disconnect-LabVM
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [LabVM] $VM
    )

    [PSCredential] $AdminCredential = CreateCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword

    # Get the Management IP Address of the VM
    $IPAddress = GetVMManagementIPAddress `
        -Lab $Lab `
        -VM $VM

    try
    {
        # Look for the session
        $Session = Get-PSSession `
            -Name 'LabBuilder' `
            -ComputerName $IPAddress `
            -Credential $AdminCredential `
            -ErrorAction Stop

        if (-not $Session)
        {
            # No session found to this machine so nothing to do.
            Write-Verbose -Message $($LocalizedData.VMSessionDoesNotExistMessage `
                -f $VM.Name)
        }
        else
        {
            if ($Session.State -eq 'Opened')
            {
                # Disconnect the session
                $null = $Session | Disconnect-PSSession
                Write-Verbose -Message $($LocalizedData.DisconnectingVMMessage `
                    -f $VM.Name,$IPAddress)
            }
            # Remove the session
            $null = $Session | Remove-PSSession -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Throw $_
    }
    finally
    {
        # Remove the entry from TrustedHosts
        $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
        if (($TrustedHosts -like "*$IPAddress*") -and ($TrustedHosts -ne '*'))
        {
            # Lazy code to remove IP address if it is in the middle
            # at the end or the beginning of the TrustedHosts list
            $TrustedHosts = $TrustedHosts -replace ",$IPAddress,",','
            $TrustedHosts = $TrustedHosts -replace "$IPAddress,",''
            $TrustedHosts = $TrustedHosts -replace ",$IPAddress",''
            Set-Item `
                -Path WSMAN::localhost\Client\TrustedHosts `
                -Value $TrustedHosts `
                -Force
            Write-Verbose -Message $($LocalizedData.RemovingIPAddressFromTrustedHostsMessage `
                -f $VM.Name,$IPAddress)
        }
    } # try
} # Disconnect-LabVM


#region LabInstallationFunctions
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
        if (-not $PSCmdlet.ShouldProcess( ( $LocalizedData.ShouldOverwriteLab `
            -f $LabPath )))
        {
            return
        }
    }
    else
    {
        Write-Verbose -Message $($LocalizedData.CreatingLabFolderMessage `
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
        if (-not $PSCmdlet.ShouldProcess( ( $LocalizedData.ShouldOverwriteLabConfig `
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
        [Switch] $CheckEnvironment
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('CheckEnvironment')
    
        if ($CheckEnvironment)
        {
            # Check Hyper-V
            InstallHyperV
        } # if

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
        Write-Verbose -Message $($LocalizedData.InitializingLabFoldersMesage)

        # Check folders are defined
        [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
        if (-not (Test-Path -Path $LabPath))
        {
            Write-Verbose -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'LabPath',$LabPath)

            $null = New-Item `
                -Path $LabPath `
                -Type Directory
        }

        [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
        if (-not (Test-Path -Path $VHDParentPath))
        {
            Write-Verbose -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'VHDParentPath',$VHDParentPath)

            $null = New-Item `
                -Path $VHDParentPath `
                -Type Directory
        }
        
        [String] $ResourcePath = $Lab.labbuilderconfig.settings.resourcepathfull
        if (-not (Test-Path -Path $ResourcePath))
        {
            Write-Verbose -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'ResourcePath',$ResourcePath)

            $null = New-Item `
                -Path $ResourcePath `
                -Type Directory
        }

        # Install Hyper-V Components
        Write-Verbose -Message $($LocalizedData.InitializingHyperVComponentsMesage)

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
                -Name $ManagementSwitchName
                
            Write-Verbose -Message $($LocalizedData.CreatingLabManagementSwitchMessage `
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
            Write-Verbose -Message $($LocalizedData.UpdatingLabManagementSwitchMessage `
                -f $ManagementSwitchName,$ManagementVlan)

            Set-VMNetworkAdapterVlan `
                -VMNetworkAdapterName $ManagementSwitchName `
                -ManagementOS `
                -Access `
                -VlanId $ManagementVlan
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

        Write-Verbose -Message $($LocalizedData.LabInstallCompleteMessage `
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

        Write-Verbose -Message $($LocalizedData.LabUpdateCompleteMessage `
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
        if ($PSCmdlet.ShouldProcess( ( $LocalizedData.ShouldUninstallLab `
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
                if ($PSCmdlet.ShouldProcess( $($LocalizedData.ShouldRemoveVMTemplate `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabVMTemplate `
                        -Lab $Lab
                } # if
            } # if

            # Remove the VM Switches
            if ($RemoveSwitch)
            {
                if ($PSCmdlet.ShouldProcess( $($LocalizedData.ShouldRemoveSwitch `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabSwitch `
                        -Lab $Lab
                } # if
            } # if

            # Remove the VM Template VHDs
            if ($RemoveVMTemplateVHD)
            {
                if ($PSCmdlet.ShouldProcess( $($LocalizedData.ShouldRemoveVMTemplateVHD `
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
                    if ($PSCmdlet.ShouldProcess( $($LocalizedData.ShouldRemoveLabFolder `
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

                Write-Verbose -Message $($LocalizedData.RemovingLabManagementSwitchMessage `
                    -f $ManagementSwitchName)
            }

            Write-Verbose -Message $($LocalizedData.LabUninstallCompleteMessage `
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
            Write-Verbose -Message $($LocalizedData.StartingBootPhaseVMsMessage `
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
                    Write-Verbose -Message $($LocalizedData.StartingVMMessage `
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
                        Write-Verbose -Message $($LocalizedData.AllBootPhaseVMsStartedMessage `
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

        Write-Verbose -Message $($LocalizedData.LabStartCompleteMessage `
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
            Write-Verbose -Message $($LocalizedData.StoppingBootPhaseVMsMessage `
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
                    Write-Verbose -Message $($LocalizedData.StoppingVMMessage `
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
                        Write-Verbose -Message $($LocalizedData.AllBootPhaseVMsStoppedMessage `
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

        Write-Verbose -Message $($LocalizedData.LabStopCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)
    } # process

    end
    {
    } # end
} # Stop-Lab
#endregion