$Global:ModuleRoot = Resolve-Path -Path "$($Script:MyInvocation.MyCommand.Path)\..\..\..\..\..\"

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


        Describe 'Get-LabResourceModule' {

            Context 'Configuration passed with resource module missing Name.' {
                It 'Throws a ResourceModuleNameIsEmptyError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.resources.module[0].RemoveAttribute('name')
                    $ExceptionParameters = @{
                        errorId = 'ResourceModuleNameIsEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ResourceModuleNameIsEmptyError)
                    }
                    $Exception = GetException @ExceptionParameters

                    { Get-LabResourceModule -Lab $Lab } | Should Throw $Exception
                }
            }
            Context 'Valid configuration is passed' {
                It 'Returns Resource Modules Array that matches Expected Array' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    [Array] $ResourceModules = Get-LabResourceModule -Lab $Lab
                    Set-Content -Path "$Global:ArtifactPath\ExpectedResourceModules.json" -Value ($ResourceModules | ConvertTo-Json -Depth 4)
                    $ExpectedResourceModules = Get-Content -Path "$Global:ExpectedContentPath\ExpectedResourceModules.json"
                    [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedResourceModules.json"),$ExpectedResourceModules,$true) | Should Be 0
                }
            }
        }



        Describe 'Initialize-LabResourceModule' {

            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            [LabResourceModule[]]$ResourceModules = Get-LabResourceModule -Lab $Lab

            Mock DownloadResourceModule

            Context 'Valid configuration is passed' {
                It 'Does not throw an Exception' {
                    { Initialize-LabResourceModule -Lab $Lab -ResourceModules $ResourceModules } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled DownloadResourceModule -Exactly 4
                }
            }
        }



        Describe 'Get-LabResourceMSU' {

            Context 'Configuration passed with resource MSU missing Name.' {
                It 'Throws a ResourceMSUNameIsEmptyError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.resources.msu[0].RemoveAttribute('name')
                    $ExceptionParameters = @{
                        errorId = 'ResourceMSUNameIsEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ResourceMSUNameIsEmptyError)
                    }
                    $Exception = GetException @ExceptionParameters

                    { Get-LabResourceMSU -Lab $Lab } | Should Throw $Exception
                }
            }
            Context 'Valid configuration is passed' {
                It 'Returns Resource MSU Array that matches Expected Array' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    [Array] $ResourceMSUs = Get-LabResourceMSU -Lab $Lab
                    Set-Content -Path "$Global:ArtifactPath\ExpectedResourceMSUs.json" -Value ($ResourceMSUs | ConvertTo-Json -Depth 4)
                    $ExpectedResourceMSUs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedResourceMSUs.json"
                    [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedResourceMSUs.json"),$ExpectedResourceMSUs,$true) | Should Be 0
                }
            }
        }



        Describe 'Initialize-LabResourceMSU' {

            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            [LabResourceMSU[]]$ResourceMSUs = Get-LabResourceMSU -Lab $Lab

            Mock DownloadAndUnzipFile

            Context 'Valid configuration is passed' {
                It 'Does not throw an Exception' {
                    { Initialize-LabResourceMSU -Lab $Lab -ResourceMSUs $ResourceMSUs } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled DownloadAndUnzipFile -Exactly 2
                }
            }
        }



        Describe 'Get-LabResourceISO' {

            Context 'Configuration passed with resource ISO missing Name.' {
                It 'Throws a ResourceISONameIsEmptyError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.resources.iso[0].RemoveAttribute('name')
                    $ExceptionParameters = @{
                        errorId = 'ResourceISONameIsEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ResourceISONameIsEmptyError)
                    }
                    $Exception = GetException @ExceptionParameters

                    { Get-LabResourceISO -Lab $Lab } | Should Throw $Exception
                }
            }
            Context 'Configuration passed with resource ISO with Empty Path' {
                It 'Throws a ResourceISOPathIsEmptyError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.resources.iso[0].path=''
                    $ExceptionParameters = @{
                        errorId = 'ResourceISOPathIsEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ResourceISOPathIsEmptyError `
                            -f $Lab.labbuilderconfig.resources.iso[0].name)
                    }
                    $Exception = GetException @ExceptionParameters

                    { Get-LabResourceISO -Lab $Lab } | Should Throw $Exception
                }
            }
            Context 'Configuration passed with resource ISO files that do exist.' {
                It 'Does not throw an Exception' {
                    $Path = "$Global:TestConfigPath\ISOFiles\SQLServer2014SP1-FullSlipstream-x64-ENU.iso"
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.resources.iso[0].RemoveAttribute('url')
                    $Lab.labbuilderconfig.resources.iso[0].SetAttribute('path',"$Global:TestConfigPath\ISOFiles\SQLServer2014SP1-FullSlipstream-x64-ENU.iso")
                    $Lab.labbuilderconfig.resources.iso[1].RemoveAttribute('url')
                    $Lab.labbuilderconfig.resources.iso[1].SetAttribute('path',"$Global:TestConfigPath\ISOFiles\SQLFULL_ENU.iso")

                    { Get-LabResourceISO -Lab $Lab } | Should Not Throw
                }
            }
            Context 'Valid configuration is passed' {
                It 'Returns Resource ISO Array that matches Expected Array' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.resources.iso[0].SetAttribute('path',"$($Global:TestConfigPath)\ISOFiles\SQLServer2014SP1-FullSlipstream-x64-ENU.iso")
                    $Lab.labbuilderconfig.resources.iso[1].SetAttribute('path',"$($Global:TestConfigPath)\ISOFiles\SQLFULL_ENU.iso")
                    [Array] $ResourceISOs = Get-LabResourceISO -Lab $Lab
                    # Adjust the path to remove machine specific path
                    $ResourceISOs.foreach({
                        $_.Path = $_.Path.Replace($Global:TestConfigPath,'.')
                    })
                    Set-Content -Path "$Global:ArtifactPath\ExpectedResourceISOs.json" -Value ($ResourceISOs | ConvertTo-Json -Depth 4)
                    $ExpectedResourceISOs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedResourceISOs.json"
                    [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedResourceISOs.json"),$ExpectedResourceISOs,$true) | Should Be 0
                }
            }
            Context 'Valid configuration is passed with ISOPath set' {
                It 'Returns Resource ISO Array that matches Expected Array' {
                    $Path = "$Global:TestConfigPath\ISOFiles"
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.resources.SetAttribute('isopath',$Path)
                    [Array] $ResourceISOs = Get-LabResourceISO -Lab $Lab
                    # Adjust the path to remove machine specific path
                    $ResourceISOs.foreach({
                        $_.Path = $_.Path.Replace($Global:TestConfigPath,'.')
                    })
                    Set-Content -Path "$Global:ArtifactPath\ExpectedResourceISOs.json" -Value ($ResourceISOs | ConvertTo-Json -Depth 4)
                    $ExpectedResourceISOs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedResourceISOs.json"
                    [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedResourceISOs.json"),$ExpectedResourceISOs,$true) | Should Be 0
                }
            }
        }



        Describe 'Initialize-LabResourceISO' {
            $Path = "$Global:TestConfigPath\ISOFiles"
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.resources.SetAttribute('isopath',$Path)
            [LabResourceISO[]]$ResourceISOs = Get-LabResourceISO -Lab $Lab

            Mock DownloadAndUnzipFile

            Context 'Valid configuration is passed and all ISOs exist' {
                It 'Does not throw an Exception' {
                    { Initialize-LabResourceISO -Lab $Lab -ResourceISOs $ResourceISOs } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled DownloadAndUnzipFile -Exactly 0
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
}
