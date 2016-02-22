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
    function New-Exception
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
    
    Describe 'GetModulesInDSCConfig' {
        Context 'Called with Test DSC Resource File' {
            $Modules = GetModulesInDSCConfig `
                -DSCConfigFile (Join-Path -Path $Global:TestConfigPath -ChildPath 'dsclibrary\PesterTest.DSC.ps1')
            It 'Should Return Expected Modules' {
                @(Compare-Object -ReferenceObject $Modules `
                    -DifferenceObject @('xActiveDirectory','xComputerManagement','xDHCPServer','xNetworking')).Count `
                | Should Be 0
            }
        }
    }
    
    Describe 'CreateDSCMOFFiles' -Tags 'Incomplete' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Config $Config
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
        
        Mock Create-LabPath
        Mock Get-Module
        Mock GetModulesInDSCConfig -MockWith { @('TestModule') }

        Context 'Empty DSC Config' {
            $VM = $VMS[0].Clone()
            $VM.DSCConfigFile = ''
            It 'Does not throw an Exception' {
                { CreateDSCMOFFiles -Config $Config -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabPath -Exactly 1
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
                    -f $VM.DSCConfigFile,$VM.Name,'TestModule')
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { CreateDSCMOFFiles -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabPath -Exactly 1
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
                    -f $VM.DSCConfigFile,$VM.Name,'TestModule')
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { CreateDSCMOFFiles -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabPath -Exactly 1
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
                    -f $VM.DSCConfigFile,$VM.Name,'TestModule')
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCModuleNotFoundError Exception' {
                { CreateDSCMOFFiles -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabPath -Exactly 1
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
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a CertificateCreateError Exception' {
                { CreateDSCMOFFiles -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabPath -Exactly 1
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
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCConfigMetaMOFCreateError Exception' {
                { CreateDSCMOFFiles -Config $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabPath -Exactly 1
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

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Config $Config
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches

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
            $Exception = New-Exception @ExceptionParameters
            It 'Throws a NetworkAdapterNotFoundError Exception' {
                { SetDSCStartFile -Config $Config -VM $VM } | Should Throw $Exception
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
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a NetworkAdapterBlankMacError Exception' {
                { SetDSCStartFile -Config $Config -VM $VM } | Should Throw $Exception
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
                { SetDSCStartFile -Config $Config -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMNetworkAdapter -Exactly ($VM.Adapters.Count+1)
                Assert-MockCalled Set-Content -Exactly 2
            }
        }
    }



    Describe 'InitializeDSC' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [array] $VMs = Get-LabVM -Config $Config

        Mock CreateDSCMOFFiles
        Mock SetDSCStartFile

        Context 'Valid Configuration Passed' {
            $VM = $VMs[0].Clone()
            
            It 'Does Not Throw Exception' {
                { InitializeDSC -Config $Config -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled CreateDSCMOFFiles -Exactly 1
                Assert-MockCalled SetDSCStartFile -Exactly 1
            }
        }
    }



    Describe 'StartDSC' -Tags 'Incomplete' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitch -Config $Config
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches

    }

}