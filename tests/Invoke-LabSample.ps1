﻿# Set the name of the sample Lab from the samples folder:
[System.String]$script:ConfigPath = "$PSScriptRoot\..\src\Samples\Sample_WS2016_DCandDHCPandCA.xml"
[System.String]$script:ModulePath = "$PSScriptRoot\..\src\LabBuilder.psd1"

####################################################################################################
Function Test-StartLabVM {
    param (
        [System.String[]]$StartVMs
    )
    $Lab = Get-Lab -Config $script:ConfigPath
    [array] $VMs = Get-LabVM `
        -Lab $Lab `
        -Name $StartVMs
    Foreach ($VM in $VMs) {
        Install-LabVM `
            -Lab $Lab `
            -VM $VM `
            -Verbose
    }
}
####################################################################################################
Function Test-LabBuilderInstall {
    Get-Lab -ConfigPath $script:ConfigPath | Install-Lab -Verbose
} # Function Test-LabBuilderInstall
####################################################################################################
Function Test-LabBuilderUpdate {
    Get-Lab -ConfigPath $script:ConfigPath | Update-Lab -Verbose
} # Function Test-LabBuilderInstall
####################################################################################################
Function Test-LabBuilderStart {
    Get-Lab -ConfigPath $script:ConfigPath | Start-Lab -Verbose
} # Function Test-LabBuilderInstall
####################################################################################################
Function Test-LabBuilderStop {
    Get-Lab -ConfigPath $script:ConfigPath | Stop-Lab -Verbose
} # Function Test-LabBuilderInstall
####################################################################################################
Function Test-LabBuilderUninstall {
    Get-Lab -ConfigPath $script:ConfigPath | Uninstall-Lab `
        -RemoveVMFolder `
        -RemoveVMTemplate `
        -RemoveLabFolder `
        -RemoveSwitch `
        -Verbose
} # Function Test-LabBuilderUnnstall
####################################################################################################
Function Test-LabBuilderLoadModule {
    Import-Module $script:ModulePath -Verbose -Force
} # Function Test-LabBuilderLoadModule
####################################################################################################

# Test-LabBuilderLoadModule

# Comment/Uncomment lines below and run this script to execute the LabBuilder commands
Test-LabBuilderInstall
# Test-LabBuilderUpdate
# Test-LabBuilderStart
# Test-LabBuilderStop
# Test-StartLabVM -StartVMs 'SA-DC1'
# Test-LabBuilderUninstall
