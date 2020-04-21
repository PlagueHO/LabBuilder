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

    Describe 'Invoke-LabDownloadAndUnzipFile' {
        $URL = 'https://raw.githubusercontent.com/PlagueHO/LabBuilder/dev/LICENSE'

        Context 'When Download folder does not exist' {
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
                $Exception = Get-LabException @exceptionParameters

                { Invoke-LabDownloadAndUnzipFile -URL $URL -DestinationPath 'c:\doesnotexist' } | Should -Throw $Exception
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
            }
        }

        Context 'When Download fails' {
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
                $Exception = Get-LabException @exceptionParameters

                { Invoke-LabDownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should -Throw $Exception
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
            }
        }

        Context 'When Download OK' {
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

        Context 'When Zip Download OK, Extract fails' {
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
                $Exception = Get-LabException @exceptionParameters

                { Invoke-LabDownloadAndUnzipFile -URL $URL -DestinationPath $ENV:Temp } | Should -Throw $Exception
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 1
                Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1
            }
        }

        Context 'When Zip Download OK, Extract OK' {
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

    Describe 'Invoke-LabDownloadResourceModule' {
        $URL = 'https://github.com/PowerShell/NetworkingDsc/archive/dev.zip'

        Mock -CommandName Get-Module -MockWith { @( New-Object -TypeName PSObject -Property @{ Name = 'NetworkingDsc'; Version = '2.4.0.0'; } ) }
        Mock -CommandName Invoke-WebRequest
        Mock -CommandName Expand-Archive
        Mock -CommandName Rename-Item
        Mock -CommandName Test-Path -MockWith { $false } -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\NetworkingDsc" }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" }
        Mock -CommandName Remove-Item
        Mock -CommandName Get-PackageProvider
        Mock -CommandName Install-Module

        Context 'When Correct module already installed; Valid URL and Folder passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
                        -URL $URL `
                        -Folder 'NetworkingDscDev'
                } | Should -Not -Throw
            }

            It 'Should call appropriate Mocks' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 0
                Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 0
                Assert-MockCalled -CommandName Rename-Item -Exactly -Times 0
                Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\NetworkingDsc" } -Exactly -Times 0
                Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly -Times 0
                Assert-MockCalled -CommandName Remove-Item -Exactly -Times 0
                Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
            }
        }

        Mock -CommandName Get-Module -MockWith { }

        Context 'When Module is not installed; Valid URL and Folder passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
                        -URL $URL `
                        -Folder 'NetworkingDscDev'
                } | Should -Not -Throw
            }

            It 'Should call appropriate Mocks' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 1
                Assert-MockCalled -CommandName Rename-Item -Exactly -Times 1
                Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\NetworkingDsc" } -Exactly -Times 1
                Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly -Times 1
                Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1
                Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
            }
        }

        Context 'When Module is not installed; No URL or Folder passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc'
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

        Mock -CommandName Get-Module -MockWith { @( New-Object -TypeName PSObject -Property @{ Name = 'NetworkingDsc'; Version = '2.4.0.0'; } ) }

        Context 'When Wrong version of module is installed; Valid URL, Folder and Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
                        -URL $URL `
                        -Folder 'NetworkingDscDev' `
                        -RequiredVersion '2.5.0.0'
                } | Should -Not -Throw
            }

            It 'Should call appropriate Mocks' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 1
                Assert-MockCalled -CommandName Rename-Item -Exactly -Times 1
                Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\NetworkingDsc" } -Exactly -Times 1
                Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly -Times 1
                Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1
                Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
            }
        }

        Context 'When Wrong version of module is installed; No URL or Folder passed, but Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
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

        Context 'When Correct version of module is installed; Valid URL, Folder and Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
                        -URL $URL `
                        -Folder 'NetworkingDscDev' `
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

        Context 'When Correct version of module is installed; No URL and Folder passed, but Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
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

        Context 'When Wrong version of module is installed; Valid URL, Folder and Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
                        -URL $URL `
                        -Folder 'NetworkingDscDev' `
                        -MinimumVersion '2.5.0.0'
                } | Should -Not -Throw
            }

            It 'Should call appropriate Mocks' {
                Assert-MockCalled -CommandName Get-Module -Exactly -Times 1
                Assert-MockCalled -CommandName Invoke-WebRequest -Exactly -Times 1
                Assert-MockCalled -CommandName Expand-Archive -Exactly -Times 1
                Assert-MockCalled -CommandName Rename-Item -Exactly -Times 1
                Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\NetworkingDsc" } -Exactly -Times 1
                Assert-MockCalled -CommandName Test-Path -ParameterFilter { $Path -eq $Path -eq "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\" } -Exactly -Times 1
                Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1
                Assert-MockCalled -CommandName Get-PackageProvider -Exactly -Times 0
                Assert-MockCalled -CommandName Install-Module -Exactly -Times 0
            }
        }

        Context 'When Wrong version of module is installed; No URL and Folder passed, but Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
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

        Context 'When Correct version of module is installed; Valid URL, Folder and Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
                        -URL $URL `
                        -Folder 'NetworkingDscDev' `
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

        Context 'When Correct version of module is installed; No URL and Folder passed, but Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
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

        Context 'When Module is not installed; Bad URL passed' {
            It 'Throws a FileDownloadError exception' {
                $exceptionParameters = @{
                    errorId = 'FileDownloadError'
                    errorCategory = 'InvalidOperation'
                    errorMessage = $($LocalizedData.FileDownloadError `
                        -f 'dev.zip',$URL,'Download Error')
                }
                $Exception = Get-LabException @exceptionParameters

                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
                        -URL $URL `
                        -Folder 'NetworkingDscDev'
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

        Context 'When Module is not installed; Not available in Repository' {
            It 'Throws a ModuleNotAvailableError exception' {
                $exceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f 'xDoesNotExist','any version',"No match was found for the specified search criteria and module name 'xDoesNotExist'")
                }
                $Exception = Get-LabException @exceptionParameters

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

        Mock -CommandName Install-Module -MockWith { Throw ("No match was found for the specified search criteria and module name 'NetworkingDsc'" )}

        Context 'When Wrong version of module is installed; No URL or Folder passed, but Required Version passed. Required Version is not available' {
            It ' Throws a ModuleNotAvailableError Exception' {
                $exceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f 'NetworkingDsc','2.5.0.0',"No match was found for the specified search criteria and module name 'NetworkingDsc'" )
                }
                $Exception = Get-LabException @exceptionParameters

                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
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

        Context 'When Wrong version of module is installed; No URL or Folder passed, but Minimum Version passed. Minimum Version is not available' {
            It ' Throws a ModuleNotAvailableError Exception' {
                $exceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f 'NetworkingDsc','min 2.5.0.0',"No match was found for the specified search criteria and module name 'NetworkingDsc'" )
                }
                $Exception = Get-LabException @exceptionParameters

                {
                    Invoke-LabDownloadResourceModule `
                        -Name 'NetworkingDsc' `
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

    Describe 'New-LabCredential' {
        Context 'When Username and Password provided' {
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

    Describe 'Install-LabHyperV.ps1' {
        $Lab = Get-Lab -ConfigPath $script:testConfigOKPath

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

        Context 'When The function is called' {
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

    Describe 'Enable-LabWSMan' {
        Context 'When WS-Man is already enabled' {
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

        Context 'When WS-Man is not enabled, user declines install' {
            Mock -CommandName Start-Service -MockWith { Throw }
            Mock -CommandName Get-PSProvider
            Mock -CommandName Enable-PSRemoting

            It 'Should throw WSManNotEnabledError exception' {
                $exceptionParameters = @{
                    errorId = 'WSManNotEnabledError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.WSManNotEnabledError)
                }
                $Exception = Get-LabException @exceptionParameters

                { Enable-LabWSMan } | Should -Throw $Exception
            }

            It 'Calls appropriate mocks' {
                Assert-MockCalled -CommandName Enable-PSRemoting -Exactly -Times 1
            }
        }
    }

    Describe 'Assert-LabValidConfigurationXMLSchema' -Tag 'Incomplete' {
    }

    Describe 'Get-NextMacAddress' {
        Context 'When MAC address 00155D0106ED is passed' {
            It 'Returns MAC address 00155D0106EE' {
                Get-NextMacAddress `
                    -MacAddress '00155D0106ED' | Should -Be '00155D0106EE'
            }
        }

        Context 'When MAC address 00155D0106ED and step 10 is passed' {
            It 'Returns IP address 00155D0106F7' {
                Get-NextMacAddress `
                    -MacAddress '00155D0106ED' `
                    -Step 10 | Should -Be '00155D0106F7'
            }
        }

        Context 'When MAC address 00155D0106ED and step 0 is passed' {
            It 'Returns IP address 00155D0106ED' {
                Get-NextMacAddress `
                    -MacAddress '00155D0106ED' `
                    -Step 0 | Should -Be '00155D0106ED'
            }
        }
    }

    Describe 'Get-LabNextIpAddress' {
        Context 'When Invalid IP Address is passed' {
            It 'Throws a IPAddressError Exception' {
                $exceptionParameters = @{
                    errorId = 'IPAddressError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.IPAddressError `
                        -f '192.168.1.999' )
                }
                $Exception = Get-LabException @exceptionParameters

                {
                    Get-LabNextIpAddress `
                        -IpAddress '192.168.1.999'
                } | Should -Throw $Exception
            }
        }

        Context 'When IP address 192.168.1.1 is passed' {
            It 'Returns IP address 192.168.1.2' {
                Get-LabNextIpAddress `
                    -IpAddress '192.168.1.1' | Should -Be '192.168.1.2'
            }
        }

        Context 'When IP address 192.168.1.255 is passed' {
            It 'Returns IP address 192.168.2.0' {
                Get-LabNextIpAddress `
                    -IpAddress '192.168.1.255' | Should -Be '192.168.2.0'
            }
        }

        Context 'When IP address 192.168.1.255 and Step 10 is passed' {
            It 'Returns IP address 192.168.2.9' {
                Get-LabNextIpAddress `
                    -IpAddress '192.168.1.255' `
                    -Step 10 | Should -Be '192.168.2.9'
            }
        }

        Context 'When IP address 192.168.1.255 and Step 0 is passed' {
            It 'Returns IP address 192.168.1.255' {
                Get-LabNextIpAddress `
                    -IpAddress '192.168.1.255' `
                    -Step 0 | Should -Be '192.168.1.255'
            }
        }

        Context 'When IP address 10.255.255.255 is passed' {
            It 'Returns IP address 11.0.0.0' {
                Get-LabNextIpAddress `
                    -IpAddress '10.255.255.255' | Should -Be '11.0.0.0'
            }
        }

        Context 'When IP address fe80::15b4:b934:5d23:1a31 is passed' {
            It 'Returns IP address fe80::15b4:b934:5d23:1a32' {
                Get-LabNextIpAddress `
                    -IpAddress 'fe80::15b4:b934:5d23:1a31' | Should -Be 'fe80::15b4:b934:5d23:1a32'
            }
        }
    }

    Describe 'Assert-LabValidIpAddress' {
        Context 'When IP address 192.168.1.1 is passed' {
            It 'Returns IP Address' {
                Assert-LabValidIpAddress `
                    -IpAddress '192.168.1.1' | Should -Be '192.168.1.1'
            }
        }

        Context 'When IP address 192.168.1.1000 is passed' {
            It 'Should Throw an Exception' {
                {
                    Assert-LabValidIpAddress `
                        -IpAddress '192.168.1.1000'
                } | Should -Throw $($LocalizedData.IPAddressError -f '192.168.1.1000')
            }
        }

        Context 'When IP address fe80::15b4:b934:5d23:1a31 is passed' {
            It 'Returns IP Address' {
                Assert-LabValidIpAddress `
                    -IpAddress 'fe80::15b4:b934:5d23:1a31' | Should -Be 'fe80::15b4:b934:5d23:1a31'
            }
        }

        Context 'When IP address fe80::15b4:b934:5d23:1a3x is passed' {
            It 'Should Throw an Exception' {
                {
                    Assert-LabValidIpAddress `
                        -IpAddress 'fe80::15b4:b934:5d23:1a3x'
                } | Should -Throw $($LocalizedData.IPAddressError -f 'fe80::15b4:b934:5d23:1a3x')
            }
        }
    }

    Describe 'Install-LabPackageProvider' {
        Context 'When Required package providers already installed' {
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

        Context 'When Required package providers not installed' {
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



    Describe 'Register-LabPackageSource' {
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

        Context 'When Required package sources already registered and trusted' {
            Mock -CommandName Get-PackageSource -MockWith {
                @(
                    [psobject] @{
                        Name         = 'nuget.org'
                        ProviderName = 'NuGet'
                        Location     = 'https://www.nuget.org/api/v2/'
                        IsTrusted    = $true
                    },
                    [psobject] @{
                        Name         = 'PSGallery'
                        ProviderName = 'PowerShellGet'
                        Location     = 'https://www.powershellgallery.com/api/v2/'
                        IsTrusted    = $true
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

        Context 'When Required package sources already registered but not trusted' {
            Mock -CommandName Get-PackageSource -MockWith {
                @(
                    [psobject] @{
                        Name         = 'nuget.org'
                        ProviderName = 'NuGet'
                        Location     = 'https://www.nuget.org/api/v2/'
                        IsTrusted    = $false
                    },
                    [psobject] @{
                        Name         = 'PSGallery'
                        ProviderName = 'PowerShellGet'
                        Location     = 'https://www.powershellgallery.com/api/v2/'
                        IsTrusted    = $false
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

        Context 'When Required package sources are not registered' {
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

    Describe 'Write-LabMessage' {
        $script:testMessage = 'Test Message'
        $script:testMessageTime = Get-Date -UFormat %T
        $script:testMessageWithTime = ('[{0}]: {1}' -f $script:testMessageTime, $script:testMessage)
        $script:testInfoMessageWithTime = ('INFO: [{0}]: {1}' -f $script:testMessageTime, $script:testMessage)

        Mock -CommandName Get-Date -ParameterFilter { $UFormat -eq '%T' } -MockWith { $script:testMessageTime }

        Context 'When Write an error message' {
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

        Context 'When Write a warning message' {
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

        Context 'When Write a verbose message' {
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

        Context 'When Write a debug message' {
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

        Context 'When Write an information message' {
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

        Context 'When Write an alert message' {
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

    Describe 'ConvertTo-LabAbsolutePath' {
        Context 'When absolute Path is passed' {
            It 'Should return the absolute path' {
                ConvertTo-LabAbsolutePath -Path 'c:\absolutepath' -BasePath 'c:\mylab' | Should -BeExactly 'c:\absolutepath'
            }
        }

        Context 'When relative Path is passed' {
            It 'Should return the absolute path' {
                ConvertTo-LabAbsolutePath -Path 'relativepath' -BasePath 'c:\mylab' | Should -BeExactly 'c:\mylab\relativepath'
            }
        }
    }

    Describe 'Get-LabBuilderModulePath' {
        It 'Should return the path to the LabBuilder Module' {
            Get-LabBuilderModulePath | Should -BeExactly (Split-Path -Path (Get-Module -Name LabBuilder).Path -Parent)
        }
    }
}
