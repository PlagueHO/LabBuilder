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

class LabResourceModule {
    [String] $Name
    [String] $URL
    [String] $Folder
    [String] $MinimumVersion
    [String] $RequiredVersion
} # class LabResourceModule

class LabResourceMSU {
    [String] $Name
    [String] $URL
    [String] $Path
} # class LabResourceMSU

class LabSwitchAdapter {
    [String] $Name
    [String] $MACAddress
    [Byte] $Vlan
} # class LabSwitchAdapter

class LabVMAdapterIPv4 {
    [String] $Address
    [String] $DefaultGateway
    [Byte] $SubnetMask
    [String] $DNSServer
} # class LabVMAdapterIPv4

class LabVMAdapterIPv6 {
    [String] $Address
    [String] $DefaultGateway
    [Byte] $SubnetMask
    [String] $DNSServer
} # class LabVMAdapterIPv6

class LabVMAdapter {
    [String] $Name
    [String] $MACAddress
    [Byte] $Vlan
    [LabVMAdapterIPv4] $IPv4
    [LabVMAdapterIPv4] $IPv6
} # class LabVMAdapter

class LabDataVHD {
    [String] $VHD
    [LabVHDType] $Type = [LabVHDType]::Dynamic
    [Uint64] $Size
    [String] $SourceVHD
    [String] $ParentVHD
    [Boolean] $MoveSourceVHD
    [String] $CopyFolders
    [LabFileSystem] $FileSystem
    [LabPartitionStyle] $PartitionStyle
    [String] $FileSystemLabel
    [Boolean] $Shared = $False
    [Boolean] $SupportsPR = $False
} # class LabDataVHD

class LabVMTemplateVHD {
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
} # class LabVMTemplateVHD

class LabVMTemplate {
    [String] $Name
    [String] $VHD
    [String] $SourceVHD
    [String] $TemplateVHD
    [Uint64] $MemoryStartupBytes = 1GB
    [Boolean] $DynamicMemoryEnabled = $True
    [Byte] $ProcessorCount = 1
    [String] $AdministratorPassword
    [String] $ProductKey
    [String] $Timezone="Pacific Standard Time"
    [LabOStype] $OSType = [LabOStype]::Server
    [String[]] $IntegrationServices = @('Guest Service Interface','Heartbeat','Key-Value Pair Exchange','Shutdown','Time Synchronization','VSS') 
    [String[]] $Packages
} # class LabVMTemplate

class LabSwitch {
    [String] $Name
    [LabSwitchType] $Type
    [Byte] $VLAN
    [String] $NATSubnetAddress
    [LabSwitchAdapter[]] $Adapters
} # class LabSwitch

class LabDSC {
    [String] $ConfigName
    [String] $ConfigFile
    [Boolean] $Logging = $False
    [String] $Parameters
} # class LabDSC

class LabVM {
    [String] $Name
    [String] $Template
    [String] $ComputerName
    [Uint64] $MemoryStartupBytes = 1GB
    [Boolean] $DynamicMemoryEnabled = $True
    [Boolean] $ExposeVirtualizationExtensions = $True
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
    [LabDSC] $DSC
    [String[]] $InstallMSU
} # class LabVM

class LabDSCModule {
    [String] $ModuleName
    [String] $ModuleVersion
} # class LabDSCModule