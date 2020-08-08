@{

    # Script module or binary module file associated with this manifest.
    RootModule            = 'LabBuilder.psm1'

    # Version number of this module.
    ModuleVersion         = '0.0.1'

    # Supported PSEditions
    CompatiblePSEditions  = 'Desktop'

    # ID used to uniquely identify this module
    GUID                  = 'e229850e-7a90-4123-9a30-37814119d3a3'

    # Author of this module
    Author                = 'Daniel Scott-Raynsford'

    # Company or vendor of this module
    CompanyName           = 'None'

    # Copyright statement for this module
    Copyright             = '(c) Daniel Scott-Raynsford. All rights reserved.'

    # Description of the functionality provided by this module
    Description           = 'Builds Hyper-V Windows multi-machine/Active Directory labs using XML configuration files and DSC Resources.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion     = '5.1'

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
    FunctionsToExport     = @('Get-LabResourceModule', 'Initialize-LabResourceModule',
        'Get-LabResourceMSU', 'Initialize-LabResourceMSU',
        'Get-LabResourceISO', 'Initialize-LabResourceISO', 'Get-LabSwitch',
        'Initialize-LabSwitch', 'Remove-LabSwitch', 'Get-LabVMTemplateVHD',
        'Initialize-LabVMTemplateVHD', 'Remove-LabVMTemplateVHD',
        'Get-LabVMTemplate', 'Initialize-LabVMTemplate',
        'Remove-LabVMTemplate', 'Get-LabVM', 'Initialize-LabVM',
        'Install-LabVM', 'Remove-LabVM', 'Get-Lab', 'New-Lab', 'Install-Lab',
        'Update-Lab', 'Uninstall-Lab', 'Start-Lab', 'Stop-Lab')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport       = '*'

    # Variables to export from this module
    VariablesToExport     = '*'

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
            Tags         = @('Hyper-V', 'Lab', 'DesiredStateConfiguration', 'DSC', 'PSEdition_Desktop')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/PlagueHO/LabBuilder/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/PlagueHO/LabBuilder'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = ''

            Prerelease   = ''
        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI           = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
