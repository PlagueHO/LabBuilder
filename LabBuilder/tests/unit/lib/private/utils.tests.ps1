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
        function Get-Exception
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

        Describe '\Lib\Private\Utils.ps1\Invoke-LabDownloadAndUnzipFile' {
            $URL = 'https://raw.githubusercontent.com/PlagueHO/LabBuilder/dev/LICENSE'

            Context 'Download folder does not exist' {
                Mock -CommandName Invoke-WebRequest
                Mock -CommandName Expand-Archive
                Mock -CommandName Remove-Item

                It 'Throws a DownloadFolderDoesNotExistError Exception' {
                    $exceptionParameters = @{
                        errorId = 'DownloadFolderDoesNotExistError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DownloadFolderDoesNotExistError `
                            -f 'c:\doesnotexist','LICENSE')
                    }
                    $Exception = Get-Exception @exceptionParameters

                    { Invoke-LabDownloadAndUnzipFile -URL $URL -DestinationPath 'c:\doesnotexist' } | Should -Throw $Exception
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                }
            }

            Context 'Download fails' {
                Mock -CommandName Invoke-WebRequest { Throw ('Download Error') }
                Mock -CommandName Expand-Archive
                Mock -CommandName Remove-Item

                It 'Throws a FileDownloadError Exception' {

                    $exceptionParameters = @{
                        errorId = 'FileDownloadError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.FileDownloadError `
                            -f 'LICENSE',$URL,'Download Error')
                    }
                    $Exception = Get-Exception @exceptionParameters

                    { Invoke-LabDownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should -Throw $Exception
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                }
            }

            Context 'Download OK' {
                Mock -CommandName Invoke-WebRequest
                Mock -CommandName Expand-Archive
                Mock -CommandName Remove-Item

                It 'Does not throw an Exception' {
                    { Invoke-LabDownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                }
            }

            $URL = 'https://raw.githubusercontent.com/PlagueHO/LabBuilder/dev/LICENSE.ZIP'

            Context 'Zip Download OK, Extract fails' {
                Mock -CommandName Invoke-WebRequest
                Mock -CommandName Expand-Archive { Throw ('Extract Error') }
                Mock -CommandName Remove-Item

                It 'Throws a FileExtractError Exception' {
                    $exceptionParameters = @{
                        errorId = 'FileExtractError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.FileExtractError `
                            -f 'LICENSE.ZIP','Extract Error')
                    }
                    $Exception = Get-Exception @exceptionParameters

                    { Invoke-LabDownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should -Throw $Exception
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 1
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1
                }
            }

            Context 'Zip Download OK, Extract OK' {
                Mock -CommandName Invoke-WebRequest
                Mock -CommandName Expand-Archive
                Mock -CommandName Remove-Item

                It 'Does not throw an Exception' {
                    { Invoke-LabDownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 1
                }
            }
        }

        Describe '\Lib\Private\Utils.ps1\Invoke-LabDownloadResourceModule' {
            $URL = 'https://github.com/PowerShell/xNetworking/archive/dev.zip'

            Mock -CommandName Get-Module -MockWith { @( New-Object -TypeName PSObject -Property @{ Name = 'xNetworking'; Version = '2.4.0.0'; } ) }
            Mock -CommandName Invoke-WebRequest
            Mock -CommandName Expand-Archive
            Mock -CommandName Rename-Item
            Mock -CommandName Test-Path -MockWith { $false } -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" }
            Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" }
            Mock -CommandName Remove-Item
            Mock -CommandName Get-PackageProvider
            Mock -CommandName Install-Module

            Context 'Correct module already installed; Valid URL and Folder passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -URL $URL `
                            -Folder 'xNetworkingDev'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" } -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                }
            }

            Mock -CommandName Get-Module -MockWith { }

            Context 'Module is not installed; Valid URL and Folder passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -URL $URL `
                            -Folder 'xNetworkingDev'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 1
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 1
                    Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" } -Exactly -Times 1
                    Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly -Times 1
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                }
            }

            Context 'Module is not installed; No URL or Folder passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 1
                }
            }

            Mock -CommandName Get-Module -MockWith { @( New-Object -TypeName PSObject -Property @{ Name = 'xNetworking'; Version = '2.4.0.0'; } ) }

            Context 'Wrong version of module is installed; Valid URL, Folder and Required Version passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -URL $URL `
                            -Folder 'xNetworkingDev' `
                            -RequiredVersion '2.5.0.0'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 1
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 1
                    Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" } -Exactly -Times 1
                    Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly -Times 1
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                }
            }

            Context 'Wrong version of module is installed; No URL or Folder passed, but Required Version passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -RequiredVersion '2.5.0.0'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 1
                }
            }

            Context 'Correct version of module is installed; Valid URL, Folder and Required Version passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -URL $URL `
                            -Folder 'xNetworkingDev' `
                            -RequiredVersion '2.4.0.0'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                }
            }

            Context 'Correct version of module is installed; No URL and Folder passed, but Required Version passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -RequiredVersion '2.4.0.0'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                }
            }

            Context 'Wrong version of module is installed; Valid URL, Folder and Minimum Version passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -URL $URL `
                            -Folder 'xNetworkingDev' `
                            -MinimumVersion '2.5.0.0'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 1
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 1
                    Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\xNetworking" } -Exactly -Times 1
                    Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly -Times 1
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                }
            }

            Context 'Wrong version of module is installed; No URL and Folder passed, but Minimum Version passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -MinimumVersion '2.5.0.0'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 1
                }
            }

            Context 'Correct version of module is installed; Valid URL, Folder and Minimum Version passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -URL $URL `
                            -Folder 'xNetworkingDev' `
                            -MinimumVersion '2.4.0.0'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                }
            }

            Context 'Correct version of module is installed; No URL and Folder passed, but Minimum Version passed' {
                It 'Does not throw an Exception' {
                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -MinimumVersion '2.4.0.0'
                    } | Should -Not -Throw
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                }
            }

            Mock -CommandName Get-Module -MockWith { }
            Mock -CommandName Invoke-WebRequest -MockWith { Throw ('Download Error') }

            Context 'Module is not installed; Bad URL passed' {
                It 'Throws a FileDownloadError exception' {
                    $exceptionParameters = @{
                        errorId = 'FileDownloadError'
                        errorCategory = 'InvalidOperation'
                        errorMessage = $($LocalizedData.FileDownloadError `
                            -f 'dev.zip',$URL,'Download Error')
                    }
                    $Exception = Get-Exception @exceptionParameters

                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -URL $URL `
                            -Folder 'xNetworkingDev'
                    } | Should -Throw $Exception
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
                }
            }

            Mock -CommandName Install-Module -MockWith { Throw ("No match was found for the specified search criteria and module name 'xDoesNotExist'" )}

            Context 'Module is not installed; Not available in Repository' {
                It 'Throws a ModuleNotAvailableError exception' {
                    $exceptionParameters = @{
                        errorId = 'ModuleNotAvailableError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ModuleNotAvailableError `
                            -f 'xDoesNotExist','any version',"No match was found for the specified search criteria and module name 'xDoesNotExist'")
                    }
                    $Exception = Get-Exception @exceptionParameters

                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xDoesNotExist'
                    } | Should -Throw $Exception
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 1
                }
            }

            Mock -CommandName Install-Module -MockWith { Throw ("No match was found for the specified search criteria and module name 'xNetworking'" )}

            Context 'Wrong version of module is installed; No URL or Folder passed, but Required Version passed. Required Version is not available' {
                It ' Throws a ModuleNotAvailableError Exception' {
                    $exceptionParameters = @{
                        errorId = 'ModuleNotAvailableError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ModuleNotAvailableError `
                            -f 'xNetworking','2.5.0.0',"No match was found for the specified search criteria and module name 'xNetworking'" )
                    }
                    $Exception = Get-Exception @exceptionParameters

                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -RequiredVersion '2.5.0.0'
                    } | Should -Throw $Exception
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 1
                }
            }

            Context 'Wrong version of module is installed; No URL or Folder passed, but Minimum Version passed. Minimum Version is not available' {
                It ' Throws a ModuleNotAvailableError Exception' {
                    $exceptionParameters = @{
                        errorId = 'ModuleNotAvailableError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ModuleNotAvailableError `
                            -f 'xNetworking','min 2.5.0.0',"No match was found for the specified search criteria and module name 'xNetworking'" )
                    }
                    $Exception = Get-Exception @exceptionParameters

                    {
                        Invoke-LabDownloadResourceModule `
                            -Name 'xNetworking' `
                            -MinimumVersion '2.5.0.0'
                    } | Should -Throw $Exception
                }

                It 'Should call appropriate Mocks' {
                    Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                    Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                    Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                    Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0
                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1
                    Assert-MockCalled -CommandName Install-Module -Exactly -Times 1
                }
            }
        }

        Describe '\Lib\Private\Utils.ps1\New-LabCredential' {
            Context 'Username and Password provided' {
                $testUsername = 'testUsername'
                $testPassword = 'testPassword'
                $testCredetial = New-Object `
                    -TypeName System.Management.Automation.PSCredential `
                    -ArgumentList ($testUsername, (ConvertTo-SecureString $testPassword -AsPlainText -Force))

                It 'Should return the exepected credential object' {
                    $result = New-LabCredential -Username $testUsername -Password $testPassword
                    $result | Should -BeOfType [System.Management.Automation.PSCredential]
                    $result.Username | Should -Be $testUsername
                }
            }
        }

        Describe '\Lib\Private\Utils.ps1\Install-LabHyperV' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath

            if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
                Mock -CommandName Get-WindowsOptionalFeature -MockWith {
                    [PSObject] @{
                        FeatureName = 'Mock'
                        State = 'Disabled'
                    }
                }
                Mock -CommandName Enable-WindowsOptionalFeature
            }
            else
            {
                Mock -CommandName Get-WindowsFeature -MockWith {
                    [PSObject] @{
                        Name = 'Mock'
                        Installed = $false
                    }
                }
                Mock -CommandName Install-WindowsFeature
            }

            Context 'The function is called' {
                It 'Does not throw an Exception' {
                    { Install-LabHyperV } | Should -Not -Throw
                }
                if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
                    It 'Calls appropriate mocks' {
                        Assert-MockCalled -CommandName Get-WindowsOptionalFeature -Exactly -Times 1
                        Assert-MockCalled -CommandName Enable-WindowsOptionalFeature -Exactly -Times 1
                    }
                }
                else
                {
                    It 'Calls appropriate mocks' {
                        Assert-MockCalled -CommandName Get-WindowsFeature -Exactly -Times 1
                        Assert-MockCalled -CommandName Install-WindowsFeature -Exactly -Times 1
                    }
                }
            }
        }

        Describe '\Lib\Private\Utils.ps1\Enable-LabWSMan' {
            Context 'WS-Man is already enabled' {
                Mock -CommandName Start-Service
                Mock -CommandName Get-PSProvider -MockWith {
                    @{
                        Name = 'wsman'
                    }
                }
                Mock -CommandName Enable-PSRemoting

                It 'Does not throw an Exception' {
                    { Enable-LabWSMan } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Enable-PSRemoting -Exactly -Times 0
                }
            }

            Context 'WS-Man is not enabled, user declines install' {
                Mock -CommandName Start-Service -MockWith { Throw }
                Mock -CommandName Get-PSProvider
                Mock -CommandName Enable-PSRemoting

                It 'Should throw WSManNotEnabledError exception' {
                    $exceptionParameters = @{
                        errorId = 'WSManNotEnabledError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.WSManNotEnabledError)
                    }
                    $Exception = Get-Exception @exceptionParameters

                    { Enable-LabWSMan } | Should -Throw $Exception
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Enable-PSRemoting -Exactly -Times 1
                }
            }
        }

        Describe '\Lib\Private\Utils.ps1\Assert-ValidConfigurationXMLSchema' -Tag 'Incomplete' {
        }

        Describe '\Lib\Private\Utils.ps1\Get-NextMacAddress' {
            Context 'MAC address 00155D0106ED is passed' {
                It 'Returns MAC address 00155D0106EE' {
                    Get-NextMacAddress `
                        -MacAddress '00155D0106ED' | Should -Be '00155D0106EE'
                }
            }

            Context 'MAC address 00155D0106ED and step 10 is passed' {
                It 'Returns IP address 00155D0106F7' {
                    Get-NextMacAddress `
                        -MacAddress '00155D0106ED' `
                        -Step 10 | Should -Be '00155D0106F7'
                }
            }

            Context 'MAC address 00155D0106ED and step 0 is passed' {
                It 'Returns IP address 00155D0106ED' {
                    Get-NextMacAddress `
                        -MacAddress '00155D0106ED' `
                        -Step 0 | Should -Be '00155D0106ED'
                }
            }
        }

        Describe '\Lib\Private\Utils.ps1\Get-NextIpAddress' {
            Context 'Invalid IP Address is passed' {
                It 'Throws a IPAddressError Exception' {
                    $exceptionParameters = @{
                        errorId = 'IPAddressError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.IPAddressError `
                            -f '192.168.1.999' )
                    }
                    $Exception = Get-Exception @exceptionParameters

                    {
                        Get-NextIpAddress `
                            -IpAddress '192.168.1.999'
                    } | Should -Throw $Exception
                }
            }

            Context 'IP address 192.168.1.1 is passed' {
                It 'Returns IP address 192.168.1.2' {
                    Get-NextIpAddress `
                        -IpAddress '192.168.1.1' | Should -Be '192.168.1.2'
                }
            }

            Context 'IP address 192.168.1.255 is passed' {
                It 'Returns IP address 192.168.2.0' {
                    Get-NextIpAddress `
                        -IpAddress '192.168.1.255' | Should -Be '192.168.2.0'
                }
            }

            Context 'IP address 192.168.1.255 and Step 10 is passed' {
                It 'Returns IP address 192.168.2.9' {
                    Get-NextIpAddress `
                        -IpAddress '192.168.1.255' `
                        -Step 10 | Should -Be '192.168.2.9'
                }
            }

            Context 'IP address 192.168.1.255 and Step 0 is passed' {
                It 'Returns IP address 192.168.1.255' {
                    Get-NextIpAddress `
                        -IpAddress '192.168.1.255' `
                        -Step 0 | Should -Be '192.168.1.255'
                }
            }

            Context 'IP address 10.255.255.255 is passed' {
                It 'Returns IP address 11.0.0.0' {
                    Get-NextIpAddress `
                        -IpAddress '10.255.255.255' | Should -Be '11.0.0.0'
                }
            }

            Context 'IP address fe80::15b4:b934:5d23:1a31 is passed' {
                It 'Returns IP address fe80::15b4:b934:5d23:1a32' {
                    Get-NextIpAddress `
                        -IpAddress 'fe80::15b4:b934:5d23:1a31' | Should -Be 'fe80::15b4:b934:5d23:1a32'
                }
            }
        }

        Describe '\Lib\Private\Utils.ps1\Assert-ValidIpAddress' {
            Context 'IP address 192.168.1.1 is passed' {
                It 'Returns IP Address' {
                    Assert-ValidIpAddress `
                        -IpAddress '192.168.1.1' | Should -Be '192.168.1.1'
                }
            }

            Context 'IP address 192.168.1.1000 is passed' {
                It 'Should Throw an Exception' {
                    {
                        Assert-ValidIpAddress `
                            -IpAddress '192.168.1.1000'
                    } | Should -Throw $($LocalizedData.IPAddressError -f '192.168.1.1000')
                }
            }

            Context 'IP address fe80::15b4:b934:5d23:1a31 is passed' {
                It 'Returns IP Address' {
                    Assert-ValidIpAddress `
                        -IpAddress 'fe80::15b4:b934:5d23:1a31' | Should -Be 'fe80::15b4:b934:5d23:1a31'
                }
            }

            Context 'IP address fe80::15b4:b934:5d23:1a3x is passed' {
                It 'Should Throw an Exception' {
                    {
                        Assert-ValidIpAddress `
                            -IpAddress 'fe80::15b4:b934:5d23:1a3x'
                    } | Should -Throw $($LocalizedData.IPAddressError -f 'fe80::15b4:b934:5d23:1a3x')
                }
            }
        }

        Describe '\Lib\Private\Utils.ps1\Install-LabPackageProvider' {
            Context 'Required package providers already installed' {
                Mock -CommandName Get-PackageProvider -MockWith {
                    @(
                        @{ Name = 'PowerShellGet' },
                        @{ Name = 'NuGet' }
                    )
                }

                Mock -CommandName Install-PackageProvider

                It 'Does not throw an Exception' {
                    { Install-LabPackageProvider -Force } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1
                    Assert-MockCalled -CommandName Install-PackageProvider -Exactly -Times 0
                }
            }

            Context 'Required package providers not installed' {
                Mock -CommandName Get-PackageProvider
                Mock -CommandName Install-PackageProvider

                It 'Does not throw an Exception' {
                    { Install-LabPackageProvider -Force } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 1
                    Assert-MockCalled -CommandName Install-PackageProvider -Exactly -Times 2
                }
            }
        }



        Describe '\Lib\Private\Utils.ps1\Register-LabPackageSource' {
            # Define this function because the built in definition does not
            # Mock -CommandName properly - the ProviderName parameter is not definied.
            function Register-PackageSource
            {
                [CmdletBinding()]
                param
                (
                    [System.String] $Name,
                    [System.String] $Location,
                    [System.String] $ProviderName,
                    [Switch] $Trusted,
                    [Switch] $Force
                )
            }

            function Get-PackageSource
            {
                [CmdletBinding()]
                param
                (
                )
            }

            BeforeEach {
                Mock -CommandName Set-PackageSource
                Mock -CommandName Register-PackageSource
            }

            Context 'Required package sources already registered and trusted' {
                Mock -CommandName Get-PackageSource -MockWith {
                    @(
                        [psobject] @{
                            Name         = 'nuget.org'
                            ProviderName = 'NuGet'
                            Location     = 'https://www.nuget.org/api/v2/'
                            IsTrusted    = $True
                        },
                        [psobject] @{
                            Name         = 'PSGallery'
                            ProviderName = 'PowerShellGet'
                            Location     = 'https://www.powershellgallery.com/api/v2/'
                            IsTrusted    = $True
                        }
                    )
                }

                It 'Does not throw an Exception' {
                    {
                        Register-LabPackageSource -Force -Verbose
                    } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Get-PackageSource -Exactly -Times 1
                    Assert-MockCalled -CommandName Set-PackageSource -Exactly -Times 0
                    Assert-MockCalled -CommandName Register-PackageSource -Exactly -Times 0
                }
            }

            Context 'Required package sources already registered but not trusted' {
                Mock -CommandName Get-PackageSource -MockWith {
                    @(
                        [psobject] @{
                            Name         = 'nuget.org'
                            ProviderName = 'NuGet'
                            Location     = 'https://www.nuget.org/api/v2/'
                            IsTrusted    = $False
                        },
                        [psobject] @{
                            Name         = 'PSGallery'
                            ProviderName = 'PowerShellGet'
                            Location     = 'https://www.powershellgallery.com/api/v2/'
                            IsTrusted    = $False
                        }
                    )
                }

                It 'Does not throw an Exception' {
                    {
                        Register-LabPackageSource -Force -Verbose
                    } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Get-PackageSource -Exactly -Times 1
                    Assert-MockCalled -CommandName Set-PackageSource -Exactly -Times 2
                    Assert-MockCalled -CommandName Register-PackageSource -Exactly -Times 0
                }
            }

            Context 'Required package sources are not registered' {
                Mock -CommandName Get-PackageSource

                It 'Does not throw an Exception' {
                    {
                        Register-LabPackageSource -Force -Verbose
                    } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Get-PackageSource -Exactly -Times 1
                    Assert-MockCalled -CommandName Set-PackageSource -Exactly -Times 0
                    Assert-MockCalled -CommandName Register-PackageSource -Exactly -Times 2
                }
            }
        }

        Describe '\Lib\Private\Utils.ps1\Write-LabMessage' {
            $script:testMessage = 'Test Message'
            $script:testMessageTime = Get-Date -UFormat %T
            $script:testMessageWithTime = ('[{0}]: {1}' -f $script:testMessageTime, $script:testMessage)
            $script:testInfoMessageWithTime = ('INFO: [{0}]: {1}' -f $script:testMessageTime, $script:testMessage)

            Mock -CommandName Get-Date -ParameterFilter { $UFormat -eq '%T' } -MockWith { $script:testMessageTime }

            Context 'Write an error message' {
                Mock -CommandName Write-Error -ParameterFilter { $Message -eq $script:testMessage }

                It 'Does not throw an Exception' {
                    {
                        Write-LabMessage -Type 'Error' -Message $script:testMessage
                    } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Write-Error -ParameterFilter { $Message -eq $script:testMessage } -Exactly -Times 1
                }
            }

            Context 'Write a warning message' {
                Mock -CommandName Write-Warning -ParameterFilter { $Message -eq $script:testMessageWithTime }

                It 'Does not throw an Exception' {
                    {
                        Write-LabMessage -Type 'Warning' -Message $script:testMessage
                    } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Write-Warning -ParameterFilter { $Message -eq $script:testMessageWithTime } -Exactly -Times 1
                }
            }

            Context 'Write a verbose message' {
                Mock -CommandName Write-Verbose -ParameterFilter { $Message -eq $script:testMessageWithTime }

                It 'Does not throw an Exception' {
                    {
                        Write-LabMessage -Type 'Verbose' -Message $script:testMessage
                    } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Write-Verbose -ParameterFilter { $Message -eq $script:testMessageWithTime } -Exactly -Times 1
                }
            }

            Context 'Write a debug message' {
                Mock -CommandName Write-Debug -ParameterFilter { $Message -eq $script:testMessageWithTime }

                It 'Does not throw an Exception' {
                    {
                        Write-LabMessage -Type 'Debug' -Message $script:testMessage
                    } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Write-Debug -ParameterFilter { $Message -eq $script:testMessageWithTime } -Exactly -Times 1
                }
            }

            Context 'Write an information message' {
                Mock -CommandName Write-Information -ParameterFilter { $MessageData -eq $script:testInfoMessageWithTime }

                It 'Does not throw an Exception' {
                    {
                        Write-LabMessage -Type 'Info' -Message $script:testMessage
                    } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Write-Information -ParameterFilter { $MessageData -eq $script:testInfoMessageWithTime } -Exactly -Times 1
                }
            }

            Context 'Write an alert message' {
                Mock -CommandName Write-Host -ParameterFilter { $Object -eq $script:testMessage }

                It 'Does not throw an Exception' {
                    {
                        Write-LabMessage -Type 'Alert' -Message $script:testMessage
                    } | Should -Not -Throw
                }

                It 'Calls appropriate mocks' {
                    Assert-MockCalled -CommandName Write-Host -ParameterFilter { $Object -eq $script:testMessage } -Exactly -Times 1
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
    $env:PSModulePath = $OldPSModulePath
}
