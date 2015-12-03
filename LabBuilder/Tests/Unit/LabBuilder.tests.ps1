#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path -Path "$here\..\..\"

Set-Location $root
if (Get-Module LabBuilder -All)
{
	Get-Module LabBuilder -All | Remove-Module
}

Import-Module "$root\LabBuilder.psd1" -Force -DisableNameChecking
$Global:TestConfigPath = "$root\Tests\PesterTestConfig"
$Global:TestConfigOKPath = "$Global:TestConfigPath\PesterTestConfig.OK.xml"
$Global:ArtifactPath = "$root\Artifacts"
$null = New-Item -Path "$Global:ArtifactPath" -ItemType Directory -Force -ErrorAction SilentlyContinue

InModuleScope LabBuilder {
####################################################################################################
Describe 'Download-WMF5Installer' {
	Context 'WMF 5.0 Installer File Exists' {
        It 'Does not throw an Exception' {
		    Mock Test-Path -MockWith { $true }
            Mock Invoke-WebRequest

			{ Download-WMF5Installer } | Should Not Throw
		}
        It 'Calls appropriate mocks' {
            Assert-MockCalled Test-Path -Exactly 1
            Assert-MockCalled Invoke-WebRequest -Exactly 0
        }
	}

	Context 'WMF 5.0 Installer File Does Not Exist' {
        It 'Does not throw an Exception' {
		    Mock Test-Path -MockWith { $false }
            Mock Invoke-WebRequest

			{ Download-WMF5Installer } | Should Not Throw
		}
        It 'Calls appropriate mocks' {
            Assert-MockCalled Test-Path -Exactly 1
            Assert-MockCalled Invoke-WebRequest -Exactly 1
        }
	}

	Context 'WMF 5.0 Installer File Does Not Exist and Fails Downloading' {
        It 'Throws a FileDownloadError Exception' {
		    Mock Test-Path -MockWith { $false }
            Mock Invoke-WebRequest { Throw ('Download Error') }

            $errorId = 'FileDownloadError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            $errorMessage = $($LocalizedData.FileDownloadError) `
                -f 'WMF 5.0 Installer','http://download.microsoft.com/download/3/F/D/3FD04B49-26F9-4D9A-8C34-4533B9D5B020/Win8.1AndW2K12R2-KB3066437-x64.msu','Download Error'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Download-WMF5Installer } | Should Throw $errorRecord
		}
        It 'Calls appropriate mocks' {
            Assert-MockCalled Test-Path -Exactly 1
            Assert-MockCalled Invoke-WebRequest -Exactly 1
        }
	}
}
####################################################################################################

####################################################################################################
Describe 'Download-CertGenerator' {
	Context 'Certificate Generator Zip File and PS1 File Exists' {
        It 'Does not throw an Exception' {
		    Mock Test-Path -MockWith { $true }
            Mock Invoke-WebRequest

			{ Download-CertGenerator } | Should Not Throw
		}
        It 'Calls appropriate mocks' {
            Assert-MockCalled Test-Path -Exactly 2
            Assert-MockCalled Invoke-WebRequest -Exactly 0
        }
	}

	Context 'Certificate Generator Zip File Exists but PS1 File Does Not' {
        It 'Does not throw an Exception' {
		    Mock Test-Path -ParameterFilter { $Path -like '*.zip' } -MockWith { $true }
		    Mock Test-Path -ParameterFilter { $Path -like '*.ps1' } -MockWith { $false }
            Mock Expand-Archive
            Mock Invoke-WebRequest

			{ Download-CertGenerator } | Should Not Throw
		}
        It 'Calls appropriate mocks' {
            Assert-MockCalled Test-Path -Exactly 2
            Assert-MockCalled Expand-Archive -Exactly 1
            Assert-MockCalled Invoke-WebRequest -Exactly 0
        }
	}

	Context 'Certificate Generator Zip File Does Not Exist' {
        It 'Does not throw an Exception' {
		    Mock Test-Path -MockWith { $false }
            Mock Expand-Archive
            Mock Invoke-WebRequest

			{ Download-CertGenerator } | Should Not Throw
		}
        It 'Calls appropriate mocks' {
            Assert-MockCalled Test-Path -Exactly 2
            Assert-MockCalled Expand-Archive -Exactly 1
            Assert-MockCalled Invoke-WebRequest -Exactly 1
        }
	}

	Context 'Certificate Generator Zip File Does Not Exist and Fails Downloading' {
        It 'Throws a FileDownloadError Exception' {
		    Mock Test-Path -MockWith { $false }
            Mock Invoke-WebRequest { Throw ('Download Error') }

            $errorId = 'FileDownloadError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            $errorMessage = $($LocalizedData.FileDownloadError) `
                -f 'Certificate Generator','https://gallery.technet.microsoft.com/scriptcenter/Self-signed-certificate-5920a7c6/file/101251/1/New-SelfSignedCertificateEx.zip','Download Error'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Download-CertGenerator } | Should Throw $errorRecord
		}
        It 'Calls appropriate mocks' {
            Assert-MockCalled Test-Path -Exactly 1
            Assert-MockCalled Invoke-WebRequest -Exactly 1
        }
	}
}
####################################################################################################

####################################################################################################
Describe 'Get-ModulesInDSCConfig' {
	Context 'Called with Test DSC Resource File' {
		$Modules = Get-ModulesInDSCConfig `
            -DSCConfigFile (Join-Path -Path $Global:TestConfigPath -ChildPath 'PesterTest.DSC.ps1')
        It 'Should Return Expected Modules' {
            @(Compare-Object -ReferenceObject $Modules `
                -DifferenceObject @('xActiveDirectory','xComputerManagement','xDHCPServer','xNetworking')).Count `
            | Should Be 0
        }
	}
}
####################################################################################################

####################################################################################################
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
            $errorId = 'ConfigurationFileNotFoundError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.ConfigurationFileNotFoundError) `
                -f 'c:\doesntexist.xml'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            Mock Test-Path -MockWith { $false }

			{ Get-LabConfiguration -Path 'c:\doesntexist.xml' } | Should Throw $errorRecord
		}
	}

	Context 'Path is provided and file exists but is empty' {
		It 'Throws ConfigurationFileEmptyError Exception' {
            $errorId = 'ConfigurationFileEmptyError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.ConfigurationFileEmptyError) `
                -f 'c:\isempty.xml'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            Mock Test-Path -MockWith { $true }
            Mock Get-Content -MockWith {''}

			{ Get-LabConfiguration -Path 'c:\isempty.xml' } | Should Throw $errorRecord
		}
	}
}
####################################################################################################

####################################################################################################
Describe 'Test-LabConfiguration' {

	$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

    Mock Test-Path -ParameterFilter { $Path -eq 'c:\exists\' } -MockWith { $true }
    Mock Test-Path -ParameterFilter { $Path -eq 'c:\doesnotexist\' } -MockWith { $false }

	Context 'Valid Configuration is provided and all paths exist' {
		It 'Returns True' {
            $Config.labbuilderconfig.settings.vmpath = 'c:\exists\'
            $Config.labbuilderconfig.settings.vhdparentpath = 'c:\exists\'

			Test-LabConfiguration -Configuration $Config | Should Be $True
		}
	}

	Context 'Valid Configuration is provided and VMPath is empty' {
		It 'Throws ConfigurationMissingElementError Exception' {
            $Config.labbuilderconfig.settings.vmpath = ''
            $Config.labbuilderconfig.settings.vhdparentpath = 'c:\exists\'

            $errorId = 'ConfigurationMissingElementError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.ConfigurationMissingElementError) `
                -f '<settings>\<vmpath>'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            { Test-LabConfiguration -Configuration $Config } | Should Throw $ErrorRecord
		}
	}

	Context 'Valid Configuration is provided and VMPath folder does not exist' {
		It 'Throws PathNotFoundError Exception' {
            $Config.labbuilderconfig.settings.vmpath = 'c:\doesnotexist\'
            $Config.labbuilderconfig.settings.vhdparentpath = 'c:\exists\'
           
            $errorId = 'PathNotFoundError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.PathNotFoundError) `
                -f '<settings>\<vmpath>','c:\doesnotexist\'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Test-LabConfiguration -Configuration $Config } | Should Throw $errorRecord
		}
	}
	
	Context 'Valid Configuration is provided and VHDParentPath is empty' {
		It 'Throws ConfigurationMissingElementError Exception' {
            $Config.labbuilderconfig.settings.vmpath = 'c:\exists\'
            $Config.labbuilderconfig.settings.vhdparentpath = ''

            $errorId = 'ConfigurationMissingElementError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.ConfigurationMissingElementError) `
                -f '<settings>\<vhdparentpath>'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            { Test-LabConfiguration -Configuration $Config } | Should Throw $errorRecord
		}
	}

	Context 'Valid Configuration is provided and VHDParentPath folder does not exist' {
		It 'Throws PathNotFoundError Exception' {
            $Config.labbuilderconfig.settings.vmpath = 'c:\exists\'
            $Config.labbuilderconfig.settings.vhdparentpath = 'c:\doesnotexist\'
            
            $errorId = 'PathNotFoundError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.PathNotFoundError) `
                -f '<settings>\<vhdparentpath>','c:\doesnotexist\'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Test-LabConfiguration -Configuration $Config } | Should Throw $errorRecord
		}
	}
}
####################################################################################################

####################################################################################################
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
####################################################################################################

####################################################################################################
Describe 'Initialize-LabConfiguration' {
    $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

    Mock Download-CertGenerator
    Mock Download-WMF5Installer
    Mock Download-LabResources
	Mock Set-VMHost

	Context 'Valid configuration is passed' {
		It 'Does not throw an Exception' {
			{ Initialize-LabConfiguration -Configuration $Config } | Should Not Throw
		}
		It 'Calls appropriate mocks' {
			Assert-MockCalled Download-CertGenerator -Exactly 1
			Assert-MockCalled Download-WMF5Installer -Exactly 1
			Assert-MockCalled Download-LabResources -Exactly 1
			Assert-MockCalled Set-VMHost -Exactly 1
		}		
	}
}
####################################################################################################

####################################################################################################
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
            $errorId = 'FileDownloadError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            $errorMessage = $($LocalizedData.FileDownloadError) `
                -f 'Module Resource xNetworking',$URL,'Download Error'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{
                Download-LabModule `
                    -Name 'xNetworking' `
                    -URL $URL `
                    -Folder 'xNetworkingDev'
            } | Should Throw $errorRecord
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
            $errorId = 'ModuleNotAvailableError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.ModuleNotAvailableError) `
                -f 'xDoesNotExist','any version',"No match was found for the specified search criteria and module name 'xDoesNotExist'"
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{
                Download-LabModule `
                    -Name 'xDoesNotExist'
            } | Should Throw $errorRecord
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
            $errorId = 'ModuleNotAvailableError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.ModuleNotAvailableError) `
                -f 'xNetworking','2.5.0.0',"No match was found for the specified search criteria and module name 'xNetworking'"
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{
                Download-LabModule `
                    -Name 'xNetworking' `
                    -RequiredVersion '2.5.0.0'
            } | Should Throw $errorRecord
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
            $errorId = 'ModuleNotAvailableError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.ModuleNotAvailableError) `
                -f 'xNetworking','min 2.5.0.0',"No match was found for the specified search criteria and module name 'xNetworking'"
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{
                Download-LabModule `
                    -Name 'xNetworking' `
                    -MinimumVersion '2.5.0.0'
            } | Should Throw $errorRecord
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
####################################################################################################

####################################################################################################
Describe 'Download-LabResources' {
    $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

	Context 'Valid configuration is passed' {
		Mock Download-LabModule
        It 'Does not throw an Exception' {
			{ Download-LabResources -Configuration $Config } | Should Not Throw
		}
        It 'Should call appropriate Mocks' {
            Assert-MockCalled Download-LabModule -Exactly 4
        }
	}
}
####################################################################################################

####################################################################################################
Describe 'Get-LabSwitches' {
	Context 'Configuration passed with switch missing Switch Name.' {
		It 'Throws a SwitchNameIsEmptyError Exception' {
			$errorId = 'SwitchNameIsEmptyError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.NoName.xml") } | Should Throw $errorRecord
		}
	}
	Context 'Configuration passed with switch missing Switch Type.' {
		It 'Throws a UnknownSwitchTypeError Exception' {
			$errorId = 'UnknownSwitchTypeError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.UnknownSwitchTypeError) `
                -f '','Pester Switch Fail'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.NoType.xml") } | Should Throw $errorRecord
		}
	}
	Context 'Configuration passed with switch invalid Switch Type.' {
		It 'Throws a UnknownSwitchTypeError Exception' {
			$errorId = 'UnknownSwitchTypeError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.UnknownSwitchTypeError) `
                -f 'BadType','Pester Switch Fail'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.BadType.xml") } | Should Throw $errorRecord
		}
	}
	Context 'Configuration passed with switch containing adapters but is not External type.' {
		It 'Throws a AdapterSpecifiedError Exception' {
			$errorId = 'AdapterSpecifiedError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.AdapterSpecifiedError) `
                -f 'Private','Pester Switch Fail'
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.AdaptersSet.xml") } | Should Throw $errorRecord
		}
	}
	Context 'Valid configuration is passed' {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		[Array]$Switches = Get-LabSwitches -Configuration $Config
		Set-Content -Path "$($Global:ArtifactPath)\ExpectedSwitches.json" -Value ($Switches | ConvertTo-Json -Depth 4) -Encoding UTF8 -NoNewLine
		
		It 'Returns Switches Object that matches Expected Object' {
			$ExpectedSwitches = Get-Content -Path "$Global:TestConfigPath\ExpectedSwitches.json" -Raw
			$SwitchesJSON = ($Switches | ConvertTo-Json -Depth 4)
			[String]::Compare(($Switches | ConvertTo-Json -Depth 4),$ExpectedSwitches,$true) | Should Be 0
		}
	}
}
####################################################################################################

####################################################################################################
Describe 'Initialize-LabSwitches' {

	$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
	[Array]$Switches = Get-LabSwitches -Configuration $Config

	Mock Get-VMSwitch
	Mock New-VMSwitch
	Mock Add-VMNetworkAdapter
	Mock Set-VMNetworkAdapterVlan

	Context 'Valid configuration is passed' {	
		It 'Does not throw an Exception' {
			{ Initialize-LabSwitches -Configuration $Config -Switches $Switches } | Should Not Throw
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
			$errorId = 'UnknownSwitchTypeError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.UnknownSwitchTypeError) `
                -f 'Invalid',$Switches[0].Name
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            { Initialize-LabSwitches -Configuration $Config -Switches $Switches } | Should Throw $errorRecord
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
			$errorId = 'SwitchNameIsEmptyError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            { Initialize-LabSwitches -Configuration $Config -Switches $Switches } | Should Throw $errorRecord
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Get-VMSwitch -Exactly 1
			Assert-MockCalled New-VMSwitch -Exactly 0
			Assert-MockCalled Add-VMNetworkAdapter -Exactly 0
			Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
		}
	}
}
####################################################################################################

####################################################################################################
Describe 'Remove-LabSwitches' {

	$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
	[Array]$Switches = Get-LabSwitches -Configuration $Config

	Mock Get-VMSwitch -MockWith { $Switches }
	Mock Remove-VMSwitch

	Context 'Valid configuration is passed' {	
		It 'Does not throw an Exception' {
			{ Remove-LabSwitches -Configuration $Config -Switches $Switches } | Should Not Throw
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Get-VMSwitch -Exactly 5
			Assert-MockCalled Remove-VMSwitch -Exactly 5
		}
	}

	Context 'Valid configuration with invalid switch type passed' {	
    	$Switches[0].Type='Invalid'
		It 'Throws a UnknownSwitchTypeError Exception' {
			$errorId = 'UnknownSwitchTypeError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.UnknownSwitchTypeError) `
                -f 'Invalid',$Switches[0].Name
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            { Remove-LabSwitches -Configuration $Config -Switches $Switches } | Should Throw $errorRecord
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
			$errorId = 'SwitchNameIsEmptyError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            { Remove-LabSwitches -Configuration $Config -Switches $Switches } | Should Throw $errorRecord
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Get-VMSwitch -Exactly 1
			Assert-MockCalled Remove-VMSwitch -Exactly 0
		}
	}

}
####################################################################################################

####################################################################################################
Describe 'Get-LabVMTemplates' {

	Mock Get-VM
	
	Context 'Configuration passed with template missing Template Name.' {
		It 'Throws a EmptyTemplateNameError Exception' {
            $errorId = 'EmptyTemplateNameError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.EmptyTemplateNameError)
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.TemplateFail.NoName.xml") } | Should Throw $errorRecord
		}
	}

	Context 'Configuration passed with template VHD empty.' {
		It 'Throws a EmptyTemplateVHDError Exception' {
            $errorId = 'EmptyTemplateVHDError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.EmptyTemplateVHDError `
				-f 'No VHD')
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.TemplateFail.NoVHD.xml") } | Should Throw $errorRecord
		}
	}

	Context 'Configuration passed with template with Source VHD set to non-existent file.' {
		It 'Throws a TemplateSourceVHDNotFoundError Exception' {
            $errorId = 'TemplateSourceVHDNotFoundError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
				-f 'Bad VHD','This File Doesnt Exist.vhdx')
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.TemplateFail.BadSourceVHD.xml") } | Should Throw $errorRecord
		}
	}
	
	$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

	Mock Get-VM
		
	Context 'Valid configuration is passed but no templates found' {
		It 'Returns Template Object that matches Expected Object' {
			[Array]$Templates = Get-LabVMTemplates -Configuration $Config 
			Set-Content -Path "$($Global:ArtifactPath)\ExpectedTemplates.json" -Value ($Templates | ConvertTo-Json -Depth 2) -Encoding UTF8 -NoNewLine
			$ExpectedTemplates = Get-Content -Path "$Global:TestConfigPath\ExpectedTemplates.json" -Raw
			[String]::Compare(($Templates | ConvertTo-Json -Depth 2),$ExpectedTemplates,$true) | Should Be 0
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Get-VM -Exactly 1
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

	Context 'Valid configuration is passed but templates are found' {
		It 'Returns Template Object that matches Expected Object' {
			[Array]$Templates = Get-LabVMTemplates -Configuration $Config 
			Set-Content -Path "$($Global:ArtifactPath)\ExpectedTemplates.FromVM.json" -Value ($Templates | ConvertTo-Json -Depth 2) -Encoding UTF8 -NoNewLine
			$ExpectedTemplates = Get-Content -Path "$Global:TestConfigPath\ExpectedTemplates.FromVM.json" -Raw
			[String]::Compare(($Templates | ConvertTo-Json -Depth 2),$ExpectedTemplates,$true) | Should Be 0
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Get-VM -Exactly 1
			Assert-MockCalled Get-VMHardDiskDrive -Exactly 3
		}
	}

}
####################################################################################################

####################################################################################################
Describe 'Initialize-LabVMTemplates' {

	$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

	Mock Copy-Item
	Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
	Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
	Mock Test-Path -ParameterFilter { $Path -eq 'This File Doesnt Exist.vhdx' } -MockWith { $false }
	Mock Optimize-VHD

	Context 'Template Template Array with non-existent VHD source file' {
		[array]$Templates = @( @{
			name = 'Bad VHD'
			templatevhd = 'This File Doesnt Exist.vhdx' 
			sourcevhd = 'This File Doesnt Exist.vhdx'
		} )

		It 'Throws a TemplateSourceVHDNotFoundError Exception' {
            $errorId = 'TemplateSourceVHDNotFoundError'
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
				-f 'Bad VHD','This File Doesnt Exist.vhdx')
            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

			{ Initialize-LabVMTemplates -Configuration $Config -VMTemplates $Templates } | Should Throw $errorRecord
		}
	}

	Context 'Valid Template Array is passed' {	
		[array]$Templates = Get-LabVMTemplates -Configuration $Config

		It 'Does not throw an Exception' {
			{ Initialize-LabVMTemplates -Configuration $Config -VMTemplates $Templates } | Should Not Throw
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Copy-Item -Exactly 3
			Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
			Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
			Assert-MockCalled Optimize-VHD -Exactly 3
		}
	}
}
####################################################################################################

####################################################################################################
Describe 'Remove-LabVMTemplates' {

	$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

	Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
	Mock Remove-Item
	Mock Test-Path -MockWith { $True }

	Context 'Valid configuration is passed' {	
		[Array]$Templates = Get-LabVMTemplates -Configuration $Config
		
		It 'Does not throw an Exception' {
			{ Remove-LabVMTemplates -Configuration $Config -VMTemplates $Templates } | Should Not Throw
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
			Assert-MockCalled Remove-Item -Exactly 3
		}
	}
}
####################################################################################################

####################################################################################################
Describe 'Set-LabDSCMOFFile' {

	Mock Get-VM

	$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
	[Array]$Switches = Get-LabSwitches -Configuration $Config
	[Array]$Templates = Get-LabVMTemplates -Configuration $Config
	[Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
	
	Mock Create-LabVMPath
	Mock Get-Module
	Mock Get-ModulesInDSCConfig -MockWith { @('TestModule') }

	Context 'Valid Parameters Passed; Empty DSC Config' {
		$VM = $VMS[0].Clone()
		$VM.DSCConfigFile = ''
		It 'Does not throw an Exception' {
			{ Set-LabDSCMOFFile -Configuration $Config -VM $VM } | Should Not Throw
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Create-LabVMPath -Exactly 1
			Assert-MockCalled Get-Module -Exactly 0
		}
	}

	Mock Find-Module
	
	Context 'Valid Parameters Passed; DSC Module Not Found' {
		$VM = $VMS[0].Clone()
		$errorId = 'DSCModuleDownloadError'
		$errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
		$errorMessage = $($LocalizedData.DSCModuleDownloadError `
			-f $VM.DSCConfigFile,$VM.Name,'TestModule')
		$exception = New-Object -TypeName System.InvalidOperationException `
			-ArgumentList $errorMessage
		$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
			-ArgumentList $exception, $errorId, $errorCategory, $null

		It 'Throws a DSCModuleDownloadError Exception' {
			{ Set-LabDSCMOFFile -Configuration $Config -VM $VM } | Should Throw $errorRecord
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Create-LabVMPath -Exactly 1
			Assert-MockCalled Get-Module -Exactly 1
			Assert-MockCalled Get-ModulesInDSCConfig -Exactly 1
			Assert-MockCalled Find-Module -Exactly 1
		}
	}

	Mock Find-Module -MockWith { @{ name = 'TestModule' } }
	Mock Install-Module -MockWith { Throw }
	
	Context 'Valid Parameters Passed; DSC Module Download Error' {
		$VM = $VMS[0].Clone()
		$errorId = 'DSCModuleDownloadError'
		$errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
		$errorMessage = $($LocalizedData.DSCModuleDownloadError `
			-f $VM.DSCConfigFile,$VM.Name,'TestModule')
		$exception = New-Object -TypeName System.InvalidOperationException `
			-ArgumentList $errorMessage
		$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
			-ArgumentList $exception, $errorId, $errorCategory, $null

		It 'Throws a DSCModuleDownloadError Exception' {
			{ Set-LabDSCMOFFile -Configuration $Config -VM $VM } | Should Throw $errorRecord
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Create-LabVMPath -Exactly 1
			Assert-MockCalled Get-Module -Exactly 1
			Assert-MockCalled Get-ModulesInDSCConfig -Exactly 1
			Assert-MockCalled Find-Module -Exactly 1
		}
	}

	Mock Install-Module -MockWith { }
	Mock Test-Path -MockWith { $false }
	
	Context 'Valid Parameters Passed; DSC Module Not Found in Path' {
		$VM = $VMS[0].Clone()
		$errorId = 'DSCModuleNotFoundError'
		$errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
		$errorMessage = $($LocalizedData.DSCModuleNotFoundError `
			-f $VM.DSCConfigFile,$VM.Name,'TestModule')
		$exception = New-Object -TypeName System.InvalidOperationException `
			-ArgumentList $errorMessage
		$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
			-ArgumentList $exception, $errorId, $errorCategory, $null

		It 'Throws a DSCModuleNotFoundError Exception' {
			{ Set-LabDSCMOFFile -Configuration $Config -VM $VM } | Should Throw $errorRecord
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Create-LabVMPath -Exactly 1
			Assert-MockCalled Get-Module -Exactly 1
			Assert-MockCalled Get-ModulesInDSCConfig -Exactly 1
			Assert-MockCalled Find-Module -Exactly 1
			Assert-MockCalled Install-Module -Exactly 1
		}
	}

	Mock Test-Path -MockWith { $true }
	Mock Copy-Item
	Mock New-LabVMSelfSignedCert
	
	Context 'Valid Parameters Passed; DSC Module Found in Path' {
		$VM = $VMS[0].Clone()
        $errorId = 'CertificateCreateError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
        $errorMessage = $($LocalizedData.CertificateCreateError `
            -f $VM.Name)
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

		It 'Throws a CertificateCreateError Exception' {
			{ Set-LabDSCMOFFile -Configuration $Config -VM $VM } | Should Throw $errorRecord
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Create-LabVMPath -Exactly 1
			Assert-MockCalled Get-Module -Exactly 1
			Assert-MockCalled Get-ModulesInDSCConfig -Exactly 1
			Assert-MockCalled Find-Module -Exactly 1
			Assert-MockCalled Install-Module -Exactly 1
			Assert-MockCalled Copy-Item -Exactly 1
			Assert-MockCalled New-LabVMSelfSignedCert -Exactly 1
		}
	}

	Mock New-LabVMSelfSignedCert -MockWith { }

	Mock Import-Certificate -MockWith {
		[PSCustomObject]@{
			Thumbprint = '1234567890ABCDEF'
		}
	}
	Mock Remove-Item -ParameterFilter { $path -eq 'Cert:LocalMachine\My\1234567890ABCDEF' }

}
####################################################################################################

####################################################################################################
Describe 'Set-LabDSCStartFile' {
	$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
	[Array]$Switches = Get-LabSwitches -Configuration $Config
	[Array]$Templates = Get-LabVMTemplates -Configuration $Config
	[Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches

	Mock Get-VM
	Mock Get-VMNetworkAdapter -MockWith { [PSObject]@{ Name = 'Dummy'; MacAddress = '00-11-22-33-44-55'; } }
	Mock Set-Content

	Context 'Valid Parameters Passed' {
		[String]$DSCStartFile = Set-LabDSCStartFile -Configuration $Config -VM $VMs[0]
		It 'Returns Expected File Content' {
			$DSCStartFile | Should Be $True
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Get-VMNetworkAdapter -Exactly 4
			Assert-MockCalled Set-Content -Exactly 1
		}
	}
}
####################################################################################################

####################################################################################################
Describe 'Get-LabUnattendFile' {

	#region Mocks
	Mock Get-VM
	#endregion

	Context 'Valid Parameters Passed' {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		[Array]$Switches = Get-LabSwitches -Configuration $Config
		[Array]$Templates = Get-LabVMTemplates -Configuration $Config
		[Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
		[String]$UnattendFile = Get-LabUnattendFile -Configuration $Config -VM $VMs[0]
		Set-Content -Path "$($Global:ArtifactPath)\UnattendFile.xml" -Value $UnattendFile -Encoding UTF8 -NoNewLine
		It 'Returns Expected File Content' {
			$UnattendFile | Should Be $True
			$ExpectedUnattendFile = Get-Content -Path "$Global:TestConfigPath\ExpectedUnattendFile.xml" -Raw
			[String]::Compare($UnattendFile,$ExpectedUnattendFile,$true) | Should Be 0
		}
	}
}
####################################################################################################

####################################################################################################
Describe 'Set-LabVMInitializationFiles' {

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

		[Array]$Templates = Get-LabVMTemplates -Configuration $Config
		[Array]$Switches = Get-LabSwitches -Configuration $Config
		[Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
				
		It 'Returns True' {
			Set-LabVMInitializationFiles -Configuration $Config -VM $VMs[0] -VMBootDiskPath 'c:\Dummy\' | Should Be $True
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
####################################################################################################

####################################################################################################
Describe 'Get-LabVMs' {

	#region mocks
	Mock Get-VM
	#endregion

	Context 'Configuration passed with VM missing VM Name.' {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.NoName.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context 'Configuration passed with VM missing Template.' {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.NoTemplate.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context 'Configuration passed with VM invalid Template.' {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadTemplate.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context 'Configuration passed with VM missing adapter name.' {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.NoAdapterName.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context 'Configuration passed with VM missing adapter switch name.' {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.NoAdapterSwitch.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context 'Configuration passed with VM invalid adapter switch name.' {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadAdapterSwitch.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM unattend file that can't be found." {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadUnattendFile.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM setup complete file that can't be found." {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadSetupCompleteFile.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context 'Configuration passed with VM setup complete file with an invalid file extension.' {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadSetupCompleteFileType.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM DSC Config File that can't be found." {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadDSCConfigFile.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context 'Configuration passed with VM DSC Config File with an invalid file extension.' {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadDSCConfigFileType.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}
	Context 'Configuration passed with VM DSC Config File but no DSC Name.' {
		It 'Fails' {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadDSCNameMissing.xml"
			[Array]$Switches = Get-LabSwitches -Configuration $Config
			[Array]$Templates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw
		}
	}

	Context 'Valid configuration is passed' {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		[Array]$Switches = Get-LabSwitches -Configuration $Config
		[Array]$Templates = Get-LabVMTemplates -Configuration $Config
		[Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
		# Clear this value out because it is completely dependent on where the test is run from. 
		$VMs[0].DSCConfigFile = ''
		Set-Content -Path "$($Global:ArtifactPath)\VMs.json" -Value ($VMs | ConvertTo-Json -Depth 4) -Encoding UTF8 -NoNewLine
		It 'Returns Template Object that matches Expected Object' {
			$ExpectedVMs = Get-Content -Path "$Global:TestConfigPath\ExpectedVMs.json" -Raw
			[String]::Compare(($VMs | ConvertTo-Json -Depth 4),$ExpectedVMs,$true) | Should Be 0
		}
	}
}
####################################################################################################

####################################################################################################
Describe 'Get-LabVMSelfSignedCert' {
}
####################################################################################################

####################################################################################################
Describe 'Start-LabVM' {
	#region Mocks
	Mock Get-VM -ParameterFilter { $Name -eq 'PESTER01' } -MockWith { [PSObject]@{ Name='PESTER01'; State='Off' } }
	Mock Get-VM -ParameterFilter { $Name -eq 'pester template *' }
	Mock Start-VM
	Mock Wait-LabVMInit -MockWith { $True }
	Mock Get-LabVMSelfSignedCert -MockWith { $True }
	Mock Initialize-LabVMDSC
	Mock Start-LabVMDSC
	#endregion

	Context 'Valid configuration is passed' {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
		New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

		[Array]$Templates = Get-LabVMTemplates -Configuration $Config
		[Array]$Switches = Get-LabSwitches -Configuration $Config
		[Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
				
		It 'Returns True' {
			Start-LabVM -Configuration $Config -VM $VMs[0] | Should Be $True
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'PESTER01' } -Exactly 1
			Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'pester template *' } -Exactly 1
			Assert-MockCalled Start-VM -Exactly 1
			Assert-MockCalled Wait-LabVMInit -Exactly 1
			Assert-MockCalled Get-LabVMSelfSignedCert -Exactly 1
			Assert-MockCalled Initialize-LabVMDSC -Exactly 1
			Assert-MockCalled Start-LabVMDSC -Exactly 1
		}
		
		Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
	}
}
####################################################################################################

####################################################################################################
Describe 'Initialize-LabVMs' {
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
	Mock Get-LabVMSelfSignedCert
	Mock Initialize-LabVMDSC
	Mock Start-LabVMDSC
	#endregion

	Context 'Valid configuration is passed' {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
		New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

		[Array]$Templates = Get-LabVMTemplates -Configuration $Config
		[Array]$Switches = Get-LabSwitches -Configuration $Config
		[Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
				
		It 'Returns True' {
			Initialize-LabVMs -Configuration $Config -VMs $VMs | Should Be $True
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
			Assert-MockCalled Get-LabVMSelfSignedCert -Exactly 1
			Assert-MockCalled Initialize-LabVMDSC -Exactly 1
			Assert-MockCalled Start-LabVMDSC -Exactly 1
		}
		
		Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
	}
}
####################################################################################################

####################################################################################################
Describe 'Remove-LabVMs' {
	#region Mocks
	Mock Get-VM -MockWith { [PSObject]@{ Name = 'PESTER01'; State = 'Running'; } }
	Mock Stop-VM
	Mock Wait-LabVMOff -MockWith { Return $True }
	Mock Get-VMHardDiskDrive
	Mock Remove-VM
	#endregion

	Context 'Valid configuration is passed' {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		[Array]$Templates = Get-LabVMTemplates -Configuration $Config
		[Array]$Switches = Get-LabSwitches -Configuration $Config
		[Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches

		# Create the dummy VM's that the Remove-LabVMs function 
		It 'Returns True' {
			Remove-LabVMs -Configuration $Config -VMs $VMs | Should Be $True
		}
		It 'Calls Mocked commands' {
			Assert-MockCalled Get-VM -Exactly 4
			Assert-MockCalled Stop-VM -Exactly 1
			Assert-MockCalled Wait-LabVMOff -Exactly 1
			Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
			Assert-MockCalled Remove-VM -Exactly 1
		}
	}
}
####################################################################################################

####################################################################################################
Describe 'Wait-LabVMInit' {
}
####################################################################################################

####################################################################################################
Describe 'Wait-LabVMStart' {
}
####################################################################################################

####################################################################################################
Describe 'Wait-LabVMOff' {
}
####################################################################################################

####################################################################################################
Describe 'Install-Lab' {
}
####################################################################################################

####################################################################################################
Describe 'Uninstall-Lab' {
}
####################################################################################################
}