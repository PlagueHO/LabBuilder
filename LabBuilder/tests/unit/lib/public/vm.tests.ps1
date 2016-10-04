$Global:ModuleRoot = Resolve-Path -Path "$($Script:MyInvocation.MyCommand.Path)\..\..\..\..\..\"
$OldPSModulePath = $env:PSModulePath
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

        Describe '\Lib\Public\Vm.ps1\Get-LabVM' {
            # Mock functions
            function Get-VM {}

            #region mocks
            Mock Get-VM
            #endregion

            # Run tests assuming Build 10586 is installed
            $Script:CurrentBuild = 10586

            # Figure out the TestVMName (saves typing later on)
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $TestVMName = "$($Lab.labbuilderconfig.settings.labid)$($Lab.labbuilderconfig.vms.vm.name)"

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
            Context "Configuration passed with VM DVD Drive that has a missing Resource ISO." {
                It 'Throw VMDataDiskSourceVHDIfMoveError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.vms.vm.dvddrives.dvddrive[0].iso='DoesNotExist'
                    [Array]$Switches = Get-LabSwitch -Lab $Lab
                    [array]$Templates = Get-LabVMTemplate -Lab $Lab
                    $ExceptionParameters = @{
                        errorId = 'VMDVDDriveISOResourceNotFOundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDVDDriveISOResourceNotFOundError `
                            -f $TestVMName,'DoesNotExist')
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
            $Script:CurrentBuild = 10560
            Context 'Configuration passed with ExposeVirtualizationExtensions required but Build is 10560.' {
                It 'Throw DSCConfigNameIsEmptyError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    [Array]$Switches = Get-LabSwitch -Lab $Lab
                    [Array]$Templates = Get-LabVMTemplate -Lab $Lab
                    $ExceptionParameters = @{
                        errorId = 'VMVirtualizationExtError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMVirtualizationExtError `
                            -f $TestVMName)
                    }
                    $Exception = GetException @ExceptionParameters
                    { Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
                }
            }
            $Script:CurrentBuild = 10586
            Context 'Valid configuration is passed but switches and VMTemplates not passed' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                # Set the Instance Count to 2 to check
                $Lab.labbuilderconfig.vms.vm.instancecount = '2'
                [Array]$VMs = Get-LabVM -Lab $Lab
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
                    Set-Content -Path "$Global:ArtifactPath\ExpectedVMs.json" -Value ($VMs | ConvertTo-Json -Depth 6)
                    $ExpectedVMs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedVMs.json"
                    [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedVMs.json"),$ExpectedVMs,$true) | Should Be 0
                }
            }
            Context 'Valid configuration is passed' {
                $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                [Array]$Switches = Get-LabSwitch -Lab $Lab
                [Array]$Templates = Get-LabVMTemplate -Lab $Lab
                # Set the Instance Count to 2 to check
                $Lab.labbuilderconfig.vms.vm.instancecount = '2'
                [Array]$VMs = Get-LabVM -Lab $Lab -VMTemplates $Templates -Switches $Switches
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
                    Set-Content -Path "$Global:ArtifactPath\ExpectedVMs.json" -Value ($VMs | ConvertTo-Json -Depth 6)
                    $ExpectedVMs = Get-Content -Path "$Global:ExpectedContentPath\ExpectedVMs.json"
                    [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedVMs.json"),$ExpectedVMs,$true) | Should Be 0
                }
            }
        }



        Describe '\Lib\Public\Vm.ps1\Initialize-LabVM'  -Tags 'Incomplete' {
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



        Describe '\Lib\Public\Vm.ps1\Remove-LabVM' {
            # Mock functions
            function Get-VM {}
            function Stop-VM {}
            function Remove-VM {}

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



        Describe '\Lib\Public\Vm.ps1\Install-LabVM' -Tags 'Incomplete' {
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



        Describe '\Lib\Public\Vm.ps1\Connect-LabVM' -Tags 'Incomplete'  {
        }



        Describe '\Lib\Public\Vm.ps1\Disconnect-LabVM' -Tags 'Incomplete'  {
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
    $env:PSModulePath = $OldPSModulePath
}
