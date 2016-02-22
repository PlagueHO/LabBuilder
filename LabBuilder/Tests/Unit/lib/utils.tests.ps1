$Global:ModuleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)))

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
}