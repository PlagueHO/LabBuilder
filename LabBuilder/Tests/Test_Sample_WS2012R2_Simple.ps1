[String]$Script:ModulePath = "$PSScriptRoot\..\LabBuilder.psd1"
[String]$Script:ConfigPath = "$PSScriptRoot\..\Samples\Sample_WS2012R2_Simple.xml"
##########################################################################################################################################
Function Test-StartLabVM {
    Param (
        [String[]]$StartVMs
    )
    $Config = Get-LabConfiguration -Path $Script:ConfigPath
    [Array]$Templates = Get-LabVMTemplate -Config $Config
    [Array]$Switches = Get-LabSwitch -Config $Config
    [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
    Foreach ($VM in $VMs) {
        If ($VM.ComputerName -in $StartVMs) {
            Start-LabVM -Config $Config -VM $VM -Verbose
        }
    }
}
##########################################################################################################################################
Function Test-LabBuilderInstall {
    Install-Lab -Path $Script:ConfigPath -Verbose
} # Function Test-LabBuilderInstall
##########################################################################################################################################
Function Test-LabBuilderUninstall {
    Uninstall-Lab -Path $Script:ConfigPath -Verbose -RemoveVHDs -RemoveTemplates
} # Function Test-LabBuilderUnnstall
##########################################################################################################################################
Function Test-LabBuilderLoadModule {
    Import-Module $Script:ModulePath -Verbose -Force
} # Function Test-LabBuilderLoadModule
##########################################################################################################################################
Test-LabBuilderLoadModule
Test-LabBuilderInstall
# Test-StartLabVM -StartVMs 'SA-DEFAULT'
# Sleep 30 # Wait 30 seconds for everything to finish building
# Test-LabBuilderUninstall
