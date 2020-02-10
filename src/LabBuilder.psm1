<#
.EXTERNALHELP LabBuilder-help.xml
#>
#Requires -version 5.1
#Requires -RunAsAdministrator

$script:LabBuidlerModuleRoot = Split-Path `
    -Path $MyInvocation.MyCommand.Path `
    -Parent

#region LocalizedData
$culture = 'en-us'

if (Test-Path -Path (Join-Path -Path $script:LabBuidlerModuleRoot -ChildPath $PSUICulture))
{
    $culture = $PSUICulture
}

Import-LocalizedData `
    -BindingVariable LocalizedData `
    -Filename 'LabBuilder_LocalizedData.psd1' `
    -BaseDirectory $script:LabBuidlerModuleRoot `
    -UICulture $culture
#endregion

#region Types
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
    [System.String] $Name
    [System.String] $URL
    [System.String] $Folder
    [System.String] $MinimumVersion
    [System.String] $RequiredVersion

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
    [System.String] $Name
    [System.String] $URL
    [System.String] $Path
    [System.String] $Filename

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
    [System.String] $Name
    [System.String] $URL
    [System.String] $Path

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
    [System.String] $Name
    [System.String] $MACAddress
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
    [System.String] $Address
    [System.String] $DefaultGateway
    [Byte] $SubnetMask
    [System.String] $DNSServer

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
    [System.String] $Address
    [System.String] $DefaultGateway
    [Byte] $SubnetMask
    [System.String] $DNSServer

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
    [System.String] $Name
    [System.String] $SwitchName
    [System.String] $MACAddress
    [System.Boolean] $MACAddressSpoofing
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
    [System.String] $VHD
    [LabVHDType] $VHDType
    [Uint64] $Size
    [System.String] $SourceVHD
    [System.String] $ParentVHD
    [System.Boolean] $MoveSourceVHD
    [System.String] $CopyFolders
    [LabFileSystem] $FileSystem
    [LabPartitionStyle] $PartitionStyle
    [System.String] $FileSystemLabel
    [System.Boolean] $Shared = $false
    [System.Boolean] $SupportPR = $false

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
    [System.String] $ISO
    [System.String] $Path

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
    [System.String] $Name
    [System.String] $ISOPath
    [System.String] $VHDPath
    [LabOStype] $OSType = [LabOStype]::Server
    [System.String] $Edition
    [Byte] $Generation = 2
    [LabVHDFormat] $VHDFormat = [LabVHDFormat]::VHDx
    [LabVHDType] $VHDType = [LabVHDType]::Dynamic
    [Uint64] $VHDSize = 0
    [System.String[]] $Packages
    [System.String[]] $Features

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
    [System.String] $Name
    [System.String] $VHD
    [System.String] $SourceVHD
    [System.String] $ParentVHD
    [System.String] $TemplateVHD
    [Uint64] $MemoryStartupBytes = 1GB
    [System.Boolean] $DynamicMemoryEnabled = $true
    [System.Boolean] $ExposeVirtualizationExtensions = $false
    [Byte] $ProcessorCount = 1
    [System.String] $AdministratorPassword
    [System.String] $ProductKey
    [System.String] $Timezone="Pacific Standard Time"
    [LabOStype] $OSType = [LabOStype]::Server
    [System.String[]] $IntegrationServices = @('Guest Service Interface','Heartbeat','Key-Value Pair Exchange','Shutdown','Time Synchronization','VSS')
    [System.String[]] $Packages
    [ValidateRange(1,2)][Byte] $Generation = 2
    [ValidateSet("5.0","6.2","7.0","7.1","8.0","9.0","254.0","255.0")][System.String] $Version = '8.0'

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
    [System.String] $Name
    [LabSwitchType] $Type
    [Byte] $VLAN
    [System.String] $BindingAdapterName
    [System.String] $BindingAdapterMac
    [System.String] $NatSubnet
    [System.String] $NatGatewayAddress
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
    [System.String] $ConfigName
    [System.String] $ConfigFile
    [System.String] $Parameters
    [System.Boolean] $Logging = $false

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
    [System.String] $Name
    [System.String] $Template
    [System.String] $ComputerName
    [Byte] $ProcessorCount
    [Uint64] $MemoryStartupBytes = 1GB
    [System.Boolean] $DynamicMemoryEnabled = $true
    [System.Boolean] $ExposeVirtualizationExtensions = $false
    [System.String] $ParentVHD
    [System.Boolean] $UseDifferencingDisk = $true
    [System.String] $AdministratorPassword
    [System.String] $ProductKey
    [System.String] $Timezone="Pacific Standard Time"
    [LabOStype] $OSType = [LabOStype]::Server
    [System.String] $UnattendFile
    [System.String] $SetupComplete
    [System.String[]] $Packages
    [ValidateRange(1,2)][Byte] $Generation = 2
    [ValidateSet("5.0","6.2","7.0","7.1","8.0","9.0","254.0","255.0")][System.String] $Version = '8.0'
    [System.Int32] $BootOrder
    [System.String[]] $IntegrationServices = @('Guest Service Interface','Heartbeat','Key-Value Pair Exchange','Shutdown','Time Synchronization','VSS')
    [LabVMAdapter[]] $Adapters
    [LabDataVHD[]] $DataVHDs
    [LabDVDDrive[]] $DVDDrives
    [LabDSC] $DSC
    [System.String] $VMRootPath
    [System.String] $LabBuilderFilesPath
    [LabCertificateSource] $CertificateSource = [LabCertificateSource]::Guest
    [System.String] $NanoODJPath

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
    [System.String] $ModuleName
    [Version] $ModuleVersion
    [Version] $MinimumVersion

    LabDSCModule() {}

    LabDSCModule($ModuleName) {
        $this.ModuleName = $ModuleName
    } # Constructor

    LabDSCModule($ModuleName,$ModuleVersion) {
        $this.ModuleName = $ModuleName
        $this.ModuleVersion = [Version] $ModuleVersion
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
[System.String] $Script:WorkingFolder = $ENV:Temp

# Supporting files
[System.String] $Script:SupportConvertWindowsImagePath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'support\Convert-WindowsImage.ps1'
[System.String] $Script:SupportGertGenPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'support\New-SelfSignedCertificateEx.ps1'

# DSC Library
[System.String] $Script:DSCLibraryPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'dsclibrary'

# Virtual Networking Parameters
[System.Int32] $Script:DefaultManagementVLan = 99

# Self-signed Certificate Parameters
[System.Int32] $Script:SelfSignedCertKeyLength = 2048
# Warning - using KSP causes the Private Key to not be accessible to PS.
[System.String] $Script:SelfSignedCertProviderName = 'Microsoft Enhanced Cryptographic Provider v1.0' # 'Microsoft Software Key Storage Provider'
[System.String] $Script:SelfSignedCertAlgorithmName = 'RSA' # 'ECDH_P256' Or 'ECDH_P384' Or 'ECDH_P521'
[System.String] $Script:SelfSignedCertSignatureAlgorithm = 'SHA256' # 'SHA1'
[System.String] $Script:DSCEncryptionCert = 'DSCEncryption.cer'
[System.String] $Script:DSCEncryptionPfxCert = 'DSCEncryption.pfx'
[System.String] $Script:DSCCertificateFriendlyName = 'DSC Credential Encryption'
[System.String] $Script:DSCCertificatePassword = 'E3jdNkd903mDn43NEk2nbDENjw'
[System.Int32] $Script:RetryConnectSeconds = 5
[System.Int32] $Script:RetryHeartbeatSeconds = 1
[System.Int32] $Script:StartupTimeout = 90

# System Info
[System.Int32] $Script:CurrentBuild = (Get-ItemProperty `
    -Path 'hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild

# XML Stuff
[System.String] $Script:ConfigurationXMLSchema = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'schema\labbuilderconfig-schema.xsd'
[System.String] $Script:ConfigurationXMLTemplate = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'template\labbuilderconfig-template.xml'

# Nano Stuff
[System.String] $Script:NanoPackageCulture = 'en-us'

#region ImportFunctions
# Dot source any functions in the libs folder
$libFiles = Get-ChildItem `
    -Path (Join-Path -Path $script:LabBuidlerModuleRoot -ChildPath 'lib') `
    -Include '*.ps1' `
    -Recurse

foreach ($libFile in $libFiles)
{
    Write-Verbose -Message $($LocalizedData.ImportingLibFileMessage -f $libFile.Fullname)
    . $libFile.Fullname
}
#endregion
