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

    function Get-VMNetworkAdapter
    {
        [CmdletBinding()]
        param
        (
            [System.String]
            $SwitchName,

            [System.String]
            $Name,

            [Switch]
            $ManagementOS
        )
    }

    function Add-VMNetworkAdapter
    {
        [CmdletBinding()]
        param
        (
            [System.String]
            $SwitchName,

            [System.String]
            $Name,

            [Switch]
            $DynamicMacAddress,

            [System.String]
            $StaticMacAddress,

            [Switch]
            $ManagementOS,

            [Switch]
            $PassThru
        )
    }

    function Set-VMNetworkAdapter
    {
        [CmdletBinding()]
        param
        (
            [Parameter(ValueFromPipeline = $true)]
            $InputObject,

            [System.String]
            $SwitchName,

            [System.String]
            $Name,

            [Switch]
            $DynamicMacAddress,

            [System.String]
            $StaticMacAddress,

            [Switch]
            $ManagementOS
        )
    }

    function Get-VMNetworkAdapterVlan
    {
        [CmdletBinding()]
        param
        (
            [System.String]
            $VMNetworkAdapterName,

            [System.Object]
            $VMNetworkAdapter,

            [Switch]
            $Untagged,

            [Switch]
            $ManagementOS
        )
    }

    function Set-VMNetworkAdapterVlan
    {
        [CmdletBinding()]
        param
        (
            [Parameter(ValueFromPipeline = $true)]
            $InputObject,

            [System.String]
            $VMNetworkAdapterName,

            [System.Object]
            $VMNetworkAdapter,

            [System.Byte]
            $VlanId,

            [Switch]
            $Access,

            [Switch]
            $Untagged,

            [Switch]
            $ManagementOS
        )
    }

    function Get-VMSwitch
    {
        [CmdletBinding()]
        param
        (
        )
    }

    function New-VMSwitch
    {
        [CmdletBinding()]
        param
        (
            [ValidateSet('Internal', 'External', 'Private')]
            [System.String]
            $SwitchType,

            [System.String]
            $Name
        )
    }

    Describe 'Get-LabManagementSwitchName' {
        Context 'Valid Configuration Passed' {
            It 'Should return "TestLab Lab Management"' {
                Get-LabManagementSwitchName -Lab $script:Lab | Should -Be 'TestLab Lab Management'
            }
        }
    }

    Describe 'Set-LabSwitchAdapter' {
        $TestAdapter = @{
            Name             = 'Adapter Name'
            SwitchName       = 'Switch Name'
            VlanId           = 10
            StaticMacAddress = '1234567890AB'
            Verbose          = $true
        }

        Context 'When Switch Management Adapter does not exist, VlanId not passed, StaticMacAddress not passed' {
            Mock -CommandName Get-VMNetworkAdapter
            Mock -CommandName Add-VMNetworkAdapter -MockWith { @{ Name = 'Adapter Name'; SwitchName = 'Switch Name' } }
            Mock -CommandName Set-VMNetworkAdapter
            Mock -CommandName Set-VMNetworkAdapterVlan

            $updateLabManagementSwitchAdapterParameters = $TestAdapter.Clone()
            $updateLabManagementSwitchAdapterParameters.Remove('VlanId')
            $updateLabManagementSwitchAdapterParameters.Remove('StaticMacAddress')

            It 'Should Not Throw Exception' {
                { Set-LabSwitchAdapter @updateLabManagementSwitchAdapterParameters } | Should -Not -Throw
            }

            It 'Should Call Mocked commands' {
                Assert-MockCalled -CommandName Get-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Add-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Set-VMNetworkAdapter -Exactly -Times 0
                Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -Exactly -Times 0
            }
        }

        Context 'When Switch Management Adapter does not exist, VlanId 10 passed, StaticMacAddress not passed' {
            Mock -CommandName Get-VMNetworkAdapter
            Mock -CommandName Add-VMNetworkAdapter -MockWith { @{ Name = 'Adapter Name'; SwitchName = 'Switch Name' } }
            Mock -CommandName Set-VMNetworkAdapter
            Mock -CommandName Set-VMNetworkAdapterVlan

            $updateLabManagementSwitchAdapterParameters = $TestAdapter.Clone()
            $updateLabManagementSwitchAdapterParameters.VlanId = 10
            $updateLabManagementSwitchAdapterParameters.Remove('StaticMacAddress')

            It 'Should Not Throw Exception' {
                { Set-LabSwitchAdapter @updateLabManagementSwitchAdapterParameters } | Should -Not -Throw
            }

            It 'Should Call Mocked commands' {
                Assert-MockCalled -CommandName Get-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Add-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Set-VMNetworkAdapter -Exactly -Times 0
                Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 } -Exactly -Times 1
                Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged } -Exactly -Times 0
            }
        }

        Context 'When Switch Management Adapter does not exist, VlanId null passed, StaticMacAddress not passed' {
            Mock -CommandName Get-VMNetworkAdapter
            Mock -CommandName Add-VMNetworkAdapter -MockWith { @{ Name = 'Adapter Name'; SwitchName = 'Switch Name' } }
            Mock -CommandName Set-VMNetworkAdapter
            Mock -CommandName Set-VMNetworkAdapterVlan

            $updateLabManagementSwitchAdapterParameters = $TestAdapter.Clone()
            $updateLabManagementSwitchAdapterParameters.VlanId = $null
            $updateLabManagementSwitchAdapterParameters.Remove('StaticMacAddress')

            It 'Should Not Throw Exception' {
                { Set-LabSwitchAdapter @updateLabManagementSwitchAdapterParameters } | Should -Not -Throw
            }

            It 'Should Call Mocked commands' {
                Assert-MockCalled -CommandName Get-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Add-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Set-VMNetworkAdapter -Exactly -Times 0
                Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 } -Exactly -Times 0
                Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged } -Exactly -Times 1
            }
        }

        Context 'When Switch Management Adapter does not exist, VlanId not passed, StaticMacAddress passed' {
            Mock -CommandName Get-VMNetworkAdapter
            Mock -CommandName Add-VMNetworkAdapter -MockWith { @{ Name = 'Adapter Name'; SwitchName = 'Switch Name' } }
            Mock -CommandName Set-VMNetworkAdapter
            Mock -CommandName Set-VMNetworkAdapterVlan

            $updateLabManagementSwitchAdapterParameters = $TestAdapter.Clone()
            $updateLabManagementSwitchAdapterParameters.Remove('VlanId')

            It 'Should Not Throw Exception' {
                { Set-LabSwitchAdapter @updateLabManagementSwitchAdapterParameters } | Should -Not -Throw
            }

            It 'Should Call Mocked commands' {
                Assert-MockCalled -CommandName Get-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Add-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Set-VMNetworkAdapter -Exactly -Times 0
                Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -Exactly -Times 0
            }
        }

        Context 'When Switch Management Adapter does not exist, VlanId not passed, empty StaticMacAddress passed' {
            Mock -CommandName Get-VMNetworkAdapter
            Mock -CommandName Add-VMNetworkAdapter -MockWith { @{ Name = 'Adapter Name'; SwitchName = 'Switch Name' } }
            Mock -CommandName Set-VMNetworkAdapter
            Mock -CommandName Set-VMNetworkAdapterVlan

            $updateLabManagementSwitchAdapterParameters = $TestAdapter.Clone()
            $updateLabManagementSwitchAdapterParameters.Remove('VlanId')
            $updateLabManagementSwitchAdapterParameters.StaticMacAddress = ''

            It 'Should Not Throw Exception' {
                { Set-LabSwitchAdapter @updateLabManagementSwitchAdapterParameters } | Should -Not -Throw
            }

            It 'Should Call Mocked commands' {
                Assert-MockCalled -CommandName Get-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Add-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Set-VMNetworkAdapter -Exactly -Times 0
                Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -Exactly -Times 0
            }
        }

        Context 'When Switch Management Adapter exists, VlanId passed, StaticMacAddress passed' {
            Mock -CommandName Get-VMNetworkAdapter -MockWith { @{ Name = 'Adapter Name'; SwitchName = 'Switch Name' } }
            Mock -CommandName Add-VMNetworkAdapter
            Mock -CommandName Set-VMNetworkAdapter
            Mock -CommandName Set-VMNetworkAdapterVlan

            $updateLabManagementSwitchAdapterParameters = $TestAdapter.Clone()

            It 'Should Not Throw Exception' {
                { Set-LabSwitchAdapter @updateLabManagementSwitchAdapterParameters } | Should -Not -Throw
            }

            It 'Should Call Mocked commands' {
                Assert-MockCalled -CommandName Get-VMNetworkAdapter -Exactly -Times 1
                Assert-MockCalled -CommandName Add-VMNetworkAdapter -Exactly -Times 0
                Assert-MockCalled -CommandName Set-VMNetworkAdapter -Exactly -Times 0
                Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 } -Exactly -Times 1
                Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged } -Exactly -Times 0
            }
        }
    }

    Describe 'Initialize-LabManagementSwitch' {
        Context 'Valid Configuration Passed and Management Switch does not exist' {
            Mock -CommandName Get-VMSwitch
            Mock -CommandName New-VMSwitch
            Mock -CommandName Get-VMNetworkAdapter `
                -MockWith { 'TestLab Lab Management Adapter' }
            Mock -CommandName Add-VMNetworkAdapter
            Mock -CommandName Get-VMNetworkAdapterVlan `
                -MockWith {
                @{
                    AccessVlanId = 1
                }
            }
            Mock -CommandName Set-VMNetworkAdapterVlan

            It 'Should Not Throw Exception' {
                Initialize-LabManagementSwitch -Lab $script:Lab
            }

            Assert-MockCalled -CommandName Get-VMSwitch -Exactly -Times 1
            Assert-MockCalled -CommandName New-VMSwitch -ParameterFilter {
                $SwitchType -eq 'Internal' -and `
                    $Name -eq 'TestLab Lab Management'
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Get-VMNetworkAdapter -ParameterFilter {
                $SwitchName -eq 'TestLab Lab Management' -and `
                    $Name -eq 'TestLab Lab Management' -and `
                    $ManagementOS
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Add-VMNetworkAdapter -Exactly -Times 0
            Assert-MockCalled -CommandName Get-VMNetworkAdapterVlan -ParameterFilter {
                $VMNetworkAdapter -eq 'TestLab Lab Management Adapter'
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -ParameterFilter {
                $VMNetworkAdapter -eq 'TestLab Lab Management Adapter' -and `
                    $VlanId -eq 99 -and `
                    $Access -eq $true
            } -Exactly -Times 1
        }

        Context 'Valid Configuration Passed and Management Switch exists but Management Adapter is missing' {
            Mock -CommandName Get-VMSwitch `
                -MockWith {
                @{
                    Name = 'TestLab Lab Management'
                }
            }
            Mock -CommandName New-VMSwitch
            Mock -CommandName Get-VMNetworkAdapter
            Mock -CommandName Add-VMNetworkAdapter `
                -MockWith { 'TestLab Lab Management Adapter' }
            Mock -CommandName Get-VMNetworkAdapterVlan `
                -MockWith {
                @{
                    AccessVlanId = 1
                }
            }
            Mock -CommandName Set-VMNetworkAdapterVlan

            It 'Should Not Throw Exception' {
                Initialize-LabManagementSwitch -Lab $script:Lab
            }

            Assert-MockCalled -CommandName Get-VMSwitch -Exactly -Times 1
            Assert-MockCalled -CommandName New-VMSwitch -Exactly -Times 0
            Assert-MockCalled -CommandName Get-VMNetworkAdapter -ParameterFilter {
                $SwitchName -eq 'TestLab Lab Management' -and `
                    $Name -eq 'TestLab Lab Management' -and `
                    $ManagementOS
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Add-VMNetworkAdapter -ParameterFilter {
                $SwitchName -eq 'TestLab Lab Management' -and `
                    $Name -eq 'TestLab Lab Management' -and `
                    $ManagementOS
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Get-VMNetworkAdapterVlan -ParameterFilter {
                $VMNetworkAdapter -eq 'TestLab Lab Management Adapter'
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -ParameterFilter {
                $VMNetworkAdapter -eq 'TestLab Lab Management Adapter' -and `
                    $VlanId -eq 99 -and `
                    $Access -eq $true
            } -Exactly -Times 1
        }

        Context 'Valid Configuration Passed and Management Switch exists but the Management Adapter has the wrong VlanId' {
            Mock -CommandName Get-VMSwitch `
                -MockWith {
                @{
                    Name = 'TestLab Lab Management'
                }
            }
            Mock -CommandName New-VMSwitch
            Mock -CommandName Get-VMNetworkAdapter `
                -MockWith { 'TestLab Lab Management Adapter' }
            Mock -CommandName Add-VMNetworkAdapter
            Mock -CommandName Get-VMNetworkAdapterVlan `
                -MockWith {
                @{
                    AccessVlanId = 1
                }
            }
            Mock -CommandName Set-VMNetworkAdapterVlan

            It 'Should Not Throw Exception' {
                Initialize-LabManagementSwitch -Lab $script:Lab
            }

            Assert-MockCalled -CommandName Get-VMSwitch -Exactly -Times 1
            Assert-MockCalled -CommandName New-VMSwitch -Exactly -Times 0
            Assert-MockCalled -CommandName Get-VMNetworkAdapter -ParameterFilter {
                $SwitchName -eq 'TestLab Lab Management' -and `
                    $Name -eq 'TestLab Lab Management' -and `
                    $ManagementOS
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Add-VMNetworkAdapter -Exactly -Times 0
            Assert-MockCalled -CommandName Get-VMNetworkAdapterVlan -ParameterFilter {
                $VMNetworkAdapter -eq 'TestLab Lab Management Adapter'
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -ParameterFilter {
                $VMNetworkAdapter -eq 'TestLab Lab Management Adapter' -and `
                    $VlanId -eq 99 -and `
                    $Access -eq $true
            } -Exactly -Times 1
        }

        Context 'Valid Configuration Passed and Management Switch exists and the Management Adapter has the correct VlanId' {
            Mock -CommandName Get-VMSwitch `
                -MockWith {
                @{
                    Name = 'TestLab Lab Management'
                }
            }
            Mock -CommandName New-VMSwitch
            Mock -CommandName Get-VMNetworkAdapter `
                -MockWith { 'TestLab Lab Management Adapter' }
            Mock -CommandName Add-VMNetworkAdapter
            Mock -CommandName Get-VMNetworkAdapterVlan `
                -MockWith {
                @{
                    AccessVlanId = 99
                }
            }
            Mock -CommandName Set-VMNetworkAdapterVlan

            It 'Should Not Throw Exception' {
                Initialize-LabManagementSwitch -Lab $script:Lab
            }

            Assert-MockCalled -CommandName Get-VMSwitch -Exactly -Times 1
            Assert-MockCalled -CommandName New-VMSwitch -Exactly -Times 0
            Assert-MockCalled -CommandName Get-VMNetworkAdapter -ParameterFilter {
                $SwitchName -eq 'TestLab Lab Management' -and `
                    $Name -eq 'TestLab Lab Management' -and `
                    $ManagementOS
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Add-VMNetworkAdapter -Exactly -Times 0
            Assert-MockCalled -CommandName Get-VMNetworkAdapterVlan -ParameterFilter {
                $VMNetworkAdapter -eq 'TestLab Lab Management Adapter'
            } -Exactly -Times 1
            Assert-MockCalled -CommandName Set-VMNetworkAdapterVlan -Exactly -Times 0
        }
    }
}
