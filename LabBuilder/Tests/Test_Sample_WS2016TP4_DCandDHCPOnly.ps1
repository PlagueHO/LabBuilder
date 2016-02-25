[String]$Script:ModulePath = "$PSScriptRoot\..\LabBuilder.psd1"
[String]$Script:ConfigPath = "$PSScriptRoot\..\Samples\Sample_WS2016TP4_DCandDHCPOnly.xml"
##########################################################################################################################################
Function Test-StartLabVM {
    Param (
        [String[]]$StartVMs
    )
    $Lab = Get-Lab -ConfigPath $Script:ConfigPath
    [Array]$Templates = Get-LabVMTemplate -Lab $Lab
    [Array]$Switches = Get-LabSwitch -Lab $Lab
    [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
    Foreach ($VM in $VMs) {
        If ($VM.ComputerName -in $StartVMs) {
            Start-LabVM -Lab $Lab -VM $VM -Verbose
        }
    }
}
##########################################################################################################################################
Function Test-LabBuilderInstall {
    Install-Lab -Path $Script:ConfigPath -Verbose
} # Function Test-LabBuilderInstall
##########################################################################################################################################
Function Test-LabBuilderUninstall {
    Uninstall-Lab -Path $Script:ConfigPath -Verbose -RemoveVMFolder -RemoveTemplate
} # Function Test-LabBuilderUnnstall
##########################################################################################################################################
Function Test-LabBuilderLoadModule {
    Import-Module $Script:ModulePath -Verbose -Force
} # Function Test-LabBuilderLoadModule
##########################################################################################################################################
Test-LabBuilderLoadModule
Test-LabBuilderInstall
# Test-StartLabVM -StartVMs 'SA-DC1'
# Sleep 30 # Wait 30 seconds for everything to finish building
# Test-LabBuilderUninstall
