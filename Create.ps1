#Requires -version 5.0

# Configuration
[string]$InternetSwitchName = 'General Purpose Internal'
[string]$DomainSwitchName = 'Domain Private Site'
[int]$DomainSiteCount = 4

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