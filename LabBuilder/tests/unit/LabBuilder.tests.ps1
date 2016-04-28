$Global:ModuleRoot = Resolve-Path -Path "$($Script:MyInvocation.MyCommand.Path)..\..\..\..\"

Push-Location
try
{
    Set-Location -Path $ModuleRoot
    if (Get-Module LabBuilder -All)
    {
        Get-Module LabBuilder -All | Remove-Module
    }

    Import-Module (Join-Path -Path $Global:ModuleRoot -ChildPath 'LabBuilder.psd1') `
        -Force `
        -DisableNameChecking
    $Global:TestConfigPath = Join-Path `
        -Path $Global:ModuleRoot `
        -ChildPath 'Tests\PesterTestConfig'
    $Global:TestConfigOKPath = Join-Path `
        -Path $Global:TestConfigPath `
        -ChildPath 'PesterTestConfig.OK.xml'
    $Global:ArtifactPath = Join-Path `
        -Path $Global:ModuleRoot `
        -ChildPath 'Artifacts'
    $Global:ExpectedContentPath = Join-Path `
        -Path $Global:TestConfigPath `
        -ChildPath 'ExpectedContent'
    $null = New-Item `
        -Path $Global:ArtifactPath `
        -ItemType Directory `
        -Force `
        -ErrorAction SilentlyContinue

    # Perform PS Script Analyzer tests on module code only
    $null = Set-PackageSource -Name PSGallery -Trusted -Force
    $null = Install-Module -Name 'PSScriptAnalyzer' -Confirm:$False
    Import-Module -Name 'PSScriptAnalyzer'

    Describe 'PSScriptAnalyzer' {
        Context 'LabBuilder Module code and Lib Functions' {
            It 'Passes Invoke-ScriptAnalyzer' {
                # Perform PSScriptAnalyzer scan.
                $PSScriptAnalyzerResult = Invoke-ScriptAnalyzer `
                    -path "$ModuleRoot\LabBuilder.psm1" `
                    -Severity Warning `
                    -ErrorAction SilentlyContinue
                $PSScriptAnalyzerResult += Invoke-ScriptAnalyzer `
                    -path "$ModuleRoot\Lib\Public\*.ps1" `
                    -excluderule "PSAvoidUsingUserNameAndPassWordParams" `
                    -Severity Warning `
                    -ErrorAction SilentlyContinue
                $PSScriptAnalyzerResult += Invoke-ScriptAnalyzer `
                    -path "$ModuleRoot\Lib\Private\*.ps1" `
                    -excluderule "PSAvoidUsingUserNameAndPassWordParams" `
                    -Severity Warning `
                    -ErrorAction SilentlyContinue
                $PSScriptAnalyzerErrors = $PSScriptAnalyzerResult | Where-Object { $_.Severity -eq 'Error' }
                $PSScriptAnalyzerWarnings = $PSScriptAnalyzerResult | Where-Object { $_.Severity -eq 'Warning' }
                if ($PSScriptAnalyzerErrors -ne $null)
                {
                    Write-Warning -Message 'There are PSScriptAnalyzer errors that need to be fixed:'
                    @($PSScriptAnalyzerErrors).Foreach( { Write-Warning -Message "$($_.Scriptname) (Line $($_.Line)): $($_.Message)" } )
                    Write-Warning -Message  'For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/psscriptAnalyzer/'
                    $PSScriptAnalyzerErrors.Count | Should Be $null
                }
                if ($PSScriptAnalyzerWarnings -ne $null)
                {
                    Write-Warning -Message 'There are PSScriptAnalyzer warnings that should be fixed:'
                    @($PSScriptAnalyzerWarnings).Foreach( { Write-Warning -Message "$($_.Scriptname) (Line $($_.Line)): $($_.Message)" } )
                }
            }
        }
    }

    InModuleScope LabBuilder {
    <#
    .SYNOPSIS
    Helper function that just creates an exception record for testing.
    #>
        function GetException
        {
            [CmdLetBinding()]
            param
            (
                [Parameter(Mandatory)]
                [String] $errorId,

                [Parameter(Mandatory)]
                [System.Management.Automation.ErrorCategory] $errorCategory,

                [Parameter(Mandatory)]
                [String] $errorMessage,
                
                [Switch]
                $terminate
            )

            $exception = New-Object -TypeName System.Exception `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null
            return $errorRecord
        }

        # Run tests assuming Build 10586 is installed
        $Script:CurrentBuild = 10586


        # Perform Configuration XML Schema validation
        Describe 'XMLConfigurationSchemaValidation' {
            Context 'PesterTestConfig.OK.XML' {
                It 'Does not throw an exception' {
                    { ValidateConfigurationXMLSchema -ConfigPath $Global:TestConfigOKPath -Verbose } | Should Not Throw
                }
            }
            $SampleFiles = Get-ChildItem -Path (Join-Path -Path $Global:ModuleRoot -ChildPath "Samples") -Recurse -Filter 'Sample_*.xml'
            foreach ($SampleFile in $SampleFiles)
            {
                Context "Samples\$SampleFile" {
                    It 'Does not throw an exception' {
                        { ValidateConfigurationXMLSchema -ConfigPath $($SampleFile.Fullname) -Verbose } | Should Not Throw
                    }
                }
            }
        }
    }
}
catch
{
    throw $_
}
finally
{
    Pop-Location
}
