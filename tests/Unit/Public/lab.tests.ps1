[System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
[CmdletBinding()]
param ()

$projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$projectName = ((Get-ChildItem -Path $projectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName

Import-Module -Name $projectName -Force

InModuleScope $projectName {
    $testRootPath = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
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

    Describe 'Get-Lab' {
        Context 'When relative path is provided and valid XML file exists' {
            Mock Get-Location -MockWith { @{ Path = $script:testConfigPath} }

            It 'Returns XmlDocument object with valid content' {
                $Lab = Get-Lab -ConfigPath (Split-Path -Path $script:testConfigOKPath -Leaf)
                $Lab.GetType().Name | Should -Be 'XmlDocument'
                $Lab.labbuilderconfig | Should -Not -Be $null
            }
        }

        Context 'When path is provided and valid XML file exists' {
            It 'Returns XmlDocument object with valid content' {
                $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $Lab.GetType().Name | Should -Be 'XmlDocument'
                $Lab.labbuilderconfig | Should -Not -Be $null
            }
        }

        Context 'When path and LabPath are provided and valid XML file exists' {
            It 'Returns XmlDocument object with valid content' {
                $Lab = Get-Lab -ConfigPath $script:testConfigOKPath `
                    -LabPath 'c:\Pester Lab'
                $Lab.GetType().Name | Should -Be 'XmlDocument'
                $Lab.labbuilderconfig.settings.labpath | Should -Be 'c:\Pester Lab'
                $Lab.labbuilderconfig | Should -Not -Be $null
            }

            It 'Prepends Module Path to $ENV:PSModulePath' {
                $env:PSModulePath.ToLower().Contains('c:\Pester Lab\Modules'.ToLower() + ';') | Should -Be $true
            }
        }

        Context 'When path is provided but file does not exist' {
            It 'Throws ConfigurationFileNotFoundError Exception' {
                $exceptionParameters = @{
                    errorId = 'ConfigurationFileNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationFileNotFoundError `
                        -f 'c:\doesntexist.xml')
                }
                $Exception = Get-LabException @exceptionParameters

                Mock Test-Path -MockWith { $false }

                { Get-Lab -ConfigPath 'c:\doesntexist.xml' } | Should -Throw $Exception
            }
        }

        Context 'When path is provided and file exists but is empty' {
            It 'Throws ConfigurationFileEmptyError Exception' {
                $exceptionParameters = @{
                    errorId = 'ConfigurationFileEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationFileEmptyError `
                        -f 'c:\isempty.xml')
                }
                $Exception = Get-LabException @exceptionParameters

                Mock Test-Path -MockWith { $true }
                Mock Get-Content -MockWith {''}

                { Get-Lab -ConfigPath 'c:\isempty.xml' } | Should -Throw $Exception
            }
        }

        $script:currentBuild = 10000

        Context 'When path is provided and file exists but host build version requirement not met' {
            It 'Throws RequiredBuildNotMetError Exception' {
                $exceptionParameters = @{
                    errorId = 'RequiredBuildNotMetError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.RequiredBuildNotMetError `
                        -f $script:currentBuild,'10560')
                }
                $Exception = Get-LabException @exceptionParameters
                { Get-Lab -ConfigPath $script:testConfigOKPath } | Should -Throw $Exception
            }
        }
        $script:currentBuild = 10586
    }

    Describe 'New-Lab' -Tags 'Incomplete' {
    }

    Describe 'Install-Lab' -Tags 'Incomplete' {
        $Lab = Get-Lab -ConfigPath $script:testConfigOKPath

        Mock Get-VMSwitch
        Mock New-VMSwitch
        Mock Get-VMNetworkAdapter -MockWith { @{ Name = 'LabBuilder Management PesterTestConfig' } }
        Mock Get-VMNetworkAdapterVlan
        Mock Set-VMNetworkAdapterVlan

        Context 'When valid configuration is passed' {
            It 'Does not throw an Exception' {
                { Install-Lab -Lab $Lab } | Should -Not -Throw
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapterVlan -Exactly 1
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 1
            }
        }
    }

    Describe 'Update-Lab' -Tags 'Incomplete'  {
    }

    Describe 'Uninstall-Lab' -Tags 'Incomplete'  {
    }

    Describe 'Start-Lab' -Tags 'Incomplete'  {
    }

    Describe 'Stop-Lab' -Tags 'Incomplete'  {
    }
}
