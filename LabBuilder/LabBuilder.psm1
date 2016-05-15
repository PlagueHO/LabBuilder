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
    [String] $BindingAdapterName
    [String] $BindingAdapterMac
    [String] $NatSubnet
    [String] $NatGatewayAddress
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
    [Boolean] $ExposeVirtualizationExtensions = $False
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
[String] $Script:SupportConvertWindowsImagePath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'Support\Convert-WindowsImage.ps1'
[String] $Script:SupportGertGenPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'Support\New-SelfSignedCertificateEx.ps1'

# DSC Library
[String] $Script:DSCLibraryPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'DSCLibrary'

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

# System Info
[Int] $Script:CurrentBuild = (Get-ItemProperty `
    -Path 'hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild

# XML Stuff
[String] $Script:ConfigurationXMLSchema = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'schema\labbuilderconfig-schema.xsd'
[String] $Script:ConfigurationXMLTemplate = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'template\labbuilderconfig-template.xml'

# Nano Stuff
[String] $Script:NanoPackageCulture = 'en-us'