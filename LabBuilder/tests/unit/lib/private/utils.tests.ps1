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



        Describe '\Lib\Private\Utils.ps1\DownloadAndUnzipFile' {
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



        Describe '\Lib\Private\Utils.ps1\CreateCredential' -Tag 'Incomplete' {
        }



        Describe '\Lib\Private\Utils.ps1\DownloadResourceModule' {
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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
                        DownloadResourceModule `
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



        Describe '\Lib\Private\Utils.ps1\InstallHyperV' {

            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath

            if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
                Mock Get-WindowsOptionalFeature { [PSObject]@{ FeatureName = 'Mock'; State = 'Disabled'; } }
                Mock Enable-WindowsOptionalFeature
            }
            else
            {
                Mock Get-WindowsFeature { [PSObject]@{ Name = 'Mock'; Installed = $false; } }
                Mock Install-WindowsFeature
            }

            Context 'The function is called' {
                It 'Does not throw an Exception' {
                    { InstallHyperV } | Should Not Throw
                }
                if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
                    It 'Calls appropriate mocks' {
                        Assert-MockCalled Get-WindowsOptionalFeature -Exactly 1
                        Assert-MockCalled Enable-WindowsOptionalFeature -Exactly 1
                    }
                }
                else
                {
                    It 'Calls appropriate mocks' {
                        Assert-MockCalled Get-WindowsFeature -Exactly 1
                        Assert-MockCalled Install-WindowsFeature -Exactly 1
                    }
                }
            }
        }



        Describe '\Lib\Private\Utils.ps1\EnableWSMan' {
            Context 'WS-Man is already enabled' {
                Mock Start-Service
                Mock Get-PSProvider -MockWith { @{ Name = 'wsman' } }
                Mock Set-WSManQuickConfig
                It 'Does not throw an Exception' {
                    { EnableWSMan } | Should Not Throw
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Set-WSManQuickConfig -Exactly 0
                }
            }
            Context 'WS-Man is not enabled, user declines install' {
                Mock Start-Service -MockWith { Throw }
                Mock Get-PSProvider
                Mock Set-WSManQuickConfig
                It 'Should throw WSManNotEnabledError exception' {
                    $ExceptionParameters = @{
                        errorId = 'WSManNotEnabledError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.WSManNotEnabledError)
                    }
                    $Exception = GetException @ExceptionParameters

                    { EnableWSMan } | Should Throw $Exception
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Set-WSManQuickConfig -Exactly 1
                }
            }
        }



        Describe '\Lib\Private\Utils.ps1\ValidateConfigurationXMLSchema' -Tag 'Incomplete' {
        }



        Describe '\Lib\Private\Utils.ps1\IncreaseMacAddress' {
            Context 'MAC address 00155D0106ED is passed' {
                It 'Returns MAC address 00155D0106EE' {
                    IncreaseMacAddress `
                        -MacAddress '00155D0106ED' | Should Be '00155D0106EE'
                }
            }
            Context 'MAC address 00155D0106ED and step 10 is passed' {
                It 'Returns IP address 00155D0106F7' {
                    IncreaseMacAddress `
                        -MacAddress '00155D0106ED' `
                        -Step 10 | Should Be '00155D0106F7'
                }
            }
            Context 'MAC address 00155D0106ED and step 0 is passed' {
                It 'Returns IP address 00155D0106ED' {
                    IncreaseMacAddress `
                        -MacAddress '00155D0106ED' `
                        -Step 0 | Should Be '00155D0106ED'
                }
            }
        }



        Describe '\Lib\Private\Utils.ps1\IncreaseIpAddress' {
            Context 'Invalid IP Address is passed' {
                It 'Throws a IPAddressError Exception' {
                    $ExceptionParameters = @{
                        errorId = 'IPAddressError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.IPAddressError `
                            -f '192.168.1.999' )
                    }
                    $Exception = GetException @ExceptionParameters

                    {
                        IncreaseIpAddress `
                            -IpAddress '192.168.1.999'
                    } | Should Throw $Exception
                }
            }
            Context 'IP address 192.168.1.1 is passed' {
                It 'Returns IP address 192.168.1.2' {
                    IncreaseIpAddress `
                        -IpAddress '192.168.1.1' | Should Be '192.168.1.2'
                }
            }
            Context 'IP address 192.168.1.255 is passed' {
                It 'Returns IP address 192.168.2.0' {
                    IncreaseIpAddress `
                        -IpAddress '192.168.1.255' | Should Be '192.168.2.0'
                }
            }
            Context 'IP address 192.168.1.255 and Step 10 is passed' {
                It 'Returns IP address 192.168.2.9' {
                    IncreaseIpAddress `
                        -IpAddress '192.168.1.255' `
                        -Step 10 | Should Be '192.168.2.9'
                }
            }
            Context 'IP address 192.168.1.255 and Step 0 is passed' {
                It 'Returns IP address 192.168.1.255' {
                    IncreaseIpAddress `
                        -IpAddress '192.168.1.255' `
                        -Step 0 | Should Be '192.168.1.255'
                }
            }
            Context 'IP address 10.255.255.255 is passed' {
                It 'Returns IP address 11.0.0.0' {
                    IncreaseIpAddress `
                        -IpAddress '10.255.255.255' | Should Be '11.0.0.0'
                }
            }
            Context 'IP address fe80::15b4:b934:5d23:1a31 is passed' {
                It 'Returns IP address fe80::15b4:b934:5d23:1a32' {
                    IncreaseIpAddress `
                        -IpAddress 'fe80::15b4:b934:5d23:1a31' | Should Be 'fe80::15b4:b934:5d23:1a32'
                }
            }
        }



        Describe '\Lib\Private\Utils.ps1\ValidateIpAddress' {
            Context 'IP address 192.168.1.1 is passed' {
                It 'Returns True' {
                    ValidateIpAddress `
                        -IpAddress '192.168.1.1' | Should Be $True
                }
            }
            Context 'IP address 192.168.1.1000 is passed' {
                It 'Returns False' {
                    ValidateIpAddress `
                        -IpAddress '192.168.1.1000' | Should Be $False
                }
            }
            Context 'IP address fe80::15b4:b934:5d23:1a31 is passed' {
                It 'Returns True' {
                    ValidateIpAddress `
                        -IpAddress 'fe80::15b4:b934:5d23:1a31' | Should Be $True
                }
            }
            Context 'IP address fe80::15b4:b934:5d23:1a3x is passed' {
                It 'Returns False' {
                    ValidateIpAddress `
                        -IpAddress 'fe80::15b4:b934:5d23:1a3x' | Should Be $False
                }
            }
        }



        Describe '\Lib\Private\Utils.ps1\InstallPackageProviders' {
            Context 'Required package providers already installed' {
                Mock Get-PackageProvider -MockWith {
                    @(
                        @{ Name = 'PowerShellGet' },
                        @{ Name = 'NuGet' }
                    )
                }
                Mock Install-PackageProvider
                It 'Does not throw an Exception' {
                    { InstallPackageProviders -Force } | Should Not Throw
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-PackageProvider -Exactly 1
                    Assert-MockCalled Install-PackageProvider -Exactly 0
                }
            }
            Context 'Required package providers not installed' {
                Mock Get-PackageProvider
                Mock Install-PackageProvider
                It 'Does not throw an Exception' {
                    { InstallPackageProviders -Force } | Should Not Throw
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-PackageProvider -Exactly 1
                    Assert-MockCalled Install-PackageProvider -Exactly 2
                }
            }
        }



        Describe '\Lib\Private\Utils.ps1\RegisterPackageSources' {
            # Define this function because the built in definition does not
            # mock properly - the ProviderName parameter is not definied.
            function Register-PackageSource {
                [CmdletBinding()]
                param (
                    [String] $Name,
                    [String] $Location,
                    [String] $ProviderName,
                    [Switch] $Trusted,
                    [Switch] $Force
                )
            }
            Context 'Required package sources already registered and trusted' {
                Mock Get-PackageSource -MockWith {
                    @(
                        @{
                            Name         = 'nuget.org'
                            ProviderName = 'NuGet'
                            Location     = 'https://www.nuget.org/api/v2/'
                            IsTrusted    = $True
                        },
                        @{
                            Name         = 'PSGallery'
                            ProviderName = 'PowerShellGet'
                            Location     = 'https://www.powershellgallery.com/api/v2/'
                            IsTrusted    = $True
                        }
                    )
                }
                Mock Set-PackageSource
                Mock Register-PackageSource
                It 'Does not throw an Exception' {
                    { RegisterPackageSources -Force } | Should Not Throw
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-PackageSource -Exactly 1
                    Assert-MockCalled Set-PackageSource -Exactly 0
                    Assert-MockCalled Register-PackageSource -Exactly 0
                }
            }
            Context 'Required package sources already registered but not trusted' {
                Mock Get-PackageSource -MockWith {
                    @(
                        @{
                            Name         = 'nuget.org'
                            ProviderName = 'NuGet'
                            Location     = 'https://www.nuget.org/api/v2/'
                            IsTrusted    = $False
                        },
                        @{
                            Name         = 'PSGallery'
                            ProviderName = 'PowerShellGet'
                            Location     = 'https://www.powershellgallery.com/api/v2/'
                            IsTrusted    = $False
                        }
                    )
                }
                Mock Set-PackageSource
                Mock Register-PackageSource
                It 'Does not throw an Exception' {
                    { RegisterPackageSources -Force } | Should Not Throw
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-PackageSource -Exactly 1
                    Assert-MockCalled Set-PackageSource -Exactly 2
                    Assert-MockCalled Register-PackageSource -Exactly 0
                }
            }
            Context 'Required package sources are not registered' {
                Mock Get-PackageSource
                Mock Set-PackageSource
                Mock Register-PackageSource
                It 'Does not throw an Exception' {
                    { RegisterPackageSources -Force } | Should Not Throw
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-PackageSource -Exactly 1
                    Assert-MockCalled Set-PackageSource -Exactly 0
                    Assert-MockCalled Register-PackageSource -Exactly 2
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
