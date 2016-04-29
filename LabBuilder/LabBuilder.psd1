@{
    RootModule = 'LabBuilder.psm1'
    ModuleVersion = '0.7.7'
    GUID = 'e229850e-7a90-4123-9a30-37814119d3a3'
    Author = 'Daniel Scott-Raynsford'
    CompanyName = ''
    Copyright = '(c) 2016 Daniel Scott-Raynsford. All rights reserved.'
    Description = 'Builds Hyper-V Windows Labs out of text based configuration files'
    PowerShellVersion = '5.0'
    ProcessorArchitecture = 'None'
    # RequiredModules = @()
    RequiredAssemblies = @()
    ScriptsToProcess = @()
    TypesToProcess = @()
    FormatsToProcess = @()
    # NestedModules = @()
    FunctionsToExport = @(
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
    # CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    # DscResourcesToExport = @()
    # ModuleList = @()
    FileList = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Hyper-V','Lab','DesiredStateConfiguration','DSC')
            # LicenseUri = https://github.com/PlagueHO/LabBuilder/blob/master/LICENSE
            ProjectUri = 'https://github.com/PlagueHO/LabBuilder'
            # IconUri = ''
            # ReleaseNotes = ''
            # ExternalModuleDependencies = ''
        } # End of PSData hashtable
    } # End of PrivateData hashtable
    HelpInfoURI = 'https://github.com/PlagueHO/LabBuilder/blob/master/README.md'
    # DefaultCommandPrefix = ''
}

