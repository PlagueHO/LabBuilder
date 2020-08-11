[System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
[CmdletBinding()]
param ()

$projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$projectName = ((Get-ChildItem -Path $projectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName

Import-Module -Name $projectName -Force

InModuleScope $projectName {
    $testRootPath = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    $testHelperPath = $testRootPath | Join-Path -ChildPath 'TestHelper'
    Import-Module -Name $testHelperPath -Force

    # Run tests assuming Build 10586 is installed
    $script:currentBuild = 10586

    $script:testConfigPath = Join-Path `
        -Path $testRootPath `
        -ChildPath 'pestertestconfig'
    $script:testConfigOKPath = Join-Path `
        -Path $script:testConfigPath `
        -ChildPath 'PesterTestConfig.OK.xml'
    $script:artifactPath = Join-Path `
        -Path $testRootPath `
        -ChildPath 'artifacts'
    $script:expectedContentPath = Join-Path `
        -Path $script:testConfigPath `
        -ChildPath 'expectedcontent'
    $null = New-Item `
        -Path $script:artifactPath `
        -ItemType Directory `
        -Force `
        -ErrorAction SilentlyContinue
    $script:Lab = Get-Lab -ConfigPath $script:testConfigOKPath

    Describe 'Get-LabVM' {
        # Mock functions
        function Get-VM {}

        #region mocks
        Mock Get-VM
        #endregion

        # Run tests assuming Build 10586 is installed
        $script:currentBuild = 10586

        # Figure out the TestVMName (saves typing later on)
        $lab = Get-Lab -ConfigPath $script:testConfigOKPath
        $TestVMName = "$($lab.labbuilderconfig.settings.labid)$($lab.labbuilderconfig.vms.vm.name)"

        Context 'When valid configuration passed with VM missing VM Name' {
            It 'Throw VMNameError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.RemoveAttribute('name')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMNameError)
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM missing Template' {
            It 'Throw VMTemplateNameEmptyError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.RemoveAttribute('template')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMTemplateNameEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                        -f $TestVMName)
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM invalid Template Name' {
            It 'Throw VMTemplateNotFoundError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.template = 'BadTemplate'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMTemplateNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                        -f $TestVMName,'BadTemplate')
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM missing adapter name' {
            It 'Throw VMAdapterNameError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.adapters.adapter[0].RemoveAttribute('name')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMAdapterNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterNameError `
                        -f $TestVMName)
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM missing adapter switch name' {
            It 'Throw VMAdapterSwitchNameError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.adapters.adapter[0].RemoveAttribute('switchname')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMAdapterSwitchNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                        -f $TestVMName,$($lab.labbuilderconfig.vms.vm.adapters.adapter[0].name))
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk with empty VHD' {
            It 'Throw VMDataDiskVHDEmptyError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = ''
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskVHDEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                        -f $TestVMName)
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk where ParentVHD can not be found' {
            It 'Throw VMDataDiskParentVHDNotFoundError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = 'c:\ThisFileDoesntExist.vhdx'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                        -f $TestVMName,"c:\ThisFileDoesntExist.vhdx")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk where SourceVHD can not be found' {
            It 'Throw VMDataDiskSourceVHDNotFoundError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = 'c:\ThisFileDoesntExist.vhdx'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                        -f $TestVMName,"c:\ThisFileDoesntExist.vhdx")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Differencing Data Disk with empty ParentVHD' {
            It 'Throw VMDataDiskParentVHDMissingError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].RemoveAttribute('parentvhd')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                        -f $TestVMName)
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk where it is a Differencing type disk but is shared' {
            It 'Throw VMDataDiskSharedDifferencingError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].SetAttribute('Shared','Y')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskSharedDifferencingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].vhd)")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk where it has an unknown Type' {
            It 'Throw VMDataDiskUnknownTypeError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].type = 'badtype'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskUnknownTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'badtype')
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk that has an invalid Partition Style' {
            It 'Throw VMDataDiskPartitionStyleError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].PartitionStyle='Bad'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskPartitionStyleError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskPartitionStyleError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'Bad')
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk that has an invalid File System' {
            It 'Throw VMDataDiskFileSystemError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].FileSystem='Bad'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskFileSystemError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskFileSystemError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'Bad')
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk that has a File System set but not a Partition Style' {
            It 'Throw VMDataDiskPartitionStyleMissingError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('partitionstyle')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskPartitionStyleMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk that has a Partition Style set but not a File System' {
            It 'Throw VMDataDiskFileSystemMissingError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('filesystem')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskFileSystemMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk that has a File System Label set but not a Partition Style or File System' {
            It 'Throw VMDataDiskPartitionStyleMissingError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[2].RemoveAttribute('partitionstyle')
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[2].RemoveAttribute('filesystem')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskPartitionStyleMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[2].vhd)")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk that exists with CopyFolders set to a folder that does not exist' {
            It 'Throw VMDataDiskCopyFolderMissingError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].CopyFolders='c:\doesnotexist'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskCopyFolderMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCopyFolderMissingError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd)",'c:\doesnotexist')
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk that does not exist but Type missing' {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('type')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk that does not exist but Size missing' {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('size')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration passed with VM Data Disk that does not exist but SourceVHD missing' {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].RemoveAttribute('sourcevhd')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd)")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context "Configuration passed with VM Data Disk that has MoveSourceVHD flag but SourceVHD missing." {
            It 'Throw VMDataDiskSourceVHDIfMoveError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.datavhds.datavhd[4].RemoveAttribute('sourcevhd')
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDIfMoveError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                        -f $TestVMName,"$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\$($lab.labbuilderconfig.vms.vm.datavhds.datavhd[4].vhd)")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration is passed with VM Data Disk with rooted VHD path.' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            $lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = "$script:testConfigPath\VhdFiles\DataDisk.vhdx"
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            It 'Returns Template Object containing VHD with correct rooted path' {
                $VMs[0].DataVhds[0].vhd | Should -Be "$script:testConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }

        Context 'When valid configuration is passed with VM Data Disk with non-rooted VHD path.' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            $lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = "DataDisk.vhdx"
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            It 'Returns Template Object containing VHD with correct rooted path' {
                $VMs[0].DataVhds[0].vhd | Should -Be "$($lab.labbuilderconfig.settings.labpath)\$TestVMName\Virtual Hard Disks\DataDisk.vhdx"
            }
        }

        Context 'When valid configuration is passed with VM Data Disk with rooted Parent VHD path.' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            $lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = "$script:testConfigPath\VhdFiles\DataDisk.vhdx"
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            It 'Returns Template Object containing Parent VHD with correct rooted path' {
                $VMs[0].DataVhds[3].parentvhd | Should -Be "$script:testConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }

        Context 'When valid configuration is passed with VM Data Disk with non-rooted Parent VHD path.' {
            Mock Test-Path -MockWith { $true }
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            $lab.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = "VhdFiles\DataDisk.vhdx"
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            It 'Returns Template Object containing Parent VHD with correct rooted path' {
                $VMs[0].DataVhds[3].parentvhd | Should -Be "$script:testConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }

        Context 'When valid configuration is passed with VM Data Disk with rooted Source VHD path.' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            $lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = "$script:testConfigPath\VhdFiles\DataDisk.vhdx"
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            It 'Returns Template Object containing Source VHD with correct rooted path' {
                $VMs[0].DataVhds[0].sourcevhd | Should -Be "$script:testConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }

        Context 'When valid configuration is passed with VM Data Disk with non-rooted Source VHD path.' {
            Mock Test-Path -MockWith { $true }
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            $lab.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = "VhdFiles\DataDisk.vhdx"
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            It 'Returns Template Object containing Source VHD with correct rooted path' {
                $VMs[0].DataVhds[0].sourcevhd | Should -Be "$script:testConfigPath\VhdFiles\DataDisk.vhdx"
            }
        }

        Context 'When the configuration passed with VM DVD Drive that has a missing Resource ISO' {
            It 'Throw VMDataDiskSourceVHDIfMoveError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.dvddrives.dvddrive[0].iso='DoesNotExist'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMDVDDriveISOResourceNotFOundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDVDDriveISOResourceNotFOundError `
                        -f $TestVMName,'DoesNotExist')
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When the configuration passed with VM unattend file that can not be found' {
            It 'Throw UnattendFileMissingError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.unattendfile = 'ThisFileDoesntExist.xml'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'UnattendFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnattendFileMissingError `
                        -f $TestVMName,"$script:testConfigPath\ThisFileDoesntExist.xml")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When the configuration passed with VM setup complete file that can not be found' {
            It 'Throw SetupCompleteFileMissingError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.setupcomplete = 'ThisFileDoesntExist.ps1'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'SetupCompleteFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                        -f $TestVMName,"$script:testConfigPath\ThisFileDoesntExist.ps1")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When the configuration passed with VM setup complete file with an invalid file extension' {
            It 'Throw SetupCompleteFileBadTypeError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.setupcomplete = 'ThisFileDoesntExist.abc'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'SetupCompleteFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                        -f $TestVMName,"$script:testConfigPath\ThisFileDoesntExist.abc")
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When the configuration passed with VM DSC Config File that can not be found' {
            It 'Throw DSCConfigFileMissingError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.dsc.configfile = 'ThisFileDoesntExist.ps1'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $expectedPath = Split-Path -Path (Join-Path -Path $script:LabBuidlerModuleRoot -ChildPath 'src') -Parent |
                    Join-Path -ChildPath 'DSCLibrary' | Join-Path -ChildPath $lab.labbuilderconfig.vms.vm.dsc.configfile
                $exceptionParameters = @{
                    errorId = 'DSCConfigFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileMissingError -f $TestVMName, $expectedPath)
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When the configuration passed with VM DSC Config File with an invalid file extension' {
            It 'Throw DSCConfigFileBadTypeError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.dsc.configfile = 'FileWithBadType.xyz'
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $expectedPath = Split-Path -Path (Join-Path -Path $script:LabBuidlerModuleRoot -ChildPath 'src') -Parent |
                    Join-Path -ChildPath 'DSCLibrary' | Join-Path -ChildPath $lab.labbuilderconfig.vms.vm.dsc.configfile
                $exceptionParameters = @{
                    errorId = 'DSCConfigFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileBadTypeError -f $TestVMName, $expectedPath)
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When the configuration passed with VM DSC Config File but no DSC Name' {
            It 'Throw DSCConfigNameIsEmptyError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                $lab.labbuilderconfig.vms.vm.dsc.configname = ''
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'DSCConfigNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                        -f $TestVMName)
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        Context 'When valid configuration is passed with and Name filter set to matching switch' {
            It 'Returns a Single Switch object' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches -Name $lab.labbuilderconfig.VMs.VM.Name
                $VMs.Count | Should -Be 1
            }
        }

        Context 'When valid configuration is passed with and Name filter set to non-matching switch' {
            It 'Returns a Single Switch object' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches -Name 'Does Not Exist'
                $VMs.Count | Should -Be 0
            }
        }

        $script:currentBuild = 10560

        Context 'When the configuration passed with ExposeVirtualizationExtensions required but Build is 10560' {
            It 'Throw DSCConfigNameIsEmptyError Exception' {
                $lab = Get-Lab -ConfigPath $script:testConfigOKPath
                [array] $Switches = Get-LabSwitch -Lab $lab
                [array] $Templates = Get-LabVMTemplate -Lab $lab
                $exceptionParameters = @{
                    errorId = 'VMVirtualizationExtError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMVirtualizationExtError `
                        -f $TestVMName)
                }
                $exception = Get-LabException @exceptionParameters
                { Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches } | Should -Throw $exception
            }
        }

        $script:currentBuild = 10586

        Context 'When valid configuration is passed but switches and VMTemplates not passed' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            # Set the Instance Count to 2 to check
            $lab.labbuilderconfig.vms.vm.instancecount = '2'
            [array] $VMs = Get-LabVM -Lab $lab
            # Remove the Source VHD and Parent VHD values for any data disks because they
            # will usually be relative to the test folder and won't exist
            foreach ($VM in $VMs)
            {
                foreach ($DataVhd in $VM.DataVhds)
                {
                    $DataVhd.ParentVHD = 'Intentionally Removed'
                    $DataVhd.SourceVHD = 'Intentionally Removed'
                }
                # Remove the DSC.ConfigFile path as this will be relative as well
                $VM.DSC.ConfigFile = ''
            }

            It 'Returns Template Object that matches Expected Object' {
                Set-Content -Path "$script:artifactPath\ExpectedVMs.json" -Value ($VMs | ConvertTo-Json -Depth 6)
                $ExpectedVMs = Get-Content -Path "$script:expectedContentPath\ExpectedVMs.json"
                [System.String]::Compare((Get-Content -Path "$script:artifactPath\ExpectedVMs.json"),$ExpectedVMs,$true) | Should -Be 0
            }
        }

        Context 'When valid configuration is passed' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $Templates = Get-LabVMTemplate -Lab $lab
            # Set the Instance Count to 2 to check
            $lab.labbuilderconfig.vms.vm.instancecount = '2'
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches
            # Remove the Source VHD and Parent VHD values for any data disks because they
            # will usually be relative to the test folder and won't exist
            foreach ($VM in $VMs)
            {
                foreach ($DataVhd in $VM.DataVhds)
                {
                    $DataVhd.ParentVHD = 'Intentionally Removed'
                    $DataVhd.SourceVHD = 'Intentionally Removed'
                }
                # Remove the DSC.ConfigFile path as this will be relative as well
                $VM.DSC.ConfigFile = ''
            }

            It 'Returns Template Object that matches Expected Object' {
                Set-Content -Path "$script:artifactPath\ExpectedVMs.json" -Value ($VMs | ConvertTo-Json -Depth 6)
                $ExpectedVMs = Get-Content -Path "$script:expectedContentPath\ExpectedVMs.json"
                [System.String]::Compare((Get-Content -Path "$script:artifactPath\ExpectedVMs.json"),$ExpectedVMs,$true) | Should -Be 0
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
        Mock Wait-LabVMInitializationComplete -MockWith { $true }
        Mock Recieve-LabSelfSignedCertificate
        Mock Initialize-LabVMDSC
        Mock Install-LabVMDSC
        #endregion

        Context 'When valid configuration is passed' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            $null = New-Item -Path $lab.labbuilderconfig.settings.labpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            $null = New-Item -Path $lab.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            It 'Returns True' {
                Initialize-LabVM -Lab $lab -VMs $VMs | Should -Be $true
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
                Assert-MockCalled Wait-LabVMInitializationComplete -Exactly 1
                Assert-MockCalled Recieve-LabSelfSignedCertificate -Exactly 1
                Assert-MockCalled Initialize-LabVMDSC -Exactly 1
                Assert-MockCalled Install-LabVMDSC -Exactly 1
            }

            Remove-Item -Path $lab.labbuilderconfig.settings.labpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $lab.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Describe 'Remove-LabVM' {
        # Mock functions
        function Get-VM {}
        function Stop-VM {}
        function Remove-VM {}

        #region Mocks
        Mock Get-VM -MockWith { [PSObject]@{ Name = 'TestLab PESTER01'; State = 'Running'; } }
        Mock Stop-VM
        Mock Wait-LabVMOff -MockWith { Return $true }
        Mock Remove-VM
        Mock Remove-Item
        Mock Test-Path -MockWith { Return $true }
        #endregion

        Context 'When valid configuration is passed' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            # Create the dummy VM's that the Remove-LabVM function
            It 'Returns True' {
                Remove-LabVM -Lab $lab -VMs $VMs | Should -Be $true
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 3
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled Wait-LabVMOff -Exactly 1
                Assert-MockCalled Remove-VM -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed but VMs not passed' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath

            # Create the dummy VM's that the Remove-LabVM function
            It 'Returns True' {
                Remove-LabVM -Lab $lab | Should -Be $true
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 3
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled Wait-LabVMOff -Exactly 1
                Assert-MockCalled Remove-VM -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
            }
        }

        Context 'When valid configuration is passed with RemoveVHDs switch' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            # Create the dummy VM's that the Remove-LabVM function
            It 'Returns True' {
                Remove-LabVM -Lab $lab -VMs $VMs -RemoveVMFolder | Should -Be $true
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 3
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled Wait-LabVMOff -Exactly 1
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
        Mock Wait-LabVMInitializationComplete -MockWith { $true }
        Mock Recieve-LabSelfSignedCertificate -MockWith { $true }
        Mock Initialize-LabVMDSC
        Mock Install-LabVMDSC
        #endregion

        Context 'When valid configuration is passed' {
            $lab = Get-Lab -ConfigPath $script:testConfigOKPath
            $null = New-Item -Path $lab.labbuilderconfig.settings.labpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            $null = New-Item -Path $lab.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [array] $Templates = Get-LabVMTemplate -Lab $lab
            [array] $Switches = Get-LabSwitch -Lab $lab
            [array] $VMs = Get-LabVM -Lab $lab -VMTemplates $Templates -Switches $Switches

            It 'Returns True' {
                Install-LabVM -Lab $lab -VM $VMs[0] | Should -Be $true
            }

            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'PESTER01' } -Exactly 1
                Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'pester template *' } -Exactly 1
                Assert-MockCalled Start-VM -Exactly 1
                Assert-MockCalled Wait-LabVMInitializationComplete -Exactly 1
                Assert-MockCalled Recieve-LabSelfSignedCertificate -Exactly 1
                Assert-MockCalled Initialize-LabVMDSC -Exactly 1
                Assert-MockCalled Install-LabVMDSC -Exactly 1
            }

            Remove-Item -Path $lab.labbuilderconfig.settings.labpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $lab.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Describe 'Connect-LabVM' -Tags 'Incomplete'  {
    }

    Describe 'Disconnect-LabVM' -Tags 'Incomplete'  {
    }
}
