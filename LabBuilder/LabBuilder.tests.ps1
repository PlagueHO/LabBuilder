#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")

Remove-Module LabBuilder -ErrorAction SilentlyContinue
Import-Module "$here\LabBuilder.psd1"
$TestConfigPath = "$here\Tests\PesterTestConfig.xml"
$helperDir = "$here\TestHelpers"
Resolve-Path $helperDir\*.ps1 | % { . $_.ProviderPath }

##########################################################################################################################################
Describe "Get-LabConfiguration" {
	Context "No parameter is passed" {
		It "Fails" {
			{ Get-LabConfiguration } | Should Throw
		}
	}
	Context "Path is provided but file does not exist" {
		It "Fails" {
			{ Get-LabConfiguration -Path 'c:\doesntexist.xml' } | Should Throw
		}
	}
	Context "Path is provided and valid XML file exists" {
		It "Returns XmlDocument object with valid content" {
			$Config = Get-LabConfiguration -Path $TestConfigPath
			$Config.GetType().Name | Should Be 'XmlDocument'
			$Config.labbuilderconfig | Should Not Be $null
		}
	}
	Context "Content is provided but is empty" {
		It "Fails" {
			{ Get-LabConfiguration -Content '' } | Should Throw
		}
	}
	Context "Content is provided and contains valid XML" {
		It "Returns XmlDocument object with valid content" {
			$Config = Get-LabConfiguration -Content (Get-Content -Path $TestConfigPath -Raw)
			$Config.GetType().Name | Should Be 'XmlDocument'
			$Config.labbuilderconfig | Should Not Be $null
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Test-LabConfiguration" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -Recurse -Force -ErrorAction SilentlyContinue

	Context "No parameter is passed" {
		It "Fails" {
			{ Test-LabConfiguration } | Should Throw
		}
	}
	Context "Valid Configuration is provided and VMPath folder does not exist" {
		It "Fails" {
			{ Test-LabConfiguration -Configuration $Config } | Should Throw
		}
	}
	
	New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -ItemType Directory

	Context "Valid Configuration is provided and VHDParentPath folder does not exist" {
		It "Fails" {
			{ Test-LabConfiguration -Configuration $Config } | Should Throw
		}
	}
	
	New-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -ItemType Directory

	Context "Valid Configuration is provided and all paths exist" {
		It "Returns True" {
			Test-LabConfiguration -Configuration $Config | Should Be $True
		}
	}
	Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -Recurse -Force -ErrorAction SilentlyContinue
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Install-LabHyperV" {
	$Config = Get-LabConfiguration -Path $TestConfigPath

	Context "The function exists" {
		It "Returns True" {
			If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
				Mock Get-WindowsOptionalFeature { return [PSCustomObject]@{ Name = 'Dummy'; State = 'Enabled'; } }
			} Else {
				Mock Get-WindowsFeature { return [PSCustomObject]@{ Name = 'Dummy'; Installed = $false; } }
			}
			Install-LabHyperV | Should Be $True
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabHyperV" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	
	$CurrentMacAddressMinimum = (Get-VMHost).MacAddressMinimum
	$CurrentMacAddressMaximum = (Get-VMHost).MacAddressMaximum
	Set-VMHost -MacAddressMinimum '001000000000' -MacAddressMaximum '0010000000FF'
	Context "No parameter is passed" {
		It "Fails" {
			{ Initialize-LabHyperV } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		It "Returns True" {
			Initialize-LabHyperV -Config $Config | Should Be $True
		}
		It "MacAddressMinumum should be $($Config.labbuilderconfig.SelectNodes('settings').macaddressminimum)" {
			(Get-VMHost).MacAddressMinimum | Should Be $Config.labbuilderconfig.SelectNodes('settings').macaddressminimum
		}
		It "MacAddressMaximum should be $($Config.labbuilderconfig.SelectNodes('settings').macaddressmaximum)" {
			(Get-VMHost).MacAddressMaximum | Should Be $Config.labbuilderconfig.SelectNodes('settings').macaddressmaximum
		}
	}
	Set-VMHost -MacAddressMinimum $CurrentMacAddressMinimum -MacAddressMaximum $CurrentMacAddressMaximum
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabDSC" {
	$Config = Get-LabConfiguration -Path $TestConfigPath

	Context "No parameter is passed" {
		It "Fails" {
			{ Initialize-LabDSC } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabSwitches" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	$ExpectedSwtiches = @( 
				@{ name="Pester Test External"; type="External"; vlan=$null; adapters=[System.Collections.Hashtable[]]@(
					@{ name="Cluster"; macaddress="00155D010701" },
					@{ name="Management"; macaddress="00155D010702" },
					@{ name="SMB"; macaddress="00155D010703" },
					@{ name="LM"; macaddress="00155D010704" }
					)
				},
				@{ name="Pester Test Private Vlan"; type="Private"; vlan="2"; adapters=@() },
				@{ name="Pester Test Private"; type="Private"; vlan=$null; adapters=@() },
				@{ name="Pester Test Internal Vlan"; type="Internal"; vlan="3"; adapters=@() },
				@{ name="Pester Test Internal"; type="Internal"; vlan=$null; adapters=@() }
			)
	Context "No parameter is passed" {
		It "Fails" {
			{ Get-LabSwitches } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Switches = Get-LabSwitches -Config $Config
		
		It "Returns 5 Switch Items" {
			$Switches.Count | Should Be 5
		}
		It "Returns Switches Object that matches Expected Object" {
			[String]::Compare(($Switches | ConvertTo-Json -Depth 4),($ExpectedSwtiches | ConvertTo-Json -Depth 4),$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabSwitches" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	$Switches = Get-LabSwitches -Config $Config
	Get-VMSwitch -Name  Pester* | Remove-VMSwitch

	Context "No parameter is passed" {
		It "Fails" {
			{ Initialize-LabSwitches } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		It "Returns True" {
			Initialize-LabSwitches -Config $Config -Switches $Switches | Should Be $True
		}
		It "Creates 2 Pester Internal Switches" {
			(Get-VMSwitch -Name Pester* | Where-Object -Property SwitchType -EQ Internal).Count | Should Be 2
		}
		It "Creates 2 Pester Private Switches" {
			(Get-VMSwitch -Name Pester* | Where-Object -Property SwitchType -EQ Private).Count | Should Be 2
		}
	}

	Get-VMSwitch -Name  Pester* | Remove-VMSwitch
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Remove-LabSwitches" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	$Switches = Get-LabSwitches -Config $Config
	New-VMSwitch -Name "Pester Test Private Vlan" -SwitchType "Private"
	New-VMSwitch -Name "Pester Test Private" -SwitchType "Private"
	New-VMSwitch -Name "Pester Test Internal Vlan" -SwitchType "Internal"
	New-VMSwitch -Name "Pester Test Internal" -SwitchType "Internal"

	Context "No parameter is passed" {
		It "Fails" {
			{ Remove-LabSwitches } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		It "Returns True" {
			Remove-LabSwitches -Config $Config -Switches $Switches | Should Be $True
		}
		It "Removes All Pester Switches" {
			(Get-VMSwitch -Name Pester*).Count | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabVMTemplates" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	$ExpectedTemplates = @( 
				@{
					name="Pester Windows Server 2012 R2 Full";
					templatevhd="C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Full.vhdx";
					installiso="Tests\DummyISO\9600.16384.130821-1623_x64fre_Server_EN-US_IRM_SSS_DV5.iso";
					allowcreate="Y";
					edition="Windows Server 2012 R2 SERVERDATACENTER";
					vhd="Windows Server 2012 R2 Datacenter Full.vhdx";
				},
				@{
					name="Pester Windows Server 2012 R2 Core";
					templatevhd="C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Core.vhdx";
					installiso="Tests\DummyISO\9600.16384.130821-1623_x64fre_Server_EN-US_IRM_SSS_DV5.iso";
					allowcreate="Y";
					edition="Windows Server 2012 R2 SERVERDATACENTERCORE";
					vhd="Windows Server 2012 R2 Datacenter Core.vhdx";
				},
				@{
					name="Pester Windows 10 Enterprise";
					templatevhd="C:\Pester Lab\Virtual Hard Disk Templates\Windows 10 Enterprise.vhdx";
					installiso="Tests\DummyISO\10240.16384.150709-1700.TH1_CLIENTENTERPRISE_VOL_X64FRE_EN-US.iso";
					allowcreate="Y";
					edition="Windows 10 Enterprise";
					vhd="Windows 10 Enterprise.vhdx";
				}
			)
	Context "No parameter is passed" {
		It "Fails" {
			{ Get-LabVMTemplates } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Templates = Get-LabVMTemplates -Config $Config
		It "Returns 3 Template Items" {
			$Templates.Count | Should Be 3
		}
		It "Returns Template Object that matches Expected Object" {
			[String]::Compare(($Templates | ConvertTo-Json -Depth 2),($ExpectedTemplates | ConvertTo-Json -Depth 2),$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabVMTemplates" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	$VMTemplates = Get-LabVMTemplates -Config $Config

	Context "No parameter is passed" {
		It "Fails" {
			{ Initialize-LabVMTemplates } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		It "Returns True" {
			Initialize-LabVMTemplates -Config $Config -VMTemplates $VMTemplates | Should Be $True
		}
	}

	Get-VMSwitch -Name  Pester* | Remove-VMSwitch
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Remove-LabVMTemplates" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	$VMTemplates = Get-LabVMTemplates -Config $Config

	Context "No parameter is passed" {
		It "Fails" {
			{ Remove-LabVMTemplates } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		It "Returns True" {
			Remove-LabVMTemplates -Config $Config -VMTemplates $VMTemplates | Should Be $True
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabVMs" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	Context "No parameter is passed" {
		It "Fails" {
			{ Get-LabVMs } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Templates = Get-LabVMSwitches -Config $Config
		$Templates = Get-LabVMTemplates -Config $Config
		It "Returns 2 Template Items" {
			$Templates.Count | Should Be 2
		}
		It "Returns Template Object that matches Expected Object" {
			[String]::Compare(($Templates | ConvertTo-Json -Depth 2),($ExpectedTemplates | ConvertTo-Json -Depth 2),$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabVMs" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	$VMTemplates = Get-LabVMTemplates -Config $Config

	Context "No parameter is passed" {
		It "Fails" {
			{ Initialize-LabVMs } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		It "Returns True" {
			Initialize-LabVMTemplates -Config $Config -VMTemplates $VMTemplates | Should Be $True
		}
	}

	Get-VMSwitch -Name  Pester* | Remove-VMSwitch
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Remove-LabVMs" {
	$Config = Get-LabConfiguration -Path $TestConfigPath
	$VMTemplates = Get-LabVMTemplates -Config $Config

	Context "No parameter is passed" {
		It "Fails" {
			{ Remove-LabVMs } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		It "Returns True" {
			Remove-LabVMTemplates -Config $Config -VMTemplates $VMTemplates | Should Be $True
		}
	}
}
##########################################################################################################################################
