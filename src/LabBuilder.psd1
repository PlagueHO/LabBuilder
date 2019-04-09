@{
    # Script module or binary module file associated with this manifest.
    RootModule            = 'LabBuilder.psm1'

    # Version number of this module.
    ModuleVersion         = '1.0.1.6'

    # Supported PSEditions
    CompatiblePSEditions  = 'Desktop'

    # ID used to uniquely identify this module
    GUID                  = 'e229850e-7a90-4123-9a30-37814119d3a3'

    # Author of this module
    Author                = 'Daniel Scott-Raynsford'

    # Company or vendor of this module
    CompanyName           = 'None'

    # Copyright statement for this module
    Copyright             = '(c) 2018 Daniel Scott-Raynsford. All rights reserved.'

    # Description of the functionality provided by this module
    Description           = 'Builds Hyper-V Windows Labs out of text based configuration files'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion     = '5.1'

    # Name of the Windows PowerShell host required by this module
    ProcessorArchitecture = 'None'

    # Minimum version of the Windows PowerShell host required by this module
    # RequiredModules = @()

    # Modules that must be imported into the global environment prior to importing this module
    RequiredAssemblies    = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess      = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess        = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess      = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport     = @(
        'Get-LabResourceModule'
        'Initialize-LabResourceModule'
        'Get-LabResourceMSU'
        'Initialize-LabResourceMSU'
        'Get-LabResourceISO'
        'Initialize-LabResourceISO'
        'Get-LabSwitch'
        'Initialize-LabSwitch'
        'Remove-LabSwitch'
        'Get-LabVMTemplateVHD'
        'Initialize-LabVMTemplateVHD'
        'Remove-LabVMTemplateVHD'
        'Get-LabVMTemplate'
        'Initialize-LabVMTemplate'
        'Remove-LabVMTemplate'
        'Get-LabVM'
        'Initialize-LabVM'
        'Install-LabVM'
        'Remove-LabVM'
        'Get-Lab'
        'New-Lab'
        'Install-Lab'
        'Update-Lab'
        'Uninstall-Lab'
        'Start-Lab'
        'Stop-Lab'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    # CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport     = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport       = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    FileList              = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData           = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @('Hyper-V', 'Lab', 'DesiredStateConfiguration', 'DSC', 'PSEdition_Desktop')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/PlagueHO/LabBuilder/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/PlagueHO/LabBuilder'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = '
## What is New in LabBuilder Ureleased

April 8, 2019

- Update to use NetworkingDsc 7.0.0.0 and converted DhcpClient
    resource to NetIpInterface - fixes [Issue #304](https://github.com/PlagueHO/LabBuilder/issues/304).
- Refactored module manifest generation process to be more reliable
    and robust.
- Convert module name to be a variable in PSake file to make it more
    easily portable between projects.
- Added samples for Windows Server 2019 - fixes [Issue #305](https://github.com/PlagueHO/LabBuilder/issues/305).
- Cleaned up unit test initialization and fixtures.
- Refactored `Install-Lab` to move Management Switch creation into a
    new function `Initialize-LabManagementSwitch` and created unit tests.
- Added more log information to `SetupComplete.cmd` to diagnose issues
    with initial machine boot on Windows Server 2019.
- Fix bug in `Remove-LabSwitch` where adapter
- Correct documentation markdown errors.
- Removed `Timeout 30` from the Initial `SetupComplete.cmd` that runs
    on each VM when first intialized because it fails to execute on
    Windows Server 2019. Replaced with `Start-Sleep` in `SetupComplete.ps1`
    that is called by `SetupComplete.cmd` - fixes [Issue #308](https://github.com/PlagueHO/LabBuilder/issues/308).
- Change `Update-LabDSC` so that module copy process to Lab Files will
    continue even if destination path is too long. This is to allow DSC
    Resource modules that have example filenames that result in a long
    path.
- Update CI module dependencies in `Requirements.psd1` to latest version:
    - PSScriptAnalyzer: 1.18.0
    - PSDeploy: 1.0.1
    - Platyps: 0.14.0
- Split Private Lib functions into individual .ps1 files.
- Refactored Private Lib functions to improve code style standards.

## What is New in LabBuilder 1.0.0.6

December 8, 2018

- Samples\Sample_WS2016_DCandDHCPandCA.xml: Added to easily create a Windows
  Server 2016 domain with a enterprise root CA.
- Correct certificate authority DSC Resources with ADCSCertificationAuthority
  to be IsSingleInstance.
- Convert xNetworking to NetworkingDsc.
- Converted repository structure and build pipeline to more modern standards.
- Enabled Azure DevOps build pipeline.
- Convert module to require WMF 5.1 and all the samples to install WMF 5.1.
- DSCLibrary\MEMBER_MEMBER_DHCP*.ps1: Fixed to support xDHCPServer 2.0.0.0.
'
            # ExternalModuleDependencies = ''
        } # End of PSData hashtable
    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    HelpInfoURI           = 'https://github.com/PlagueHO/LabBuilder/blob/master/README.md'

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}

