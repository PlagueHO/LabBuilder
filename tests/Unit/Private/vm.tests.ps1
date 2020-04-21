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

    Describe 'New-LabVMInitializationFile' -Tags 'Incomplete' {
    }

    Describe 'Get-LabUnattendFileContent' -Tags 'Incomplete' {
    }

    Describe 'Get-LabCertificatePsFileContent' -Tags 'Incomplete' {
    }

    Describe 'Recieve-LabSelfSignedCertificate' -Tags 'Incomplete' {
    }

    Describe 'Request-LabSelfSignedCertificate' -Tags 'Incomplete' {
    }

    Describe 'New-LabHostSelfSignedCertificate' -Tags 'Incomplete' {
    }

    Describe 'Wait-LabVMInitializationComplete' -Tags 'Incomplete' {
    }

    Describe 'Wait-LabVMStarted' -Tags 'Incomplete'  {
    }

    Describe 'Wait-LabVMOff' -Tags 'Incomplete'  {
    }

    Describe 'Get-LabIntegrationServiceName' {
        Mock -CommandName Get-CimInstance `
            -ParameterFilter { $Class -eq 'Msvm_VssComponentSettingData' } `
            -MockWith { @{ Caption = 'VSS' }}
        Mock -CommandName Get-CimInstance `
            -ParameterFilter { $Class -eq 'Msvm_ShutdownComponentSettingData' } `
            -MockWith { @{ Caption = 'Shutdown' }}
        Mock -CommandName Get-CimInstance `
            -ParameterFilter { $Class -eq 'Msvm_TimeSyncComponentSettingData' } `
            -MockWith { @{ Caption = 'Time Synchronization' }}
        Mock -CommandName Get-CimInstance `
            -ParameterFilter { $Class -eq 'Msvm_HeartbeatComponentSettingData' } `
            -MockWith { @{ Caption = 'Heartbeat' }}
        Mock -CommandName Get-CimInstance `
            -ParameterFilter { $Class -eq 'Msvm_GuestServiceInterfaceComponentSettingData' } `
            -MockWith { @{ Caption = 'Guest Service Interface' }}
        Mock -CommandName Get-CimInstance `
            -ParameterFilter { $Class -eq 'Msvm_KvpExchangeComponentSettingData' } `
            -MockWith { @{ Caption = 'Key-Value Pair Exchange' }}

        Context 'When called' {
            It 'Returns expected Integration Service names' {
                Get-LabIntegrationServiceName | Should -Be @(
                    'VSS'
                    'Shutdown'
                    'Time Synchronization'
                    'Heartbeat'
                    'Guest Service Interface'
                    'Key-Value Pair Exchange'
                )
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-CimInstance -Exactly 6
            }
        }
    }

    Describe 'Update-LabVMIntegrationService' {
        function Get-VMIntegrationService {}
        function Enable-VMIntegrationService {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromPipeline = $true)]
                $Name,

                [Parameter()]
                $VM
            )
        }
        function Disable-VMIntegrationService {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromPipeline = $true)]
                $Name,

                [Parameter()]
                $VM
            )
        }

        Mock -CommandName Get-LabIntegrationServiceName -MockWith {
            @(
                'VSS'
                'Shutdown'
                'Time Synchronization'
                'Heartbeat'
                'Guest Service Interface'
                'Key-Value Pair Exchange'
            )
        }
        Mock -CommandName Get-VMIntegrationService -MockWith { @(
            @{ Name = 'Guest Service Interface'; Enabled = $false }
            @{ Name = 'Heartbeat'; Enabled = $true }
            @{ Name = 'Key-Value Pair Exchange'; Enabled = $false }
            @{ Name = 'Shutdown'; Enabled = $true }
            @{ Name = 'Time Synchronization'; Enabled = $true }
            @{ Name = 'VSS'; Enabled = $true }
        ) }
        Mock -CommandName Enable-VMIntegrationService
        Mock -CommandName Disable-VMIntegrationService

        $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
        [array] $Templates = Get-LabVMTemplate -Lab $Lab
        [array] $Switches = Get-LabSwitch -Lab $Lab

        Context 'When valid configuration is passed with null Integration Services' {
            [array] $VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = $null

            It 'Does not throw an Exception' {
                { Update-LabVMIntegrationService -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMIntegrationService -Exactly 1
                Assert-MockCalled -CommandName Enable-VMIntegrationService -Exactly 2
                Assert-MockCalled -CommandName Disable-VMIntegrationService -Exactly 0
            }
        }

        Context 'When valid configuration is passed with blank Integration Services' {
            [array] $VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = ''

            It 'Does not throw an Exception' {
                { Update-LabVMIntegrationService -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMIntegrationService -Exactly 1
                Assert-MockCalled -CommandName Enable-VMIntegrationService -Exactly 0
                Assert-MockCalled -CommandName Disable-VMIntegrationService -Exactly 4
            }
        }

        Context 'When valid configuration is passed with VSS only enabled' {
            [array] $VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = 'VSS'

            It 'Does not throw an Exception' {
                { Update-LabVMIntegrationService -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMIntegrationService -Exactly 1
                Assert-MockCalled -CommandName Enable-VMIntegrationService -Exactly 0
                Assert-MockCalled -CommandName Disable-VMIntegrationService -Exactly 3
            }
        }

        Context 'When valid configuration is passed with Guest Service Interface only enabled' {
            [array] $VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = 'Guest Service Interface'

            It 'Does not throw an Exception' {
                { Update-LabVMIntegrationService -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMIntegrationService -Exactly 1
                Assert-MockCalled -CommandName Enable-VMIntegrationService -Exactly 1
                Assert-MockCalled -CommandName Disable-VMIntegrationService -Exactly 4
            }
        }
    }


    Describe 'Update-LabVMDataDisk' {
        function Get-VM {}
        function Get-VHD {}
        function Resize-VHD {}
        function New-VHD {}
        function Get-VMHardDiskDrive {}
        function Add-VMHardDiskDrive {}
        function Mount-VHD {}
        function Dismount-VHD {}

        Mock -CommandName Get-VM
        Mock -CommandName Get-VHD
        Mock -CommandName Resize-VHD
        Mock -CommandName Move-Item
        Mock -CommandName Copy-Item
        Mock -CommandName New-VHD
        Mock -CommandName Get-VMHardDiskDrive
        Mock -CommandName Add-VMHardDiskDrive
        Mock -CommandName Test-Path -ParameterFilter { $Path -eq 'DoesNotExist.Vhdx' } -MockWith { $false }
        Mock -CommandName Test-Path -ParameterFilter { $Path -eq 'DoesExist.Vhdx' } -MockWith { $true }
        Mock -CommandName Initialize-LabVHD
        Mock -CommandName Mount-VHD
        Mock -CommandName Dismount-VHD
        Mock -CommandName Copy-Item
        Mock -CommandName New-Item

        # The same VM will be used for all tests, but a different
        # DataVHds array will be created/assigned for each test.
        $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
        [array] $Templates = Get-LabVMTemplate -Lab $Lab
        [array] $Switches = Get-LabSwitch -Lab $Lab
        [array] $VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches

        Context 'When valid configuration is passed with no DataVHDs' {
            $VMs[0].DataVHDs = @()

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a DataVHD that exists but has different type' {
            $DataVHD = [LabDataVHD]::New('DoesExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Fixed
            $DataVHD.Size = 10GB
            $VMs[0].DataVHDs = @( $DataVHD )

            Mock -CommandName Get-VHD -MockWith { @{
                VhdType =  'Dynamic'
            } }

            It 'Throws VMDataDiskVHDConvertError Exception' {
                $exceptionParameters = @{
                    errorId = 'VMDataDiskVHDConvertError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDConvertError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs.Vhd,$VMs[0].DataVHDs.VhdType)
                }
                $exception = Get-LabException @exceptionParameters
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Throw $exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 1
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }
        Context 'When valid configuration is passed with a DataVHD that exists but has smaller size' {
            $DataVHD = [LabDataVHD]::New('DoesExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Fixed
            $DataVHD.Size = 10GB
            $VMs[0].DataVHDs = @( $DataVHD )

            Mock -CommandName Get-VHD -MockWith { @{
                VhdType =  'Fixed'
                Size = 20GB
            } }

            It 'Throws VMDataDiskVHDShrinkError Exception' {
                $exceptionParameters = @{
                    errorId = 'VMDataDiskVHDShrinkError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDShrinkError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].Vhd,$VMs[0].DataVHDs[0].Size)
                }
                $Exception = Get-LabException @exceptionParameters
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 1
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a DataVHD that exists but has larger size' {
            $DataVHD = [LabDataVHD]::New('DoesExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Fixed
            $DataVHD.Size = 30GB
            $VMs[0].DataVHDs = @( $DataVHD )

            Mock -CommandName Get-VHD -MockWith { @{
                VhdType =  'Fixed'
                Size = 20GB
            } }

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 1
                Assert-MockCalled -CommandName Resize-VHD -Exactly 1
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Mock -CommandName Get-VHD

        Context 'When valid configuration is passed with a SourceVHD and DataVHD that does not exist' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.SourceVhd = 'DoesNotExist.Vhdx'
            $VMs[0].DataVHDs = @( $DataVHD )
            It 'Throws VMDataDiskSourceVHDNotFoundError Exception' {
                $exceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].SourceVhd)
                }
                $Exception = Get-LabException @exceptionParameters
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a SourceVHD that exists and DataVHD that does not exist' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.SourceVhd = 'DoesExist.Vhdx'
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 1
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a SourceVHD that exists and DataVHD that do not exist and MoveSourceVHD set' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.SourceVhd = 'DoesExist.Vhdx'
            $DataVHD.MoveSourceVHD = $true
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 1
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a 10GB Fixed DataVHD that does not exist' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Fixed
            $DataVHD.Size = 10GB
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a 10GB Dynamic DataVHD that does not exist' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Dynamic
            $DataVHD.Size = 10GB
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a 10GB Dynamic DataVHD that does not exist and PartitionStyle and FileSystem is set' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Dynamic
            $DataVHD.Size = 10GB
            $DataVHD.PartitionStyle = [LabPartitionStyle]::GPT
            $DataVHD.FileSystem = [LabFileSystem]::NTFS
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 1
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 1
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a 10GB Dynamic DataVHD that does not exist and PartitionStyle, FileSystem and CopyFolders is set' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Dynamic
            $DataVHD.Size = 10GB
            $DataVHD.PartitionStyle = [LabPartitionStyle]::GPT
            $DataVHD.FileSystem = [LabFileSystem]::NTFS
            $DataVHD.CopyFolders = "$script:testConfigPath\ExpectedContent"
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 1
                Assert-MockCalled -CommandName New-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 1
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 1
                Assert-MockCalled -CommandName New-Item -Exactly 1
            }
        }

        Context 'When valid configuration is passed with a 10GB Dynamic DataVHD that does not exist and CopyFolders is set' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Dynamic
            $DataVHD.Size = 10GB
            $DataVHD.CopyFolders = "$script:testConfigPath\ExpectedContent"
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 1
                Assert-MockCalled -CommandName New-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 1
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 1
                Assert-MockCalled -CommandName New-Item -Exactly 1
            }
        }

        Context 'When valid configuration is passed with a 10GB Differencing DataVHD that does not exist where ParentVHD is not set' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Differencing
            $DataVHD.Size = 10GB
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Throws VMDataDiskParentVHDMissingError Exception' {
                $exceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                        -f $VMs[0].Name)
                }
                $Exception = Get-LabException @exceptionParameters
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a 10GB Differencing DataVHD that does not exist where ParentVHD does not exist' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Differencing
            $DataVHD.Size = 10GB
            $DataVHD.ParentVHD = 'DoesNotExist.vhdx'
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Throws VMDataDiskParentVHDNotFoundError Exception' {
                $exceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].ParentVhd)
                }
                $Exception = Get-LabException @exceptionParameters
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a 10GB Differencing DataVHD that does not exist' {
            $DataVHD = [LabDataVHD]::New('DoesNotExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Dynamic
            $DataVHD.Size = 10GB
            $DataVHD.ParentVHD = 'DoesExist.vhdx'
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }

        Mock -CommandName Get-VHD -MockWith { @{
            VhdType =  'Fixed'
            Size = 10GB
        } }

        Context 'When valid configuration is passed with a 10GB Fixed DataVHD that exists and is already added to VM' {
            Mock -CommandName Get-VMHardDiskDrive -MockWith { @{ Path = 'DoesExist.vhdx' } }
            $DataVHD = [LabDataVHD]::New('DoesExist.vhdx')
            $DataVHD.VhdType = [LabVHDType]::Fixed
            $DataVHD.Size = 10GB
            $VMs[0].DataVHDs = @( $DataVHD )

            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 1
                Assert-MockCalled -CommandName Resize-VHD -Exactly 0
                Assert-MockCalled -CommandName Move-Item -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName New-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled -CommandName Initialize-LabVHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Dismount-VHD -Exactly 0
                Assert-MockCalled -CommandName New-Item -Exactly 0
            }
        }
    }

    Describe 'Update-LabVMDvdDrive' {
        function Get-VMDVDDrive {}
        function Add-VMDVDDrive {}
        function Set-VMDVDDrive {}

        Mock -CommandName Get-VMDVDDrive
        Mock -CommandName Add-VMDVDDrive
        Mock -CommandName Set-VMDVDDrive

        # The same VM will be used for all tests, but a different
        # DVD Drives array will be created/assigned for each test.
        $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
        [array] $Templates = Get-LabVMTemplate -Lab $Lab
        [array] $Switches = Get-LabSwitch -Lab $Lab
        [array] $VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches

        Context 'When valid configuration is passed with no DVDDrives' {
            $VMs[0].DVDDrives = @()

            It 'Does not throw an Exception' {
                { Update-LabVMDvdDrive -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMDVDDrive -Exactly 0
                Assert-MockCalled -CommandName Add-VMDVDDrive -Exactly 0
                Assert-MockCalled -CommandName Set-VMDVDDrive -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a DVD Drive that is empty and empty DVD Drive exists' {
            $DVDDrive = [LabDVDDrive]::New()
            $VMs[0].DVDDrives = @( $DVDDrive )

            Mock -CommandName Get-VMDVDDrive -MockWith { @{
                Path = $null
                ControllerNumber = 0
                ControllerLocation = 1
            } }

            It 'Does not throw an Exception' {
                { Update-LabVMDvdDrive -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMDVDDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMDVDDrive -Exactly 0
                Assert-MockCalled -CommandName Set-VMDVDDrive -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a DVD Drive that is empty and DVD Drive exists but is not empty' {
            $DVDDrive = [LabDVDDrive]::New()
            $VMs[0].DVDDrives = @( $DVDDrive )

            Mock -CommandName Get-VMDVDDrive -MockWith { @{
                Path = 'SQL2014_FULL_ENU.iso'
                ControllerNumber = 0
                ControllerLocation = 1
            } }

            It 'Does not throw an Exception' {
                { Update-LabVMDvdDrive -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMDVDDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMDVDDrive -Exactly 0
                Assert-MockCalled -CommandName Set-VMDVDDrive -Exactly 1
            }
        }

        Context 'When valid configuration is passed with a DVD Drive that has an ISO and DVD Drive exists but is empty' {
            $DVDDrive = [LabDVDDrive]::New()
            $DVDDrive.Path = 'SQL2014_FULL_ENU.iso'
            $VMs[0].DVDDrives = @( $DVDDrive )

            Mock -CommandName Get-VMDVDDrive -MockWith { @{
                Path = $null
                ControllerNumber = 0
                ControllerLocation = 1
            } }

            It 'Does not throw an Exception' {
                { Update-LabVMDvdDrive -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMDVDDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMDVDDrive -Exactly 0
                Assert-MockCalled -CommandName Set-VMDVDDrive -Exactly 1
            }
        }

        Context 'When valid configuration is passed with a DVD Drive that has an ISO and DVD Drive exists but contains a different ISO' {
            $DVDDrive = [LabDVDDrive]::New()
            $DVDDrive.Path = 'SQL2014_FULL_ENU.iso'
            $VMs[0].DVDDrives = @( $DVDDrive )

            Mock -CommandName Get-VMDVDDrive -MockWith { @{
                Path = 'SQL2012_FULL_ENU.iso'
                ControllerNumber = 0
                ControllerLocation = 1
            } }

            It 'Does not throw an Exception' {
                { Update-LabVMDvdDrive -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMDVDDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMDVDDrive -Exactly 0
                Assert-MockCalled -CommandName Set-VMDVDDrive -Exactly 1
            }
        }

        Context 'When valid configuration is passed with a DVD Drive that has an ISO and DVD Drive exists and has the same ISO' {
            $DVDDrive = [LabDVDDrive]::New()
            $DVDDrive.Path = 'SQL2014_FULL_ENU.iso'
            $VMs[0].DVDDrives = @( $DVDDrive )

            Mock -CommandName Get-VMDVDDrive -MockWith { @{
                Path = 'SQL2014_FULL_ENU.iso'
                ControllerNumber = 0
                ControllerLocation = 1
            } }

            It 'Does not throw an Exception' {
                { Update-LabVMDvdDrive -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMDVDDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMDVDDrive -Exactly 0
                Assert-MockCalled -CommandName Set-VMDVDDrive -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a DVD Drive that has an ISO and no DVD Drives exist' {
            $DVDDrive = [LabDVDDrive]::New()
            $DVDDrive.Path = 'SQL2014_FULL_ENU.iso'
            $VMs[0].DVDDrives = @( $DVDDrive )

            Mock -CommandName Get-VMDVDDrive

            It 'Does not throw an Exception' {
                { Update-LabVMDvdDrive -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMDVDDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMDVDDrive -Exactly 1
                Assert-MockCalled -CommandName Set-VMDVDDrive -Exactly 0
            }
        }

        Context 'When valid configuration is passed with a DVD Drive that is empty and no DVD Drives exist' {
            $DVDDrive = [LabDVDDrive]::New()
            $VMs[0].DVDDrives = @( $DVDDrive )

            Mock -CommandName Get-VMDVDDrive

            It 'Does not throw an Exception' {
                { Update-LabVMDvdDrive -Lab $Lab -VM $VMs[0] } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName Get-VMDVDDrive -Exactly 1
                Assert-MockCalled -CommandName Add-VMDVDDrive -Exactly 1
                Assert-MockCalled -CommandName Set-VMDVDDrive -Exactly 0
            }
        }
    }
}
