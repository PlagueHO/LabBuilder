#Requires -version 5.0

# This line makes sure that the script doesn't run with F5
# Return

# Configuration Variables
[string]$Script:DomainName = 'BMDLAB.LOCAL'
[string]$Script:InternetSwitchName = 'General Purpose External'
[string]$Script:DomainSwitchName = 'Domain Private Site'
[int]$Script:DomainSiteCount = 4
[string]$Script:VMPath = "c:\vm\$DomainName"
[string]$Script:VHDParentPath = "$VMPath\Virtual Hard Disk Templates"

[System.Collections.Hashtable[]]$Script:VMs = @(
    @{
        Name = "$DomainName SS_ROOTCA";
        Template = 'Windows Server 2012 R2 Datacenter Full';
        MemoryStartupBytes = 1024MB;
        Networks = @('@'); # Internet Switches to connect to - @ is Internet
        DataVHDSize = 0; # Don't add an extra VHD to the VM
    }
)

# This array contains hash tables representing each template VM and applicable HD's
# It gets populated by the Init Templates function
[System.Collections.Hashtable[]]$Script:VMTemplates = @()

function InitVMTemplates {
    [CmdLetBinding()]
    param (
    )

    $VMTemplates = Get-VM -Name Template*
    Foreach ($VMTemplate in $VMTemplates) {
        [String]$VMTemplateName = $VMTemplate.Name.SubString(9)
        [String]$VMTemplateSourceVHD = ($VMTemplate | Get-VMHardDiskDrive).Path
        [String]$VMTemplateDestVHD = "$Script:VHDParentPath\$([System.IO.Path]::GetFileName($VMTemplateSourceVHD))"
        $Script:VMTemplates += @{ Name = $VMTemplateName; SourceVHD = $VMTemplateSourceVHD; DestVHD = $VMTemplateDestVHD; }
    } # Foreach
    Foreach ($VMTemplate in $Script:VMTemplates) {
        If (-not (Test-Path $VMTemplate.DestVHD)) {
            # The template VHD isn't in the VHD Parent folder - so copy it there after optimizing it
            Set-ItemProperty -Path $VMTemplate.SourceVHD -Name IsReadOnly -Value $False
            Write-Verbose "Optimizing template source VHD $($VMTemplate.SourceVHD) ..."
            Optimize-VHD -Path $VMTemplate.SourceVHD -Mode Full
            Set-ItemProperty -Path $VMTemplate.SourceVHD -Name IsReadOnly -Value $True
            Write-Verbose "Copying template source VHD $($VMTemplate.SourceVHD) to $($VMTemplate.DestVHD) ..."
            Copy-Item -Path $VMTemplate.SourceVHD -Destination $VMTemplate.DestVHD
            Set-ItemProperty -Path $VMTemplate.DestVHD -Name IsReadOnly -Value $True
        }
    }
} # InitVMTemplates

function PerformPreChecks {
    [CmdLetBinding()]
    param (
    )

    # Pre-checks
    # Create Folder for VMs (this should always exist because otherwise the Parent disks won't either)
    If (-not (Test-Path -Path $Script:VMPath)) {
        Throw "The VM Path $Script:VMPath is not found."
    }

    If (-not (Test-Path -Path $Script:VHDParentPath)) {
        Throw "The VHD Parent Path $Script:VHDParentPath is not found."
    }

    Return $True
} # PerformPreChecks

function InitHyperV {
    [CmdLetBinding()]
    param (
    )
    
    # Install Hyper-V Components
    Write-Verbose "Installing Hyper-V Components ..."
    Get-WindowsOptionalFeature -Online -FeatureName *Hyper-V* | Where-Object -Property State -Eq 'Disabled' | Enable-WindowsOptionalFeature -Online

    Set-VMHost -MacAddressMinimum '00155D010600' -MacAddressMaximum '00155D0106FF'

    # Create Hyper-V Switches
    If ((Get-VMSwitch | Where-Object -Property Name -eq $InternetSwitchName).Count -eq 0) {
        Write-Verbose "Creating Virtual Switch '$InternetSwitchName' ..."
        New-VMSwitch -Name $InternetSwitchName -SwitchType External
        Add-VMNetworkAdapter -ManagementOS -SwitchName $InternetSwitchName -Name 'Cluster' -StaticMacAddress '00155D010701'
        Add-VMNetworkAdapter -ManagementOS -SwitchName $InternetSwitchName -Name 'Management' -StaticMacAddress '00155D010702'
        Add-VMNetworkAdapter -ManagementOS -SwitchName $InternetSwitchName -Name 'SMB' -StaticMacAddress '00155D010703'
        Add-VMNetworkAdapter -ManagementOS -SwitchName $InternetSwitchName -Name 'LM' -StaticMacAddress '00155D010704'
    }
    For ([int]$Switch=0; $Switch -lt $Script:DomainSiteCount; $Switch++ ) {
        [char]$SiteLetter = [Convert]::ToChar([Convert]::ToByte([Char]'A')+$Switch)
        [string]$SwitchName = "$DomainSwitchName $SiteLetter"
        If ((Get-VMSwitch | Where-Object -Property Name -eq $SwitchName).Count -eq 0) {
            Write-Verbose "Creating Virtual Switch '$SwitchName' ..."
            New-VMSwitch -Name $SwitchName -SwitchType Private
        }
    }
} # InitHyperV

function InitVMs {
    [CmdLetBinding()]
    param (
    )
    
    $ExitingVMs = Get-VM
    Foreach ($VM in $Script:VMs) {
        If (($ExistingMVs | Where-Object -Property Name -eq $VM.Name).Count -eq 0) {
            Write-Verbose "Creating VM $($VM.Name) ..."

            # Find the template that this VM uses and get the Parent VHD Path
            [String]$ParentVHDPath = $null
            Foreach ($VMTemplate in $Script:VMTemplates) {
                If ($VMTemplate.Name -eq $VM.Template) {
                    $ParentVHDPath = $VMTemplate.DestVHD
                    Break

                }
            }
            If ($ParentVHDPath -eq $null)
            {
                throw "The template $($VMTemplate.Name) is not available."
            }
            If (-not (Test-Path $ParentVHDPath))
            {
                throw "The template parent VHD $ParentVHDPath can not be found."
            }

            If (-not (Test-Path -Path "$VMPath\$($VM.Name)")) {
                New-Item -Path "$VMPath\$($VM.Name)" -ItemType Directory | Out-Null
            }
            If (-not (Test-Path -Path "$VMPath\$($VM.Name)\Virtual Machines")) {
                New-Item -Path "$VMPath\$($VM.Name)\Virtual Machines" -ItemType Directory | Out-Null
            }
            If (-not (Test-Path -Path "$VMPath\$($VM.Name)\Virtual Hard Disks")) {
                New-Item -Path "$VMPath\$($VM.Name)\Virtual Hard Disks" -ItemType Directory | Out-Null
            }
            $VMBootDiskPath = "$VMPath\$($VM.Name)\Virtual Hard Disks\$($VM.Name) Boot Disk.vhdx"
            If (-not (Test-Path -Path $VMBootDiskPath)) {
                Write-Verbose "Creating VM $($VM.Name) Boot Disk $VMBootDiskPath ..."
                New-VHD -Differencing -Path $VMBootDiskPath -ParentPath $ParentVHDPath | Out-Null
            } Else {
                Write-Verbose "VM $($VM.Name) Boot Disk $VMBootDiskPath already exists..."
            }
            New-VM -Name $VM.Name -MemoryStartupBytes $VM.MemoryStartupBytes -Generation 2 -Path $VMPath -VHDPath $VMBootDiskPath -SwitchName $Script:InternetSwitchName | Out-Null
            If (($VM.DataVHDSize -ne $null) -and ($VM.DataVHDSize -gt 0)) {
                $VMDataDiskPath = "$VMPath\$($VM.Name)\Virtual Hard Disks\$($VM.Name) Data Disk.vhdx"
                If (-not (Test-Path -Path $VMDataDiskPath)) {
                    Write-Verbose "Creating VM $($VM.Name) Data Disk $VMDataDiskPath ..."
                    New-VHD -Path $VMDataDiskPath -SizeBytes $VM.DataVHDSize -Dynamic | Out-Null
                } Else {
                    Write-Verbose "VM $($VM.Name) Data Disk $VMDataDiskPath already exists..."
                }
                Add-VMHardDiskDrive -VMName $VM.Name -Path $VMDataDiskPath -ControllerType SCSI -ControllerLocation 1 -ControllerNumber 0 | Out-Null
            }
            For ([int]$Switch=0; $Switch -lt $Script:DomainSiteCount; $Switch++ ) {
                [char]$SiteLetter = [Convert]::ToChar([Convert]::ToByte([Char]'A')+$Switch)
                If ($SiteLetter -in $VM.Networks) {
                    [string]$SwitchName = "$DomainSwitchName $SiteLetter"
                    Add-VMNetworkAdapter -VMName $VM.Name -SwitchName $SwitchName -Passthru | Set-VMNetworkAdapterVlan -Access -VlanId $($Switch+2) | Out-Null
                }
            }
            If ('@' -notin $VM.Networks) {
                Get-VMNetworkAdapter -VMName $VM.Name -Name 'Network Adapter' | Where-Object -Property SwitchName -eq $Script:InternetSwitchName | Remove-VMNetworkAdapter
            }            
        }
    } 
} # InitVMs


Function BuildLab {
    [CmdLetBinding()]
    param (
    )

    # Make sure everything is OK to install the lab
    try {
        If (-not (PerformPreChecks -Verbose)) {
                return
            }
    }
    catch {
        return
    }

    try {
        InitVMTemplates -Verbose
    }
    catch {
        return
    }

    try {
        InitHyperV -Verbose
    }
    catch {
        return
    }

    try {
        InitVMs -Verbose
    }
    catch {
        return
    }
} # BuildLab

Function RemoveLab {
    [CmdLetBinding()]
    param (
    )
} # RemoveLab

BuildLab
Return

RemoveLab
Return