##########################################################################################################################################
Function Test-LabBuilderInstall {
	Install-Lab -Path "$PSScriptRoot\TestConfigDCandDHCPOnly.xml" -Verbose
} # Function Test-LabBuilderInstall
##########################################################################################################################################
Function Test-LabBuilderUninstall {
	Uninstall-Lab -Path "$PSScriptRoot\TestConfigDCandDHCPOnly.xml" -Verbose -RemoveVHDs -RemoveTemplates
} # Function Test-LabBuilderUnnstall
##########################################################################################################################################
Function Test-LabBuilderLoadModule {
	Import-Module "$PSScriptRoot\..\LabBuilder" -Verbose -Force
} # Function Test-LabBuilderLoadModule
##########################################################################################################################################
Test-LabBuilderLoadModule
Test-LabBuilderInstall
# Sleep 30 # Wait 30 seconds for everything to finish building
# Test-LabBuilderUninstall
