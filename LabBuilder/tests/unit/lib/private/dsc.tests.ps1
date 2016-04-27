$Global:ModuleRoot = Resolve-Path -Path "$($Script:MyInvocation.MyCommand.Path)\..\..\..\..\..\"

$OldLocation = Get-Location
Set-Location -Path $ModuleRoot
if (Get-Module LabBuilder -All)
{
    Get-Module LabBuilder -All | Remove-Module
}

Import-Module "$Global:ModuleRoot\LabBuilder.psd1" `
    -Force `
    -DisableNameChecking
$Global:TestConfigPath = "$Global:ModuleRoot\Tests\PesterTestConfig"
$Global:TestConfigOKPath = "$Global:TestConfigPath\PesterTestConfig.OK.xml"
$Global:ArtifactPath = "$Global:ModuleRoot\Artifacts"
$Global:ExpectedContentPath = "$Global:TestConfigPath\ExpectedContent"
$null = New-Item -Path "$Global:ArtifactPath" `
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


    Describe 'GetModulesInDSCConfig' {
        Context 'Called with Test DSC Resource File' {
            It 'Returns DSCModules Object that matches Expected Object' {
                $DSCModules = GetModulesInDSCConfig `
                    -DSCConfigFile (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1')

                Set-Content `
                    -Path "$Global:ArtifactPath\ExpectedDSCModules.json" `
                    -Value ($DSCModules | ConvertTo-Json -Depth 4)
                $ExpectedDSCModules = Get-Content `
                    -Path "$Global:ExpectedContentPath\ExpectedDSCModules.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedDSCModules.json"),$ExpectedDSCModules,$true) | Should Be 0
            }
        }
        Context 'Called with Test DSC Resource Content' {
            It 'Returns DSCModules Object that matches Expected Object' {
                $Content = Get-Content -Path (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') -RAW
                $DSCModules = GetModulesInDSCConfig `
                    -DSCConfigContent $Content

                Set-Content `
                    -Path "$Global:ArtifactPath\ExpectedDSCModules.json" `
                    -Value ($DSCModules | ConvertTo-Json -Depth 4)
                $ExpectedDSCModules = Get-Content -Path "$Global:ExpectedContentPath\ExpectedDSCModules.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedDSCModules.json"),$ExpectedDSCModules,$true) | Should Be 0
            }
        }
    }


    
    Describe 'SetModulesInDSCConfig' {
        $Module1 = [LabDSCModule]::New('PSDesiredStateConfiguration','1.0')
        $Module2 = [LabDSCModule]::New('xActiveDirectory')
        $Module3 = [LabDSCModule]::New('xComputerManagement','1.4.0.0')
        $Module4 = [LabDSCModule]::New('xNewModule','9.9.9.9')
        [LabDSCModule[]] $UpdateModules = @($Module1,$Module2,$Module3,$Module4)

        Context 'Called with Test DSC Resource File' {
            It 'Returns DSCConfig Content that matches Expected String' {
                [String] $DSCConfig = SetModulesInDSCConfig `
                    -DSCConfigFile (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') `
                    -Modules $UpdateModules

                Set-Content -Path "$Global:ArtifactPath\ExpectedDSCConfig.txt" -Value $DSCConfig
                $ExpectedDSCConfig = Get-Content -Path "$Global:ExpectedContentPath\ExpectedDSCConfig.txt"
                @(Compare-Object `
                    -ReferenceObject $ExpectedDSCConfig `
                    -DifferenceObject (Get-Content -Path "$Global:ArtifactPath\ExpectedDSCConfig.txt")).Count  | Should Be 0 
            }
        }
        Context 'Called with Test DSC Resource Content' {
            It 'Returns DSCModules Content that matches Expected String' {
                [String] $Content = Get-Content -Path (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1') -RAW
                $DSCConfig = SetModulesInDSCConfig `
                    -DSCConfigContent $Content `
                    -Modules $UpdateModules

                Set-Content -Path "$Global:ArtifactPath\ExpectedDSCConfig.txt" -Value $DSCConfig
                $ExpectedDSCConfig = Get-Content -Path "$Global:ExpectedContentPath\ExpectedDSCConfig.txt"
                @(Compare-Object `
                    -ReferenceObject $ExpectedDSCConfig `
                    -DifferenceObject (Get-Content -Path "$Global:ArtifactPath\ExpectedDSCConfig.txt")).Count  | Should Be 0 
            }
        }
    }



    Describe 'CreateDSCMOFFiles' -Tags 'Incomplete' {

        Mock Get-VM

        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Lab $Lab
        [Array]$Templates = Get-LabVMTemplate -Lab $Lab
        [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
        
        Mock Get-Module
        Mock GetModulesInDSCConfig -MockWith { @('TestModule') }

        Context 'Empty DSC Config' {
            $VM = $VMS[0].Clone()
            $VM.DSC.ConfigFile = ''
            It 'Does not throw an Exception' {
                { CreateDSCMOFFiles -Lab $Lab -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
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
                    -f $VM.DSC.ConfigFile,$VM.Name,'TestModule')
            }
            $Exception = GetException @ExceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { CreateDSCMOFFiles -Lab $Lab -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
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
                    -f $VM.DSC.ConfigFile,$VM.Name,'TestModule')
            }
            $Exception = GetException @ExceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { CreateDSCMOFFiles -Lab $Lab -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
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
                    -f $VM.DSC.ConfigFile,$VM.Name,'TestModule')
            }
            $Exception = GetException @ExceptionParameters

            It 'Throws a DSCModuleNotFoundError Exception' {
                { CreateDSCMOFFiles -Lab $Lab -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
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
            $Exception = GetException @ExceptionParameters

            It 'Throws a CertificateCreateError Exception' {
                { CreateDSCMOFFiles -Lab $Lab -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
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
            $Exception = GetException @ExceptionParameters

            It 'Throws a DSCConfigMetaMOFCreateError Exception' {
                { CreateDSCMOFFiles -Lab $Lab -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
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



    Describe 'SetDSCStartFile' {

        Mock Get-VM

        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Lab $Lab
        [Array]$Templates = Get-LabVMTemplate -Lab $Lab
        [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches

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
            $Exception = GetException @ExceptionParameters
            It 'Throws a NetworkAdapterNotFoundError Exception' {
                { SetDSCStartFile -Lab $Lab -VM $VM } | Should Throw $Exception
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
            $Exception = GetException @ExceptionParameters

            It 'Throws a NetworkAdapterBlankMacError Exception' {
                { SetDSCStartFile -Lab $Lab -VM $VM } | Should Throw $Exception
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
                { SetDSCStartFile -Lab $Lab -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMNetworkAdapter -Exactly ($VM.Adapters.Count+1)
                Assert-MockCalled Set-Content -Exactly 2
            }
        }
    }



    Describe 'InitializeDSC' -Tag 'Incomplete' {
        $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
        [LabVM[]] $VMs = Get-LabVM -Lab $Lab

# There is a problem with Pester where the custom classes declared in type.ps1
# are not able to be found by the Mock, so an error is thrown trying to mock
# either of these two functions.
        Mock CreateDSCMOFFiles
        Mock SetDSCStartFile

        Context 'Valid Configuration Passed' {
            $VM = $VMs[0].Clone()
            
            It 'Does Not Throw Exception' {
                { InitializeDSC -Lab $Lab -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled CreateDSCMOFFiles -Exactly 1
                Assert-MockCalled SetDSCStartFile -Exactly 1
            }
        }
    }



    Describe 'StartDSC' -Tags 'Incomplete' {
    }


    Describe 'GetDSCNetworkingConfig' -Tags 'Incomplete' {
    }
}

Set-Location -Path $OldLocation
