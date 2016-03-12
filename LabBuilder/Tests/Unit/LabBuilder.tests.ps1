#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

$Global:ModuleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))

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

# Perform PS Script Analyzer tests on module code only
$null = Set-PackageSource -Name PSGallery -Trusted -Force
$null = Install-Module -Name 'PSScriptAnalyzer' -Confirm:$False
Import-Module -Name 'PSScriptAnalyzer'

Describe 'PSScriptAnalyzer' {
    Context 'LabBuilder Module code and Lib Functions' {
        It 'Passes Invoke-ScriptAnalyzer' {
            # Perform PSScriptAnalyzer scan.
            $PSScriptAnalyzerResult = Invoke-ScriptAnalyzer `
                -path "$ModuleRoot\LabBuilder.psm1" `
                -Severity Warning `
                -ErrorAction SilentlyContinue
            $PSScriptAnalyzerResult += Invoke-ScriptAnalyzer `
                -path "$ModuleRoot\Lib\*.ps1" `
                -excluderule "PSAvoidUsingUserNameAndPassWordParams" `
                -Severity Warning `
                -ErrorAction SilentlyContinue
            $PSScriptAnalyzerErrors = $PSScriptAnalyzerResult | Where-Object { $_.Severity -eq 'Error' }
            $PSScriptAnalyzerWarnings = $PSScriptAnalyzerResult | Where-Object { $_.Severity -eq 'Warning' }
            if ($PSScriptAnalyzerErrors -ne $null)
            {
                Write-Warning -Message 'There are PSScriptAnalyzer errors that need to be fixed:'
                @($PSScriptAnalyzerErrors).Foreach( { Write-Warning -Message "$($_.Scriptname) (Line $($_.Line)): $($_.Message)" } )
                Write-Warning -Message  'For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/psscriptAnalyzer/'
                $PSScriptAnalyzerErrors.Count | Should Be $null
            }
            if ($PSScriptAnalyzerWarnings -ne $null)
            {
                Write-Warning -Message 'There are PSScriptAnalyzer warnings that should be fixed:'
                @($PSScriptAnalyzerWarnings).Foreach( { Write-Warning -Message "$($_.Scriptname) (Line $($_.Line)): $($_.Message)" } )
            }
        }
    }
}

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


    # Perform Configuration XML Schema validation
    Describe 'XMLConfigurationSchemaValidation' {
        Context 'PesterTestConfig.OK.XML' {
            It 'Does not throw an exception' {
                { ValidateConfigurationXMLSchema -ConfigPath $Global:TestConfigOKPath -Verbose } | Should Not Throw
            }
        }
        $SampleFiles = Get-ChildItem -Path (Join-Path -Path $Global:ModuleRoot -ChildPath "Samples") -Recurse -Filter 'Sample_*.xml'
        foreach ($SampleFile in $SampleFiles)
        {
            Context "Samples\$SampleFile" {
                It 'Does not throw an exception' {
                    { ValidateConfigurationXMLSchema -ConfigPath $($SampleFile.Fullname) -Verbose } | Should Not Throw
                }
            }
        }
    }



#region LabResourceFunctions
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
#endregion

#region LabSwitchFunctions
    Describe 'Get-LabSwitch' {

        Context 'Configuration passed with switch missing Switch Name.' {
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.switches.switch[0].RemoveAttribute('name')
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabSwitch -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with switch missing Switch Type.' {
            It 'Throws a UnknownSwitchTypeError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.switches.switch[0].RemoveAttribute('type')
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f '','External')
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabSwitch -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with switch invalid Switch Type.' {
            It 'Throws a UnknownSwitchTypeError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.switches.switch[0].type='BadType'
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f 'BadType','External')
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabSwitch -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with switch containing adapters but is not External type.' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.switches.switch[0].type='Private'
            It 'Throws a AdapterSpecifiedError Exception' {
                $ExceptionParameters = @{
                    errorId = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.AdapterSpecifiedError `
                        -f 'Private',"$($Lab.labbuilderconfig.settings.labid) External")
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabSwitch -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed with and Name filter set to matching switch' {
            It 'Returns a Single Switch object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array] $Switches = Get-LabSwitch -Lab $Lab -Name $Lab.labbuilderconfig.switches.switch[0].name
                $Switches.Count | Should Be 1
            }
        }
        Context 'Valid configuration is passed with and Name filter set to non-matching switch' {
            It 'Returns a Single Switch object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array] $Switches = Get-LabSwitch -Lab $Lab -Name 'Does Not Exist'
                $Switches.Count | Should Be 0
            }
        }
        Context 'Valid configuration is passed' {
            It 'Returns Switches Object that matches Expected Object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array] $Switches = Get-LabSwitch -Lab $Lab
                Set-Content -Path "$Global:ArtifactPath\ExpectedSwitches.json" -Value ($Switches | ConvertTo-Json -Depth 4)
                $ExpectedSwitches = Get-Content -Path "$Global:ExpectedContentPath\ExpectedSwitches.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedSwitches.json"),$ExpectedSwitches,$true) | Should Be 0
            }
        }
    }



    Describe 'Initialize-LabSwitch' {

        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
        [LabSwitch[]] $Switches = Get-LabSwitch -Lab $Lab

        Mock Get-VMSwitch
        Mock New-VMSwitch
        Mock Add-VMNetworkAdapter
        Mock Set-VMNetworkAdapterVlan

        Context 'Valid configuration is passed' {	
            It 'Does not throw an Exception' {
                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should Not Throw
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
                { Initialize-LabSwitch -Lab $Lab } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 5
                Assert-MockCalled New-VMSwitch -Exactly 5
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }

        Context 'Valid configuration NAT with blank NAT Subnet Address' {	
            $Switches[0].Type = [LabSwitchType]::NAT
            It 'Throws a NatSubnetAddressEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'NatSubnetAddressEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NatSubnetAddressEmptyError `
                        -f $Switches[0].Name)
                }
                $Exception = GetException @ExceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 0
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }

        Context 'Valid configuration with blank switch name passed' {	
            $Switches[0].Type = [LabSwitchType]::External
            $Switches[0].Name = ''
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = GetException @ExceptionParameters

                { Initialize-LabSwitch -Lab $Lab -Switches $Switches } | Should Throw $Exception
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

        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
        [LabSwitch[]] $Switches = Get-LabSwitch -Lab $Lab

        Mock Get-VMSwitch -MockWith { $Switches }
        Mock Remove-VMSwitch
        Mock Remove-VMNetworkAdapter

        Context 'Valid configuration is passed' {	
            It 'Does not throw an Exception' {
                { Remove-LabSwitch -Lab $Lab -Switches $Switches } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 5
                Assert-MockCalled Remove-VMSwitch -Exactly 5
                Assert-MockCalled Remove-VMNetworkAdapter -Exactly 4
            }
        }

        Context 'Valid configuration is passed without switches' {	
            It 'Does not throw an Exception' {
                { Remove-LabSwitch -Lab $Lab } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 5
                Assert-MockCalled Remove-VMSwitch -Exactly 5
                Assert-MockCalled Remove-VMNetworkAdapter -Exactly 4
            }
        }

        Context 'Valid configuration with blank switch name passed' {	
            $Switches[0].Name = ''
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = GetException @ExceptionParameters

                { Remove-LabSwitch -Lab $Lab -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled Remove-VMSwitch -Exactly 0
                Assert-MockCalled Remove-VMNetworkAdapter -Exactly 0
            }
        }
    }
#endregion


#region LabVMTemplateVHDFunctions
    Describe 'Get-LabVMTemplateVHD' {

        Context 'Configuration passed with rooted ISO Root Path that does not exist' {
            It 'Throws a VMTemplateVHDISORootPathNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.ISOPath = "$Global:TestConfigPath\MissingFolder"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISORootPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                        -f "$Global:TestConfigPath\MissingFolder")
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with relative ISO Root Path that does not exist' {
            It 'Throws a VMTemplateVHDISORootPathNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.ISOPath = "MissingFolder"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISORootPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                        -f "$Global:TestConfigPath\MissingFolder")
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with rooted VHD Root Path that does not exist' {
            It 'Throws a VMTemplateVHDRootPathNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.VHDPath = "$Global:TestConfigPath\MissingFolder"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDRootPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                        -f "$Global:TestConfigPath\MissingFolder")
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with relative VHD Root Path that does not exist' {
            It 'Throws a VMTemplateVHDRootPathNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.VHDPath = "MissingFolder"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDRootPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                        -f "$Global:TestConfigPath\MissingFolder")
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with empty template VHD Name' {
            It 'Throws a EmptyVMTemplateVHDNameError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.templatevhd[0].RemoveAttribute('name')
                $ExceptionParameters = @{
                    errorId = 'EmptyVMTemplateVHDNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyVMTemplateVHDNameError)
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template ISO Path is empty' {
            It 'Throws a EmptyVMTemplateVHDISOPathError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.templatevhd[0].ISO = ''
                $ExceptionParameters = @{
                    errorId = 'EmptyVMTemplateVHDISOPathError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyVMTemplateVHDISOPathError `
                        -f $Lab.labbuilderconfig.templatevhds.templatevhd[0].name)
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template ISO Path that does not exist' {
            It 'Throws a VMTemplateVHDISOPathNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.templatevhd[0].ISO = "$Global:TestConfigPath\MissingFolder\DoesNotExist.iso"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISOPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                        -f $Lab.labbuilderconfig.templatevhds.templatevhd[0].name,"$Global:TestConfigPath\MissingFolder\DoesNotExist.iso")
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with relative template ISO Path that does not exist' {
            It 'Throws a VMTemplateVHDISOPathNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.templatevhd[0].ISO = "MissingFolder\DoesNotExist.iso"
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISOPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                        -f $Lab.labbuilderconfig.templatevhds.templatevhd[0].name,"$Global:TestConfigPath\ISOFiles\MissingFolder\DoesNotExist.iso")
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with invalid OSType' {
            It 'Throws a InvalidVMTemplateVHDOSTypeError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.templatevhd[0].OSType = 'invalid'
                $ExceptionParameters = @{
                    errorId = 'InvalidVMTemplateVHDOSTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InvalidVMTemplateVHDOSTypeError `
                        -f $Lab.labbuilderconfig.templatevhds.templatevhd[0].name,'invalid')
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with invalid VHDFormat' {
            It 'Throws a InvalidVMTemplateVHDVHDFormatError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.templatevhd[0].VHDFormat = 'invalid'
                $ExceptionParameters = @{
                    errorId = 'InvalidVMTemplateVHDVHDFormatError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDFormatError `
                        -f $Lab.labbuilderconfig.templatevhds.templatevhd[0].name,'invalid')
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with invalid VHDType' {
            It 'Throws a InvalidVMTemplateVHDVHDTypeError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.templatevhd[0].VHDType = 'invalid'
                $ExceptionParameters = @{
                    errorId = 'InvalidVMTemplateVHDVHDTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDTypeError `
                        -f $Lab.labbuilderconfig.templatevhds.templatevhd[0].name,'invalid')
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with invalid VHDType' {
            It 'Throws a InvalidVMTemplateVHDGenerationError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templatevhds.templatevhd[0].Generation = '99'
                $ExceptionParameters = @{
                    errorId = 'InvalidVMTemplateVHDGenerationError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InvalidVMTemplateVHDGenerationError `
                        -f $Lab.labbuilderconfig.templatevhds.templatevhd[0].name,'99')
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplateVHD -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed missing TemplateVHDs Node' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.RemoveChild($Lab.labbuilderconfig.templatevhds)
            It 'Returns null' {
                Get-LabVMTemplateVHD -Lab $Lab  | Should Be $null
            }
        }
        Context 'Valid configuration is passed with no TemplateVHD Nodes' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.templatevhds.IsEmpty = $true
            It 'Returns null' {
                Get-LabVMTemplateVHD -Lab $Lab | Should Be $null
            }
        }
        Context 'Valid configuration is passed with and Name filter set to matching switch' {
            It 'Returns a Single Switch object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array] $TemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab -Name $Lab.labbuilderconfig.TemplateVHDs.templateVHD[0].Name
                $TemplateVHDs.Count | Should Be 1
            }
        }
        Context 'Valid configuration is passed with and Name filter set to non-matching switch' {
            It 'Returns a Single Switch object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array] $TemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab -Name 'Does Not Exist'
                $TemplateVHDs.Count | Should Be 0
            }
        }
        Context 'Valid configuration is passed and template VHD ISOs are found' {
            It 'Returns VMTemplateVHDs array that matches Expected array' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array] $TemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab 
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
        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
        $ResourceMSUFile = Join-Path -Path $Lab.labbuilderconfig.settings.resourcepathfull -ChildPath "Win8.1AndW2K12R2-KB3134758-x64.msu"

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
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.RemoveChild($Lab.labbuilderconfig.templatevhds)
                { Initialize-LabVMTemplateVHD -Lab $Lab } | Should Not Throw
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
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
                $VMTemplateVHDs[0].isopath = 'doesnotexist.iso'
                $VMTemplateVHDs[0].vhdpath = 'doesnotexist.vhdx'
                $ExceptionParameters = @{
                    errorId = 'VMTemplateVHDISOPathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                        -f $Lab.labbuilderconfig.templatevhds.templatevhd[0].name,'doesnotexist.iso')
                }
                $Exception = GetException @ExceptionParameters

                { Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Throw $Exception
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
        Context 'Valid configuration passed with no packages' {
            It 'Does not throw an Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
                foreach ($VMTemplateVHD in $VMTemplateVHDs)
                {
                    $VMTemplateVHD.Packages = ''
                }
                { Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Not Throw
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Mount-DiskImage -Exactly 2
                Assert-MockCalled Get-Diskimage -Exactly 2
                Assert-MockCalled Get-Volume -Exactly 2
                Assert-MockCalled Dismount-DiskImage -Exactly 2
                Assert-MockCalled Get-WindowsImage -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Convert-WindowsImage -Exactly 2
            }
        }
        Context 'Valid configuration passed with valid packages' {
            Mock Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $True }
            It 'Does not throw an Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
                { Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Not Throw
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Mount-DiskImage -Exactly 2
                Assert-MockCalled Get-Diskimage -Exactly 2
                Assert-MockCalled Get-Volume -Exactly 2
                Assert-MockCalled Dismount-DiskImage -Exactly 2
                Assert-MockCalled Get-WindowsImage -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Convert-WindowsImage -Exactly 2
            }
        }
        Context 'Valid configuration passed with an invalid package' {
            It 'Throws a PackageNotFoundError exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
                foreach ($VMTemplateVHD in $VMTemplateVHDs)
                {
                    $VMTemplateVHD.Packages='DoesNotExist'
                }
                $ExceptionParameters = @{
                    errorId = 'PackageNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.PackageNotFoundError `
                        -f 'DoesNotExist')
                }
                $Exception = GetException @ExceptionParameters
                { Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Throw $Exception
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Mount-DiskImage -Exactly 1
                Assert-MockCalled Get-Diskimage -Exactly 1
                Assert-MockCalled Get-Volume -Exactly 1
                Assert-MockCalled Dismount-DiskImage -Exactly 1
                Assert-MockCalled Get-WindowsImage -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Convert-WindowsImage -Exactly 0
            }
        }
        Context 'Valid configuration passed with an invalid package' {
            Mock Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $False }
            It 'Throws a PackageMSUNotFoundError exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'PackageMSUNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.PackageMSUNotFoundError `
                        -f 'WMF5.0-WS2012R2-W81',$ResourceMSUFile)
                }
                $Exception = GetException @ExceptionParameters
                { Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Throw $Exception
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Mount-DiskImage -Exactly 1
                Assert-MockCalled Get-Diskimage -Exactly 1
                Assert-MockCalled Get-Volume -Exactly 1
                Assert-MockCalled Dismount-DiskImage -Exactly 1
                Assert-MockCalled Get-WindowsImage -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Convert-WindowsImage -Exactly 0
            }
        }
    }


    Describe 'Remove-LabVMTemplateVHD' {
        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
        $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
        Mock Remove-Item                        
        Mock Test-Path -MockWith { $False }
        Context 'Configuration passed with VMtemplateVHDs but VHD not found' {
            It 'Does not throw an Exception' {
                { Remove-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Not Throw
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Test-Path -Exactly $VMTemplateVHDs.Count
                Assert-MockCalled Remove-Item -Exactly 0
            }            
        }
        Mock Test-Path -MockWith { $True }
        Context 'Configuration passed with VMtemplateVHDs but VHD found' {
            It 'Does not throw an Exception' {
                { Remove-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Not Throw
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Test-Path -Exactly $VMTemplateVHDs.Count
                Assert-MockCalled Remove-Item -Exactly $VMTemplateVHDs.Count
            }            
        }
        Context 'Configuration passed with no VMtemplateVHDs' {
            It 'Does not throw an Exception' {
                { Remove-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $null } | Should Not Throw
            }
            It 'Calls expected mocks commands' {
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
            }            
        }
    }
#endregion


#region LabVMTemplateFunctions
    Describe 'Get-LabVMTemplate' {

        Mock Get-VM
        
        Context 'Configuration passed with template missing Template Name.' {
            It 'Throws a EmptyTemplateNameError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templates.template[0].RemoveAttribute('name')
                $ExceptionParameters = @{
                    errorId = 'EmptyTemplateNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyTemplateNameError)
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplate -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template with Source VHD set to relative non-existent file.' {
            It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templates.template[0].sourcevhd = 'This File Doesnt Exist.vhdx'
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $Lab.labbuilderconfig.templates.template[0].name,"$Global:TestConfigPath\This File Doesnt Exist.vhdx")
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplate -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template with Source VHD set to absolute non-existent file.' {
            It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templates.template[0].sourcevhd = 'c:\This File Doesnt Exist.vhdx'
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $Lab.labbuilderconfig.templates.template[0].name,"c:\This File Doesnt Exist.vhdx")
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplate -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template with Source VHD and Template VHD.' {
            It 'Throws a TemplateSourceVHDAndTemplateVHDConflictError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templates.template[0].SetAttribute('templatevhd','Windows Server 2012 R2 Datacenter FULL')
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDAndTemplateVHDConflictError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDAndTemplateVHDConflictError `
                        -f $Lab.labbuilderconfig.templates.template[0].name)
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplate -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with template with no Source VHD and no Template VHD.' {
            It 'Throws a TemplateSourceVHDandTemplateVHDMissingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templates.template[0].RemoveAttribute('sourcevhd')
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDandTemplateVHDMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDandTemplateVHDMissingError `
                        -f $Lab.labbuilderconfig.templates.template[0].name)
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplate -Lab $Lab } | Should Throw $Exception
            }
        }

        Context 'Configuration passed with template with Template VHD that does not exist.' {
            It 'Throws a TemplateSourceVHDAndTemplateVHDConflictError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templates.template[1].TemplateVHD='Template VHD Does Not Exist'
                $ExceptionParameters = @{
                    errorId = 'TemplateTemplateVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateTemplateVHDNotFoundError `
                        -f $Lab.labbuilderconfig.templates.template[1].name,'Template VHD Does Not Exist')
                }
                $Exception = GetException @ExceptionParameters

                { Get-LabVMTemplate -Lab $Lab } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed but no templates found' {
            It 'Returns Template Object that matches Expected Object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array]$Templates = Get-LabVMTemplate -Lab $Lab 
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

        Context 'Valid configuration is passed with a Name filter set to matching VM' {
            It 'Returns a Single Template object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templates.SetAttribute('fromvm','Pester *')
                [Array] $Templates = Get-LabVMTemplate `
                    -Lab $Lab `
                    -Name $Lab.labbuilderconfig.Templates.template[0].Name
                $Templates.Count | Should Be 1
            }
        }
        Context 'Valid configuration is passed with a Name filter set to non-matching VM' {
            It 'Returns no Template objects' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templates.SetAttribute('fromvm','Pester *')
                [Array] $Templates = Get-LabVMTemplate `
                    -Lab $Lab `
                    -Name 'Does Not Exist'
                $Templates.Count | Should Be 0
            }
        }
        Context 'Valid configuration is passed and some templates are found' {
            It 'Returns Template Object that matches Expected Object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.templates.SetAttribute('fromvm','Pester *')
                [Array]$Templates = Get-LabVMTemplate -Lab $Lab 
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

        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
        [array] $VMTemplates = Get-LabVMTemplate -Lab $Lab
        [Int32] $TemplateCount = $Lab.labbuilderconfig.templates.template.count
        $ResourceWMFMSUFile = Join-Path -Path $Lab.labbuilderconfig.settings.resourcepathfull -ChildPath "Win8.1AndW2K12R2-KB3134758-x64.msu"
        $ResourceRSATMSUFile = Join-Path -Path $Lab.labbuilderconfig.settings.resourcepathfull -ChildPath "WindowsTH-KB2693643-x64.msu"

        Mock Copy-Item
        Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
        Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
        Mock Test-Path -ParameterFilter { $Path -eq 'This File Doesnt Exist.vhdx' } -MockWith { $false }
        Mock Optimize-VHD
        Mock Get-VM
        Mock New-Item
        Mock Mount-WindowsImage
        Mock Add-WindowsPackage
        Mock Dismount-WindowsImage
        Mock Remove-Item

        Context 'Valid Template Array with non-existent VHD source file' {
            $Template = [LabVMTemplate]::New('Bad VHD')
            $Template.ParentVHD = 'This File Doesnt Exist.vhdx' 
            $Template.SourceVHD = 'This File Doesnt Exist.vhdx'
            [LabVMTemplate[]] $Templates = @( $Template )

            It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $Template.Name,$Template.SourceVHD)
                }
                $Exception = GetException @ExceptionParameters

                { Initialize-LabVMTemplate -Lab $Lab -VMTemplates $Templates } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled Set-ItemProperty -Exactly 0 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
                Assert-MockCalled Set-ItemProperty -Exactly 0 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
                Assert-MockCalled Optimize-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
                Assert-MockCalled Mount-WindowsImage -Exactly 0
                Assert-MockCalled Add-WindowsPackage -Exactly 0
                Assert-MockCalled Dismount-WindowsImage -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed' {	
            Mock Test-Path -ParameterFilter { $Path -eq $ResourceWMFMSUFile } -MockWith { $True }
            Mock Test-Path -ParameterFilter { $Path -eq $ResourceRSATMSUFile } -MockWith { $True }
            It 'Does not throw an Exception' {
                { Initialize-LabVMTemplate -Lab $Lab -VMTemplates $VMTemplates } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Copy-Item -Exactly ($TemplateCount + 1)
                Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
                Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
                Assert-MockCalled Optimize-VHD -Exactly $TemplateCount
                Assert-MockCalled New-Item -Exactly 3
                Assert-MockCalled Mount-WindowsImage -Exactly 3
                Assert-MockCalled Add-WindowsPackage -Exactly 3
                Assert-MockCalled Dismount-WindowsImage -Exactly 3
                Assert-MockCalled Remove-Item -Exactly 3
            }
        }
        Context 'Valid configuration is passed without VMTemplates' {	
            Mock Test-Path -ParameterFilter { $Path -eq $ResourceWMFMSUFile } -MockWith { $True }
            Mock Test-Path -ParameterFilter { $Path -eq $ResourceRSATMSUFile } -MockWith { $True }
            It 'Does not throw an Exception' {
                { Initialize-LabVMTemplate -Lab $Lab } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Copy-Item -Exactly ($TemplateCount + 1)
                Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
                Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
                Assert-MockCalled Optimize-VHD -Exactly $TemplateCount
                Assert-MockCalled New-Item -Exactly 3
                Assert-MockCalled Mount-WindowsImage -Exactly 3
                Assert-MockCalled Add-WindowsPackage -Exactly 3
                Assert-MockCalled Dismount-WindowsImage -Exactly 3
                Assert-MockCalled Remove-Item -Exactly 3
            }
        }
    }



    Describe 'Remove-LabVMTemplate' {

        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
        $TemplateCount = $Lab.labbuilderconfig.templates.template.count

        Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
        Mock Remove-Item
        Mock Test-Path -MockWith { $True }
        Mock Get-VM

        Context 'Valid configuration is passed' {	
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            
            It 'Does not throw an Exception' {
                { Remove-LabVMTemplate -Lab $Lab -VMTemplates $Templates } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
                Assert-MockCalled Remove-Item -Exactly $TemplateCount
            }
        }
    }
#endregion


#region LabVMFunctions
    Describe 'Get-LabVM' {

        #region mocks
        Mock Get-VM
        #endregion

        # Figure out the TestVMName (saves typing later on)
        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath        
        $TestVMName = "$($Lab.labbuilderconfig.settings.labid) $($Lab.labbuilderconfig.vms.vm.name)"

        Context 'Configuration passed with VM missing VM Name.' {
            It 'Throw VMNameError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath        
                $Lab.labbuilderconfig.vms.vm.RemoveAttribute('name')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMNameError)
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM missing Template.' {
            It 'Throw VMTemplateNameEmptyError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.RemoveAttribute('template')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMTemplateNameEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                        -f $TestVMName)
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM invalid Template Name.' {
            It 'Throw VMTemplateNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.template = 'BadTemplate'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMTemplateNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                        -f $TestVMName,'BadTemplate')
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM missing adapter name.' {
            It 'Throw VMAdapterNameError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.adapters.adapter[0].RemoveAttribute('name')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMAdapterNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterNameError `
                        -f $TestVMName)
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM missing adapter switch name.' {
            It 'Throw VMAdapterSwitchNameError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.adapters.adapter[0].RemoveAttribute('switchname')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                        -f $TestVMName,$($Lab.labbuilderconfig.vms.vm.adapters.adapter[0].name))
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM Data Disk with empty VHD.' {
            It 'Throw VMDataDiskVHDEmptyError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = ''
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                        -f $TestVMName)
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where ParentVHD can't be found." {
            It 'Throw VMDataDiskParentVHDNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = 'c:\ThisFileDoesntExist.vhdx'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                        -f $TestVMName,"c:\ThisFileDoesntExist.vhdx")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where SourceVHD can't be found." {
            It 'Throw VMDataDiskSourceVHDNotFoundError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = 'c:\ThisFileDoesntExist.vhdx'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                        -f $TestVMName,"c:\ThisFileDoesntExist.vhdx")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Differencing Data Disk with empty ParentVHD." {
            It 'Throw VMDataDiskParentVHDMissingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].RemoveAttribute('parentvhd')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                        -f $TestVMName)
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where it is a Differencing type disk but is shared." {
            It 'Throw VMDataDiskSharedDifferencingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].SetAttribute('Shared','Y')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSharedDifferencingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].vhd)")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where it has an unknown Type." {
            It 'Throw VMDataDiskUnknownTypeError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].type = 'badtype'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskUnknownTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'badtype')
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk is not Shared but SupportPR is Y." {
            It 'Throw VMDataDiskSupportPRError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].supportpr = 'Y'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSupportPRError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSupportPRError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }        
        Context "Configuration passed with VM Data Disk that has an invalid Partition Style." {
            It 'Throw VMDataDiskPartitionStyleError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].PartitionStyle='Bad'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskPartitionStyleError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskPartitionStyleError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'Bad')
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has an invalid File System." {
            It 'Throw VMDataDiskFileSystemError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].FileSystem='Bad'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskFileSystemError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskFileSystemError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'Bad')
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has a File System set but not a Partition Style." {
            It 'Throw VMDataDiskPartitionStyleMissingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('partitionstyle')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskPartitionStyleMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has a Partition Style set but not a File System." {
            It 'Throw VMDataDiskFileSystemMissingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('filesystem')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskFileSystemMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has a File System Label set but not a Partition Style or File System." {
            It 'Throw VMDataDiskPartitionStyleMissingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[2].RemoveAttribute('partitionstyle')
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[2].RemoveAttribute('filesystem')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskPartitionStyleMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[2].vhd)")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that exists with CopyFolders set to a folder that does not exist." {
            It 'Throw VMDataDiskCopyFolderMissingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].CopyFolders='c:\doesnotexist'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCopyFolderMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCopyFolderMissingError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd)",'c:\doesnotexist')
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that does not exist but Type missing." {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('type')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that does not exist but Size missing." {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('size')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that does not exist but SourceVHD missing." {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].RemoveAttribute('sourcevhd')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd)")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has MoveSourceVHD flag but SourceVHD missing." {
            It 'Throw VMDataDiskSourceVHDIfMoveError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[4].RemoveAttribute('sourcevhd')
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDIfMoveError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                        -f $TestVMName,"$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($Lab.labbuilderconfig.vms.vm.datavhds.datavhd[4].vhd)")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM unattend file that can't be found." {
            It 'Throw UnattendFileMissingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.unattendfile = 'ThisFileDoesntExist.xml'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'UnattendFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnattendFileMissingError `
                        -f $TestVMName,"$Global:TestConfigPath\ThisFileDoesntExist.xml")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM setup complete file that can't be found." {
            It 'Throw SetupCompleteFileMissingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.setupcomplete = 'ThisFileDoesntExist.ps1'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                        -f $TestVMName,"$Global:TestConfigPath\ThisFileDoesntExist.ps1")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM setup complete file with an invalid file extension.' {
            It 'Throw SetupCompleteFileBadTypeError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.setupcomplete = 'ThisFileDoesntExist.abc'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                        -f $TestVMName,"$Global:TestConfigPath\ThisFileDoesntExist.abc")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM DSC Config File that can't be found." {
            It 'Throw DSCConfigFileMissingError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.dsc.configfile = 'ThisFileDoesntExist.ps1'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                        -f $TestVMName,"$Global:TestConfigPath\DSCLibrary\ThisFileDoesntExist.ps1")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM DSC Config File with an invalid file extension.' {
            It 'Throw DSCConfigFileBadTypeError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.dsc.configfile = 'FileWithBadType.xyz'
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                        -f $TestVMName,"$Global:TestConfigPath\DSCLibrary\FileWithBadType.xyz")
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM DSC Config File but no DSC Name.' {
            It 'Throw DSCConfigNameIsEmptyError Exception' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.labbuilderconfig.vms.vm.dsc.configname = ''
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [Array]$Templates = Get-LabVMTemplate -Lab $Lab
                $ExceptionParameters = @{
                    errorId = 'DSCConfigNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                        -f $TestVMName)
                }
                $Exception = GetException @ExceptionParameters
                { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with rooted VHD path.' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing VHD with correct rooted path' {
                $VMs[0].DataVhds[0].vhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with non-rooted VHD path.' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = "DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing VHD with correct rooted path' {
                $VMs[0].DataVhds[0].vhd | Should Be "$($Lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with rooted Parent VHD path.' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Parent VHD with correct rooted path' {
                $VMs[0].DataVhds[3].parentvhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with non-rooted Parent VHD path.' {
            Mock Test-Path -MockWith { $true }
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = "VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Parent VHD with correct rooted path' {
                $VMs[0].DataVhds[3].parentvhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with rooted Source VHD path.' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Source VHD with correct rooted path' {
                $VMs[0].DataVhds[0].sourcevhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with non-rooted Source VHD path.' {
            Mock Test-Path -MockWith { $true }
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $Lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = "VhdFiles\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Source VHD with correct rooted path' {
                $VMs[0].DataVhds[0].sourcevhd | Should Be "$Global:TestConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with and Name filter set to matching switch' {
            It 'Returns a Single Switch object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [Array]$Templates = Get-LabVMTemplate -Lab $Lab
                [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches -Name $Lab.labbuilderconfig.VMs.VM.Name
                $VMs.Count | Should Be 1
            }
        }
        Context 'Valid configuration is passed with and Name filter set to non-matching switch' {
            It 'Returns a Single Switch object' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [Array]$Templates = Get-LabVMTemplate -Lab $Lab
                [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches -Name 'Does Not Exist'
                $VMs.Count | Should Be 0
            }
        }
        Context 'Valid configuration is passed but switches and VMTemplates not passed' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            [Array]$VMs = Get-LabVM -Lab $Lab
            # Remove the Source VHD and Parent VHD values for any data disks because they
            # will usually be relative to the test folder and won't exist
            foreach ($DataVhd in $VMs[0].DataVhds)
            {
                $DataVhd.ParentVHD = 'Intentionally Removed'
                $DataVhd.SourceVHD = 'Intentionally Removed'
            }
            # Remove the DSC.ConfigFile path as this will be relative as well
            $VMs[0].DSC.ConfigFile = ''
            It 'Returns Template Object that matches Expected Object' {
                Set-Content -Path "$Global:ArtifactPath\ExpectedVMs.json" -Value ($VMs | ConvertTo-Json -Depth 6)
                $ExpectedVMs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedVMs.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedVMs.json"),$ExpectedVMs,$true) | Should Be 0
            }
        }
        Context 'Valid configuration is passed' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
            # Remove the Source VHD and Parent VHD values for any data disks because they
            # will usually be relative to the test folder and won't exist
            foreach ($DataVhd in $VMs[0].DataVhds)
            {
                $DataVhd.ParentVHD = 'Intentionally Removed'
                $DataVhd.SourceVHD = 'Intentionally Removed'
            }
            # Remove the DSC.ConfigFile path as this will be relative as well
            $VMs[0].DSC.ConfigFile = ''
            It 'Returns Template Object that matches Expected Object' {
                Set-Content -Path "$Global:ArtifactPath\ExpectedVMs.json" -Value ($VMs | ConvertTo-Json -Depth 6)
                $ExpectedVMs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedVMs.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedVMs.json"),$ExpectedVMs,$true) | Should Be 0
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
        Mock CreateLabVMInitializationFiles
        Mock Get-VMNetworkAdapter
        Mock Add-VMNetworkAdapter
        Mock Start-VM
        Mock WaitVMInitializationComplete -MockWith { $True }
        Mock GetSelfSignedCertificate
        Mock Initialize-LabVMDSC
        Mock Install-LabVMDSC
        #endregion

        Context 'Valid configuration is passed' {	
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            New-Item -Path $Lab.labbuilderconfig.settings.labpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            New-Item -Path $Lab.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
                    
            It 'Returns True' {
                Initialize-LabVM -Lab $Lab -VMs $VMs | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled New-VM -Exactly 1
                Assert-MockCalled Set-VM -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled CreateLabVMInitializationFiles -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 9
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Start-VM -Exactly 1
                Assert-MockCalled WaitVMInitializationComplete -Exactly 1
                Assert-MockCalled GetSelfSignedCertificate -Exactly 1
                Assert-MockCalled Initialize-LabVMDSC -Exactly 1
                Assert-MockCalled Install-LabVMDSC -Exactly 1
            }
            
            Remove-Item -Path $Lab.labbuilderconfig.settings.labpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $Lab.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }


    Describe 'Remove-LabVM' {
        #region Mocks
        Mock Get-VM -MockWith { [PSObject]@{ Name = 'TestLab PESTER01'; State = 'Running'; } }
        Mock Stop-VM
        Mock WaitVMOff -MockWith { Return $True }
        Mock Remove-VM
        Mock Remove-Item
        Mock Test-Path -MockWith { Return $True }
        #endregion

        Context 'Valid configuration is passed' {	
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches

            # Create the dummy VM's that the Remove-LabVM function 
            It 'Returns True' {
                Remove-LabVM -Lab $Lab -VMs $VMs | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 3
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled WaitVMOff -Exactly 1
                Assert-MockCalled Remove-VM -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed but VMs not passed' {	
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath

            # Create the dummy VM's that the Remove-LabVM function 
            It 'Returns True' {
                Remove-LabVM -Lab $Lab | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 3
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled WaitVMOff -Exactly 1
                Assert-MockCalled Remove-VM -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with RemoveVHDs switch' {	
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches

            # Create the dummy VM's that the Remove-LabVM function 
            It 'Returns True' {
                Remove-LabVM -Lab $Lab -VMs $VMs -RemoveVMFolder | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 3
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled WaitVMOff -Exactly 1
                Assert-MockCalled Remove-VM -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 1
            }
        }
    }


    Describe 'Install-LabVM' -Tags 'Incomplete' {
        #region Mocks
        Mock Get-VM -ParameterFilter { $Name -eq 'PESTER01' } -MockWith { [PSObject]@{ Name='PESTER01'; State='Off' } }
        Mock Get-VM -ParameterFilter { $Name -eq 'pester template *' }
        Mock Start-VM
        Mock WaitVMInitializationComplete -MockWith { $True }
        Mock GetSelfSignedCertificate -MockWith { $True }
        Mock Initialize-LabVMDSC
        Mock Install-LabVMDSC
        #endregion

        Context 'Valid configuration is passed' {	
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            New-Item -Path $Lab.labbuilderconfig.settings.labpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            New-Item -Path $Lab.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [Array]$Templates = Get-LabVMTemplate -Lab $Lab
            [Array]$Switches = Get-LabSwitch -Lab $Lab
            [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
                    
            It 'Returns True' {
                Install-LabVM -Lab $Lab -VM $VMs[0] | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'PESTER01' } -Exactly 1
                Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'pester template *' } -Exactly 1
                Assert-MockCalled Start-VM -Exactly 1
                Assert-MockCalled WaitVMInitializationComplete -Exactly 1
                Assert-MockCalled GetSelfSignedCertificate -Exactly 1
                Assert-MockCalled Initialize-LabVMDSC -Exactly 1
                Assert-MockCalled Install-LabVMDSC -Exactly 1
            }
            
            Remove-Item -Path $Lab.labbuilderconfig.settings.labpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $Lab.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    
    Describe 'Connect-LabVM' -Tags 'Incomplete'  {
    }



    Describe 'Disconnect-LabVM' -Tags 'Incomplete'  {
    }
#endregion


#region LabFunctions
    Describe 'Get-Lab' {
        Context 'Path is provided and valid XML file exists' {
            It 'Returns XmlDocument object with valid content' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                $Lab.GetType().Name | Should Be 'XmlDocument'
                $Lab.labbuilderconfig | Should Not Be $null
            }
        }
        Context 'Path and LabPath are provided and valid XML file exists' {
            It 'Returns XmlDocument object with valid content' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath -LabPath 'c:\MyLab'
                $Lab.GetType().Name | Should Be 'XmlDocument'
                $Lab.labbuilderconfig.settings.labpath | Should Be 'c:\MyLab'
                $Lab.labbuilderconfig | Should Not Be $null
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
                $Exception = GetException @ExceptionParameters

                Mock Test-Path -MockWith { $false }

                { Get-Lab -ConfigPath 'c:\doesntexist.xml' } | Should Throw $Exception
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
                $Exception = GetException @ExceptionParameters

                Mock Test-Path -MockWith { $true }
                Mock Get-Content -MockWith {''}

                { Get-Lab -ConfigPath 'c:\isempty.xml' } | Should Throw $Exception
            }
        }
    }
    
    
    
    Describe 'New-Lab' -Tags 'Incomplete'  {
    }



    Describe 'Install-Lab' -Tags 'Incomplete'  {
        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath

        Mock Get-VMSwitch
        Mock New-VMSwitch
        Mock Get-VMNetworkAdapter -MockWith { @{ Name = 'LabBuilder Management PesterTestConfig' } }
        Mock Get-VMNetworkAdapterVlan
        Mock Set-VMNetworkAdapterVlan        

        Context 'Valid configuration is passed' {
            It 'Does not throw an Exception' {
                { Install-Lab -Lab $Lab } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapterVlan -Exactly 1
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 1
            }		
        }
    }



    Describe 'Update-Lab' -Tags 'Incomplete'  {
    }



    Describe 'Uninstall-Lab' -Tags 'Incomplete'  {
    }



    Describe 'Start-Lab' -Tags 'Incomplete'  {
    }
    
    
    
    Describe 'Stop-Lab' -Tags 'Incomplete'  {
    }    
#endregion    
}

Set-Location -Path $OldLocation
