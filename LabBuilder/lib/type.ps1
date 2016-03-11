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

class LabResourceModule:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabResourceModule]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
    [String] $Name
    [String] $URL
    [String] $Folder
    [String] $MinimumVersion
    [String] $RequiredVersion
} # class LabResourceModule

class LabResourceMSU:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabResourceMSU]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
    [String] $Name
    [String] $URL
    [String] $Path
    [String] $Filename
} # class LabResourceMSU

class LabSwitchAdapter:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabSwitchAdapter]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
    [String] $Name
    [String] $MACAddress
    [Byte] $Vlan
} # class LabSwitchAdapter

class LabVMAdapterIPv4:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabVMAdapterIPv4]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
    [String] $Address
    [String] $DefaultGateway
    [Byte] $SubnetMask
    [String] $DNSServer
} # class LabVMAdapterIPv4

class LabVMAdapterIPv6:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabVMAdapterIPv6]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
    [String] $Address
    [String] $DefaultGateway
    [Byte] $SubnetMask
    [String] $DNSServer
} # class LabVMAdapterIPv6

class LabVMAdapter:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabVMAdapter]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
    [String] $Name
    [String] $SwitchName
    [String] $MACAddress
    [Boolean] $MACAddressSpoofing
    [Byte] $Vlan
    [LabVMAdapterIPv4] $IPv4
    [LabVMAdapterIPv6] $IPv6
} # class LabVMAdapter

class LabDataVHD:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabDataVHD]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
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
} # class LabDataVHD

class LabVMTemplateVHD:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabVMTemplateVHD]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
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

class LabVMTemplate:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabVMTemplate]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
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
} # class LabVMTemplate

class LabSwitch:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabSwitch]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
    [String] $Name
    [LabSwitchType] $Type
    [Byte] $VLAN
    [String] $NATSubnetAddress
    [LabSwitchAdapter[]] $Adapters
} # class LabSwitch

class LabDSC:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabDSC]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
    [String] $ConfigName
    [String] $ConfigFile
    [String] $Parameters
    [Boolean] $Logging = $False
} # class LabDSC

class LabVM:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabVM]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
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
    [LabDSC] $DSC
    [String] $VMRootPath
    [String] $LabBuilderFilesPath
} # class LabVM

class LabDSCModule:System.ICloneable {
    [Object] Clone () {
        $NewVM = [LabDSCModule]::New()
        foreach ($Property in ($this | Get-Member -MemberType Property))
        {
            $NewVM.$($Property.Name) = $this.$($Property.Name)
        } # foreach
        return $NewVM
    } # Clone
    [String] $ModuleName
    [String] $ModuleVersion
} # class LabDSCModule