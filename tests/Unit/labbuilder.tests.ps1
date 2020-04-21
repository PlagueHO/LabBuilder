[System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
[CmdletBinding()]
param ()

$projectPath = "$PSScriptRoot\..\.." | Convert-Path
$projectName = ((Get-ChildItem -Path $projectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName

Import-Module -Name $projectName -Force

InModuleScope $projectName {
    $testRootPath = $PSScriptRoot | Split-Path -Parent
    $testHelperPath = $testRootPath | Join-Path -ChildPath 'TestHelper'
    Import-Module -Name $testHelperPath -Force

    # Run tests assuming Build 10586 is installed
    $script:currentBuild = 10586

    $script:testConfigPath = Join-Path `
        -Path $testRootPath `
        -ChildPath 'pestertestconfig'
    $script:testConfigOKPath = Join-Path `
        -Path $script:testConfigPath `
        -ChildPath 'PesterTestConfig.OK.xml'
    $script:artifactPath = Join-Path `
        -Path $testRootPath `
        -ChildPath 'artifacts'
    $script:expectedContentPath = Join-Path `
        -Path $script:testConfigPath `
        -ChildPath 'expectedcontent'
    $null = New-Item `
        -Path $script:artifactPath `
        -ItemType Directory `
        -Force `
        -ErrorAction SilentlyContinue
    $script:Lab = Get-Lab -ConfigPath $script:testConfigOKPath

    Import-Module -Name 'PSScriptAnalyzer'

    Describe 'PSScriptAnalyzer' {
        Context 'LabBuilder Module code and Lib Functions' {
            It 'Passes Invoke-ScriptAnalyzer' {
                # Perform PSScriptAnalyzer scan.
                $PSScriptAnalyzerResult = Invoke-ScriptAnalyzer `
                    -Path ((Get-Module -Name LabBuilder).Path) `
                    -Severity Warning `
                    -ErrorAction SilentlyContinue
                $PSScriptAnalyzerErrors = $PSScriptAnalyzerResult | Where-Object { $_.Severity -eq 'Error' }
                $PSScriptAnalyzerWarnings = $PSScriptAnalyzerResult | Where-Object { $_.Severity -eq 'Warning' }

                if ($PSScriptAnalyzerErrors -ne $null)
                {
                    Write-Warning -Message 'There are PSScriptAnalyzer errors that need to be fixed:'
                    @($PSScriptAnalyzerErrors).Foreach( { Write-Warning -Message "$($_.Scriptname) (Line $($_.Line)): $($_.Message)" } )
                    Write-Warning -Message  'For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/psscriptAnalyzer/'
                    $PSScriptAnalyzerErrors.Count | Should -Be $null
                }

                if ($PSScriptAnalyzerWarnings -ne $null)
                {
                    Write-Warning -Message 'There are PSScriptAnalyzer warnings that should be fixed:'
                    @($PSScriptAnalyzerWarnings).Foreach( { Write-Warning -Message "$($_.Scriptname) (Line $($_.Line)): $($_.Message)" } )
                }
            }
        }
    }

    # Perform Configuration XML Schema validation
    Describe 'Validate XML schema of lab test files' {
        Context 'When validing lab test file PesterTestConfig.OK.xml' {
            It 'Should not throw an exception' {
                { Assert-LabValidConfigurationXMLSchema -ConfigPath $script:TestConfigOKPath -Verbose } | Should -Not -Throw
            }
        }
    }

    Describe 'Validate XML schema of lab sample files' {
        $samplesFolder = Split-Path -Path ((Get-Module -Name LabBuilder).Path) -Parent | Join-Path -ChildPath 'Samples'
        $sampleFiles = Get-ChildItem -Path $samplesFolder -Recurse -Filter 'Sample_*.xml'

        foreach ($SampleFile in $SampleFiles)
        {
            Context "When validating sample '$SampleFile'" {
                It 'Should not throw an exception' {
                    { Assert-LabValidConfigurationXMLSchema -ConfigPath $($SampleFile.Fullname) -Verbose } | Should -Not -Throw
                }
            }
        }
    }
}
