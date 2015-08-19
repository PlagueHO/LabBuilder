#Requires -version 5.0

# Install Hyper-V Components
Write-Verbose "Installing Hyper-V Components ..."
Get-WindowsOptionalFeature -Online -FeatureName *Hyper-V* | Where-Object -Property State -Eq 'Disabled' | Enable-WindowsOptionalFeature -Online

# Create Hyper-V Switches
If ((Get-VMSwitch -Name 'General Purpose External').Count -eq 0) {
    Write-Verbose "Installing Virtual Switch 'General Purpose External' ..."
    New-VMSwitch -Name 'General Purpose External' -SwitchType External
    Add-VMNetworkAdapter -ManagementOS -SwitchName 'General Purpose External' -Name 'Cluster' -StaticMacAddress '00155D010675'
    Add-VMNetworkAdapter -ManagementOS -SwitchName 'General Purpose External' -Name 'Management' -StaticMacAddress '00155D010677'
    Add-VMNetworkAdapter -ManagementOS -SwitchName 'General Purpose External' -Name 'SMB' -StaticMacAddress '00155D010674'
    Add-VMNetworkAdapter -ManagementOS -SwitchName 'General Purpose External' -Name 'LM' -StaticMacAddress '00155D010676'
}