$Global:ModuleRoot = Resolve-Path -Path "$($Script:MyInvocation.MyCommand.Path)\..\..\..\..\..\"

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


        Describe '\Lib\Private\Switch.ps1\GetManagementSwitchName' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath

            Context 'Valid Configuration Passed' {
                It 'Should return "TestLab Lab Management"' {
                    GetManagementSwitchName -Lab $Lab | Should Be 'TestLab Lab Management'
                }
            }
        }


        Describe '\Lib\Private\Switch.ps1\UpdateSwitchManagementAdapter' {
            # Mock functions
            function Set-VMNetworkAdapter {
                param (
                    [Parameter(ValueFromPipeline=$True)]
                    $InputObject,
                    [Switch] $DynamicMacAddress,
                    [String] $StaticMacAddress
                )
            }
            function Set-VMNetworkAdapterVlan {
                param (
                    [Parameter(ValueFromPipeline=$True)]
                    $InputObject,
                    [Switch] $Untagged,
                    [Byte] $VlanId,
                    [Switch] $Access
                )
            }
            function Get-VMNetworkAdapter {}
            function Add-VMNetworkAdapter {}

            $TestAdapter = @{
                Name = 'Adapter Name'
                SwitchName = 'Switch Name'
                VlanId = 10
                StaticMacAddress = '1234567890AB'
            }


            Mock Get-VMNetworkAdapter
            Mock Add-VMNetworkAdapter -MockWith { @{ Name = 'Adapter Name'; SwitchName = 'Switch Name' } }
            Mock Set-VMNetworkAdapter -ParameterFilter { $DynamicMacAddress }
            Mock Set-VMNetworkAdapter -ParameterFilter { $StaticMacAddress -eq '1234567890AB' }
            Mock Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 }
            Mock Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged }

            Context 'Switch Management Adapter does not exist, VlanId not passed, StaticMacAddress not passed' {
                $Splat = $TestAdapter.Clone()
                $Splat.Remove('VlanId')
                $Splat.Remove('StaticMacAddress')
                It 'Does Not Throw Exception' {
                    { UpdateSwitchManagementAdapter @Splat } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Add-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $DynamicMacAddress } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $StaticMacAddress -eq '1234567890AB' } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged } -Exactly 0
                }
            }

            Context 'Switch Management Adapter does not exist, VlanId 10 passed, StaticMacAddress not passed' {
                $Splat = $TestAdapter.Clone()
                $Splat.VlanId = 10
                $Splat.Remove('StaticMacAddress')
                It 'Does Not Throw Exception' {
                    { UpdateSwitchManagementAdapter @Splat } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Add-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $DynamicMacAddress } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $StaticMacAddress -eq '1234567890AB' } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 } -Exactly 1
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged } -Exactly 0
                }
            }

            Context 'Switch Management Adapter does not exist, VlanId null passed, StaticMacAddress not passed' {
                $Splat = $TestAdapter.Clone()
                $Splat.VlanId = $null
                $Splat.Remove('StaticMacAddress')
                It 'Does Not Throw Exception' {
                    { UpdateSwitchManagementAdapter @Splat } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Add-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $DynamicMacAddress } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $StaticMacAddress -eq '1234567890AB' } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged } -Exactly 1
                }
            }

            Context 'Switch Management Adapter does not exist, VlanId not passed, StaticMacAddress passed' {
                $Splat = $TestAdapter.Clone()
                $Splat.Remove('VlanId')
                It 'Does Not Throw Exception' {
                    { UpdateSwitchManagementAdapter @Splat } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Add-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $DynamicMacAddress } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $StaticMacAddress -eq '1234567890AB' } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged } -Exactly 0
                }
            }

            Context 'Switch Management Adapter does not exist, VlanId not passed, empty StaticMacAddress passed' {
                $Splat = $TestAdapter.Clone()
                $Splat.Remove('VlanId')
                $Splat.StaticMacAddress = ''
                It 'Does Not Throw Exception' {
                    { UpdateSwitchManagementAdapter @Splat } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Add-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $DynamicMacAddress } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $StaticMacAddress -eq '1234567890AB' } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged } -Exactly 0
                }
            }

            Mock Get-VMNetworkAdapter -MockWith { @{ Name = 'Adapter Name'; SwitchName = 'Switch Name' } }
            Mock Add-VMNetworkAdapter

            Context 'Switch Management Adapter exists, VlanId passed, StaticMacAddress passed' {
                $Splat = $TestAdapter.Clone()
                It 'Does Not Throw Exception' {
                    { UpdateSwitchManagementAdapter @Splat } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                    Assert-MockCalled Add-VMNetworkAdapter -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $DynamicMacAddress } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapter -ParameterFilter { $StaticMacAddress -eq '1234567890AB' } -Exactly 0
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $VlanId -eq 10 } -Exactly 1
                    Assert-MockCalled Set-VMNetworkAdapterVlan -ParameterFilter { $Untagged } -Exactly 0
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
