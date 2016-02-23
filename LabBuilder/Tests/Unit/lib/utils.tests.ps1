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
    
    
    
    Describe 'IsAdmin' -Tag 'Incomplete' {
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
                $Exception = GetException @ExceptionParameters

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
                $Exception = GetException @ExceptionParameters

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
                $Exception = GetException @ExceptionParameters

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



    Describe 'CreateCredential' -Tag 'Incomplete' {
    }



    Describe 'DownloadModule' {
        $URL = 'https://github.com/PowerShell/xNetworking/archive/dev.zip'
        
        Mock Get-Module -MockWith { @( New-Object -TypeName PSObject -Property @{ Name = 'xNetworking'; Version = '2.4.0.0'; } ) }
        Mock Invoke-WebRequest
        Mock Expand-Archive
        Mock Rename-Item
        Mock Test-Path -MockWith { $false } -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" }
        Mock Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" }
        Mock Remove-Item
        Mock Get-PackageProvider
        Mock Install-Module
        Context 'Correct module already installed; Valid URL and Folder passed' {
            It 'Does not throw an Exception' {
                {
                    DownloadModule `
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
                Assert-MockCalled Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" } -Exactly 0
                Assert-MockCalled Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }
        Mock Get-Module -MockWith { }
        Context 'Module is not installed; Valid URL and Folder passed' {
            It 'Does not throw an Exception' {
                {
                    DownloadModule `
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
                Assert-MockCalled Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" } -Exactly 1
                Assert-MockCalled Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 1
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }
        Context 'Module is not installed; No URL or Folder passed' {
            It 'Does not throw an Exception' {
                {
                    DownloadModule `
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
                    DownloadModule `
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
                Assert-MockCalled Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" } -Exactly 1
                Assert-MockCalled Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 1
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }
        Context 'Wrong version of module is installed; No URL or Folder passed, but Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    DownloadModule `
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
                    DownloadModule `
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
                    DownloadModule `
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
                    DownloadModule `
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
                Assert-MockCalled Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" } -Exactly 1
                Assert-MockCalled Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 1
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }
        Context 'Wrong version of module is installed; No URL and Folder passed, but Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    DownloadModule `
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
                    DownloadModule `
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
                    DownloadModule `
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
                        -f 'dev.zip',$URL,'Download Error')
                }
                $Exception = GetException @ExceptionParameters

                {
                    DownloadModule `
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
                Assert-MockCalled Test-Path -Exactly 1
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
                $Exception = GetException @ExceptionParameters

                {
                    DownloadModule `
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
                $Exception = GetException @ExceptionParameters

                {
                    DownloadModule `
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
                $Exception = GetException @ExceptionParameters

                {
                    DownloadModule `
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



    Describe 'DownloadResources' -Tags 'Incomplete' {
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Context 'Valid configuration is passed' {
            Mock DownloadModule
            It 'Does not throw an Exception' {
                { DownloadResources -Config $Config } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled DownloadModule -Exactly 4
            }
        }
    }



    Describe 'InstallHyperV' {

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
                { InstallHyperV } | Should Not Throw
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
}

Set-Location -Path $OldLocation