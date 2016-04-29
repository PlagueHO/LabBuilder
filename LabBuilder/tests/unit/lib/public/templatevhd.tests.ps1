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
            Mock Test-Path -ParameterFilter { $Path -eq 'X:\Sources\Install.WIM' } -MockWith { $True }
            Mock Test-Path -ParameterFilter { $Path -eq 'C:\dism\dism.exe' } -MockWith { $False }

            Context 'Configuration passed but alternate DISM not found' {
                It 'Throws a FileNotFoundError exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
                    $ExceptionParameters = @{
                        errorId = 'FileNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.FileNotFoundError `
                            -f 'alternate DISM.EXE','C:\dism\dism.exe')
                    }
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

            Mock Test-Path -ParameterFilter { $Path -eq 'C:\dism\dism.exe' } -MockWith { $True }

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
            Context 'Valid configuration passed with two VHDx files not generated and no packages' {
                It 'Does not throw an Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
                    $VMTemplateVHDs[0].vhdpath = 'doesnotexist.vhdx'
                    $VMTemplateVHDs[1].vhdpath = 'doesnotexist.vhdx'
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
            Context 'Valid configuration passed with two VHDx files not generated valid packages' {
                Mock Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $True }
                It 'Does not throw an Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
                    $VMTemplateVHDs[0].vhdpath = 'doesnotexist.vhdx'
                    $VMTemplateVHDs[1].vhdpath = 'doesnotexist.vhdx'
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
                    $VMTemplateVHDs[0].vhdpath = 'doesnotexist.vhdx'
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
                    $VMTemplateVHDs[0].vhdpath = 'doesnotexist.vhdx'
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

            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
            $VMTemplateVHDs[5].vhdpath = "$($VMTemplateVHDs[5].vhdpath).NotExist"

            $NanoServerPackagesFolder = Join-Path `
                    -Path (Split-Path -Path $VMTemplateVHDs[5].vhdpath -Parent) `
                    -ChildPath 'NanoServerPackages'
            
            Context 'Valid Configuration Passed with Nano Server VHDx not generated and two packages' {
                Mock Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $True }
                Mock Test-Path -ParameterFilter { $Path -like "$NanoServerPackagesFolder\*.cab" } -MockWith { $True }

                It 'Does Not Throw Exception' {
                    $VMTemplateVHDs[5].Packages = 'Microsoft-NanoServer-Containers-Package.cab,Microsoft-NanoServer-Guest-Package.cab'
                    { Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled Mount-DiskImage -Exactly 1
                    Assert-MockCalled Get-Diskimage -Exactly 1
                    Assert-MockCalled Get-Volume -Exactly 1
                    Assert-MockCalled Dismount-DiskImage -Exactly 1
                    Assert-MockCalled Get-WindowsImage -Exactly 0
                    Assert-MockCalled Copy-Item -Exactly 0
                    Assert-MockCalled Rename-Item -Exactly 0
                    Assert-MockCalled Convert-WindowsImage -Exactly 1
                }
            }
            Context 'Valid Configuration Passed with Nano Server VHDx not generated and two packages and an MSU' {
                Mock Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $True }
                Mock Test-Path -ParameterFilter { $Path -like "$NanoServerPackagesFolder\*.cab" } -MockWith { $True }
                Mock Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $True }

                It 'Does Not Throw Exception' {
                    $VMTemplateVHDs[5].Packages = 'Microsoft-NanoServer-Containers-Package.cab,Microsoft-NanoServer-Guest-Package.cab,WMF5.0-WS2012R2-W81'
                    { Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled Mount-DiskImage -Exactly 1
                    Assert-MockCalled Get-Diskimage -Exactly 1
                    Assert-MockCalled Get-Volume -Exactly 1
                    Assert-MockCalled Dismount-DiskImage -Exactly 1
                    Assert-MockCalled Get-WindowsImage -Exactly 0
                    Assert-MockCalled Copy-Item -Exactly 0
                    Assert-MockCalled Rename-Item -Exactly 0
                    Assert-MockCalled Convert-WindowsImage -Exactly 1
                }
            }
            Context 'Valid Configuration Passed with Nano Server VHDx not generated and no edition set' {
                Mock Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $True }
                Mock Test-Path -ParameterFilter { $Path -like "$NanoServerPackagesFolder\*.cab" } -MockWith { $True }

                It 'Does Not Throw Exception' {
                    $VMTemplateVHDs[5].Packages = ''
                    $VMTemplateVHDs[5].Edition = $null
                    { Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs } | Should Not Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled Mount-DiskImage -Exactly 1
                    Assert-MockCalled Get-Diskimage -Exactly 1
                    Assert-MockCalled Get-Volume -Exactly 1
                    Assert-MockCalled Dismount-DiskImage -Exactly 1
                    Assert-MockCalled Get-WindowsImage -Exactly 1
                    Assert-MockCalled Copy-Item -Exactly 0
                    Assert-MockCalled Rename-Item -Exactly 0
                    Assert-MockCalled Convert-WindowsImage -Exactly 1
                }
            }
            Context 'Valid configuration passed but Convert-WindowsImage throws' {
                Mock Convert-WindowsImage -MockWith { Throw 'Convert-WindowsImage Exception' }
                Mock Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $True }
                It 'Throws a ConvertWindowsImageError exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
                    $VMTemplateVHDs[0].vhdpath = 'doesnotexist.vhdx'
                    $VMTemplateVHDs[1].vhdpath = 'doesnotexist.vhdx'
                    $ExceptionParameters = @{
                        errorId = 'ConvertWindowsImageError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ConvertWindowsImageError `
                            -f $VMTemplateVHDs[0].ISOPath,'X:\Sources\Install.WIM',$VMTemplateVHDs[0].Edition,$VMTemplateVHDs[0].VHDFormat,'Convert-WindowsImage Exception')
                    }
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
                    Assert-MockCalled Convert-WindowsImage -Exactly 1
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
