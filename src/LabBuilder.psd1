#
# Module manifest for module 'LabBuilder'
#
# Generated by: Daniel Scott-Raynsford
#
# Generated on: 9/27/2019
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'LabBuilder.psm1'

# Version number of this module.
ModuleVersion = '1.0.5.83'

# Supported PSEditions
CompatiblePSEditions = 'Desktop'

# ID used to uniquely identify this module
GUID = 'e229850e-7a90-4123-9a30-37814119d3a3'

# Author of this module
Author = 'Daniel Scott-Raynsford'

# Company or vendor of this module
CompanyName = 'None'

# Copyright statement for this module
Copyright = '(c) 2019 Daniel Scott-Raynsford. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Builds Hyper-V Windows multi-machine/Active Directory labs using XML configuration files and DSC Resources.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
ProcessorArchitecture = 'None'

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Get-LabResourceModule', 'Initialize-LabResourceModule',
               'Get-LabResourceMSU', 'Initialize-LabResourceMSU',
               'Get-LabResourceISO', 'Initialize-LabResourceISO', 'Get-LabSwitch',
               'Initialize-LabSwitch', 'Remove-LabSwitch', 'Get-LabVMTemplateVHD',
               'Initialize-LabVMTemplateVHD', 'Remove-LabVMTemplateVHD',
               'Get-LabVMTemplate', 'Initialize-LabVMTemplate',
               'Remove-LabVMTemplate', 'Get-LabVM', 'Initialize-LabVM',
               'Install-LabVM', 'Remove-LabVM', 'Get-Lab', 'New-Lab', 'Install-Lab',
               'Update-Lab', 'Uninstall-Lab', 'Start-Lab', 'Stop-Lab'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'Hyper-V', 'Lab', 'DesiredStateConfiguration', 'DSC', 'PSEdition_Desktop'

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PlagueHO/LabBuilder/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PlagueHO/LabBuilder'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '
## What is New In LabBuilder Unreleased

- Samples\Sample_WS2019_AzureADConnect.xml: Added sample for installing Azure AD
  Connect.
- Convert all DSC configurations to use ActiveDirectoryDsc version
  4.1.0.0.
- `dsclibrary\RODC_SECONDARY.DSC.ps1`:
  - Enable RODC creation because it is supported by ActiveDirectoryDsc.
- `dsclibrary\DC_FORESTPRIMARY.DSC.ps1`:
  - Enabled customizing of Domain NetBios name.
- `Get-LabVm.ps1`:
  - Clean up code style.
- `Enable-LabWSMan.ps1`:
  - Improved function so that if WinRM Service is stopped it will be started.
- `Get-Lab.ps1`:
  - Clean up code style.
  - Fix bug reading `configpath` from `settings` node.
  - Changed to use `ConvertTo-LabAbsolutePath.ps1` to simplify code.
  - Changed to automatically use the `DSCLibrary` folder that comes as part of
    the LabBuilder module if the `dsclibrarypath` setting is not specified
    in the lab configuration - fixes [Issue-335](https://github.com/PlagueHO/LabBuilder/issues/335).
- `ConvertTo-LabAbsolutePath.ps1`:
  - Added function to create an absolute path from a relative lab path.
- Removed `dsclibrarypath` setting from all samples as it is no longer required.
- `Get-LabResourceISO.ps1`:
  - Clean up code style.

## What is New in LabBuilder 1.0.4.83

- `Get-LabUnattendFileContent.ps1`:
- Enabled PSRemoting in Unattend.xml (allows DSC to initialize properly on
   newer operating systems).
- Enabled local administrator account for Client operating systems
  (Windows 10).
- Enabled PowerShell script execution for both 32-bit and 64-bit processes.
- `Connect-LabVM.ps1`:
- Test WinRM connectivity prior to initializing DSC.
- `Install-LabVM.ps1`:
  - Check for DSC Configuration section in XML file prior to calling DSC.

July 21, 2019

- `dsclibrary\MEMBER_SUBCA.DSC.ps1`:
  - CAServer parameter removed from ADCSWebEnrollment - fixes [Issue-320](https://github.com/PlagueHO/LabBuilder/issues/320).
  - Fix error occuring when `c:\windows\setup\scripts\` folder does not exist when
    setting the advanced CA configuration settings - fixes [Issue-325](https://github.com/PlagueHO/LabBuilder/issues/325).
- `dsclibrary\MEMBER_ROOTCA.DSC.ps1`:
  - CAServer parameter removed from ADCSWebEnrollment - fixes [Issue-320](https://github.com/PlagueHO/LabBuilder/issues/320).
  - Change `DiscreteSignatureAlgorithm` to `AlternateSignatureAlgorithm` and set
    it to 0 - fixes [Issue-322](https://github.com/PlagueHO/LabBuilder/issues/322).
  - Fix error occuring when `c:\windows\setup\scripts\` folder does not exist when
    setting the advanced CA configuration settings - fixes [Issue-325](https://github.com/PlagueHO/LabBuilder/issues/325).
  - Changed CApolicy.inf RenewalKeyLength to 4096, CNGHashAlgorithm to SHA256 and
    LoadDefaultTemplates to 0 - fixes [Issue-324](https://github.com/PlagueHO/LabBuilder/issues/324).
- `dsclibrary\STANDALONE_ROOTCA.DSC.ps1`:
  - Correct SubCA resource name to wait for - fixes [Issue-321](https://github.com/PlagueHO/LabBuilder/issues/321).
  - Change `DiscreteSignatureAlgorithm` to `AlternateSignatureAlgorithm` and set
    it to 0 - fixes [Issue-322](https://github.com/PlagueHO/LabBuilder/issues/322).
  - Fix error occuring when `c:\windows\setup\scripts\` folder does not exist when
    setting the advanced CA configuration settings - fixes [Issue-325](https://github.com/PlagueHO/LabBuilder/issues/325).
- `dsclibrary\STANDALONE_ROOTCA_NOSUBCA.DSC.ps1`:
  - Change `DiscreteSignatureAlgorithm` to `AlternateSignatureAlgorithm` and set
    it to 0 - fixes [Issue-322](https://github.com/PlagueHO/LabBuilder/issues/322).
  - Fix error occuring when `c:\windows\setup\scripts\` folder does not exist when
    setting the advanced CA configuration settings - fixes [Issue-325](https://github.com/PlagueHO/LabBuilder/issues/325).
- Added `.markdownlint.json` file.
- Fix markdown rule violations in `CHANGELOG.MD`.
- `dsclibrary\MEMBER_FAILOVERCLUSTER_DHCP.DSC.ps1`:
  - Fix DHCP scope to work with newer version of xDhcpServerScope DSC resource.
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\STANDALONE_DHCPDNS.DSC.DSC.ps1`:
  - Fix DHCP scope to work with newer version of xDhcpServerScope DSC resource.
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\STANDALONE_INTERNET.DSC.DSC.ps1`:
  - Fix DHCP scope to work with newer version of xDhcpServerScope DSC resource.
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCPDNS.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCPNPAS2016.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_NPS_DFSTEST.ps1`:
  - Fix to use correct name of the DFSReplicationGroup resource.
- `dsclibrary\MEMBER_WDS.DSC.ps1`:
  - Fix configuration.

## What is New in LabBuilder 1.0.2.58

May 5, 2019

- Reword module description in Manifest.
- Fix bug when connecting to a Lab VM when TrustedHosts is empty - fixes
    [Issue #314](https://github.com/PlagueHO/LabBuilder/issues/314).
- Moved Schema documentation file into docs folder and converted to
    PlatyPS compatible file.
- Cleaned up Schema documentation file to remove most markdown rule
    violations.
- Cleaned up README.MD file to remove most markdown rule
    violations.
- Fix infinite loop bug occuring in `Stop-Lab` when Lab VM does not
  exist - fixes [Issue #316](https://github.com/PlagueHO/LabBuilder/issues/316).
- Fix infinite loop bug occuring in `Start-Lab` when Lab VM does not
  exist.
- DSCLibrary\MEMBER_NANO.DSC.ps1: Rename xOfflineDomainJoin to
  OfflineDomainJoin - fixes [Issue #317](https://github.com/PlagueHO/LabBuilder/issues/317).
'

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'https://github.com/PlagueHO/LabBuilder/blob/master/README.md'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}


