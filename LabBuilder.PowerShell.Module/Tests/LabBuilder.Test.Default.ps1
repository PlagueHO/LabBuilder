##########################################################################################################################################
Function Test-LabBuilderInstall {
	Install-Lab -Path "$PSScriptRoot\TestConfig1.xml" -Verbose
} # Function Test-LabBuilderInstall
##########################################################################################################################################
Function Test-LabBuilderLoadModule {
	Get-Module | Where-Object -Property Name -Eq LabBuilder | Remove-Module
	Import-Module "$PSScriptRoot\..\LabBuilder" -Verbose
} # Function Test-LabBuilderLoadModule
##########################################################################################################################################
Test-LabBuilderLoadModule
Test-LabBuilderInstall
