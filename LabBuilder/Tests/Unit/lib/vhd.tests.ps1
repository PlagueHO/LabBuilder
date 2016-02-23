$Global:ModuleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)))

$OldLocation = Get-Location
Set-Location -Path $ModuleRoot
if (Get-Module LabBuilder -All)
{
    Get-Module LabBuilder -All | Remove-Module
}

Import-Module "$Global:ModuleRoot\LabBuilder.psd1" -Force -DisableNameChecking
$Global:TestConfigPath = "$Global:ModuleRoot\Tests\PesterTestConfig"
$Global:TestConfigOKPath = "$Global:TestConfigPath\PesterTestConfig.OK.xml"
$Global:ArtifactPath = "$Global:ModuleRoot\Artifacts"
$Global:ExpectedContentPath = "$Global:TestConfigPath\ExpectedContent"
$null = New-Item -Path "$Global:ArtifactPath" -ItemType Directory -Force -ErrorAction SilentlyContinue

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
    


    Describe 'InitializeBootVHD' {
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [array] $VMs = Get-LabVM -Config $Config
        $NanoServerPackagesFolder = Join-Path -Path $Config.labbuilderconfig.settings.labpath -ChildPath 'NanoServerPackages'

        Mock New-Item
        Mock Mount-WindowsImage
        Mock DownloadAndUnzipFile
        Mock Dismount-WindowsImage
        Mock Add-WindowsPackage
        Mock Copy-Item
        Mock Remove-Item

        Context 'Valid Configuration Passed with no install MSU' {	
            It 'Does Not Throw Exception' {
                $VM = $VMs[0].Clone()
                $VM.InstallMSU = ''
                { InitializeBootVHD -Config $Config -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled New-Item -Exactly 3
                Assert-MockCalled Mount-WindowsImage -Exactly 1
                Assert-MockCalled DownloadAndUnzipFile -Exactly 0
                Assert-MockCalled Dismount-WindowsImage -Exactly 1
                Assert-MockCalled Add-WindowsPackage -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 4
                Assert-MockCalled Remove-Item -Exactly 1
            }
        }
        Context 'Valid Configuration Passed with Nano Server VM' {	
            Mock Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $True }
            It 'Does Not Throw Exception' {
                $VM = $VMs[0].Clone()
                $VM.OSType = 'Nano'
                { InitializeBootVHD -Config $Config -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled New-Item -Exactly 3
                Assert-MockCalled Mount-WindowsImage -Exactly 1
                Assert-MockCalled DownloadAndUnzipFile -Exactly 1
                Assert-MockCalled Dismount-WindowsImage -Exactly 1
                Assert-MockCalled Add-WindowsPackage -Exactly 3
                Assert-MockCalled Copy-Item -Exactly 3
                Assert-MockCalled Remove-Item -Exactly 1
            }
        }
        Context 'Valid Configuration Passed with Nano Server VM but NanoServerPackages folder missing' {	
            Mock Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $False }
            It 'Throws a NanoServerPackagesFolderMissingError exception' {
                $VM = $VMs[0].Clone()
                $VM.OSType = 'Nano'
                $ExceptionParameters = @{
                    errorId = 'NanoServerPackagesFolderMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NanoServerPackagesFolderMissingError `
                        -f $NanoServerPackagesFolder)
                }
                $Exception = GetException @ExceptionParameters
                { InitializeBootVHD -Config $Config -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled New-Item -Exactly 1
                Assert-MockCalled Mount-WindowsImage -Exactly 1
                Assert-MockCalled DownloadAndUnzipFile -Exactly 1
                Assert-MockCalled Dismount-WindowsImage -Exactly 1
                Assert-MockCalled Add-WindowsPackage -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 1
            }
        }
        Context 'Valid Configuration Passed' {	
            It 'Does Not Throw Exception' {
                $VM = $VMs[0].Clone()
                { InitializeBootVHD -Config $Config -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled New-Item -Exactly 3
                Assert-MockCalled Mount-WindowsImage -Exactly 1
                Assert-MockCalled DownloadAndUnzipFile -Exactly 1
                Assert-MockCalled Dismount-WindowsImage -Exactly 1
                Assert-MockCalled Add-WindowsPackage -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 4
                Assert-MockCalled Remove-Item -Exactly 1
            }
        }
    }



    Describe 'InitializeVHD' {
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
        
        Mock Test-Path -MockWith { $False } 
        Mock Get-VHD
        Mock Mount-VHD
        Mock Get-Disk
        Mock Initialize-Disk
        Mock Get-Partition
        Mock New-Partition
        Mock Get-Volume
        Mock Format-Volume
        Mock Set-Volume
        Mock Set-Partition
        Mock Add-PartitionAccessPath
        Context 'VHDx file does not exist' {
            It 'Throws a FileNotFoundError Exception' {
                $Splat = $VHD.Clone()
                $ExceptionParameters = @{
                    errorId = 'FileNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.FileNotFoundError `
                        -f "VHD",$Splat.Path)
                }
                $Exception = GetException @ExceptionParameters

                { InitializeVHD @Splat } | Should Throw $Exception
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Get-Disk -Exactly 0
                Assert-MockCalled Initialize-Disk -Exactly 0
                Assert-MockCalled Get-Partition -Exactly 0
                Assert-MockCalled New-Partition -Exactly 0
                Assert-MockCalled Get-Volume -Exactly 0
                Assert-MockCalled Format-Volume -Exactly 0
                Assert-MockCalled Set-Volume -Exactly 0
                Assert-MockCalled Set-Partition -Exactly 0
                Assert-MockCalled Add-PartitionAccessPath -Exactly 0
            }
        }
        Mock Test-Path -MockWith { $True } 
        Mock Get-VHD -MockWith { @{ Attached = $False; DiskNumber = 9 } }
        Mock Get-Disk -MockWith { @{ PartitionStyle = 'RAW' } }
        Context 'VHDx file exists is not mounted, is not initialized and partition style is not passed' {
            It 'Throws a InitializeVHDNotInitializedError Exception' {
                $Splat = $VHD.Clone()
                $ExceptionParameters = @{
                    errorId = 'InitializeVHDNotInitializedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InitializeVHDNotInitializedError `
                        -f$Splat.Path)
                }
                $Exception = GetException @ExceptionParameters

                { InitializeVHD @Splat } | Should Throw $Exception
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VHD -Exactly 2
                Assert-MockCalled Mount-VHD -Exactly 1
                Assert-MockCalled Get-Disk -Exactly 1
                Assert-MockCalled Initialize-Disk -Exactly 0
                Assert-MockCalled Get-Partition -Exactly 0
                Assert-MockCalled New-Partition -Exactly 0
                Assert-MockCalled Get-Volume -Exactly 0
                Assert-MockCalled Format-Volume -Exactly 0
                Assert-MockCalled Set-Volume -Exactly 0
                Assert-MockCalled Set-Partition -Exactly 0
                Assert-MockCalled Add-PartitionAccessPath -Exactly 0
            }
        }
        Mock Get-Disk -MockWith { @{ PartitionStyle = $VHDLabel.PartitionStyle } }
        Mock Get-Partition -MockWith { @( $Partition1 ) }
        Mock Get-Volume -MockWith { $NewVolume } -ParameterFilter { $Partition -eq $Partition1 }
        Mock Get-Volume -MockWith { $Volume2 } -ParameterFilter { $Partition -eq $Partition2 }
        Mock Set-Volume -MockWith { $RenamedVolume }
        Context 'VHDx file exists is not mounted, is initialized, has 1 partition the volume FileSystemLabel is different' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()
                $Splat.FileSystemLabel = 'Different'

                InitializeVHD @Splat | Should Be $RenamedVolume
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VHD -Exactly 2
                Assert-MockCalled Mount-VHD -Exactly 1
                Assert-MockCalled Get-Disk -Exactly 1
                Assert-MockCalled Initialize-Disk -Exactly 0
                Assert-MockCalled Get-Partition -Exactly 1
                Assert-MockCalled New-Partition -Exactly 0
                Assert-MockCalled Get-Volume -Exactly 2
                Assert-MockCalled Format-Volume -Exactly 0
                Assert-MockCalled Set-Volume -Exactly 1
                Assert-MockCalled Set-Partition -Exactly 0
                Assert-MockCalled Add-PartitionAccessPath -Exactly 0
            }
        }
        Mock Get-Partition -MockWith { @( $Partition1,$Partition2 ) }
        Mock Get-Volume -MockWith { $Volume1 } -ParameterFilter { $Partition -eq $Partition1 }
        Mock Get-Volume -MockWith { $Volume2 } -ParameterFilter { $Partition -eq $Partition2 }
        Context 'VHDx file exists is not mounted, is initialized, has 2 partitions' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()
                $Splat.FileSystemLabel = 'Different'

                InitializeVHD @Splat | Should Be $RenamedVolume
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VHD -Exactly 2
                Assert-MockCalled Mount-VHD -Exactly 1
                Assert-MockCalled Get-Disk -Exactly 1
                Assert-MockCalled Initialize-Disk -Exactly 0
                Assert-MockCalled Get-Partition -Exactly 1
                Assert-MockCalled New-Partition -Exactly 0
                Assert-MockCalled Get-Volume -Exactly 3
                Assert-MockCalled Format-Volume -Exactly 0
                Assert-MockCalled Set-Volume -Exactly 1
                Assert-MockCalled Set-Partition -Exactly 0
                Assert-MockCalled Add-PartitionAccessPath -Exactly 0
            }
        }        
        Mock Get-Disk -MockWith { @{ PartitionStyle = 'RAW' } }
        Mock Get-Partition 
        Mock New-Partition -MockWith { @( $Partition1 ) }
        Mock Get-Volume -MockWith { $UnformattedVolume } -ParameterFilter { $Partition -eq $Partition1 }
        Mock Format-Volume -MockWith { @( $NewVolume ) }
        Context 'VHDx file exists is not mounted, is not initialized and label is passed' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()

                InitializeVHD @Splat | Should Be $NewVolume
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VHD -Exactly 2
                Assert-MockCalled Mount-VHD -Exactly 1
                Assert-MockCalled Get-Disk -Exactly 1
                Assert-MockCalled Initialize-Disk -Exactly 1
                Assert-MockCalled Get-Partition -Exactly 1
                Assert-MockCalled New-Partition -Exactly 1
                Assert-MockCalled Get-Volume -Exactly 2
                Assert-MockCalled Format-Volume -Exactly 1
                Assert-MockCalled Set-Volume -Exactly 0
                Assert-MockCalled Set-Partition -Exactly 0
                Assert-MockCalled Add-PartitionAccessPath -Exactly 0
            }
        }
        Context 'VHDx file exists is not mounted, is not initialized and label and DriveLetter passed' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()
                $Splat.DriveLetter = 'X'

                InitializeVHD @Splat | Should Be $UnformattedVolume # would be NewVolume but Get-Volume is mocked to this.
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VHD -Exactly 2
                Assert-MockCalled Mount-VHD -Exactly 1
                Assert-MockCalled Get-Disk -Exactly 1
                Assert-MockCalled Initialize-Disk -Exactly 1
                Assert-MockCalled Get-Partition -Exactly 1
                Assert-MockCalled New-Partition -Exactly 1
                Assert-MockCalled Get-Volume -Exactly 3
                Assert-MockCalled Format-Volume -Exactly 1
                Assert-MockCalled Set-Volume -Exactly 0
                Assert-MockCalled Set-Partition -Exactly 1
                Assert-MockCalled Add-PartitionAccessPath -Exactly 0
            }
        }
        Context 'VHDx file exists is not mounted, is not initialized and label and AccessPath passed' {
            It 'Returns Expected Volume' {
                $Splat = $VHDLabel.Clone()
                $Splat.AccessPath = 'c:\Exists'

                InitializeVHD @Splat | Should Be $NewVolume
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VHD -Exactly 2
                Assert-MockCalled Mount-VHD -Exactly 1
                Assert-MockCalled Get-Disk -Exactly 1
                Assert-MockCalled Initialize-Disk -Exactly 1
                Assert-MockCalled Get-Partition -Exactly 1
                Assert-MockCalled New-Partition -Exactly 1
                Assert-MockCalled Get-Volume -Exactly 2
                Assert-MockCalled Format-Volume -Exactly 1
                Assert-MockCalled Set-Volume -Exactly 0
                Assert-MockCalled Set-Partition -Exactly 0
                Assert-MockCalled Add-PartitionAccessPath -Exactly 1
            }
        }
        Mock Test-Path -ParameterFilter { $Path -eq 'c:\DoesNotExist' } -MockWith { $false }
        Context 'VHDx file exists is not mounted, is not initialized and invalid AccessPath passed' {
            It 'Throws a InitializeVHDAccessPathNotFoundError Exception' {
                $Splat = $VHDLabel.Clone()
                $Splat.AccessPath = 'c:\DoesNotExist'

                $ExceptionParameters = @{
                    errorId = 'InitializeVHDAccessPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InitializeVHDAccessPathNotFoundError `
                        -f$Splat.Path,'c:\DoesNotExist')
                }
                $Exception = GetException @ExceptionParameters

                { InitializeVHD @Splat } | Should Throw $Exception
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VHD -Exactly 2
                Assert-MockCalled Mount-VHD -Exactly 1
                Assert-MockCalled Get-Disk -Exactly 1
                Assert-MockCalled Initialize-Disk -Exactly 1
                Assert-MockCalled Get-Partition -Exactly 1
                Assert-MockCalled New-Partition -Exactly 1
                Assert-MockCalled Get-Volume -Exactly 2
                Assert-MockCalled Format-Volume -Exactly 1
                Assert-MockCalled Set-Volume -Exactly 0
                Assert-MockCalled Set-Partition -Exactly 0
                Assert-MockCalled Add-PartitionAccessPath -Exactly 0
            }
        }
    }
}

Set-Location -Path $OldLocation
