[String]$Script:ModulePath = "$PSScriptRoot\..\LabBuilder.psd1"
[String]$Script:ConfigPath = "$PSScriptRoot\..\Samples\Sample_DomainComplete.xml"
##########################################################################################################################################
Function Test-StartLabVM {
    Param (
        [String[]]$StartVMs
    )
    $Config = Get-LabConfiguration -Path $Script:ConfigPath
    [Array]$Templates = Get-LabVMTemplates -Configuration $Config
    [Array]$Switches = Get-LabSwitches -Configuration $Config
    [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
    Foreach ($VM in $VMs) {
        If ($VM.ComputerName -in $StartVMs) {
            Start-LabVM -Configuration $Config -VM $VM -Verbose
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
# Test-StartLabVM -StartVMs 'SA_DHCP1'
# Sleep 30 # Wait 30 seconds for everything to finish building
# Test-LabBuilderUninstall
