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
    
    Describe 'CreateVMInitializationFiles' -Tags 'Incomplete' {
    }


    Describe 'GetUnattendFileContent' -Tags 'Incomplete' {
    }


    Describe 'GetCertificatePsFileContent' -Tags 'Incomplete' {
    }
    
    
    Describe 'GetSelfSignedCertificate' -Tags 'Incomplete' {
    }
    
    
    Describe 'RecreateSelfSignedCertificate' -Tags 'Incomplete' {
    }
    
}    
