$Global:ModuleRoot = Resolve-Path -Path "$($Script:MyInvocation.MyCommand.Path)\..\..\..\..\..\"
$OldPSModulePath = $env:PSModulePath
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

        Describe '\Lib\Private\Dsc.ps1\Get-ModulesInDSCConfig' {
            Context 'Called with Test DSC Resource File' {
                It 'Returns DSCModules Object that matches Expected Object' {
                    $dscModules = Get-ModulesInDSCConfig `
                        -DSCConfigFile (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') `
                        -Verbose

                    Set-Content `
                        -Path "$Global:ArtifactPath\ExpectedDSCModules.json" `
                        -Value ($dscModules | ConvertTo-Json -Depth 4)

                    $expectedDSCModules = Get-Content -Path "$Global:ExpectedContentPath\ExpectedDSCModules.json"
                    [System.String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedDSCModules.json"), $expectedDSCModules, $true) | Should -Be 0
                }
            }

            Context 'Called with Test DSC Resource Content' {
                It 'Returns DSCModules Object that matches Expected Object' {
                    $content = Get-Content -Path (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') -RAW
                    $dscModules = Get-ModulesInDSCConfig `
                        -DSCConfigContent $content `
                        -Verbose

                    Set-Content `
                        -Path "$Global:ArtifactPath\ExpectedDSCModules.json" `
                        -Value ($dscModules | ConvertTo-Json -Depth 4)

                    $expectedDSCModules = Get-Content -Path "$Global:ExpectedContentPath\ExpectedDSCModules.json"
                    [System.String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedDSCModules.json"), $expectedDSCModules, $true) | Should -Be 0
                }
            }
        }

        Describe '\Lib\Private\Dsc.ps1\Set-ModulesInDSCConfig' {
            $module1 = [LabDSCModule]::New('PSDesiredStateConfiguration', '1.0')
            $module2 = [LabDSCModule]::New('xActiveDirectory')
            $module3 = [LabDSCModule]::New('xComputerManagement', '1.4.0.0')
            $module4 = [LabDSCModule]::New('xNewModule', '9.9.9.9')
            [LabDSCModule[]] $UpdateModules = @($module1, $module2, $module3, $module4)

            Context 'Called with Test DSC Resource File' {
                It 'Returns DSCConfig Content that matches Expected String' {
                    $dscConfig = Set-ModulesInDSCConfig `
                        -DSCConfigFile (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') `
                        -Modules $UpdateModules `
                        -Verbose

                    Set-Content -Path "$Global:ArtifactPath\ExpectedDSCConfig.txt" -Value $dscConfig
                    $expectedDSCConfig = Get-Content -Path "$Global:ExpectedContentPath\ExpectedDSCConfig.txt"
                    @(Compare-Object `
                            -ReferenceObject $expectedDSCConfig `
                            -DifferenceObject (Get-Content -Path "$Global:ArtifactPath\ExpectedDSCConfig.txt")).Count  | Should -Be 0
                }
            }

            Context 'Called with Test DSC Resource Content' {
                It 'Returns DSCModules Content that matches Expected String' {
                    $content = Get-Content -Path (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') -Raw
                    $dscConfig = Set-ModulesInDSCConfig `
                        -DSCConfigContent $Content `
                        -Modules $UpdateModules `
                        -Verbose

                    Set-Content -Path "$Global:ArtifactPath\ExpectedDSCConfig.txt" -Value $dscConfig
                    $expectedDSCConfig = Get-Content -Path "$Global:ExpectedContentPath\ExpectedDSCConfig.txt"
                    @(Compare-Object `
                            -ReferenceObject $expectedDSCConfig `
                            -DifferenceObject (Get-Content -Path "$Global:ArtifactPath\ExpectedDSCConfig.txt")).Count  | Should -Be 0
                }
            }
        }

        Describe '\Lib\Private\Dsc.ps1\Update-LabDSC' {
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

            $lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $switches = Get-LabSwitch -Lab $lab
            $templates = Get-LabVMTemplate -Lab $lab
            $vms = Get-LabVM -Lab $lab -VMTemplates $templates -Switches $switches

            Context 'Empty DSC Config' {
                Mock -CommandName Get-Module
                Mock -CommandName Get-ModulesInDSCConfig -MockWith { @('TestModule') }

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
                Mock -CommandName Get-ModulesInDSCConfig -MockWith { @('TestModule') }
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
                    Assert-MockCalled -CommandName Get-ModulesInDSCConfig -Exactly -Times 1
                    Assert-MockCalled -CommandName Find-Module -Exactly -Times 1
                }
            }

            Context 'DSC Module Download Error' {
                Mock -CommandName Get-Module
                Mock -CommandName Get-ModulesInDSCConfig -MockWith { @('TestModule') }
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
                    Assert-MockCalled -CommandName Get-ModulesInDSCConfig -Exactly -Times 1
                    Assert-MockCalled -CommandName Find-Module -Exactly -Times 1
                }
            }

            Context 'DSC Module Not Found in Path' {
                Mock -CommandName Get-Module
                Mock -CommandName Get-ModulesInDSCConfig -MockWith { @('TestModule') }
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
                    Assert-MockCalled -CommandName Get-ModulesInDSCConfig -Exactly -Times 1
                    Assert-MockCalled -CommandName Find-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 1
                }
            }

            Context 'Certificate Create Failed' {
                Mock -CommandName Get-Module
                Mock -CommandName Get-ModulesInDSCConfig -MockWith { @('TestModule') }
                Mock -CommandName Find-Module -MockWith { @{ name = 'TestModule' } }
                Mock -CommandName Install-Module
                Mock -CommandName Test-Path `
                    -ParameterFilter { ($Path -like '*TestModule') -or ($Path -like '*xNetworking') } `
                    -MockWith { $true }
                Mock -CommandName Copy-Item
                Mock -CommandName Request-SelfSignedCertificate `
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
                    Assert-MockCalled -CommandName Get-ModulesInDSCConfig -Exactly -Times 1
                    Assert-MockCalled -CommandName Find-Module -Exactly -Times 2
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 2
                    Assert-MockCalled -CommandName Copy-Item -Exactly -Times 2
                    Assert-MockCalled -CommandName Request-SelfSignedCertificate -Exactly -Times 1
                }
            }

            Context 'Meta MOF Create Failed' {
                Mock -CommandName Get-Module
                Mock -CommandName Get-ModulesInDSCConfig -MockWith { @('TestModule') }
                Mock -CommandName Find-Module -MockWith { @{ name = 'TestModule' } }
                Mock -CommandName Install-Module
                Mock -CommandName Test-Path `
                    -ParameterFilter { ($Path -like '*TestModule') -or ($Path -like '*xNetworking') } `
                    -MockWith { $true }
                Mock -CommandName Copy-Item
                Mock -CommandName Request-SelfSignedCertificate -MockWith { $true }
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
                    Assert-MockCalled -CommandName Get-ModulesInDSCConfig -Exactly -Times 1
                    Assert-MockCalled -CommandName Find-Module -Exactly -Times 2
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 2
                    Assert-MockCalled -CommandName Copy-Item -Exactly -Times 2
                    Assert-MockCalled -CommandName Request-SelfSignedCertificate -Exactly -Times 1
                    Assert-MockCalled -CommandName Import-Certificate -Exactly -Times 1
                    Assert-MockCalled -CommandName Get-ChildItem -ParameterFilter { $path -eq 'cert:\LocalMachine\My' } -Exactly -Times 1
                    Assert-MockCalled -CommandName Remove-Item
                    Assert-MockCalled -CommandName ConfigLCM -Exactly -Times 1
                }
            }
        }

        Describe '\Lib\Private\Dsc.ps1\Set-LabDSC' {
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

            $lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $switches = Get-LabSwitch -Lab $lab
            $templates = Get-LabVMTemplate -Lab $lab
            $vms = Get-LabVM -Lab $lab -VMTemplates $templates -Switches $switches

            Context 'Network Adapter does not Exist' {
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

            Context 'Network Adapter has blank MAC Address' {
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

            Context 'Valid Configuration Passed' {
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

        Describe '\Lib\Private\Dsc.ps1\Initialize-LabDSC' {
            $lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $vms = Get-LabVM -Lab $lab

            Mock -CommandName Update-LabDSC
            Mock -CommandName Set-LabDSC

            Context 'Valid Configuration Passed' {
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

        Describe '\Lib\Private\Dsc.ps1\Start-LabDSC' -Tags 'Incomplete' {
        }

        Describe '\Lib\Private\Dsc.ps1\Get-LabDSCNetworkingConfig' -Tags 'Incomplete' {
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
