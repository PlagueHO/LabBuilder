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

    Describe 'Initialize-LabBootVHD' {
        $Lab = Get-Lab -ConfigPath $script:testConfigOKPath
        [array] $VMs = Get-LabVM -Lab $Lab
        $NanoServerPackagesFolder = Join-Path -Path $Lab.labbuilderconfig.settings.labpath -ChildPath 'NanoServerPackages'
        $ResourceMSUFile = Join-Path -Path $Lab.labbuilderconfig.settings.resourcepathfull -ChildPath "W2K12-KB3191565-x64.msu"

        Mock -CommandName New-Item
        Mock -CommandName Mount-WindowsImage
        Mock -CommandName Dismount-WindowsImage
        Mock -CommandName Add-WindowsPackage
        Mock -CommandName Copy-Item
        Mock -CommandName Remove-Item

        Context 'When valid configuration passed with server VM and an invalid package' {
            It 'Throws a PackageNotFoundError exception' {
                $VM = $VMs[0].Clone()
                $VM.Packages = 'DoesNotExist'
                $exceptionParameters = @{
                    errorId = 'PackageNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.PackageNotFoundError `
                        -f 'DoesNotExist')
                }
                $Exception = Get-LabException @exceptionParameters
                { Initialize-LabBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName New-Item -Exactly 1
                Assert-MockCalled -CommandName Mount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Dismount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Add-WindowsPackage -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName Remove-Item -Exactly 1
            }
        }

        Context 'When valid configuration passed with server VM and one package' {
            Mock -CommandName Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $true }

            It 'Does Not Throw Exception' {
                $VM = $VMs[0].Clone()
                $VM.Packages = 'WMF5.1-WS2012R2-W81'
                { Initialize-LabBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName New-Item -Exactly 4
                Assert-MockCalled -CommandName Mount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Dismount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Add-WindowsPackage -Exactly 1
                Assert-MockCalled -CommandName Copy-Item -Exactly 4
                Assert-MockCalled -CommandName Remove-Item -Exactly 1
            }
        }

        Context 'When valid configuration passed with server VM and one package but MSU does not exist' {
            Mock -CommandName Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $false }

            It 'Throws a PackageMSUNotFoundError exception' {
                $VM = $VMs[0].Clone()
                $VM.Packages = 'WMF5.1-WS2012R2-W81'
                $exceptionParameters = @{
                    errorId = 'PackageMSUNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.PackageMSUNotFoundError `
                        -f 'WMF5.1-WS2012R2-W81',$ResourceMSUFile)
                }
                $exception = Get-LabException @exceptionParameters
                { Initialize-LabBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Throw $exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName New-Item -Exactly 1
                Assert-MockCalled -CommandName Mount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Dismount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Add-WindowsPackage -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName Remove-Item -Exactly 1
                Assert-MockCalled -CommandName Test-Path -Exactly 1
            }
        }

        Context 'When valid configuration passed with Nano Server VM and no packages' {
            Mock -CommandName Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $true }
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "$NanoServerPackagesFolder\*.cab" } -MockWith { $true }

            It 'Does Not Throw Exception' {
                $VM = $VMs[0].Clone()
                $VM.Packages = ''
                $VM.OSType = [LabOStype]::Nano
                { Initialize-LabBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName New-Item -Exactly 4
                Assert-MockCalled -CommandName Mount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Dismount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Add-WindowsPackage -Exactly 2
                Assert-MockCalled -CommandName Copy-Item -Exactly 3
                Assert-MockCalled -CommandName Remove-Item -Exactly 1
                Assert-MockCalled -CommandName Test-Path -Exactly 3
            }
        }

        Context 'When valid configuration passed with Nano Server VM and two packages' {
            Mock -CommandName Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $true }
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "$NanoServerPackagesFolder\*.cab" } -MockWith { $true }

            It 'Does Not Throw Exception' {
                $VM = $VMs[0].Clone()
                $VM.OSType = [LabOStype]::Nano
                $VM.Packages = 'Microsoft-NanoServer-Containers-Package.cab,Microsoft-NanoServer-Guest-Package.cab'
                { Initialize-LabBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName New-Item -Exactly 4
                Assert-MockCalled -CommandName Mount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Dismount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Add-WindowsPackage -Exactly 6
                Assert-MockCalled -CommandName Copy-Item -Exactly 3
                Assert-MockCalled -CommandName Remove-Item -Exactly 1
                Assert-MockCalled -CommandName Test-Path -Exactly 7
            }
        }

        Context 'When valid configuration passed with Nano Server VM and two packages and an MSU' {
            Mock -CommandName Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $true }
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "$NanoServerPackagesFolder\*.cab" } -MockWith { $true }
            Mock -CommandName Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $true }

            It 'Does Not Throw Exception' {
                $VM = $VMs[0].Clone()
                $VM.OSType = [LabOStype]::Nano
                $VM.Packages = 'Microsoft-NanoServer-Containers-Package.cab,Microsoft-NanoServer-Guest-Package.cab,WMF5.1-WS2012R2-W81'
                { Initialize-LabBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName New-Item -Exactly 4
                Assert-MockCalled -CommandName Mount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Dismount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Add-WindowsPackage -Exactly 7
                Assert-MockCalled -CommandName Copy-Item -Exactly 3
                Assert-MockCalled -CommandName Remove-Item -Exactly 1
                Assert-MockCalled -CommandName Test-Path -Exactly 8
            }
        }

        Context 'When valid configuration passed with Nano Server VM and two packages but NanoServerPackages folder missing' {
            Mock -CommandName Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $false }

            It 'Throws a NanoServerPackagesFolderMissingError exception' {
                $VM = $VMs[0].Clone()
                $VM.OSType = [LabOStype]::Nano
                $VM.Packages = 'Microsoft-NanoServer-Containers-Package.cab,Microsoft-NanoServer-Guest-Package.cab'
                $exceptionParameters = @{
                    errorId = 'NanoServerPackagesFolderMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NanoServerPackagesFolderMissingError `
                        -f $NanoServerPackagesFolder)
                }
                $Exception = Get-LabException @exceptionParameters
                { Initialize-LabBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Throw $Exception
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName New-Item -Exactly 1
                Assert-MockCalled -CommandName Mount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Dismount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Add-WindowsPackage -Exactly 0
                Assert-MockCalled -CommandName Copy-Item -Exactly 0
                Assert-MockCalled -CommandName Remove-Item -Exactly 1
                Assert-MockCalled -CommandName Test-Path -Exactly 1
            }
        }

        Context 'When valid configuration Passed' {
            Mock -CommandName Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $true }

            It 'Does Not Throw Exception' {
                $VM = $VMs[0].Clone()
                { Initialize-LabBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled -CommandName New-Item -Exactly 4
                Assert-MockCalled -CommandName Mount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Dismount-WindowsImage -Exactly 1
                Assert-MockCalled -CommandName Add-WindowsPackage -Exactly 1
                Assert-MockCalled -CommandName Copy-Item -Exactly 4
                Assert-MockCalled -CommandName Remove-Item -Exactly 1
                Assert-MockCalled -CommandName Test-Path -Exactly 1
            }
        }
    }

    Describe 'Initialize-LabVHD' {
        function Get-VHD {}
        function Mount-VHD {}

        $VHD = @{
            Path = 'c:\DataVHDx.vhdx'
        }
        $VHDCreate = @{
            Path = $VHD.Path
            PartitionStyle = 'GPT'
            FileSystem = 'NTFS'
        }
        $VHDLabel = @{
            Path = $VHD.Path
            PartitionStyle = 'GPT'
            FileSystem = 'NTFS'
            FileSystemLabel = 'New'
        }
        $Partition1 = New-CimInstance `
                -ClassName 'MSFT_Partition' `
                -Namespace ROOT/Microsoft/Windows/Storage `
                -ClientOnly `
                -Property @{
                    DiskNumber = 9
                    Type = 'Basic'
                    PartitionNumber = 1
                }
        $Partition2 = New-CimInstance `
                -ClassName 'MSFT_Partition' `
                -Namespace ROOT/Microsoft/Windows/Storage `
                -ClientOnly `
                -Property @{
                    DiskNumber = 9
                    Type = 'Basic'
                    PartitionNumber = 2
                }
        $Volume1 = New-CimInstance `
                -ClassName 'MSFT_Volume' `
                -Namespace ROOT/Microsoft/Windows/Storage `
                -ClientOnly `
                -Property @{
                    FileSystem = 'FAT32'
                    FileSystemLabel = 'Volume1'
                }
        $Volume2 = New-CimInstance `
                -ClassName 'MSFT_Volume' `
                -Namespace ROOT/Microsoft/Windows/Storage `
                -ClientOnly `
                -Property @{
                    FileSystem = 'NTFS'
                    FileSystemLabel = 'Volume2'
                }
        $NewVolume = New-CimInstance `
                -ClassName 'MSFT_Volume' `
                -Namespace ROOT/Microsoft/Windows/Storage `
                -ClientOnly `
                -Property @{
                    FileSystem = $VHDLabel.FileSystem
                    FileSystemLabel = $VHDLabel.FileSystemLabel
                }
        $RenamedVolume = New-CimInstance `
                -ClassName 'MSFT_Volume' `
                -Namespace ROOT/Microsoft/Windows/Storage `
                -ClientOnly `
                -Property @{
                    FileSystem = $VHDLabel.FileSystem
                    FileSystemLabel = 'Different'
                }
        $UnformattedVolume = New-CimInstance `
                -ClassName 'MSFT_Volume' `
                -Namespace ROOT/Microsoft/Windows/Storage `
                -ClientOnly `
                -Property @{
                    FileSystem = ''
                    FileSystemLabel = $VHDLabel.FileSystemLabel
                }

        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Get-VHD
        Mock -CommandName Mount-VHD
        Mock -CommandName Get-Disk
        Mock -CommandName Initialize-Disk
        Mock -CommandName Get-Partition
        Mock -CommandName New-Partition
        Mock -CommandName Get-Volume
        Mock -CommandName Format-Volume
        Mock -CommandName Set-Volume
        Mock -CommandName Set-Partition
        Mock -CommandName Add-PartitionAccessPath

        Context 'When VHDx file does not exist' {
            It 'Throws a FileNotFoundError Exception' {
                $Splat = $VHD.Clone()
                $exceptionParameters = @{
                    errorId = 'FileNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.FileNotFoundError `
                        -f "VHD",$Splat.Path)
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabVHD @Splat } | Should -Throw $Exception
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 0
                Assert-MockCalled -CommandName Mount-VHD -Exactly 0
                Assert-MockCalled -CommandName Get-Disk -Exactly 0
                Assert-MockCalled -CommandName Initialize-Disk -Exactly 0
                Assert-MockCalled -CommandName Get-Partition -Exactly 0
                Assert-MockCalled -CommandName New-Partition -Exactly 0
                Assert-MockCalled -CommandName Get-Volume -Exactly 0
                Assert-MockCalled -CommandName Format-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Partition -Exactly 0
                Assert-MockCalled -CommandName Add-PartitionAccessPath -Exactly 0
            }
        }

        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-VHD -MockWith { @{ Attached = $false; DiskNumber = 9 } }
        Mock -CommandName Get-Disk -MockWith { @{ PartitionStyle = 'RAW' } }

        Context 'When VHDx file exists is not mounted, is not initialized and partition style is not passed' {
            It 'Throws a InitializeVHDNotInitializedError Exception' {
                $Splat = $VHD.Clone()
                $exceptionParameters = @{
                    errorId = 'InitializeVHDNotInitializedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InitializeVHDNotInitializedError `
                        -f$Splat.Path)
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabVHD @Splat } | Should -Throw $Exception
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 2
                Assert-MockCalled -CommandName Mount-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-Disk -Exactly 1
                Assert-MockCalled -CommandName Initialize-Disk -Exactly 0
                Assert-MockCalled -CommandName Get-Partition -Exactly 0
                Assert-MockCalled -CommandName New-Partition -Exactly 0
                Assert-MockCalled -CommandName Get-Volume -Exactly 0
                Assert-MockCalled -CommandName Format-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Partition -Exactly 0
                Assert-MockCalled -CommandName Add-PartitionAccessPath -Exactly 0
            }
        }

        Mock -CommandName Get-Disk -MockWith { @{ PartitionStyle = $VHDLabel.PartitionStyle } }
        Mock -CommandName Get-Partition -MockWith { @( $Partition1 ) }
        Mock -CommandName Get-Volume -MockWith { $NewVolume } -ParameterFilter { $Partition -eq $Partition1 }
        Mock -CommandName Get-Volume -MockWith { $Volume2 } -ParameterFilter { $Partition -eq $Partition2 }
        Mock -CommandName Set-Volume -MockWith { $RenamedVolume }

        Context 'When VHDx file exists is not mounted, is initialized, has 1 partition the volume FileSystemLabel is different' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()
                $Splat.FileSystemLabel = 'Different'

                Initialize-LabVHD @Splat | Should -Be $RenamedVolume
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 2
                Assert-MockCalled -CommandName Mount-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-Disk -Exactly 1
                Assert-MockCalled -CommandName Initialize-Disk -Exactly 0
                Assert-MockCalled -CommandName Get-Partition -Exactly 1
                Assert-MockCalled -CommandName New-Partition -Exactly 0
                Assert-MockCalled -CommandName Get-Volume -Exactly 2
                Assert-MockCalled -CommandName Format-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Volume -Exactly 1
                Assert-MockCalled -CommandName Set-Partition -Exactly 0
                Assert-MockCalled -CommandName Add-PartitionAccessPath -Exactly 0
            }
        }

        Mock -CommandName Get-Partition -MockWith { @( $Partition1,$Partition2 ) }
        Mock -CommandName Get-Volume -MockWith { $Volume1 } -ParameterFilter { $Partition -eq $Partition1 }
        Mock -CommandName Get-Volume -MockWith { $Volume2 } -ParameterFilter { $Partition -eq $Partition2 }

        Context 'When VHDx file exists is not mounted, is initialized, has 2 partitions' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()
                $Splat.FileSystemLabel = 'Different'

                Initialize-LabVHD @Splat | Should -Be $RenamedVolume
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 2
                Assert-MockCalled -CommandName Mount-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-Disk -Exactly 1
                Assert-MockCalled -CommandName Initialize-Disk -Exactly 0
                Assert-MockCalled -CommandName Get-Partition -Exactly 1
                Assert-MockCalled -CommandName New-Partition -Exactly 0
                Assert-MockCalled -CommandName Get-Volume -Exactly 3
                Assert-MockCalled -CommandName Format-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Volume -Exactly 1
                Assert-MockCalled -CommandName Set-Partition -Exactly 0
                Assert-MockCalled -CommandName Add-PartitionAccessPath -Exactly 0
            }
        }

        Mock -CommandName Get-Disk -MockWith { @{ PartitionStyle = 'RAW' } }
        Mock -CommandName Get-Partition
        Mock -CommandName New-Partition -MockWith { @( $Partition1 ) }
        Mock -CommandName Get-Volume -MockWith { $UnformattedVolume } -ParameterFilter { $Partition -eq $Partition1 }
        Mock -CommandName Format-Volume -MockWith { @( $NewVolume ) }

        Context 'When VHDx file exists is not mounted, is not initialized and label is passed' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()

                Initialize-LabVHD @Splat | Should -Be $NewVolume
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 2
                Assert-MockCalled -CommandName Mount-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-Disk -Exactly 1
                Assert-MockCalled -CommandName Initialize-Disk -Exactly 1
                Assert-MockCalled -CommandName Get-Partition -Exactly 1
                Assert-MockCalled -CommandName New-Partition -Exactly 1
                Assert-MockCalled -CommandName Get-Volume -Exactly 2
                Assert-MockCalled -CommandName Format-Volume -Exactly 1
                Assert-MockCalled -CommandName Set-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Partition -Exactly 0
                Assert-MockCalled -CommandName Add-PartitionAccessPath -Exactly 0
            }
        }

        Context 'When VHDx file exists is not mounted, is not initialized and label and DriveLetter passed' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()
                $Splat.DriveLetter = 'X'

                Initialize-LabVHD @Splat | Should -Be $UnformattedVolume # would be NewVolume but Get-Volume is mocked to this.
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 2
                Assert-MockCalled -CommandName Mount-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-Disk -Exactly 1
                Assert-MockCalled -CommandName Initialize-Disk -Exactly 1
                Assert-MockCalled -CommandName Get-Partition -Exactly 1
                Assert-MockCalled -CommandName New-Partition -Exactly 1
                Assert-MockCalled -CommandName Get-Volume -Exactly 3
                Assert-MockCalled -CommandName Format-Volume -Exactly 1
                Assert-MockCalled -CommandName Set-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Partition -Exactly 1
                Assert-MockCalled -CommandName Add-PartitionAccessPath -Exactly 0
            }
        }

        Context 'When VHDx file exists is not mounted, is not initialized and label and AccessPath passed' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()
                $Splat.AccessPath = 'c:\Exists'

                Initialize-LabVHD @Splat | Should -Be $NewVolume
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 2
                Assert-MockCalled -CommandName Mount-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-Disk -Exactly 1
                Assert-MockCalled -CommandName Initialize-Disk -Exactly 1
                Assert-MockCalled -CommandName Get-Partition -Exactly 1
                Assert-MockCalled -CommandName New-Partition -Exactly 1
                Assert-MockCalled -CommandName Get-Volume -Exactly 2
                Assert-MockCalled -CommandName Format-Volume -Exactly 1
                Assert-MockCalled -CommandName Set-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Partition -Exactly 0
                Assert-MockCalled -CommandName Add-PartitionAccessPath -Exactly 1
            }
        }

        Mock -CommandName Test-Path -ParameterFilter { $Path -eq 'c:\DoesNotExist' } -MockWith { $false }

        Context 'When VHDx file exists is not mounted, is not initialized and invalid AccessPath passed' {
            It 'Throws a InitializeVHDAccessPathNotFoundError Exception' {
                $Splat = $VHDLabel.Clone()
                $Splat.AccessPath = 'c:\DoesNotExist'

                $exceptionParameters = @{
                    errorId = 'InitializeVHDAccessPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InitializeVHDAccessPathNotFoundError `
                        -f$Splat.Path,'c:\DoesNotExist')
                }
                $Exception = Get-LabException @exceptionParameters

                { Initialize-LabVHD @Splat } | Should -Throw $Exception
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Get-VHD -Exactly 2
                Assert-MockCalled -CommandName Mount-VHD -Exactly 1
                Assert-MockCalled -CommandName Get-Disk -Exactly 1
                Assert-MockCalled -CommandName Initialize-Disk -Exactly 1
                Assert-MockCalled -CommandName Get-Partition -Exactly 1
                Assert-MockCalled -CommandName New-Partition -Exactly 1
                Assert-MockCalled -CommandName Get-Volume -Exactly 2
                Assert-MockCalled -CommandName Format-Volume -Exactly 1
                Assert-MockCalled -CommandName Set-Volume -Exactly 0
                Assert-MockCalled -CommandName Set-Partition -Exactly 0
                Assert-MockCalled -CommandName Add-PartitionAccessPath -Exactly 0
            }
        }
    }
}
