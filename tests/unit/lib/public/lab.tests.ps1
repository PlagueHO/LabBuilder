$global:LabBuilderProjectRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent

if (Get-Module -Name LabBuilder -All)
{
    Get-Module -Name LabBuilder -All | Remove-Module
}

Import-Module -Name (Join-Path -Path $global:LabBuilderProjectRoot -ChildPath 'src\LabBuilder.psd1') `
    -Force `
    -DisableNameChecking `
    -Verbose:$false
Import-Module -Name (Join-Path -Path $global:LabBuilderProjectRoot -ChildPath 'test\testhelper\testhelper.psm1') `
    -Global

InModuleScope LabBuilder {
    # Run tests assuming Build 10586 is installed
    $script:CurrentBuild = 10586

    $script:TestConfigPath = Join-Path `
        -Path $global:LabBuilderProjectRoot `
        -ChildPath 'test\pestertestconfig'
    $script:TestConfigOKPath = Join-Path `
        -Path $script:TestConfigPath `
        -ChildPath 'PesterTestConfig.OK.xml'
    $script:ArtifactPath = Join-Path `
        -Path $global:LabBuilderProjectRoot `
        -ChildPath 'test\artifacts'
    $script:ExpectedContentPath = Join-Path `
        -Path $script:TestConfigPath `
        -ChildPath 'expectedcontent'
    $null = New-Item `
        -Path $script:ArtifactPath `
        -ItemType Directory `
        -Force `
        -ErrorAction SilentlyContinue

    Describe 'Get-Lab' {
        Context 'When relative path is provided and valid XML file exists' {
            Mock Get-Location -MockWith { @{ Path = $script:TestConfigPath} }

            It 'Returns XmlDocument object with valid content' {
                $Lab = Get-Lab -ConfigPath (Split-Path -Path $script:TestConfigOKPath -Leaf)
                $Lab.GetType().Name | Should -Be 'XmlDocument'
                $Lab.labbuilderconfig | Should -Not -Be $null
            }
        }

        Context 'When path is provided and valid XML file exists' {
            It 'Returns XmlDocument object with valid content' {
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                $Lab.GetType().Name | Should -Be 'XmlDocument'
                $Lab.labbuilderconfig | Should -Not -Be $null
            }
        }

        Context 'When path and LabPath are provided and valid XML file exists' {
            It 'Returns XmlDocument object with valid content' {
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath `
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

        $Script:CurrentBuild = 10000

        Context 'When path is provided and file exists but host build version requirement not met' {
            It 'Throws RequiredBuildNotMetError Exception' {
                $exceptionParameters = @{
                    errorId = 'RequiredBuildNotMetError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.RequiredBuildNotMetError `
                        -f $Script:CurrentBuild,'10560')
                }
                $Exception = Get-LabException @exceptionParameters
                { Get-Lab -ConfigPath $script:TestConfigOKPath } | Should -Throw $Exception
            }
        }
        $Script:CurrentBuild = 10586
    }

    Describe 'New-Lab' -Tags 'Incomplete' {
    }

    Describe 'Install-Lab' -Tags 'Incomplete' {
        $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath

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
