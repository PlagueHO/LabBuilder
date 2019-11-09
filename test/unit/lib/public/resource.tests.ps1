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

    Describe 'Get-LabResourceModule' {
        Context 'When valid configuration passed with resource module missing Name.' {
            It 'Throws a ResourceModuleNameIsEmptyError Exception' {
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                $Lab.labbuilderconfig.resources.module[0].RemoveAttribute('name')
                $exceptionParameters = @{
                    errorId = 'ResourceModuleNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceModuleNameIsEmptyError)
                }
                $Exception = Get-LabException @exceptionParameters

                { Get-LabResourceModule -Lab $Lab } | Should -Throw $Exception
            }
        }

        Context 'When valid configuration is passed' {
            It 'Returns Resource Modules Array that matches Expected Array' {
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                [Array] $ResourceModules = Get-LabResourceModule -Lab $Lab
                Set-Content -Path "$script:ArtifactPath\ExpectedResourceModules.json" -Value ($ResourceModules | ConvertTo-Json -Depth 4)
                $ExpectedResourceModules = Get-Content -Path "$script:ExpectedContentPath\ExpectedResourceModules.json"
                [System.String]::Compare((Get-Content -Path "$script:ArtifactPath\ExpectedResourceModules.json"),$ExpectedResourceModules,$true) | Should -Be 0
            }
        }
    }

    Describe 'Initialize-LabResourceModule' {
        $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
        [LabResourceModule[]]$ResourceModules = Get-LabResourceModule -Lab $Lab

        Mock Invoke-LabDownloadResourceModule

        Context 'When valid configuration is passed' {
            It 'Does not throw an Exception' {
                { Initialize-LabResourceModule -Lab $Lab -ResourceModules $ResourceModules } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Invoke-LabDownloadResourceModule -Exactly 4
            }
        }
    }



    Describe 'Get-LabResourceMSU' {
        Context 'When valid configuration passed with resource MSU missing Name.' {
            It 'Throws a ResourceMSUNameIsEmptyError Exception' {
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                $Lab.labbuilderconfig.resources.msu[0].RemoveAttribute('name')
                $exceptionParameters = @{
                    errorId = 'ResourceMSUNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceMSUNameIsEmptyError)
                }
                $Exception = Get-LabException @exceptionParameters

                { Get-LabResourceMSU -Lab $Lab } | Should -Throw $Exception
            }
        }

        Context 'When valid configuration is passed' {
            It 'Returns Resource MSU Array that matches Expected Array' {
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                [Array] $ResourceMSUs = Get-LabResourceMSU -Lab $Lab
                Set-Content -Path "$script:ArtifactPath\ExpectedResourceMSUs.json" -Value ($ResourceMSUs | ConvertTo-Json -Depth 4)
                $ExpectedResourceMSUs = Get-Content -Path "$script:ExpectedContentPath\ExpectedResourceMSUs.json"
                [System.String]::Compare((Get-Content -Path "$script:ArtifactPath\ExpectedResourceMSUs.json"),$ExpectedResourceMSUs,$true) | Should -Be 0
            }
        }
    }

    Describe 'Initialize-LabResourceMSU' {
        $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
        [LabResourceMSU[]]$ResourceMSUs = Get-LabResourceMSU -Lab $Lab

        Mock Invoke-LabDownloadAndUnzipFile
        Mock Test-Path -MockWith { $false }

        Context 'When valid configuration is passed and resources are missing' {
            It 'Does not throw an Exception' {
                { Initialize-LabResourceMSU -Lab $Lab -ResourceMSUs $ResourceMSUs } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Invoke-LabDownloadAndUnzipFile -Exactly 2
            }
        }
    }

    Describe 'Get-LabResourceISO' {
        Context 'When valid configuration passed with resource ISO missing Name.' {
            It 'Throws a ResourceISONameIsEmptyError Exception' {
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                $Lab.labbuilderconfig.resources.iso[0].RemoveAttribute('name')
                $exceptionParameters = @{
                    errorId = 'ResourceISONameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceISONameIsEmptyError)
                }
                $Exception = Get-LabException @exceptionParameters

                { Get-LabResourceISO -Lab $Lab } | Should -Throw $Exception
            }
        }

        Context 'When valid configuration passed with resource ISO with Empty Path' {
            It 'Throws a ResourceISOPathIsEmptyError Exception' {
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                $Lab.labbuilderconfig.resources.iso[0].path=''
                $exceptionParameters = @{
                    errorId = 'ResourceISOPathIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceISOPathIsEmptyError `
                        -f $Lab.labbuilderconfig.resources.iso[0].name)
                }
                $Exception = Get-LabException @exceptionParameters

                { Get-LabResourceISO -Lab $Lab } | Should -Throw $Exception
            }
        }

        Context 'When valid configuration passed with resource ISO files that do exist.' {
            It 'Does not throw an Exception' {
                $Path = "$script:TestConfigPath\ISOFiles\SQLServer2014SP1-FullSlipstream-x64-ENU.iso"
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                $Lab.labbuilderconfig.resources.iso[0].RemoveAttribute('url')
                $Lab.labbuilderconfig.resources.iso[0].SetAttribute('path',"$script:TestConfigPath\ISOFiles\SQLServer2014SP1-FullSlipstream-x64-ENU.iso")
                $Lab.labbuilderconfig.resources.iso[1].RemoveAttribute('url')
                $Lab.labbuilderconfig.resources.iso[1].SetAttribute('path',"$script:TestConfigPath\ISOFiles\SQLFULL_ENU.iso")

                { Get-LabResourceISO -Lab $Lab } | Should -Not -Throw
            }
        }

        Context 'When valid configuration is passed' {
            It 'Returns Resource ISO Array that matches Expected Array' {
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                $Lab.labbuilderconfig.resources.iso[0].SetAttribute('path',"$($script:TestConfigPath)\ISOFiles\SQLServer2014SP1-FullSlipstream-x64-ENU.iso")
                $Lab.labbuilderconfig.resources.iso[1].SetAttribute('path',"$($script:TestConfigPath)\ISOFiles\SQLFULL_ENU.iso")
                [Array] $ResourceISOs = Get-LabResourceISO -Lab $Lab
                # Adjust the path to remove machine specific path
                $ResourceISOs.foreach({
                    $_.Path = $_.Path.Replace($script:TestConfigPath,'.')
                })
                Set-Content -Path "$script:ArtifactPath\ExpectedResourceISOs.json" -Value ($ResourceISOs | ConvertTo-Json -Depth 4)
                $ExpectedResourceISOs = Get-Content -Path "$script:ExpectedContentPath\ExpectedResourceISOs.json"
                [System.String]::Compare((Get-Content -Path "$script:ArtifactPath\ExpectedResourceISOs.json"),$ExpectedResourceISOs,$true) | Should -Be 0
            }
        }

        Context 'When valid configuration is passed with ISOPath set' {
            It 'Returns Resource ISO Array that matches Expected Array' {
                $Path = "$script:TestConfigPath\ISOFiles"
                $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
                $Lab.labbuilderconfig.resources.SetAttribute('isopath',$Path)
                [Array] $ResourceISOs = Get-LabResourceISO -Lab $Lab
                # Adjust the path to remove machine specific path
                $ResourceISOs.foreach({
                    $_.Path = $_.Path.Replace($script:TestConfigPath,'.')
                })
                Set-Content -Path "$script:ArtifactPath\ExpectedResourceISOs.json" -Value ($ResourceISOs | ConvertTo-Json -Depth 4)
                $ExpectedResourceISOs = Get-Content -Path "$script:ExpectedContentPath\ExpectedResourceISOs.json"
                [System.String]::Compare((Get-Content -Path "$script:ArtifactPath\ExpectedResourceISOs.json"),$ExpectedResourceISOs,$true) | Should -Be 0
            }
        }
    }

    Describe 'Initialize-LabResourceISO' {
        $Path = "$script:TestConfigPath\ISOFiles"
        $Lab = Get-Lab -ConfigPath $script:TestConfigOKPath
        $Lab.labbuilderconfig.resources.SetAttribute('isopath',$Path)
        [LabResourceISO[]]$ResourceISOs = Get-LabResourceISO -Lab $Lab

        Mock Invoke-LabDownloadAndUnzipFile

        Context 'When valid configuration is passed and all ISOs exist' {
            It 'Does not throw an Exception' {
                { Initialize-LabResourceISO -Lab $Lab -ResourceISOs $ResourceISOs } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Invoke-LabDownloadAndUnzipFile -Exactly 0
            }
        }
    }
}
