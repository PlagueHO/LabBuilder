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

    Describe 'Get-LabSwitch' {
        Context 'When valid configuration passed with switch missing Switch Name.' {
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $Lab.labbuilderconfig.switches.switch[0].RemoveAttribute('name')
                $exceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = Get-LabException @exceptionParameters

                { Get-LabSwitch -Lab $Lab } | Should -Throw $Exception
            }
        }

        Context 'When valid configuration passed with switch missing Switch Type.' {
            It 'Throws a UnknownSwitchTypeError Exception' {
                $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $Lab.labbuilderconfig.switches.switch[0].RemoveAttribute('type')
                $exceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f '','External')
                }
                $Exception = Get-LabException @exceptionParameters

                { Get-LabSwitch -Lab $Lab } | Should -Throw $Exception
            }
        }

        Context 'When valid configuration passed with switch invalid Switch Type.' {
            It 'Throws a UnknownSwitchTypeError Exception' {
                $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $Lab.labbuilderconfig.switches.switch[0].type='BadType'
                $exceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f 'BadType','External')
                }
                $Exception = Get-LabException @exceptionParameters

                { Get-LabSwitch -Lab $Lab } | Should -Throw $Exception
            }
        }

        Context 'When valid configuration passed with switch containing adapters but is not External type.' {
            $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
            $Lab.labbuilderconfig.switches.switch[0].type='Private'
            It 'Throws a AdapterSpecifiedError Exception' {
                $exceptionParameters = @{
                    errorId = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.AdapterSpecifiedError `
                        -f 'Private',"$($Lab.labbuilderconfig.settings.labid)External")
                }
                $Exception = Get-LabException @exceptionParameters

                { Get-LabSwitch -Lab $Lab } | Should -Throw $Exception
            }
        }

        Context 'When valid configuration is passed with and Name filter set to matching switch' {
            It 'Returns a Single Switch object' {
                $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
                [Array] $Switches = Get-LabSwitch -Lab $Lab -Name $Lab.labbuilderconfig.switches.switch[0].name
                $Switches.Count | Should -Be 1
            }
        }

        Context 'When valid configuration is passed with and Name filter set to non-matching switch' {
            It 'Returns a Single Switch object' {
                $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
                [Array] $Switches = Get-LabSwitch -Lab $Lab -Name 'Does Not Exist'
                $Switches.Count | Should -Be 0
            }
        }

        Context 'When valid configuration is passed' {
            It 'Returns Switches Object that matches Expected Object' {
                $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
                [Array] $Switches = Get-LabSwitch -Lab $Lab
                Set-Content -Path "$script:artifactPath\ExpectedSwitches.json" -Value ($Switches | ConvertTo-Json -Depth 4)
                $ExpectedSwitches = Get-Content -Path "$script:expectedContentPath\ExpectedSwitches.json"
                [System.String]::Compare((Get-Content -Path "$script:artifactPath\ExpectedSwitches.json"),$ExpectedSwitches,$true) | Should -Be 0
            }
        }
    }

    Describe 'Initialize-LabSwitch' {
        $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
        [LabSwitch[]] $Switches = Get-LabSwitch -Lab $Lab

        function Get-VMSwitch {}
        function New-VMSwitch {}
        function Get-VMNetworkAdapter {
            [cmdletbinding()]
            param (
                [System.String] $Name,
                [System.String] $SwitchName,
                [Switch] $ManagementOS
            )
        }
        function Get-NetAdapter {
            [cmdletbinding()]
            param (
                [Parameter(ValueFromPipeline=$true)]
                $InputObject,
                [Switch] $Physical,
                [System.String] $Name
            )
        }
        function New-NetIPAddress {
            [cmdletbinding()]
            param (
                [Parameter(ValueFromPipeline=$true)]
                $InputObject,
                [System.String] $IPAddress,
                $PrefixLength
            )
        }
        function Get-NetNat {
            [cmdletbinding()]
            param (
                [System.String] $Name
            )
        }
        function New-NetNat {
            [cmdletbinding()]
            param (
                [System.String] $Name,
                [System.String] $InternalIPInterfaceAddressPrefix
            )
        }
        function Remove-NetNat {
            [cmdletbinding()]
            param (
                [Parameter(ValueFromPipeline=$true)]
                $InputObject
            )
        }

        Mock Get-VMSwitch -MockWith {
            @{
                Name = 'Dummy Switch'
                SwitchType = 'External'
            }
        }
        Mock New-VMSwitch
        Mock Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' }
        Mock Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -MockWith { @{ MacAddress = '0012345679A0' } }
        Mock Set-LabSwitchAdapter
        Mock New-NetIPAddress
        Mock Get-NetNat
        Mock New-NetNat
        Mock Remove-NetNat
        Mock Get-NetAdapter -MockWith {
            @{
                Name       = 'Ethernet'
                MACAddress = '0012345679A0'
                Status     = 'Up'
                Virtual    = $false
            }
        }

        $script:currentBuild = 14295

        Context 'When valid configuration is passed' {
            It 'Does not throw an Exception' {
                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 7
                Assert-MockCalled New-VMSwitch -Exactly 6
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 1
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 8
                Assert-MockCalled Get-NetAdapter -Exactly 3
                Assert-MockCalled New-NetIPAddress -Exactly 1
                Assert-MockCalled Get-NetNat -Exactly 1
                Assert-MockCalled New-NetNat -Exactly 1
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        Context 'When valid configuration without switches is passed' {
            It 'Does not throw an Exception' {
                { Initialize-LabSwitch -Lab $Lab } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 7
                Assert-MockCalled New-VMSwitch -Exactly 6
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 1
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 8
                Assert-MockCalled Get-NetAdapter -Exactly 3
                Assert-MockCalled New-NetIPAddress -Exactly 1
                Assert-MockCalled Get-NetNat -Exactly 1
                Assert-MockCalled New-NetNat -Exactly 1
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        Context 'When valid configuration NAT with blank NAT Subnet' {
            $Switches[0].Type = [LabSwitchType]::NAT
            $Switches[0].NatSubnet = ''

            It 'Throws a NatSubnetEmptyError Exception' {
                $exceptionParameters = @{
                    errorId = 'NatSubnetEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NatSubnetEmptyError `
                        -f $Switches[0].Name)
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 0
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 0
                Assert-MockCalled Get-NetAdapter -Exactly 0
                Assert-MockCalled New-NetIPAddress -Exactly 0
                Assert-MockCalled Get-NetNat -Exactly 0
                Assert-MockCalled New-NetNat -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        $script:currentBuild = 10586

        Context 'When valid configuration NAT on unsupported build' {
            $Switches[0].Type = [LabSwitchType]::NAT

            It 'Throws a NatSubnetEmptyError Exception' {
                $exceptionParameters = @{
                    errorId = 'NatSwitchNotSupportedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NatSwitchNotSupportedError `
                        -f $Switches[0].Name)
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 0
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 0
                Assert-MockCalled Get-NetAdapter -Exactly 0
                Assert-MockCalled New-NetIPAddress -Exactly 0
                Assert-MockCalled Get-NetNat -Exactly 0
                Assert-MockCalled New-NetNat -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        $script:currentBuild = 14295

        Context 'When valid configuration NAT with invalid NAT Subnet' {
            $Switches[0].Type = [LabSwitchType]::NAT
            $Switches[0].NatSubnet = 'Invalid'

            It 'Throws a NatSubnetInvalidError Exception' {
                $exceptionParameters = @{
                    errorId = 'NatSubnetInvalidError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NatSubnetInvalidError `
                        -f $Switches[0].Name,'Invalid')
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 0
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 0
                Assert-MockCalled Get-NetAdapter -Exactly 0
                Assert-MockCalled New-NetIPAddress -Exactly 0
                Assert-MockCalled Get-NetNat -Exactly 0
                Assert-MockCalled New-NetNat -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        Context 'When valid configuration NAT with invalid NAT Subnet Address' {
            $Switches[0].Type = [LabSwitchType]::NAT
            $Switches[0].NatSubnet = '192.168.1.1000/24'

            It 'Throws a NatSubnetAddressInvalidError Exception' {
                $exceptionParameters = @{
                    errorId = 'NatSubnetAddressInvalidError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NatSubnetAddressInvalidError `
                        -f $Switches[0].Name,'192.168.1.1000')
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 0
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 0
                Assert-MockCalled Get-NetAdapter -Exactly 0
                Assert-MockCalled New-NetIPAddress -Exactly 0
                Assert-MockCalled Get-NetNat -Exactly 0
                Assert-MockCalled New-NetNat -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        Context 'When valid configuration NAT with invalid NAT Subnet Address' {
            $Switches[0].Type = [LabSwitchType]::NAT
            $Switches[0].NatSubnet = '192.168.1.0/33'

            It 'Throws a NatSubnetPrefixLengthInvalidError Exception' {
                $exceptionParameters = @{
                    errorId = 'NatSubnetPrefixLengthInvalidError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NatSubnetPrefixLengthInvalidError `
                        -f $Switches[0].Name,33)
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 0
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 0
                Assert-MockCalled Get-NetAdapter -Exactly 0
                Assert-MockCalled New-NetIPAddress -Exactly 0
                Assert-MockCalled Get-NetNat -Exactly 0
                Assert-MockCalled New-NetNat -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        Mock Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -MockWith { @{ MacAddress = '' } }

        Context 'When valid configuration NAT with switch default network adapter missing MAC address' {
            $Switches[0].Name = 'TestLab NAT'
            $Switches[0].Type = [LabSwitchType]::NAT
            $Switches[0].NatSubnet = '192.168.1.0/24'

            It 'Throws a NatSwitchDefaultAdapterMacEmptyError Exception' {
                $exceptionParameters = @{
                    errorId = 'NatSwitchDefaultAdapterMacEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NatSwitchDefaultAdapterMacEmptyError `
                        -f $Switches[0].Name)
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 1
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 0
                Assert-MockCalled Get-NetAdapter -Exactly 0
                Assert-MockCalled New-NetIPAddress -Exactly 0
                Assert-MockCalled Get-NetNat -Exactly 0
                Assert-MockCalled New-NetNat -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        Mock Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -MockWith { @{ MacAddress = '001122334455' } }

        Context 'When valid configuration with blank switch name passed' {
            $Switches[0].Type = [LabSwitchType]::External
            $Switches[0].Name = ''

            It 'Throws a SwitchNameIsEmptyError Exception' {
                $exceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 0
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 0
                Assert-MockCalled Get-NetAdapter -Exactly 0
                Assert-MockCalled New-NetIPAddress -Exactly 0
                Assert-MockCalled Get-NetNat -Exactly 0
                Assert-MockCalled New-NetNat -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        [LabSwitch[]] $Switches = Get-LabSwitch -Lab $Lab

        Context 'When valid configuration with External switch with binding Adapter name bad' {
            Mock Get-NetAdapter

            It 'Throws a BindingAdapterNotFoundError Exception' {
                $exceptionParameters = @{
                    errorId = 'BindingAdapterNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.BindingAdapterNotFoundError `
                        -f $Switches[0].Name,"with a name '$($Switches[0].BindingAdapterName)' ")
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 0
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 0
                Assert-MockCalled Get-NetAdapter -Exactly 1
                Assert-MockCalled New-NetIPAddress -Exactly 0
                Assert-MockCalled Get-NetNat -Exactly 0
                Assert-MockCalled New-NetNat -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        Context 'When valid configuration with External switch with binding Adapter MAC bad' {
            Mock Get-NetAdapter
            $Switches[0].BindingAdapterName = ''
            $Switches[0].BindingAdapterMac = '1111111111'

            It 'Throws a BindingAdapterNotFoundError Exception' {
                $exceptionParameters = @{
                    errorId = 'BindingAdapterNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.BindingAdapterNotFoundError `
                        -f $Switches[0].Name,"with a MAC address '$($Switches[0].BindingAdapterMac)' ")
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'Dummy Switch' } -Exactly 0
                Assert-MockCalled Get-VMNetworkAdapter -ParameterFilter { $SwitchName -eq 'TestLab NAT' } -Exactly 0
                Assert-MockCalled Set-LabSwitchAdapter -Exactly 0
                Assert-MockCalled Get-NetAdapter -Exactly 1
                Assert-MockCalled New-NetIPAddress -Exactly 0
                Assert-MockCalled Get-NetNat -Exactly 0
                Assert-MockCalled New-NetNat -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }
    }

    Describe 'Remove-LabSwitch' {
        function Get-VMSwitch {}
        function Remove-VMSwitch {}
        function Remove-VMNetworkAdapter {}
        function Remove-NetNat {}

        $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
        [LabSwitch[]] $Switches = Get-LabSwitch -Lab $Lab

        Mock Get-VMSwitch -MockWith { $Switches }
        Mock Remove-VMSwitch
        Mock Remove-VMNetworkAdapter
        Mock Remove-NetNat

        Context 'When valid configuration is passed without RemoveExternal Switch' {
            It 'Does not throw an Exception' {
                { Remove-LabSwitch -Lab $Lab -Switches $Switches } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 6
                Assert-MockCalled Remove-VMSwitch -Exactly 5
                Assert-MockCalled Remove-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Remove-NetNat -Exactly 1
            }
        }

        Context 'When valid configuration is passed without switches without RemoveExternal Switch' {
            It 'Does not throw an Exception' {
                { Remove-LabSwitch -Lab $Lab } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 6
                Assert-MockCalled Remove-VMSwitch -Exactly 5
                Assert-MockCalled Remove-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Remove-NetNat -Exactly 1
            }
        }

        Context 'When valid configuration with blank switch name passed without RemoveExternal Switch' {
            $Switches[0].Name = ''

            It 'Throws a SwitchNameIsEmptyError Exception' {
                $exceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = Get-LabException @exceptionParameters

                { Remove-LabSwitch -Lab $Lab -Switches $Switches } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled Remove-VMSwitch -Exactly 0
                Assert-MockCalled Remove-VMNetworkAdapter -Exactly 0
                Assert-MockCalled Remove-NetNat -Exactly 0
            }
        }

        Context 'When valid configuration is passed with RemoveExternal Switch' {
            It 'Does not throw an Exception' {
                { Remove-LabSwitch -Lab $Lab -RemoveExternal } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 6
                Assert-MockCalled Remove-VMSwitch -Exactly 6
                Assert-MockCalled Remove-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Remove-NetNat -Exactly 1
            }
        }
    }
}

