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
