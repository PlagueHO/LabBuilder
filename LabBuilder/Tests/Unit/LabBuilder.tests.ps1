#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

$Global:ModuleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))

Set-Location $ModuleRoot
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
    function New-Exception
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



    Describe 'DownloadAndUnzipFile' {
        $URL = 'https://raw.githubusercontent.com/PlagueHO/LabBuilder/dev/LICENSE'      
        Context 'Download folder does not exist' {
            Mock Invoke-WebRequest
            Mock Expand-Archive
            Mock Remove-Item
            It 'Throws a DownloadFolderDoesNotExistError Exception' {
                $ExceptionParameters = @{
                    errorId = 'DownloadFolderDoesNotExistError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DownloadFolderDoesNotExistError `
                        -f 'c:\doesnotexist','LICENSE')
                }
                $Exception = New-Exception @ExceptionParameters

                { DownloadAndUnzipFile -URL $URL -DestinationPath 'c:\doesnotexist' } | Should Throw $Exception
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
            }
        }
        Context 'Download fails' {
            Mock Invoke-WebRequest { Throw ('Download Error') }
            Mock Expand-Archive
            Mock Remove-Item
            It 'Throws a FileDownloadError Exception' {

                $ExceptionParameters = @{
                    errorId = 'FileDownloadError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.FileDownloadError `
                        -f 'LICENSE',$URL,'Download Error')
                }
                $Exception = New-Exception @ExceptionParameters

                { DownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should Throw $Exception
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
            }
        }
        Context 'Download OK' {
            Mock Invoke-WebRequest
            Mock Expand-Archive
            Mock Remove-Item
            It 'Does not throw an Exception' {
                { DownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0                
            }
        }
        $URL = 'https://raw.githubusercontent.com/PlagueHO/LabBuilder/dev/LICENSE.ZIP'
        Context 'Zip Download OK, Extract fails' {
            Mock Invoke-WebRequest
            Mock Expand-Archive { Throw ('Extract Error') }
            Mock Remove-Item
            It 'Throws a FileExtractError Exception' {

                $ExceptionParameters = @{
                    errorId = 'FileExtractError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.FileExtractError `
                        -f 'LICENSE.ZIP','Extract Error')
                }
                $Exception = New-Exception @ExceptionParameters

                { DownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should Throw $Exception
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 1
            }
        }
        Context 'Zip Download OK, Extract OK' {
            Mock Invoke-WebRequest
            Mock Expand-Archive
            Mock Remove-Item
            It 'Does not throw an Exception' {
                { DownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 1
            }
        }
    }



    Describe 'Initialize-Vhd' {
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
                $Exception = New-Exception @ExceptionParameters

                { Initialize-Vhd @Splat } | Should Throw $Exception
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
                $Exception = New-Exception @ExceptionParameters

                { Initialize-Vhd @Splat } | Should Throw $Exception
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

                Initialize-Vhd @Splat | Should Be $RenamedVolume
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

                Initialize-Vhd @Splat | Should Be $RenamedVolume
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

                Initialize-Vhd @Splat | Should Be $NewVolume
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

                Initialize-Vhd @Splat | Should Be $UnformattedVolume # would be NewVolume but Get-Volume is mocked to this.
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

                Initialize-Vhd @Splat | Should Be $NewVolume
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
                $Exception = New-Exception @ExceptionParameters

                { Initialize-Vhd @Splat } | Should Throw $Exception
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



    Describe 'GetModulesInDSCConfig' {
        Context 'Called with Test DSC Resource File' {
            $Modules = GetModulesInDSCConfig `
                -DSCConfigFile (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1')
            It 'Should Return Expected Modules' {
                @(Compare-Object -ReferenceObject $Modules `
                    -DifferenceObject @('xActiveDirectory','xComputerManagement','xDHCPServer','xNetworking')).Count `
                | Should Be 0
            }
        }
    }



    Describe 'Get-LabConfiguration' {
        Context 'Path is provided and valid XML file exists' {
            It 'Returns XmlDocument object with valid content' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.GetType().Name | Should Be 'XmlDocument'
                $Config.labbuilderconfig | Should Not Be $null
            }
        }

        Context 'Path is provided but file does not exist' {
            It 'Throws ConfigurationFileNotFoundError Exception' {

                $ExceptionParameters = @{
                    errorId = 'ConfigurationFileNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationFileNotFoundError `
                        -f 'c:\doesntexist.xml')
                }
                $Exception = New-Exception @ExceptionParameters

                Mock Test-Path -MockWith { $false }

                { Get-LabConfiguration -Path 'c:\doesntexist.xml' } | Should Throw $Exception
            }
        }

        Context 'Path is provided and file exists but is empty' {
            It 'Throws ConfigurationFileEmptyError Exception' {

                $ExceptionParameters = @{
                    errorId = 'ConfigurationFileEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationFileEmptyError `
                        -f 'c:\isempty.xml')
                }
                $Exception = New-Exception @ExceptionParameters

                Mock Test-Path -MockWith { $true }
                Mock Get-Content -MockWith {''}

                { Get-LabConfiguration -Path 'c:\isempty.xml' } | Should Throw $Exception
            }
        }
    }



    Describe 'Test-LabConfiguration' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Mock Test-Path -ParameterFilter { $Path -eq 'c:\exists\' } -MockWith { $true }
        Mock Test-Path -ParameterFilter { $Path -eq 'c:\doesnotexist\' } -MockWith { $false }

        Context 'Valid Configuration is provided and all paths exist' {
            It 'Returns True' {
                $Config.labbuilderconfig.settings.vmpath = 'c:\exists\'
                $Config.labbuilderconfig.settings.vhdparentpath = 'c:\exists\'

                Test-LabConfiguration -Config $Config | Should Be $True
            }
        }

        Context 'Valid Configuration is provided and VMPath is empty' {
            It 'Throws ConfigurationMissingElementError Exception' {
                $Config.labbuilderconfig.settings.vmpath = ''
                $Config.labbuilderconfig.settings.vhdparentpath = 'c:\exists\'

                $ExceptionParameters = @{
                    errorId = 'ConfigurationMissingElementError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationMissingElementError `
                        -f '<settings>\<vmpath>')
                }
                $Exception = New-Exception @ExceptionParameters

                { Test-LabConfiguration -Config $Config } | Should Throw $Exception
            }
        }

        Context 'Valid Configuration is provided and VMPath folder does not exist' {
            It 'Throws PathNotFoundError Exception' {
                $Config.labbuilderconfig.settings.vmpath = 'c:\doesnotexist\'
                $Config.labbuilderconfig.settings.vhdparentpath = 'c:\exists\'
            
                $ExceptionParameters = @{
                    errorId = 'PathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.PathNotFoundError `
                        -f '<settings>\<vmpath>','c:\doesnotexist\')
                }
                $Exception = New-Exception @ExceptionParameters

                { Test-LabConfiguration -Config $Config } | Should Throw $Exception
            }
        }
        
        Context 'Valid Configuration is provided and VHDParentPath is empty' {
            It 'Throws ConfigurationMissingElementError Exception' {
                $Config.labbuilderconfig.settings.vmpath = 'c:\exists\'
                $Config.labbuilderconfig.settings.vhdparentpath = ''

                $ExceptionParameters = @{
                    errorId = 'ConfigurationMissingElementError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationMissingElementError `
                        -f '<settings>\<vhdparentpath>')
                }
                $Exception = New-Exception @ExceptionParameters

                { Test-LabConfiguration -Config $Config } | Should Throw $Exception
            }
        }

        Context 'Valid Configuration is provided and VHDParentPath folder does not exist' {
            It 'Throws PathNotFoundError Exception' {
                $Config.labbuilderconfig.settings.vmpath = 'c:\exists\'
                $Config.labbuilderconfig.settings.vhdparentpath = 'c:\doesnotexist\'
                
                $ExceptionParameters = @{
                    errorId = 'PathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.PathNotFoundError `
                        -f '<settings>\<vhdparentpath>','c:\doesnotexist\')
                }
                $Exception = New-Exception @ExceptionParameters

                { Test-LabConfiguration -Config $Config } | Should Throw $Exception
            }
        }
    }



    Describe 'Install-LabHyperV' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
            Mock Get-WindowsOptionalFeature { [PSObject]@{ FeatureName = 'Mock'; State = 'Disabled'; } }
            Mock Enable-WindowsOptionalFeature 
        } Else {
            Mock Get-WindowsFeature { [PSObject]@{ Name = 'Mock'; Installed = $false; } }
            Mock Install-WindowsFeature
        }

        Context 'The function is called' {
            It 'Does not throw an Exception' {
                { Install-LabHyperV } | Should Not Throw
            }
            If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-WindowsOptionalFeature -Exactly 1
                    Assert-MockCalled Enable-WindowsOptionalFeature -Exactly 1
                }
            } Else {
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-WindowsFeature -Exactly 1
                    Assert-MockCalled Install-WindowsFeature -Exactly 1
                }
            }
        }
    }



    Describe 'Initialize-LabConfiguration' {
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Mock Download-LabResources
        Mock Set-VMHost
        Mock Get-VMSwitch
        Mock New-VMSwitch
        Mock Get-VMNetworkAdapter -MockWith { @{ Name = 'LabBuilder Management PesterTestConfig' } }
        Mock Get-VMNetworkAdapterVlan
        Mock Set-VMNetworkAdapterVlan        

        Context 'Valid configuration is passed' {
            It 'Does not throw an Exception' {
                { Initialize-LabConfiguration -Config $Config } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Download-LabResources -Exactly 1
                Assert-MockCalled Set-VMHost -Exactly 1
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapterVlan -Exactly 1
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 1
            }		
        }
    }



    Describe 'Download-LabModule' {
        $URL = 'https://github.com/PowerShell/xNetworking/archive/dev.zip'
        
        Mock Get-Module -MockWith { @( New-Object -TypeName PSObject -Property @{ Name = 'xNetworking'; Version = '2.4.0.0'; } ) }
        Mock Invoke-WebRequest
        Mock Expand-Archive
        Mock Rename-Item
        Mock Test-Path -MockWith { $false }
        Mock Remove-Item
        Mock Get-PackageProvider
        Mock Install-Module

        Context 'Correct module already installed; Valid URL and Folder passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Mock Get-Module -MockWith { }

        Context 'Module is not installed; Valid URL and Folder passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 1
                Assert-MockCalled Rename-Item -Exactly 1
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Module is not installed; No URL or Folder passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Mock Get-Module -MockWith { @( New-Object -TypeName PSObject -Property @{ Name = 'xNetworking'; Version = '2.4.0.0'; } ) }

        Context 'Wrong version of module is installed; Valid URL, Folder and Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev' `
                        -RequiredVersion '2.5.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 1
                Assert-MockCalled Rename-Item -Exactly 1
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Wrong version of module is installed; No URL or Folder passed, but Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -RequiredVersion '2.5.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Context 'Correct version of module is installed; Valid URL, Folder and Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev' `
                        -RequiredVersion '2.4.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Correct version of module is installed; No URL and Folder passed, but Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -RequiredVersion '2.4.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Wrong version of module is installed; Valid URL, Folder and Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev' `
                        -MinimumVersion '2.5.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 1
                Assert-MockCalled Rename-Item -Exactly 1
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Wrong version of module is installed; No URL and Folder passed, but Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -MinimumVersion '2.5.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Context 'Correct version of module is installed; Valid URL, Folder and Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev' `
                        -MinimumVersion '2.4.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Correct version of module is installed; No URL and Folder passed, but Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -MinimumVersion '2.4.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Mock Get-Module -MockWith { }
        Mock Invoke-WebRequest -MockWith { Throw ('Download Error') }

        Context 'Module is not installed; Bad URL passed' {
            It 'Throws a FileDownloadError exception' {
                $ExceptionParameters = @{
                    errorId = 'FileDownloadError'
                    errorCategory = 'InvalidOperation'
                    errorMessage = $($LocalizedData.FileDownloadError `
                        -f 'Module Resource xNetworking',$URL,'Download Error')
                }
                $Exception = New-Exception @ExceptionParameters

                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev'
                } | Should Throw $Exception
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Mock Install-Module -MockWith { Throw ("No match was found for the specified search criteria and module name 'xDoesNotExist'" )}

        Context 'Module is not installed; Not available in Repository' {
            It 'Throws a ModuleNotAvailableError exception' {
                $ExceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f 'xDoesNotExist','any version',"No match was found for the specified search criteria and module name 'xDoesNotExist'")
                }
                $Exception = New-Exception @ExceptionParameters

                {
                    Download-LabModule `
                        -Name 'xDoesNotExist'
                } | Should Throw $Exception
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Mock Install-Module -MockWith { Throw ("No match was found for the specified search criteria and module name 'xNetworking'" )}

        Context 'Wrong version of module is installed; No URL or Folder passed, but Required Version passed. Required Version is not available' {
            It ' Throws a ModuleNotAvailableError Exception' {
                $ExceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f 'xNetworking','2.5.0.0',"No match was found for the specified search criteria and module name 'xNetworking'" )
                }
                $Exception = New-Exception @ExceptionParameters

                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -RequiredVersion '2.5.0.0'
                } | Should Throw $Exception
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }
        
        Context 'Wrong version of module is installed; No URL or Folder passed, but Minimum Version passed. Minimum Version is not available' {
            It ' Throws a ModuleNotAvailableError Exception' {
                $ExceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f 'xNetworking','min 2.5.0.0',"No match was found for the specified search criteria and module name 'xNetworking'" )
                }
                $Exception = New-Exception @ExceptionParameters

                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -MinimumVersion '2.5.0.0'
                } | Should Throw $Exception
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

    }



    Describe 'Download-LabResources' -Tags 'Incomplete' {
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Context 'Valid configuration is passed' {
            Mock Download-LabModule
            It 'Does not throw an Exception' {
                { Download-LabResources -Config $Config } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Download-LabModule -Exactly 4
            }
        }
    }



    Describe 'Get-LabSwitch' {
        Context 'Configuration passed with switch missing Switch Name.' {
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabSwitch -Config (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.NoName.xml") } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with switch missing Switch Type.' {
            It 'Throws a UnknownSwitchTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f '','Pester Switch Fail')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabSwitch -Config (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.NoType.xml") } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with switch invalid Switch Type.' {
            It 'Throws a UnknownSwitchTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f 'BadType','Pester Switch Fail')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabSwitch -Config (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.BadType.xml") } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with switch containing adapters but is not External type.' {
            It 'Throws a AdapterSpecifiedError Exception' {
                $ExceptionParameters = @{
                    errorId = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.AdapterSpecifiedError `
                        -f 'Private','Pester Switch Fail')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabSwitch -Config (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.AdaptersSet.xml") } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed' {
            It 'Returns Switches Object that matches Expected Object' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                [Array]$Switches = Get-LabSwitch -Config $Config
                Set-Content -Path "$Global:ArtifactPath\ExpectedSwitches.json" -Value ($Switches | ConvertTo-Json -Depth 4)
                $ExpectedSwitches = Get-Content -Path "$Global:ExpectedContentPath\ExpectedSwitches.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedSwitches.json"),$ExpectedSwitches,$true) | Should Be 0
            }
        }
    }



    Describe 'Initialize-LabSwitch' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Config $Config

        Mock Get-VMSwitch
        Mock New-VMSwitch
        Mock Add-VMNetworkAdapter
        Mock Set-VMNetworkAdapterVlan

        Context 'Valid configuration is passed' {	
            It 'Does not throw an Exception' {
                { Initialize-LabSwitch -Config $Config -Switches $Switches } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 5
                Assert-MockCalled New-VMSwitch -Exactly 5
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }

        Context 'Valid configuration without switches is passed' {	
            It 'Does not throw an Exception' {
                { Initialize-LabSwitch -Config $Config } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 5
                Assert-MockCalled New-VMSwitch -Exactly 5
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }

        Context 'Valid configuration with invalid switch type passed' {	
            $Switches[0].Type='Invalid'
            It 'Throws a UnknownSwitchTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f 'Invalid',$Switches[0].Name)
                }
                $Exception = New-Exception @ExceptionParameters

                { Initialize-LabSwitch -Config $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 0
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }

        Context 'Valid configuration NAT with blank NAT Subnet Address' {	
            $Switches[0].Type = 'NAT'
            It 'Throws a NatSubnetAddressEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'NatSubnetAddressEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NatSubnetAddressEmptyError `
                        -f $Switches[0].Name)
                }
                $Exception = New-Exception @ExceptionParameters

                { Initialize-LabSwitch -Config $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 0
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }

        Context 'Valid configuration with blank switch name passed' {	
            $Switches[0].Type = 'External'
            $Switches[0].Name = ''
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = New-Exception @ExceptionParameters

                { Initialize-LabSwitch -Config $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 0
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }
    }



    Describe 'Remove-LabSwitch' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Config $Config

        Mock Get-VMSwitch -MockWith { $Switches }
        Mock Remove-VMSwitch

        Context 'Valid configuration is passed' {	
            It 'Does not throw an Exception' {
                { Remove-LabSwitch -Config $Config -Switches $Switches } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 5
                Assert-MockCalled Remove-VMSwitch -Exactly 5
            }
        }

        Context 'Valid configuration is passed without switches' {	
            It 'Does not throw an Exception' {
                { Remove-LabSwitch -Config $Config } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 5
                Assert-MockCalled Remove-VMSwitch -Exactly 5
            }
        }

        Context 'Valid configuration with invalid switch type passed' {	
            $Switches[0].Type='Invalid'
            It 'Throws a UnknownSwitchTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f 'Invalid',$Switches[0].Name)
                }
                $Exception = New-Exception @ExceptionParameters

                { Remove-LabSwitch -Config $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled Remove-VMSwitch -Exactly 0
            }
        }

        Context 'Valid configuration with blank switch name passed' {	
            $Switches[0].Type = 'External'
            $Switches[0].Name = ''
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = New-Exception @ExceptionParameters

                { Remove-LabSwitch -Config $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled Remove-VMSwitch -Exactly 0
            }
        }
    }



    Describe 'Get-LabVMTemplateVHD' {

        Context 'Configuration passed with rooted ISO Root Path that does not exist' {
            It 'Throws a VMTemplateVHDISORootPathNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.ISOPath = "$Global:TestConfigPath\MissingFolder"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISORootPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                        -f "$Global:TestConfigPath\MissingFolder")
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with relative ISO Root Path that does not exist' {
            It 'Throws a VMTemplateVHDISORootPathNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.ISOPath = "MissingFolder"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISORootPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                        -f "$Global:TestConfigPath\MissingFolder")
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with rooted VHD Root Path that does not exist' {
            It 'Throws a VMTemplateVHDRootPathNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.VHDPath = "$Global:TestConfigPath\MissingFolder"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDRootPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                        -f "$Global:TestConfigPath\MissingFolder")
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with relative VHD Root Path that does not exist' {
            It 'Throws a VMTemplateVHDRootPathNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.VHDPath = "MissingFolder"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDRootPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                        -f "$Global:TestConfigPath\MissingFolder")
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with empty template VHD Name' {
            It 'Throws a EmptyVMTemplateVHDNameError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.templatevhd[0].RemoveAttribute('name')
                $ExceptionParameters = @{
                    errorId = 'EmptyVMTemplateVHDNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyVMTemplateVHDNameError)
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template ISO Path is empty' {
            It 'Throws a EmptyVMTemplateVHDISOPathError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.templatevhd[0].ISO = ''
                $ExceptionParameters = @{
                    errorId = 'EmptyVMTemplateVHDISOPathError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyVMTemplateVHDISOPathError `
                        -f $Config.labbuilderconfig.templatevhds.templatevhd[0].name)
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template ISO Path that does not exist' {
            It 'Throws a VMTemplateVHDISOPathNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.templatevhd[0].ISO = "$Global:TestConfigPath\MissingFolder\DoesNotExist.iso"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISOPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                        -f $Config.labbuilderconfig.templatevhds.templatevhd[0].name,"$Global:TestConfigPath\MissingFolder\DoesNotExist.iso")
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with relative template ISO Path that does not exist' {
            It 'Throws a VMTemplateVHDISOPathNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.templatevhd[0].ISO = "MissingFolder\DoesNotExist.iso"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISOPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                        -f $Config.labbuilderconfig.templatevhds.templatevhd[0].name,"$Global:TestConfigPath\ISOFiles\MissingFolder\DoesNotExist.iso")
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with invalid OSType' {
            It 'Throws a InvalidVMTemplateVHDOSTypeError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.templatevhd[0].OSType = 'invalid'
                $ExceptionParameters = @{
                    errorId = 'InvalidVMTemplateVHDOSTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InvalidVMTemplateVHDOSTypeError `
                        -f $Config.labbuilderconfig.templatevhds.templatevhd[0].name,'invalid')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with invalid VHDFormat' {
            It 'Throws a InvalidVMTemplateVHDVHDFormatError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.templatevhd[0].VHDFormat = 'invalid'
                $ExceptionParameters = @{
                    errorId = 'InvalidVMTemplateVHDVHDFormatError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDFormatError `
                        -f $Config.labbuilderconfig.templatevhds.templatevhd[0].name,'invalid')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with invalid VHDType' {
            It 'Throws a InvalidVMTemplateVHDVHDTypeError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.templatevhd[0].VHDType = 'invalid'
                $ExceptionParameters = @{
                    errorId = 'InvalidVMTemplateVHDVHDTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDTypeError `
                        -f $Config.labbuilderconfig.templatevhds.templatevhd[0].name,'invalid')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with invalid VHDType' {
            It 'Throws a InvalidVMTemplateVHDGenerationError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templatevhds.templatevhd[0].Generation = '99'
                $ExceptionParameters = @{
                    errorId = 'InvalidVMTemplateVHDGenerationError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InvalidVMTemplateVHDGenerationError `
                        -f $Config.labbuilderconfig.templatevhds.templatevhd[0].name,'99')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplateVHD -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed missing TemplateVHDs Node' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.RemoveChild($Config.labbuilderconfig.templatevhds)
            It 'Returns null' {
                Get-LabVMTemplateVHD -Config $Config  | Should Be $null
            }
        }
        Context 'Valid configuration is passed with no TemplateVHD Nodes' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.templatevhds.IsEmpty = $true
            It 'Returns null' {
                Get-LabVMTemplateVHD -Config $Config | Should Be $null
            }
        }
        Context 'Valid configuration is passed and template VHD ISOs are found' {
            It 'Returns VMTemplateVHDs array that matches Expected array' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                [Array] $TemplateVHDs = Get-LabVMTemplateVHD -Config $Config 
                # Remove the VHDPath and ISOPath values for any VMtemplatesVHD
                #  because they will usually be relative to the test folder and
                # won't exist on any other test system
                foreach ($TemplateVHD in $TemplateVHDs)
                {
                    $TemplateVHD.VHDPath = 'Intentionally Removed'
                    $TemplateVHD.ISOPath = 'Intentionally Removed'
                }
                Set-Content -Path "$Global:ArtifactPath\ExpectedTemplateVHDs.json" -Value ($TemplateVHDs | ConvertTo-Json -Depth 2)
                $ExpectedTemplateVHDs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedTemplateVHDs.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedTemplateVHDs.json"),$ExpectedTemplateVHDs,$true) | Should Be 0
            }
        }
    }



    Describe 'Initialize-LabVMTemplateVHD' {
        Mock Mount-DiskImage
        Mock Get-Diskimage -MockWith {
            New-CimInstance `
                -ClassName 'MSFT_DiskImage' `
                -Namespace Root/Microsoft/Windows/Storage `
                -ClientOnly `
                -Property @{
                    Attached = $True
                    BlockSize = 0
                    DevicePath = '\\.\CDROM1'
                    ImagePath = 'c:\doesnotmatter.iso'
                    LogicalSectorSize = 2048
                    Number = 1
                    Size = 3842639872
                    StorageType = 1
                }
        }
        Mock Get-Volume -MockWith { @{ DriveLetter = 'X' } }
        Mock Dismount-DiskImage
        Mock Get-WindowsImage -MockWith { @{ ImageName = 'DOESNOTMATTER' } }
        Mock Copy-Item
        Mock Rename-Item
        
        # Mock Convert-WindowsImage
        if (-not (Test-Path -Path Function:Convert-WindowsImage))
        {
            . "$Global:ModuleRoot\support\Convert-WindowsImage.ps1"
        }
        Mock Convert-WindowsImage 
        Mock Resolve-Path -MockWith { 'X:\Sources\Install.WIM' }
        Mock Test-Path -MockWith { $True } -ParameterFilter { $Path -eq 'X:\Sources\Install.WIM' }
                
        Context 'Configuration passed with no VMtemplateVHDs' {
            It 'Does not throw an Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.RemoveChild($Config.labbuilderconfig.templatevhds)
                { Initialize-LabVMTemplateVHD -Config $Config } | Should Not Throw
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Mount-DiskImage -Exactly 0
                Assert-MockCalled Get-Diskimage -Exactly 0
                Assert-MockCalled Get-Volume -Exactly 0
                Assert-MockCalled Dismount-DiskImage -Exactly 0
                Assert-MockCalled Get-WindowsImage -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Convert-WindowsImage -Exactly 0
            }            
        }
        Context 'Configuration passed where the template ISO can not be found' {
            It 'Throws an VMTemplateVHDISOPathNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config
                $VMTemplateVHDs[0].isopath = 'doesnotexist.iso'
                $VMTemplateVHDs[0].vhdpath = 'doesnotexist.vhdx'
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISOPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                        -f $Config.labbuilderconfig.templatevhds.templatevhd[0].name,'doesnotexist.iso')
                }
                $Exception = New-Exception @ExceptionParameters

                { Initialize-LabVMTemplateVHD -Config $Config -VMTemplateVHDs $VMTemplateVHDs } | Should Throw $Exception
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Mount-DiskImage -Exactly 0
                Assert-MockCalled Get-Diskimage -Exactly 0
                Assert-MockCalled Get-Volume -Exactly 0
                Assert-MockCalled Dismount-DiskImage -Exactly 0
                Assert-MockCalled Get-WindowsImage -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Convert-WindowsImage -Exactly 0
            }            
        }
        Context 'Valid configuration passed' {
            It 'Does not throw an Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                { Initialize-LabVMTemplateVHD -Config $Config } | Should Not Throw
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Mount-DiskImage -Exactly 3
                Assert-MockCalled Get-Diskimage -Exactly 3
                Assert-MockCalled Get-Volume -Exactly 3
                Assert-MockCalled Dismount-DiskImage -Exactly 3
                Assert-MockCalled Get-WindowsImage -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled Rename-Item -Exactly 1
                Assert-MockCalled Convert-WindowsImage -Exactly 3
            }            
        }
    }



    Describe 'Get-LabVMTemplate' {

        Mock Get-VM
        
        Context 'Configuration passed with template missing Template Name.' {
            It 'Throws a EmptyTemplateNameError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templates.template[0].RemoveAttribute('name')
                $ExceptionParameters = @{
                    errorId = 'EmptyTemplateNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyTemplateNameError)
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplate -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template VHD empty.' {
            It 'Throws a EmptyTemplateVHDError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templates.template[0].RemoveAttribute('vhd')
                $ExceptionParameters = @{
                    errorId = 'EmptyTemplateVHDError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyTemplateVHDError `
                        -f $Config.labbuilderconfig.templates.template[0].name)
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplate -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template with Source VHD set to relative non-existent file.' {
            It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templates.template[0].sourcevhd = 'This File Doesnt Exist.vhdx'
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $Config.labbuilderconfig.templates.template[0].name,"$Global:TestConfigPath\This File Doesnt Exist.vhdx")
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplate -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template with Source VHD set to absolute non-existent file.' {
            It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templates.template[0].sourcevhd = 'c:\This File Doesnt Exist.vhdx'
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $Config.labbuilderconfig.templates.template[0].name,"c:\This File Doesnt Exist.vhdx")
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplate -Config $Config } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed but no templates found' {
            It 'Returns Template Object that matches Expected Object' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                [Array]$Templates = Get-LabVMTemplate -Config $Config 
                # Remove the SourceVHD values for any templates because they
                # will usually be relative to the test folder and won't exist
                foreach ($Template in $Templates)
                {
                    $Template.SourceVHD = 'Intentionally Removed'
                }
                Set-Content -Path "$Global:ArtifactPath\ExpectedTemplates.json" -Value ($Templates | ConvertTo-Json -Depth 2)
                $ExpectedTemplates = Get-Content -Path "$Global:ExpectedContentPath\ExpectedTemplates.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedTemplates.json"),$ExpectedTemplates,$true) | Should Be 0
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 0
            }
        }

        Mock Get-VM -MockWith { @( 
                @{ name = 'Pester Windows Server 2012 R2 Datacenter Full' }
                @{ name = 'Pester Windows Server 2012 R2 Datacenter Core' } 
                @{ name = 'Pester Windows 10 Enterprise' } 
            ) }
        Mock Get-VMHardDiskDrive -ParameterFilter { $VMName -eq 'Pester Windows Server 2012 R2 Datacenter Full' } `
            -MockWith { @{ path = 'Pester Windows Server 2012 R2 Datacenter Full.vhdx' } }
        Mock Get-VMHardDiskDrive -ParameterFilter { $VMName -eq 'Pester Windows Server 2012 R2 Datacenter Core' } `
            -MockWith { @{ path = 'Pester Windows Server 2012 R2 Datacenter Core.vhdx' } }
        Mock Get-VMHardDiskDrive -ParameterFilter { $VMName -eq 'Pester Windows 10 Enterprise' } `
            -MockWith { @{ path = 'Pester Windows 10 Enterprise.vhdx' } }

        Context 'Valid configuration is passed and templates are found' {
            It 'Returns Template Object that matches Expected Object' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.templates.SetAttribute('fromvm','Pester *')
                [Array]$Templates = Get-LabVMTemplate -Config $Config 
                # Remove the SourceVHD values for any templates because they
                # will usually be relative to the test folder and won't exist
                foreach ($Template in $Templates)
                {
                    $Template.SourceVHD = 'Intentionally Removed'
                }
                Set-Content -Path "$Global:ArtifactPath\ExpectedTemplates.FromVM.json" -Value ($Templates | ConvertTo-Json -Depth 2)
                $ExpectedTemplates = Get-Content -Path "$Global:ExpectedContentPath\ExpectedTemplates.FromVM.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedTemplates.FromVM.json"),$ExpectedTemplates,$true) | Should Be 0
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 3
            }
        }
    }
    
    
    
    Describe 'Initialize-LabVMTemplate' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Mock Copy-Item
        Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
        Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
        Mock Test-Path -ParameterFilter { $Path -eq 'This File Doesnt Exist.vhdx' } -MockWith { $false }
        Mock Optimize-VHD
        Mock Get-VM

        Context 'Valid Template Array with non-existent VHD source file' {
            [array]$Templates = @( @{
                name = 'Bad VHD'
                templatevhd = 'This File Doesnt Exist.vhdx' 
                sourcevhd = 'This File Doesnt Exist.vhdx'
            } )

            It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f 'Bad VHD','This File Doesnt Exist.vhdx')
                }
                $Exception = New-Exception @ExceptionParameters

                { Initialize-LabVMTemplate -Config $Config -VMTemplates $Templates } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed' {	
            [array]$VMTemplates = Get-LabVMTemplate -Config $Config
            [array]$VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config

            It 'Does not throw an Exception' {
                { Initialize-LabVMTemplate -Config $Config -VMTemplates $VMTemplates } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Copy-Item -Exactly 3
                Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
                Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
                Assert-MockCalled Optimize-VHD -Exactly 3
            }
        }
        Context 'Valid configuration is passed without VMTemplates or VMTemplateVHDs' {	
            It 'Does not throw an Exception' {
                { Initialize-LabVMTemplate -Config $Config } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Copy-Item -Exactly 3
                Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
                Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
                Assert-MockCalled Optimize-VHD -Exactly 3
            }
        }
    }



    Describe 'Remove-LabVMTemplate' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
        Mock Remove-Item
        Mock Test-Path -MockWith { $True }
        Mock Get-VM

        Context 'Valid configuration is passed' {	
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            
            It 'Does not throw an Exception' {
                { Remove-LabVMTemplate -Config $Config -VMTemplates $Templates } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
                Assert-MockCalled Remove-Item -Exactly 3
            }
        }
    }



    Describe 'Set-LabVMDSCMOFFile' -Tags 'Incomplete' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Config $Config
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
        
        Mock Create-LabVMPath
        Mock Get-Module
        Mock GetModulesInDSCConfig -MockWith { @('TestModule') }

        Context 'Empty DSC Config' {
            $VM = $VMS[0].Clone()
            $VM.DSCConfigFile = ''
            It 'Does not throw an Exception' {
                { Set-LabVMDSCMOFFile -Config $Config -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 0
            }
        }

        Mock Find-Module
        
        Context 'DSC Module Not Found' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'DSCModuleDownloadError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCModuleDownloadError `
                    -f $VM.DSCConfigFile,$VM.Name,'TestModule')
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { Set-LabVMDSCMOFFile -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled GetModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
            }
        }

        Mock Find-Module -MockWith { @{ name = 'TestModule' } }
        Mock Install-Module -MockWith { Throw }
        
        Context 'DSC Module Download Error' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'DSCModuleDownloadError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCModuleDownloadError `
                    -f $VM.DSCConfigFile,$VM.Name,'TestModule')
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { Set-LabVMDSCMOFFile -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled GetModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
            }
        }

        Mock Install-Module -MockWith { }
        Mock Test-Path `
            -ParameterFilter { $Path -like '*TestModule' } `
            -MockWith { $false }
        
        Context 'DSC Module Not Found in Path' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'DSCModuleNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCModuleNotFoundError `
                    -f $VM.DSCConfigFile,$VM.Name,'TestModule')
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCModuleNotFoundError Exception' {
                { Set-LabVMDSCMOFFile -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled GetModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Mock Test-Path `
            -ParameterFilter { $Path -like '*TestModule' } `
            -MockWith { $true }
        Mock Copy-Item
        Mock Get-LabVMCertificate
        
        Context 'Certificate Create Failed' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'CertificateCreateError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.CertificateCreateError `
                    -f $VM.Name)
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a CertificateCreateError Exception' {
                { Set-LabVMDSCMOFFile -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled GetModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled Get-LabVMCertificate -Exactly 1
            }
        }

        Mock Get-LabVMCertificate -MockWith { $true }
        Mock Import-Certificate
        Mock Get-ChildItem `
            -ParameterFilter { $path -eq 'cert:\LocalMachine\My' } `
            -MockWith { @{ 
                FriendlyName = 'DSC Credential Encryption'
                Thumbprint = '1FE3BA1B6DBE84FCDF675A1C944A33A55FD4B872'	
            } }
        Mock Remove-Item
        Mock ConfigLCM
        
        Context 'Meta MOF Create Failed' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'DSCConfigMetaMOFCreateError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCConfigMetaMOFCreateError `
                    -f $VM.Name)
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCConfigMetaMOFCreateError Exception' {
                { Set-LabVMDSCMOFFile -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled GetModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled Get-LabVMCertificate -Exactly 1
                Assert-MockCalled Import-Certificate -Exactly 1			
                Assert-MockCalled Get-ChildItem -ParameterFilter { $path -eq 'cert:\LocalMachine\My' } -Exactly 1
                Assert-MockCalled Remove-Item
                Assert-MockCalled ConfigLCM -Exactly 1
            }
        }
    }



    Describe 'Set-LabVMDSCStartFile' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Config $Config
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches

        Mock Get-VMNetworkAdapter

        Context 'Network Adapter does not Exist' {
            $VM = $VMS[0].Clone()
            $VM.Adapters[0].Name = 'DoesNotExist'
            $ExceptionParameters = @{
                errorId = 'NetworkAdapterNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.NetworkAdapterNotFoundError `
                    -f 'DoesNotExist',$VMS[0].Name)
            }
            $Exception = New-Exception @ExceptionParameters
            It 'Throws a NetworkAdapterNotFoundError Exception' {
                { Set-LabVMDSCStartFile -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
            }
        }

        Mock Get-VMNetworkAdapter -MockWith { @{ Name = 'Exists'; MacAddress = '' }}

        Context 'Network Adapter has blank MAC Address' {
            $VM = $VMS[0].Clone()
            $VM.Adapters[0].Name = 'Exists'
            $ExceptionParameters = @{
                errorId = 'NetworkAdapterBlankMacError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.NetworkAdapterBlankMacError `
                    -f 'Exists',$VMS[0].Name)
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a NetworkAdapterBlankMacError Exception' {
                { Set-LabVMDSCStartFile -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
            }
        }

        Mock Get-VMNetworkAdapter -MockWith { @{ Name = 'Exists'; MacAddress = '111111111111' }}
        Mock Set-Content
        
        Context 'Valid Configuration Passed' {
            $VM = $VMS[0].Clone()
            
            It 'Does Not Throw Exception' {
                { Set-LabVMDSCStartFile -Config $Config -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMNetworkAdapter -Exactly ($VM.Adapters.Count+1)
                Assert-MockCalled Set-Content -Exactly 2
            }
        }
    }



    Describe 'Initialize-LabVMDSC' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Config $Config
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches

        Mock Set-LabVMDSCMOFFile
        Mock Set-LabVMDSCStartFile

        Context 'Valid Configuration Passed' {
            $VM = $VMS[0].Clone()
            
            It 'Does Not Throw Exception' {
                { Initialize-LabVMDSC -Config $Config -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Set-LabVMDSCMOFFile -Exactly 1
                Assert-MockCalled Set-LabVMDSCStartFile -Exactly 1
            }
        }
    }



    Describe 'Start-LabVMDSC' -Tags 'Incomplete' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Config $Config
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches

    }



    Describe 'Get-LabUnattendFile' -Tags 'Incomplete' {

        Mock Get-VM

        Context 'Valid Parameters Passed' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            [String]$UnattendFile = Get-LabUnattendFile -Config $Config -VM $VMs[0]
            Set-Content -Path "$($Global:ArtifactPath)\ExpectedUnattendFile.xml" -Value $UnattendFile -Encoding UTF8 -NoNewLine
            It 'Returns Expected File Content' {
                $UnattendFile | Should Be $True
                $ExpectedUnattendFile = Get-Content -Path "$Global:ExpectedContentPath\ExpectedUnattendFile.xml" -Raw
                [String]::Compare($UnattendFile,$ExpectedUnattendFile,$true) | Should Be 0
            }
        }
    }



    Describe 'Set-LabVMInitializationFiles' -Tags 'Incomplete' {

        #region Mocks
        Mock Get-VM
        Mock Mount-WindowsImage
        Mock Dismount-WindowsImage
        Mock Invoke-WebRequest
        Mock Add-WindowsPackage
        Mock Set-Content
        Mock Copy-Item
        #endregion

        Context 'Valid configuration is passed' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
                    
            It 'Returns True' {
                Set-LabVMInitializationFiles -Config $Config -VM $VMs[0] -VMBootDiskPath 'c:\Dummy\' | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Mount-WindowsImage -Exactly 1
                Assert-MockCalled Dismount-WindowsImage -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Add-WindowsPackage -Exactly 1
                Assert-MockCalled Set-Content -Exactly 6
                Assert-MockCalled Copy-Item -Exactly 1
            }

            Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }



    Describe 'Get-LabVM' {

        #region mocks
        Mock Get-VM
        #endregion

        Context 'Configuration passed with VM missing VM Name.' {
            It 'Throw VMNameError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.RemoveAttribute('name')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMNameError)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM missing Template.' {
            It 'Throw VMTemplateNameEmptyError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.RemoveAttribute('template')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMTemplateNameEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM invalid Template Name.' {
            It 'Throw VMTemplateNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.template = 'BadTemplate'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMTemplateNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                        -f $Config.labbuilderconfig.vms.vm.name,'BadTemplate')
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM missing adapter name.' {
            It 'Throw VMAdapterNameError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.adapters.adapter[0].RemoveAttribute('name')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMAdapterNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterNameError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM missing adapter switch name.' {
            It 'Throw VMAdapterSwitchNameError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.adapters.adapter[0].RemoveAttribute('switchname')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                        -f $Config.labbuilderconfig.vms.vm.name,$Config.labbuilderconfig.vms.vm.adapters.adapter[0].name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM Data Disk with empty VHD.' {
            It 'Throw VMDataDiskVHDEmptyError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = ''
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where ParentVHD can't be found." {
            It 'Throw VMDataDiskParentVHDNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = 'c:\ThisFileDoesntExist.vhdx'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                        -f $Config.labbuilderconfig.vms.vm.name,"c:\ThisFileDoesntExist.vhdx")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where SourceVHD can't be found." {
            It 'Throw VMDataDiskSourceVHDNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = 'c:\ThisFileDoesntExist.vhdx'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                        -f $Config.labbuilderconfig.vms.vm.name,"c:\ThisFileDoesntExist.vhdx")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Differencing Data Disk with empty ParentVHD." {
            It 'Throw VMDataDiskParentVHDMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].RemoveAttribute('parentvhd')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where it is a Differencing type disk but is shared." {
            It 'Throw VMDataDiskSharedDifferencingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].SetAttribute('Shared','Y')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSharedDifferencingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where it has an unknown Type." {
            It 'Throw VMDataDiskUnknownTypeError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].type = 'badtype'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskUnknownTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'badtype')
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk is not Shared but SupportPR is Y." {
            It 'Throw VMDataDiskSupportPRError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].supportpr = 'Y'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSupportPRError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSupportPRError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }        
        Context "Configuration passed with VM Data Disk that has an invalid Partition Style." {
            It 'Throw VMDataDiskPartitionStyleError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].PartitionStyle='Bad'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskPartitionStyleError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskPartitionStyleError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'Bad')
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has an invalid File System." {
            It 'Throw VMDataDiskFileSystemError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].FileSystem='Bad'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskFileSystemError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskFileSystemError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'Bad')
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has a File System set but not a Partition Style." {
            It 'Throw VMDataDiskPartitionStyleMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('partitionstyle')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskPartitionStyleMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has a Partition Style set but not a File System." {
            It 'Throw VMDataDiskFileSystemMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('filesystem')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskFileSystemMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has a File System Label set but not a Partition Style or File System." {
            It 'Throw VMDataDiskPartitionStyleMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[2].RemoveAttribute('partitionstyle')
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[2].RemoveAttribute('filesystem')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskPartitionStyleMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[2].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that exists with CopyFolders set to a folder that does not exist." {
            It 'Throw VMDataDiskCopyFolderMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].CopyFolders='c:\doesnotexist'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCopyFolderMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCopyFolderMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd)",'c:\doesnotexist')
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that does not exist but Type missing." {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('type')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that does not exist but Size missing." {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('size')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that does not exist but SourceVHD missing." {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].RemoveAttribute('sourcevhd')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has MoveSourceVHD flag but SourceVHD missing." {
            It 'Throw VMDataDiskSourceVHDIfMoveError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[4].RemoveAttribute('sourcevhd')
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDIfMoveError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[4].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM unattend file that can't be found." {
            It 'Throw UnattendFileMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.unattendfile = 'ThisFileDoesntExist.xml'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'UnattendFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnattendFileMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\ThisFileDoesntExist.xml")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM setup complete file that can't be found." {
            It 'Throw SetupCompleteFileMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.setupcomplete = 'ThisFileDoesntExist.ps1'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\ThisFileDoesntExist.ps1")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM setup complete file with an invalid file extension.' {
            It 'Throw SetupCompleteFileBadTypeError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.setupcomplete = 'ThisFileDoesntExist.abc'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\ThisFileDoesntExist.abc")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM DSC Config File that can't be found." {
            It 'Throw DSCConfigFileMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.dsc.configfile = 'ThisFileDoesntExist.ps1'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\DSCLibrary\ThisFileDoesntExist.ps1")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM DSC Config File with an invalid file extension.' {
            It 'Throw DSCConfigFileBadTypeError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.dsc.configfile = 'FileWithBadType.xyz'
                [Array]$Switches = Get-LabSwitch -Config $Config
                [array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\DSCLibrary\FileWithBadType.xyz")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM DSC Config File but no DSC Name.' {
            It 'Throw DSCConfigNameIsEmptyError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.dsc.configname = ''
                [Array]$Switches = Get-LabSwitch -Config $Config
                [Array]$Templates = Get-LabVMTemplate -Config $Config
                $ExceptionParameters = @{
                    errorId = 'DSCConfigNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with rooted VHD path.' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing VHD with correct rooted path' {
                $VMs[0].DataVhds[0].vhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with non-rooted VHD path.' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = "DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing VHD with correct rooted path' {
                $VMs[0].DataVhds[0].vhd | Should Be "$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with rooted Parent VHD path.' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Parent VHD with correct rooted path' {
                $VMs[0].DataVhds[3].parentvhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with non-rooted Parent VHD path.' {
            Mock Test-Path -MockWith { $true }
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = "VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Parent VHD with correct rooted path' {
                $VMs[0].DataVhds[3].parentvhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with rooted Source VHD path.' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Source VHD with correct rooted path' {
                $VMs[0].DataVhds[0].sourcevhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with non-rooted Source VHD path.' {
            Mock Test-Path -MockWith { $true }
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = "VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Source VHD with correct rooted path' {
                $VMs[0].DataVhds[0].sourcevhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed but switches and VMTemplates not passed' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            [Array]$VMs = Get-LabVM -Config $Config
            # Remove the Source VHD and Parent VHD values for any data disks because they
            # will usually be relative to the test folder and won't exist
            foreach ($DataVhd in $VMs[0].DataVhds)
            {
                $DataVhd.ParentVHD = 'Intentionally Removed'
                $DataVhd.SourceVHD = 'Intentionally Removed'
            }
            # Remove the DSCConfigFile path as this will be relative as well
            $VMs[0].DSCConfigFile = ''
            It 'Returns Template Object that matches Expected Object' {
                Set-Content -Path "$Global:ArtifactPath\ExpectedVMs.json" -Value ($VMs | ConvertTo-Json -Depth 6)
                $ExpectedVMs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedVMs.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedVMs.json"),$ExpectedVMs,$true) | Should Be 0
            }
        }
        Context 'Valid configuration is passed' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            # Remove the Source VHD and Parent VHD values for any data disks because they
            # will usually be relative to the test folder and won't exist
            foreach ($DataVhd in $VMs[0].DataVhds)
            {
                $DataVhd.ParentVHD = 'Intentionally Removed'
                $DataVhd.SourceVHD = 'Intentionally Removed'
            }
            # Remove the DSCConfigFile path as this will be relative as well
            $VMs[0].DSCConfigFile = ''
            It 'Returns Template Object that matches Expected Object' {
                Set-Content -Path "$Global:ArtifactPath\ExpectedVMs.json" -Value ($VMs | ConvertTo-Json -Depth 6)
                $ExpectedVMs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedVMs.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedVMs.json"),$ExpectedVMs,$true) | Should Be 0
            }
        }
    }



    Describe 'Get-LabVMelfSignedCert' -Tags 'Incomplete' {
    }



    Describe 'Start-LabVM' -Tags 'Incomplete' {
        #region Mocks
        Mock Get-VM -ParameterFilter { $Name -eq 'PESTER01' } -MockWith { [PSObject]@{ Name='PESTER01'; State='Off' } }
        Mock Get-VM -ParameterFilter { $Name -eq 'pester template *' }
        Mock Start-VM
        Mock Wait-LabVMInit -MockWith { $True }
        Mock Get-LabVMelfSignedCert -MockWith { $True }
        Mock Initialize-LabVMDSC
        Mock Start-LabVMDSC
        #endregion

        Context 'Valid configuration is passed' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
                    
            It 'Returns True' {
                Start-LabVM -Config $Config -VM $VMs[0] | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'PESTER01' } -Exactly 1
                Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'pester template *' } -Exactly 1
                Assert-MockCalled Start-VM -Exactly 1
                Assert-MockCalled Wait-LabVMInit -Exactly 1
                Assert-MockCalled Get-LabVMelfSignedCert -Exactly 1
                Assert-MockCalled Initialize-LabVMDSC -Exactly 1
                Assert-MockCalled Start-LabVMDSC -Exactly 1
            }
            
            Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }



    Describe 'Update-LabVMDataDisk' {
        #region Mocks
        Mock Get-VM
        Mock Get-VHD
        Mock Resize-VHD
        Mock Move-Item
        Mock Copy-Item
        Mock New-VHD
        Mock Get-VMHardDiskDrive
        Mock Add-VMHardDiskDrive
        Mock Test-Path -ParameterFilter { $Path -eq 'DoesNotExist.Vhdx' } -MockWith { $False }        
        Mock Test-Path -ParameterFilter { $Path -eq 'DoesExist.Vhdx' } -MockWith { $True }        
        Mock Initialize-VHD
        Mock Mount-VHD
        Mock Dismount-VHD
        Mock Copy-Item
        Mock New-Item
        #endregion

        # The same VM will be used for all tests, but a different
        # DataVHds array will be created/assigned for each test.
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$Switches = Get-LabSwitch -Config $Config
        [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches

        Context 'Valid configuration is passed with no DataVHDs' {
            $VMs[0].DataVHDs = @()
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that exists but has different type' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
                
            } )
            Mock Get-VHD -MockWith { @{
                VhdType =  'Dynamic'
            } }
            It 'Throws VMDataDiskVHDConvertError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDConvertError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDConvertError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs.Vhd,$VMs[0].DataVHDs.Type)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that exists but has smaller size' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
            } )
            Mock Get-VHD -MockWith { @{
                VhdType =  'Fixed'
                Size = 20GB
            } }
            It 'Throws VMDataDiskVHDShrinkError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDShrinkError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDShrinkError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].Vhd,$VMs[0].DataVHDs[0].Size)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that exists but has larger size' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 30GB
            } )
            Mock Get-VHD -MockWith { @{
                VhdType =  'Fixed'
                Size = 20GB
            } }
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 1
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Mock Get-VHD
        Context 'Valid configuration is passed with a SourceVHD and DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                SourceVhd = 'DoesNotExist.Vhdx'
            } )
            It 'Throws VMDataDiskSourceVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].SourceVhd)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a SourceVHD that exists and DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                SourceVhd = 'DoesExist.Vhdx'
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a SourceVHD that exists and DataVHD that do not exist and MoveSourceVHD set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                SourceVhd = 'DoesExist.Vhdx'
                MoveSourceVHD = $true
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Fixed DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Dynamic DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Dynamic DataVHD that does not exist and PartitionStyle and FileSystem is set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
                PartitionStyle = 'GPT'
                FileSystem = 'NTFS'
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Initialize-VHD -Exactly 1
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 1
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Dynamic DataVHD that does not exist and PartitionStyle, FileSystem and CopyFolders is set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
                PartitionStyle = 'GPT'
                FileSystem = 'NTFS'
                CopyFolders = "$Global:TestConfigPath\ExpectedContent"
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Initialize-VHD -Exactly 1
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 1
                Assert-MockCalled New-Item -Exactly 1
            }
        }
        Context 'Valid configuration is passed with a 10GB Dynamic DataVHD that does not exist and CopyFolders is set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
                CopyFolders = "$Global:TestConfigPath\ExpectedContent"
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Initialize-VHD -Exactly 1
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 1
                Assert-MockCalled New-Item -Exactly 1
            }
        }
        Context 'Valid configuration is passed with a 10GB Differencing DataVHD that does not exist where ParentVHD is not set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Differencing'
                Size = 10GB
            } )
            It 'Throws VMDataDiskParentVHDMissingError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                        -f $VMs[0].Name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Differencing DataVHD that does not exist where ParentVHD does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Differencing'
                Size = 10GB
                ParentVHD = 'DoesNotExist.vhdx'
            } )
            It 'Throws VMDataDiskParentVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].ParentVhd)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Differencing DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
                ParentVHD = 'DoesExist.vhdx'
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that does not exist and an unknown Type' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Unknown'
                Size = 10GB
            } )
            It 'Throws VMDataDiskUnknownTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskUnknownTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].Vhd,$VMs[0].DataVHDs[0].Type)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Mock Get-VHD -MockWith { @{
            VhdType =  'Fixed'
            Size = 10GB
        } }
        Context 'Valid configuration is passed with a 10GB Fixed DataVHD that exists and is already added to VM' {
            Mock Get-VMHardDiskDrive -MockWith { @{ Path = 'DoesExist.vhdx' } }
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Initialize-VHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
    }


    Describe 'Update-LabVMIntegrationService' {
        #region Mocks
        Mock Get-VMIntegrationService -MockWith { @(
            @{ Name = 'Guest Service Interface'; Enabled = $False }
            @{ Name = 'Heartbeat'; Enabled = $True }
            @{ Name = 'Key-Value Pair Exchange'; Enabled = $True }
            @{ Name = 'Shutdown'; Enabled = $True }
            @{ Name = 'Time Synchronization'; Enabled = $True }
            @{ Name = 'VSS'; Enabled = $True }                             
        ) }
        Mock Enable-VMIntegrationService
        Mock Disable-VMIntegrationService
        #endregion

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$Switches = Get-LabSwitch -Config $Config

        Context 'Valid configuration is passed with null Integration Services' {
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            $VMs[0].Remove('IntegrationServices')
            It 'Does not throw an Exception' {
                { Update-LabVMIntegrationService -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMIntegrationService -Exactly 1
                Assert-MockCalled Enable-VMIntegrationService -Exactly 1
                Assert-MockCalled Disable-VMIntegrationService -Exactly 0
            }
        }

        Context 'Valid configuration is passed with blank Integration Services' {
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = ''
            It 'Does not throw an Exception' {
                { Update-LabVMIntegrationService -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMIntegrationService -Exactly 1
                Assert-MockCalled Enable-VMIntegrationService -Exactly 0 
                Assert-MockCalled Disable-VMIntegrationService -Exactly 5
            }
        }

        Context 'Valid configuration is passed with VSS only enabled' {
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = 'VSS'
            It 'Does not throw an Exception' {
                { Update-LabVMIntegrationService -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMIntegrationService -Exactly 1
                Assert-MockCalled Enable-VMIntegrationService -Exactly 0 
                Assert-MockCalled Disable-VMIntegrationService -Exactly 4
            }
        }
        Context 'Valid configuration is passed with Guest Service Interface only enabled' {
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = 'Guest Service Interface'
            It 'Does not throw an Exception' {
                { Update-LabVMIntegrationService -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMIntegrationService -Exactly 1
                Assert-MockCalled Enable-VMIntegrationService -Exactly 1 
                Assert-MockCalled Disable-VMIntegrationService -Exactly 5
            }
        }
    }
    
    Describe 'Initialize-LabVM'  -Tags 'Incomplete' {
        #region Mocks
        Mock New-VHD
        Mock New-VM
        Mock Get-VM -MockWith { [PSObject]@{ ProcessorCount = '2'; State = 'Off' } }
        Mock Set-VM
        Mock Get-VMHardDiskDrive
        Mock Set-LabVMInitializationFiles
        Mock Get-VMNetworkAdapter
        Mock Add-VMNetworkAdapter
        Mock Start-VM
        Mock Wait-LabVMInit -MockWith { $True }
        Mock Get-LabVMelfSignedCert
        Mock Initialize-LabVMDSC
        Mock Start-LabVMDSC
        #endregion

        Context 'Valid configuration is passed' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
                    
            It 'Returns True' {
                Initialize-LabVM -Config $Config -VMs $VMs | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled New-VM -Exactly 1
                Assert-MockCalled Set-VM -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Set-LabVMInitializationFiles -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 9
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Start-VM -Exactly 1
                Assert-MockCalled Wait-LabVMInit -Exactly 1
                Assert-MockCalled Get-LabVMelfSignedCert -Exactly 1
                Assert-MockCalled Initialize-LabVMDSC -Exactly 1
                Assert-MockCalled Start-LabVMDSC -Exactly 1
            }
            
            Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }



    Describe 'Remove-LabVM' {
        #region Mocks
        Mock Get-VM -MockWith { [PSObject]@{ Name = 'PESTER01'; State = 'Running'; } }
        Mock Stop-VM
        Mock Wait-LabVMOff -MockWith { Return $True }
        Mock Get-VMHardDiskDrive
        Mock Remove-VM
        #endregion

        Context 'Valid configuration is passed' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches

            # Create the dummy VM's that the Remove-LabVM function 
            It 'Returns True' {
                Remove-LabVM -Config $Config -VMs $VMs | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 3
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled Wait-LabVMOff -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Remove-VM -Exactly 1
            }
        }
        Context 'Valid configuration is passed but VMs not passed' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

            # Create the dummy VM's that the Remove-LabVM function 
            It 'Returns True' {
                Remove-LabVM -Config $Config | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 3
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled Wait-LabVMOff -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Remove-VM -Exactly 1
            }
        }
        Context 'Valid configuration is passed with RemoveVHDs switch' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            [Array]$Templates = Get-LabVMTemplate -Config $Config
            [Array]$Switches = Get-LabSwitch -Config $Config
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches

            # Create the dummy VM's that the Remove-LabVM function 
            It 'Returns True' {
                Remove-LabVM -Config $Config -VMs $VMs -RemoveVHDs | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 3
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled Wait-LabVMOff -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Remove-VM -Exactly 1
            }
        }
    }



    Describe 'Wait-LabVMInit' -Tags 'Incomplete' {
    }



    Describe 'Wait-LabVMStart' -Tags 'Incomplete'  {
    }



    Describe 'Wait-LabVMOff' -Tags 'Incomplete'  {
    }



    Describe 'Install-Lab' -Tags 'Incomplete'  {
    }



    Describe 'Uninstall-Lab' -Tags 'Incomplete'  {
    }
}