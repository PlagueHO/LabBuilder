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

    Describe 'Get-LabModulesInDSCConfig' {
        Context 'When Called with Test DSC Resource File' {
            It 'Returns DSCModules Object that matches Expected Object' {
                $dscModules = Get-LabModulesInDSCConfig `
                    -DSCConfigFile (Join-Path -Path $script:testConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') `
                    -Verbose

                Set-Content `
                    -Path "$script:artifactPath\ExpectedDSCModules.json" `
                    -Value ($dscModules | ConvertTo-Json -Depth 4)

                $expectedDSCModules = Get-Content -Path "$script:expectedContentPath\ExpectedDSCModules.json"
                [System.String]::Compare((Get-Content -Path "$script:artifactPath\ExpectedDSCModules.json"), $expectedDSCModules, $true) | Should -Be 0
            }
        }

        Context 'When Called with Test DSC Resource Content' {
            It 'Returns DSCModules Object that matches Expected Object' {
                $content = Get-Content -Path (Join-Path -Path $script:testConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') -RAW
                $dscModules = Get-LabModulesInDSCConfig `
                    -DSCConfigContent $content `
                    -Verbose

                Set-Content `
                    -Path "$script:artifactPath\ExpectedDSCModules.json" `
                    -Value ($dscModules | ConvertTo-Json -Depth 4)

                $expectedDSCModules = Get-Content -Path "$script:expectedContentPath\ExpectedDSCModules.json"
                [System.String]::Compare((Get-Content -Path "$script:artifactPath\ExpectedDSCModules.json"), $expectedDSCModules, $true) | Should -Be 0
            }
        }
    }

    Describe 'Set-LabModulesInDSCConfig' {
        $module1 = [LabDSCModule]::New('PSDesiredStateConfiguration', '1.0')
        $module2 = [LabDSCModule]::New('xActiveDirectory')
        $module3 = [LabDSCModule]::New('ComputerManagementDsc', '1.4.0.0')
        $module4 = [LabDSCModule]::New('xNewModule', '9.9.9.9')
        [LabDSCModule[]] $UpdateModules = @($module1, $module2, $module3, $module4)

        Context 'When called with Test DSC Resource File' {
            It 'Returns DSCConfig Content that matches Expected String' {
                $dscConfig = Set-LabModulesInDSCConfig `
                    -DSCConfigFile (Join-Path -Path $script:testConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') `
                    -Modules $UpdateModules `
                    -Verbose

                Set-Content -Path "$script:artifactPath\ExpectedDSCConfig.txt" -Value $dscConfig
                $expectedDSCConfig = Get-Content -Path "$script:expectedContentPath\ExpectedDSCConfig.txt"
                @(Compare-Object `
                        -ReferenceObject $expectedDSCConfig `
                        -DifferenceObject (Get-Content -Path "$script:artifactPath\ExpectedDSCConfig.txt")).Count | Should -Be 0
            }
        }

        Context 'When called with Test DSC Resource Content' {
            It 'Returns DSCModules Content that matches Expected String' {
                $content = Get-Content -Path (Join-Path -Path $script:testConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') -Raw
                $dscConfig = Set-LabModulesInDSCConfig `
                    -DSCConfigContent $Content `
                    -Modules $UpdateModules `
                    -Verbose

                Set-Content -Path "$script:artifactPath\ExpectedDSCConfig.txt" -Value $dscConfig
                $expectedDSCConfig = Get-Content -Path "$script:expectedContentPath\ExpectedDSCConfig.txt"
                @(Compare-Object `
                        -ReferenceObject $expectedDSCConfig `
                        -DifferenceObject (Get-Content -Path "$script:artifactPath\ExpectedDSCConfig.txt")).Count | Should -Be 0
            }
        }
    }

    Describe 'Update-LabDSC' {
        function Get-VM
        {
            [CmdletBinding()]
            param
            (
            )
        }

        function Get-VMNetworkAdapter
        {
            [CmdletBinding()]
            param
            (
            )
        }

        function Find-Module
        {
            [CmdletBinding()]
            param
            (
                [System.String]
                $Name,

                [System.String]
                $MinimumVersion
            )
        }

        function Install-Module
        {
            [CmdletBinding()]
            param
            (
                [Parameter(ValueFromPipeline = $true)]
                $InputObject,

                [System.String]
                $Name,

                [System.String]
                $MinimumVersion
            )
        }

        Mock -CommandName Get-VM

        $lab = Get-Lab -ConfigPath $script:testConfigOKPath
        $switches = Get-LabSwitch -Lab $lab
        $templates = Get-LabVMTemplate -Lab $lab
        $vms = Get-LabVM -Lab $lab -VMTemplates $templates -Switches $switches

        Context 'Empty DSC Config' {
            Mock -CommandName Get-Module
            Mock -CommandName Get-LabModulesInDSCConfig -MockWith { @('TestModule') }

            $vm = $vms[0].Clone()
            $vmConfigFile = $vm.DSC.ConfigFile
            $vm.DSC.ConfigFile = ''

            It 'Does not throw an Exception' {
                { Update-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 0
            }

            $vm.DSC.ConfigFile = $vmConfigFile
        }

        Context 'DSC Module Not Found' {
            Mock -CommandName Get-Module
            Mock -CommandName Get-LabModulesInDSCConfig -MockWith { @('TestModule') }
            Mock -CommandName Find-Module

            $vm = $vms[0].Clone()
            $exceptionParameters = @{
                errorId       = 'DSCModuleDownloadError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.DSCModuleDownloadError `
                        -f $vm.DSC.ConfigFile, $vm.Name, 'TestModule')
            }
            $exception = Get-LabException @exceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { Update-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Throw $exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Get-LabModulesInDSCConfig -Exactly -Times 1
                Assert-MockCalled -CommandName Find-Module -Exactly -Times 1
            }
        }

        Context 'When DSC Module Download Error' {
            Mock -CommandName Get-Module
            Mock -CommandName Get-LabModulesInDSCConfig -MockWith { @('TestModule') }
            Mock -CommandName Find-Module -MockWith { @{ name = 'TestModule' } }
            Mock -CommandName Install-Module -MockWith { Throw }

            $vm = $vms[0].Clone()
            $exceptionParameters = @{
                errorId       = 'DSCModuleDownloadError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.DSCModuleDownloadError `
                        -f $vm.DSC.ConfigFile, $vm.Name, 'TestModule')
            }
            $exception = Get-LabException @exceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { Update-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Throw $exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Get-LabModulesInDSCConfig -Exactly -Times 1
                Assert-MockCalled -CommandName Find-Module -Exactly -Times 1
            }
        }

        Context 'When DSC Module Not Found in Path' {
            Mock -CommandName Get-Module
            Mock -CommandName Get-LabModulesInDSCConfig -MockWith { @('TestModule') }
            Mock -CommandName Find-Module -MockWith { @{ name = 'TestModule' } }
            Mock -CommandName Install-Module
            Mock -CommandName Test-Path `
                -ParameterFilter { $Path -like '*TestModule' } `
                -MockWith { $false }

            $vm = $vms[0].Clone()
            $exceptionParameters = @{
                errorId       = 'DSCModuleNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.DSCModuleNotFoundError `
                        -f $vm.DSC.ConfigFile, $vm.Name, 'TestModule')
            }
            $exception = Get-LabException @exceptionParameters

            It 'Throws a DSCModuleNotFoundError Exception' {
                { Update-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Throw $exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Get-LabModulesInDSCConfig -Exactly -Times 1
                Assert-MockCalled -CommandName Find-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Install-Module -Exactly -Times 1
            }
        }

        Context 'When Certificate Create Failed' {
            Mock -CommandName Get-Module
            Mock -CommandName Get-LabModulesInDSCConfig -MockWith { @('TestModule') }
            Mock -CommandName Find-Module -MockWith { @{ name = 'TestModule' } }
            Mock -CommandName Install-Module
            Mock -CommandName Test-Path `
                -ParameterFilter { ($Path -like '*TestModule') -or ($Path -like '*NetworkingDsc') } `
                -MockWith { $true }
            Mock -CommandName Copy-Item
            Mock -CommandName Request-LabSelfSignedCertificate `
                -MockWith { $false }

            $vm = $vms[0].Clone()
            $vm.CertificateSource = [LabCertificateSource]::Guest
            $exceptionParameters = @{
                errorId       = 'CertificateCreateError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.CertificateCreateError `
                        -f $vm.Name)
            }
            $exception = Get-LabException @exceptionParameters

            It 'Throws a CertificateCreateError Exception' {
                { Update-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Throw $exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Get-LabModulesInDSCConfig -Exactly -Times 1
                Assert-MockCalled -CommandName Find-Module -Exactly -Times 2
                Assert-MockCalled -CommandName Install-Module -Exactly -Times 2
                Assert-MockCalled -CommandName Copy-Item -Exactly -Times 2
                Assert-MockCalled -CommandName Request-LabSelfSignedCertificate -Exactly -Times 1
            }
        }

        Context 'When Meta MOF Create Failed' {
            Mock -CommandName Get-Module
            Mock -CommandName Get-LabModulesInDSCConfig -MockWith { @('TestModule') }
            Mock -CommandName Find-Module -MockWith { @{ name = 'TestModule' } }
            Mock -CommandName Install-Module
            Mock -CommandName Test-Path `
                -ParameterFilter { ($Path -like '*TestModule') -or ($Path -like '*NetworkingDsc') } `
                -MockWith { $true }
            Mock -CommandName Copy-Item
            Mock -CommandName Request-LabSelfSignedCertificate -MockWith { $true }
            Mock -CommandName Import-Certificate
            Mock -CommandName Get-ChildItem `
                -ParameterFilter { $path -eq 'cert:\LocalMachine\My' } `
                -MockWith { @{
                    FriendlyName = 'DSC Credential Encryption'
                    Thumbprint   = '1FE3BA1B6DBE84FCDF675A1C944A33A55FD4B872'
                } }
            Mock -CommandName Remove-Item
            Mock -CommandName ConfigLCM

            $vm = $vms[0].Clone()
            $vm.CertificateSource = [LabCertificateSource]::Guest
            $exceptionParameters = @{
                errorId       = 'DSCConfigMetaMOFCreateError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.DSCConfigMetaMOFCreateError `
                        -f $vm.Name)
            }
            $exception = Get-LabException @exceptionParameters

            It 'Throws a DSCConfigMetaMOFCreateError Exception' {
                { Update-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Throw $exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Get-LabModulesInDSCConfig -Exactly -Times 1
                Assert-MockCalled -CommandName Find-Module -Exactly -Times 2
                Assert-MockCalled -CommandName Install-Module -Exactly -Times 2
                Assert-MockCalled -CommandName Copy-Item -Exactly -Times 2
                Assert-MockCalled -CommandName Request-LabSelfSignedCertificate -Exactly -Times 1
                Assert-MockCalled -CommandName Import-Certificate -Exactly -Times 1
                Assert-MockCalled -CommandName Get-ChildItem -ParameterFilter { $path -eq 'cert:\LocalMachine\My' } -Exactly -Times 1
                Assert-MockCalled -CommandName Remove-Item
                Assert-MockCalled -CommandName ConfigLCM -Exactly -Times 1
            }
        }
    }

    Describe 'Set-LabDSC' {
        # Mock functions
        function Get-VM
        {
            param
            (
            )
        }

        function Get-VMNetworkAdapter
        {
            param
            (
            )
        }

        Mock -CommandName Get-VM

        $lab = Get-Lab -ConfigPath $script:testConfigOKPath
        $switches = Get-LabSwitch -Lab $lab
        $templates = Get-LabVMTemplate -Lab $lab
        $vms = Get-LabVM -Lab $lab -VMTemplates $templates -Switches $switches

        Context 'When Network Adapter does not Exist' {
            Mock -CommandName Get-VMNetworkAdapter

            $vm = $vms[0].Clone()
            $vm.Adapters[0].Name = 'DoesNotExist'
            $exceptionParameters = @{
                errorId       = 'NetworkAdapterNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.NetworkAdapterNotFoundError `
                        -f 'DoesNotExist', $vms[0].Name)
            }
            $exception = Get-LabException @exceptionParameters

            It 'Throws a NetworkAdapterNotFoundError Exception' {
                { Set-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Throw $exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMNetworkAdapter -Exactly -Times 1
            }
        }

        Context 'When Network Adapter has blank MAC Address' {
            Mock -CommandName Get-VMNetworkAdapter -MockWith { @{ Name = 'Exists'; MacAddress = '' }}

            $vm = $vms[0].Clone()
            $vm.Adapters[0].Name = 'Exists'
            $exceptionParameters = @{
                errorId       = 'NetworkAdapterBlankMacError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.NetworkAdapterBlankMacError `
                        -f 'Exists', $vms[0].Name)
            }
            $exception = Get-LabException @exceptionParameters

            It 'Throws a NetworkAdapterBlankMacError Exception' {
                { Set-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Throw $exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMNetworkAdapter -Exactly -Times 1
            }
        }

        Context 'When Valid Configuration Passed' {
            Mock -CommandName Get-VMNetworkAdapter -MockWith { @{ Name = 'Exists'; MacAddress = '111111111111' }}
            Mock -CommandName Set-Content

            $vm = $vms[0].Clone()

            It 'Does Not Throw Exception' {
                { Set-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Not -Throw
            }
            It 'Calls Mocked commands' {

                Assert-MockCalled -CommandName Get-VMNetworkAdapter -Exactly -Times ($vm.Adapters.Count + 1)
                Assert-MockCalled -CommandName Set-Content -Exactly -Times 2
            }
        }
    }

    Describe 'Initialize-LabDSC' {
        $lab = Get-Lab -ConfigPath $script:testConfigOKPath
        $vms = Get-LabVM -Lab $lab

        Mock -CommandName Update-LabDSC
        Mock -CommandName Set-LabDSC

        Context 'When Valid Configuration Passed' {
            $vm = $vms[0].Clone()

            It 'Does Not Throw Exception' {
                { Initialize-LabDSC -Lab $lab -VM $vm -Verbose } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Update-LabDSC -Exactly -Times 1
                Assert-MockCalled -CommandName Set-LabDSC -Exactly -Times 1
            }
        }
    }

    Describe 'Start-LabDSC' -Tags 'Incomplete' {
    }

    Describe 'Get-LabDSCNetworkingConfig' -Tags 'Incomplete' {
    }
}
