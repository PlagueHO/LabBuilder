#Requires -version 5.0

# This line makes sure that the script doesn't run prematurely
#Return

# Configuration
[string]$InternetSwitchName = 'General Purpose Internal'
[string]$DomainSwitchName = 'Domain Private Site'
[int]$DomainSiteCount = 4
[string]$VMPath = 'c:\vm\bmdlab.local'

# Used as the parent disks for all differencing disks used by the VMs
$ParentVHDs = @{
    WindowsServer2012R2Full = "$($VMpath)\Virtual Hard Disks\Windows Server 2012 R2 Full Parent.vhdx";
    WindowsServer2012R2Core = "$($VMpath)\Virtual Hard Disks\Windows Server 2012 R2 Core Parent.vhdx";
    Windows10Ent = "$($VMPath)\Virtual Hard Disks\Windows 10 Enterprise Parent.vhdx";
    }

# Pre-checks
# Check all VM Parent disks exist
Foreach ($ParentVHD in $ParentVHDs.Values) {
    If (-not (Test-Path -Path $ParentVHD)) {
        Write-Error "The parent VHD $ParentVHD is not found."
        Return
    }
}

# Create Folder for VMs
If (-not (Test-Path -Path $VMPath)) {
    New-Item -Path $VMPath -ItemType Directory
}

# Install Hyper-V Components
Write-Verbose "Installing Hyper-V Components ..."
Get-WindowsOptionalFeature -Online -FeatureName *Hyper-V* | Where-Object -Property State -Eq 'Disabled' | Enable-WindowsOptionalFeature -Online

# Create Hyper-V Switches
If ((Get-VMSwitch -Name $InternetSwitchName).Count -eq 0) {
    Write-Verbose "Creating Virtual Switch '$InternetSwitchName' ..."
    New-VMSwitch -Name $InternetSwitchName -SwitchType External
    Add-VMNetworkAdapter -ManagementOS -SwitchName $InternetSwitchName -Name 'Cluster' -StaticMacAddress '00155D010675'
    Add-VMNetworkAdapter -ManagementOS -SwitchName $InternetSwitchName -Name 'Management' -StaticMacAddress '00155D010677'
    Add-VMNetworkAdapter -ManagementOS -SwitchName $InternetSwitchName -Name 'SMB' -StaticMacAddress '00155D010674'
    Add-VMNetworkAdapter -ManagementOS -SwitchName $InternetSwitchName -Name 'LM' -StaticMacAddress '00155D010676'
}
For ([int]$Switch=1; $Switch++; $Switch -le $DomainSwitchCount) {
    [char]$SiteLetter = [Convert]::ToChar([Convert]::ToByte([Char]'A')+$Switch)
    [string]$SwitchName = "$DomainSwitchName $SiteLetter"
    Write-Verbose "Creating Virtual Switch '$SwitchName' ..."
    New-VMSwitch -Name $SwitchName -SwitchType Private
}
