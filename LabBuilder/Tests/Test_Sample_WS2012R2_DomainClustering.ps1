[String]$Script:ModulePath = "$PSScriptRoot\..\LabBuilder.psd1"
[String]$Script:ConfigPath = "$PSScriptRoot\..\Samples\Sample_WS2012R2_DomainClustering.xml"
##########################################################################################################################################
Function Test-StartLabVM {
    Param (
        [String[]]$StartVMs
    )
    $Lab = Get-Lab -Path $Script:ConfigPath
    [Array]$VMs = Get-LabVM `
        -Lab $Lab `
        -Name $StartVMs
    Foreach ($VM in $VMs) {
        Install-LabVM `
            -Lab $Lab `
            -VM $VM `
            -Verbose
    }
}
##########################################################################################################################################
Function Test-LabBuilderInstall {
    Get-Lab -ConfigPath $Script:ConfigPath | Install-Lab -Verbose
} # Function Test-LabBuilderInstall
##########################################################################################################################################
Function Test-LabBuilderUpdate {
    Get-Lab -ConfigPath $Script:ConfigPath | Update-Lab -Verbose
} # Function Test-LabBuilderInstall
##########################################################################################################################################
Function Test-LabBuilderStart {
    Get-Lab -ConfigPath $Script:ConfigPath | Start-Lab -Verbose
} # Function Test-LabBuilderInstall
##########################################################################################################################################
Function Test-LabBuilderStop {
    Get-Lab -ConfigPath $Script:ConfigPath | Stop-Lab -Verbose
} # Function Test-LabBuilderInstall
##########################################################################################################################################
Function Test-LabBuilderUninstall {
    Get-Lab -ConfigPath $Script:ConfigPath | Uninstall-Lab -Verbose -RemoveVMFolder -RemoveVMTemplate -RemoveLabFolder
} # Function Test-LabBuilderUnnstall
##########################################################################################################################################
Function Test-LabBuilderLoadModule {
    Import-Module $Script:ModulePath -Verbose -Force
} # Function Test-LabBuilderLoadModule
##########################################################################################################################################
Test-LabBuilderLoadModule
Test-LabBuilderInstall
# Test-LabBuilderUpdate
# Test-LabBuilderStart
# Test-LabBuilderStop
# Test-StartLabVM -StartVMs 'SA-DC1'
# Test-LabBuilderUninstall
