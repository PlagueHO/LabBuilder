@{
    PSDependOptions     = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
        }
    }

    InvokeBuild         = 'latest'
    PSScriptAnalyzer    = 'latest'
    Pester              = '4.10.1'
    Plaster             = 'latest'
    Platyps             = 'latest'
    ModuleBuilder       = 'latest'
    ChangelogManagement = 'latest'
    Sampler             = 'latest'
    MarkdownLinkCheck   = 'latest'
}
