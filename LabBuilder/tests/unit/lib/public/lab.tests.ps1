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


        Describe 'Get-Lab' {
            Context 'Relative Path is provided and valid XML file exists' {
                Mock Get-Location -MockWith { @{ Path = $Global:TestConfigPath} }
                It 'Returns XmlDocument object with valid content' {
                    $Lab = Get-Lab -ConfigPath (Split-Path -Path $Global:TestConfigOKPath -Leaf)
                    $Lab.GetType().Name | Should Be 'XmlDocument'
                    $Lab.labbuilderconfig | Should Not Be $null
                }
            }
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
