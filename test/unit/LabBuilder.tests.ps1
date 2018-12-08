$Global:ModuleRoot = Resolve-Path -Path "$($Script:MyInvocation.MyCommand.Path)..\..\..\..\"
$OldPSModulePath = $env:PSModulePath
Push-Location
try
{
    Set-Location -Path $ModuleRoot
    if (Get-Module LabBuilder -All)
    {
        Get-Module LabBuilder -All | Remove-Module
    }

    Import-Module (Join-Path -Path $Global:ModuleRoot -ChildPath 'src\LabBuilder.psd1') `
        -Force `
        -DisableNameChecking
    $Global:TestConfigPath = Join-Path `
        -Path $Global:ModuleRoot `
        -ChildPath 'test\pestertestconfig'
    $Global:TestConfigOKPath = Join-Path `
        -Path $Global:TestConfigPath `
        -ChildPath 'PesterTestConfig.OK.xml'
    $Global:ArtifactPath = Join-Path `
        -Path $Global:ModuleRoot `
        -ChildPath 'test\artifacts'
    $Global:ExpectedContentPath = Join-Path `
        -Path $Global:TestConfigPath `
        -ChildPath 'expectedcontent'
    $null = New-Item `
        -Path $Global:ArtifactPath `
        -ItemType Directory `
        -Force `
        -ErrorAction SilentlyContinue

    # Perform PS Script Analyzer tests on module code only
    $null = Set-PackageSource -Name PSGallery -Trusted -Force
    $null = Install-Module -Name 'PSScriptAnalyzer' -Confirm:$false
    Import-Module -Name 'PSScriptAnalyzer'

    Describe 'PSScriptAnalyzer' {
        Context 'LabBuilder Module code and Lib Functions' {
            It 'Passes Invoke-ScriptAnalyzer' {
                # Perform PSScriptAnalyzer scan.
                $PSScriptAnalyzerResult = Invoke-ScriptAnalyzer `
                    -path "$ModuleRoot\src\LabBuilder.psm1" `
                    -Severity Warning `
                    -ErrorAction SilentlyContinue
                $PSScriptAnalyzerResult += Invoke-ScriptAnalyzer `
                    -path "$ModuleRoot\src\lib\public\*.ps1" `
                    -excluderule "PSAvoidUsingUserNameAndPassWordParams" `
                    -Severity Warning `
                    -ErrorAction SilentlyContinue
                $PSScriptAnalyzerResult += Invoke-ScriptAnalyzer `
                    -path "$ModuleRoot\src\lib\private\*.ps1" `
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

    InModuleScope LabBuilder {
    <#
    .SYNOPSIS
    Helper function that just creates an exception record for testing.
    #>
        function Get-LabException
        {
            [CmdLetBinding()]
            param
            (
                [Parameter(Mandatory = $true)]
                [System.String] $errorId,

                [Parameter(Mandatory = $true)]
                [System.Management.Automation.ErrorCategory] $errorCategory,

                [Parameter(Mandatory = $true)]
                [System.String] $errorMessage,

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
        Describe 'Validate XML schema of lab test files' {
            Context 'PesterTestConfig.OK.XML' {
                It 'Does not throw an exception' {
                    { Assert-ValidConfigurationXMLSchema -ConfigPath $Global:TestConfigOKPath -Verbose } | Should -Not -Throw
                }
            }
        }

        Describe 'Validate XML schema of lab sample files' {
            $SampleFiles = Get-ChildItem -Path (Join-Path -Path $Global:ModuleRoot -ChildPath "Samples") -Recurse -Filter 'Sample_*.xml'

            foreach ($SampleFile in $SampleFiles)
            {
                Context "Samples\$SampleFile" {
                    It 'Does not throw an exception' {
                        { Assert-ValidConfigurationXMLSchema -ConfigPath $($SampleFile.Fullname) -Verbose } | Should -Not -Throw
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
    $env:PSModulePath = $OldPSModulePath
}
