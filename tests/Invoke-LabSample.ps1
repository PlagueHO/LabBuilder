# Load the LabBuilder Module after being built by .\build.ps1 -Tasks Build
$projectPath = "$PSScriptRoot\.." | Convert-Path

Import-Module -Name LabBuilder -Force

# Set the name of the sample Lab from the samples folder:
$sampleConfigName = 'Sample_WS2019_AzureADConnect.xml'
$samplePath = "$projectPath\source\Samples\"
$configPath = Join-Path -Path $samplePath -ChildPath $sampleConfigName
$labParameters = @{
    ConfigPath = $configPath
}

####################################################################################################
function Test-StartLabVM {
    param (
        [System.String[]]
        $StartVMs
    )

    $Lab = Get-Lab -Config $script:ConfigPath
    $VMs = Get-LabVM `
        -Lab $Lab `
        -Name $StartVMs
    foreach ($VM in $VMs) {
        Install-LabVM `
            -Lab $Lab `
            -VM $VM `
            -Verbose
    }
}

####################################################################################################
function Test-LabBuilderInstall {
    param (
        [System.String]
        $ConfigPath
    )

    Get-Lab -ConfigPath $ConfigPath | Install-Lab -Verbose
} # Function Test-LabBuilderInstall

####################################################################################################
Function Test-LabBuilderUpdate {
    param (
        [System.String]
        $ConfigPath
    )

    Get-Lab -ConfigPath $ConfigPath | Update-Lab -Verbose
} # Function Test-LabBuilderInstall

####################################################################################################
Function Test-LabBuilderStart {
    param (
        [System.String]
        $ConfigPath
    )

    Get-Lab -ConfigPath $ConfigPath | Start-Lab -Verbose
} # Function Test-LabBuilderInstall

####################################################################################################
Function Test-LabBuilderStop {
    param (
        [System.String]
        $ConfigPath
    )

    Get-Lab -ConfigPath $ConfigPath | Stop-Lab -Verbose
} # Function Test-LabBuilderInstall

####################################################################################################
Function Test-LabBuilderUninstall {
    param (
        [System.String]
        $ConfigPath
    )

    Get-Lab -ConfigPath $ConfigPath | Uninstall-Lab `
        -RemoveVMFolder `
        -RemoveVMTemplate `
        -RemoveLabFolder `
        -RemoveSwitch `
        -Verbose
} # Function Test-LabBuilderUnnstall
####################################################################################################

# Comment/Uncomment lines below and run this script to execute the LabBuilder commands
Test-LabBuilderInstall @LabParameters
# Test-LabBuilderUpdate @LabParameters
# Test-LabBuilderStart @LabParameters
# Test-LabBuilderStop @LabParameters
# Test-StartLabVM @LabParameters -StartVMs 'SA-DC1'
# Test-LabBuilderUninstall @LabParameters
