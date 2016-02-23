$Global:ModuleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)))

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
    

    Describe 'CreateHostSelfSignedCertificate' -Tags 'Incomplete' {
    }


    Describe 'WaitVMInitializationComplete' -Tags 'Incomplete' {
    }


    Describe 'WaitVMStarted' -Tags 'Incomplete'  {
    }


    Describe 'WaitVMOff' -Tags 'Incomplete'  {
    }
    
    
    Describe 'UpdateVMIntegrationServices' {
        #region Mocks
        Mock Get-VMIntegrationService -MockWith { @(
            @{ Name = 'Guest Service Interface'; Enabled = $False }
            @{ Name = 'Heartbeat'; Enabled = $True }
            @{ Name = 'Key-Value Pair Exchange'; Enabled = $True }
            @{ Name = 'Shutdown'; Enabled = $True }
            @{ Name = 'Time Synchronization'; Enabled = $True }
            @{ Name = 'VSS'; Enabled = $True }                             
        ) }
        Mock Enable-VMIntegrationService
        Mock Disable-VMIntegrationService
        #endregion

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$Switches = Get-LabSwitch -Config $Config

        Context 'Valid configuration is passed with null Integration Services' {
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            $VMs[0].Remove('IntegrationServices')
            It 'Does not throw an Exception' {
                { UpdateVMIntegrationServices -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMIntegrationService -Exactly 1
                Assert-MockCalled Enable-VMIntegrationService -Exactly 1
                Assert-MockCalled Disable-VMIntegrationService -Exactly 0
            }
        }

        Context 'Valid configuration is passed with blank Integration Services' {
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = ''
            It 'Does not throw an Exception' {
                { UpdateVMIntegrationServices -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMIntegrationService -Exactly 1
                Assert-MockCalled Enable-VMIntegrationService -Exactly 0 
                Assert-MockCalled Disable-VMIntegrationService -Exactly 5
            }
        }

        Context 'Valid configuration is passed with VSS only enabled' {
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = 'VSS'
            It 'Does not throw an Exception' {
                { UpdateVMIntegrationServices -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMIntegrationService -Exactly 1
                Assert-MockCalled Enable-VMIntegrationService -Exactly 0 
                Assert-MockCalled Disable-VMIntegrationService -Exactly 4
            }
        }
        Context 'Valid configuration is passed with Guest Service Interface only enabled' {
            [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches
            $VMs[0].IntegrationServices = 'Guest Service Interface'
            It 'Does not throw an Exception' {
                { UpdateVMIntegrationServices -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMIntegrationService -Exactly 1
                Assert-MockCalled Enable-VMIntegrationService -Exactly 1 
                Assert-MockCalled Disable-VMIntegrationService -Exactly 5
            }
        }
    }


    Describe 'UpdateVMDataDisks' {
        #region Mocks
        Mock Get-VM
        Mock Get-VHD
        Mock Resize-VHD
        Mock Move-Item
        Mock Copy-Item
        Mock New-VHD
        Mock Get-VMHardDiskDrive
        Mock Add-VMHardDiskDrive
        Mock Test-Path -ParameterFilter { $Path -eq 'DoesNotExist.Vhdx' } -MockWith { $False }        
        Mock Test-Path -ParameterFilter { $Path -eq 'DoesExist.Vhdx' } -MockWith { $True }        
        Mock InitializeVHD
        Mock Mount-VHD
        Mock Dismount-VHD
        Mock Copy-Item
        Mock New-Item
        #endregion

        # The same VM will be used for all tests, but a different
        # DataVHds array will be created/assigned for each test.
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Templates = Get-LabVMTemplate -Config $Config
        [Array]$Switches = Get-LabSwitch -Config $Config
        [Array]$VMs = Get-LabVM -Config $Config -VMTemplates $Templates -Switches $Switches

        Context 'Valid configuration is passed with no DataVHDs' {
            $VMs[0].DataVHDs = @()
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that exists but has different type' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
                
            } )
            Mock Get-VHD -MockWith { @{
                VhdType =  'Dynamic'
            } }
            It 'Throws VMDataDiskVHDConvertError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDConvertError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDConvertError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs.Vhd,$VMs[0].DataVHDs.Type)
                }
                $Exception = GetException @ExceptionParameters
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that exists but has smaller size' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
            } )
            Mock Get-VHD -MockWith { @{
                VhdType =  'Fixed'
                Size = 20GB
            } }
            It 'Throws VMDataDiskVHDShrinkError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDShrinkError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDShrinkError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].Vhd,$VMs[0].DataVHDs[0].Size)
                }
                $Exception = GetException @ExceptionParameters
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that exists but has larger size' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 30GB
            } )
            Mock Get-VHD -MockWith { @{
                VhdType =  'Fixed'
                Size = 20GB
            } }
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 1
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Mock Get-VHD
        Context 'Valid configuration is passed with a SourceVHD and DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                SourceVhd = 'DoesNotExist.Vhdx'
            } )
            It 'Throws VMDataDiskSourceVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].SourceVhd)
                }
                $Exception = GetException @ExceptionParameters
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a SourceVHD that exists and DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                SourceVhd = 'DoesExist.Vhdx'
            } )
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a SourceVHD that exists and DataVHD that do not exist and MoveSourceVHD set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                SourceVhd = 'DoesExist.Vhdx'
                MoveSourceVHD = $true
            } )
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Fixed DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
            } )
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Dynamic DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
            } )
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Dynamic DataVHD that does not exist and PartitionStyle and FileSystem is set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
                PartitionStyle = 'GPT'
                FileSystem = 'NTFS'
            } )
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled InitializeVHD -Exactly 1
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 1
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Dynamic DataVHD that does not exist and PartitionStyle, FileSystem and CopyFolders is set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
                PartitionStyle = 'GPT'
                FileSystem = 'NTFS'
                CopyFolders = "$Global:TestConfigPath\ExpectedContent"
            } )
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled InitializeVHD -Exactly 1
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 1
                Assert-MockCalled New-Item -Exactly 1
            }
        }
        Context 'Valid configuration is passed with a 10GB Dynamic DataVHD that does not exist and CopyFolders is set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
                CopyFolders = "$Global:TestConfigPath\ExpectedContent"
            } )
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled InitializeVHD -Exactly 1
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 1
                Assert-MockCalled New-Item -Exactly 1
            }
        }
        Context 'Valid configuration is passed with a 10GB Differencing DataVHD that does not exist where ParentVHD is not set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Differencing'
                Size = 10GB
            } )
            It 'Throws VMDataDiskParentVHDMissingError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                        -f $VMs[0].Name)
                }
                $Exception = GetException @ExceptionParameters
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Differencing DataVHD that does not exist where ParentVHD does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Differencing'
                Size = 10GB
                ParentVHD = 'DoesNotExist.vhdx'
            } )
            It 'Throws VMDataDiskParentVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].ParentVhd)
                }
                $Exception = GetException @ExceptionParameters
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Differencing DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
                ParentVHD = 'DoesExist.vhdx'
            } )
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that does not exist and an unknown Type' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Unknown'
                Size = 10GB
            } )
            It 'Throws VMDataDiskUnknownTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskUnknownTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].Vhd,$VMs[0].DataVHDs[0].Type)
                }
                $Exception = GetException @ExceptionParameters
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
        Mock Get-VHD -MockWith { @{
            VhdType =  'Fixed'
            Size = 10GB
        } }
        Context 'Valid configuration is passed with a 10GB Fixed DataVHD that exists and is already added to VM' {
            Mock Get-VMHardDiskDrive -MockWith { @{ Path = 'DoesExist.vhdx' } }
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
            } )
            It 'Does not throw an Exception' {
                { UpdateVMDataDisks -Config $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
                Assert-MockCalled InitializeVHD -Exactly 0
                Assert-MockCalled Mount-VHD -Exactly 0
                Assert-MockCalled Dismount-VHD -Exactly 0
                Assert-MockCalled New-Item -Exactly 0
            }
        }
    }
}    

Set-Location -Path $OldLocation
