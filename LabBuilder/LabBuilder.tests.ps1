#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Set-Location $here
if (Get-Module LabBuilder -All)
{
    Get-Module LabBuilder -All | Remove-Module
}

Import-Module "$here\LabBuilder.psd1" -Force -DisableNameChecking
$Global:TestConfigPath = "$here\Tests\PesterTestConfig"
$Global:TestConfigOKPath = "$Global:TestConfigPath\PesterTestConfig.OK.xml"

InModuleScope LabBuilder {
##########################################################################################################################################
Describe "Get-LabConfiguration" {
	Context "No parameters passed" {
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
			$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
			$Config.GetType().Name | Should Be 'XmlDocument'
			$Config.labbuilderconfig | Should Not Be $null
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Test-LabConfiguration" {

	Context "No parameters passed" {
		It "Fails" {
			{ Test-LabConfiguration } | Should Throw
		}
	}

	$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

	Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vmpath -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue

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
	Remove-Item -Path $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Install-LabHyperV" {

	#region Mocks
    Mock Get-WindowsOptionalFeature { [PSObject]@{ FeatureName = 'Mock'; State = 'Disabled'; } }
	Mock Enable-WindowsOptionalFeature 
	Mock Get-WindowsFeature { [PSObject]@{ Name = 'Mock'; Installed = $false; } }
	Mock Install-WindowsFeature
	#endregion

	Context "The function exists" {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		It "Returns True" {
			Install-LabHyperV | Should Be $True
		}
		If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
			It "Calls Mocked commands" {
				Assert-MockCalled Get-WindowsOptionalFeature -Exactly 1
				Assert-MockCalled Enable-WindowsOptionalFeature -Exactly 1
			}
		} Else {
			It "Calls Mocked commands" {
				Assert-MockCalled Get-WindowsFeature -Exactly 1
				Assert-MockCalled Install-WindowsFeature -Exactly 1
			}
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabHyperV" {
	Context "No parameters passed" {
		It "Fails" {
			{ Initialize-LabHyperV } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
	
		$CurrentMacAddressMinimum = (Get-VMHost).MacAddressMinimum
		$CurrentMacAddressMaximum = (Get-VMHost).MacAddressMaximum
		Set-VMHost -MacAddressMinimum '001000000000' -MacAddressMaximum '0010000000FF'

		It "Returns True" {
			Initialize-LabHyperV -Configuration $Config | Should Be $True
		}
		It "MacAddressMinumum should be $($Config.labbuilderconfig.SelectNodes('settings').macaddressminimum)" {
			(Get-VMHost).MacAddressMinimum | Should Be $Config.labbuilderconfig.SelectNodes('settings').macaddressminimum
		}
		It "MacAddressMaximum should be $($Config.labbuilderconfig.SelectNodes('settings').macaddressmaximum)" {
			(Get-VMHost).MacAddressMaximum | Should Be $Config.labbuilderconfig.SelectNodes('settings').macaddressmaximum
		}
		
		Set-VMHost -MacAddressMinimum $CurrentMacAddressMinimum -MacAddressMaximum $CurrentMacAddressMaximum
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabSwitches" {
	Context "No parameters passed" {
		It "Fails" {
			{ Get-LabConfiguration } | Should Throw
		}
	}
	Context "Configuration passed with switch missing Switch Name." {
		It "Fails" {
			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.NoName.xml") } | Should Throw
		}
	}
	Context "Configuration passed with switch missing Switch Type." {
		It "Fails" {
			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.NoType.xml") } | Should Throw
		}
	}
	Context "Configuration passed with switch invalid Switch Type." {
		It "Fails" {
			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.BadType.xml") } | Should Throw
		}
	}
	Context "Configuration passed with switch containing adapters but is not External type." {
		It "Fails" {
			{ Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.AdaptersSet.xml") } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config
		# Set-Content -Path "$($ENV:Temp)\Switches.json" -Value ($Switches | ConvertTo-Json -Depth 4)
		
		It "Returns Switches Object that matches Expected Object" {
			$ExpectedSwitches = [string] @"
[
    {
        "vlan":  null,
        "name":  "Pester Test External",
        "adapters":  [
                         {
                             "name":  "Cluster",
                             "macaddress":  "00155D010701"
                         },
                         {
                             "name":  "Management",
                             "macaddress":  "00155D010702"
                         },
                         {
                             "name":  "SMB",
                             "macaddress":  "00155D010703"
                         },
                         {
                             "name":  "LM",
                             "macaddress":  "00155D010704"
                         }
                     ],
        "type":  "External"
    },
    {
        "vlan":  "2",
        "name":  "Pester Test Private Vlan",
        "adapters":  null,
        "type":  "Private"
    },
    {
        "vlan":  null,
        "name":  "Pester Test Private",
        "adapters":  null,
        "type":  "Private"
    },
    {
        "vlan":  "3",
        "name":  "Pester Test Internal Vlan",
        "adapters":  null,
        "type":  "Internal"
    },
    {
        "vlan":  null,
        "name":  "Pester Test Internal",
        "adapters":  null,
        "type":  "Internal"
    }
]
"@
			[String]::Compare(($Switches | ConvertTo-Json -Depth 4),$ExpectedSwitches,$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabSwitches" {

	#region Mocks
    Mock Get-VMSwitch
    Mock New-VMSwitch
    Mock Add-VMNetworkAdapter
    Mock Set-VMNetworkAdapterVlan
    #endregion

	Context "No parameters passed" {
		It "Fails" {
			{ Initialize-LabSwitches } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config

		It "Returns True" {
			Initialize-LabSwitches -Configuration $Config -Switches $Switches | Should Be $True
		}
		It "Calls Mocked commands" {
			Assert-MockCalled Get-VMSwitch -Exactly 5
			Assert-MockCalled New-VMSwitch -Exactly 5
			Assert-MockCalled Add-VMNetworkAdapter -Exactly 4
			Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Remove-LabSwitches" {

	#region Mocks
    Mock Get-VMSwitch
    Mock Remove-VMSwitch
    #endregion

	Context "No parameters passed" {
		It "Fails" {
			{ Remove-LabSwitches } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config

		It "Returns True" {
			Remove-LabSwitches -Configuration $Config -Switches $Switches | Should Be $True
		}
		It "Calls Mocked commands" {
			Assert-MockCalled Get-VMSwitch -Exactly 5
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabVMTemplates" {
	Context "No parameters passed" {
		It "Fails" {
			{ Get-LabVMTemplates } | Should Throw
		}
	}
	Context "Configuration passed with template missing Template Name." {
		It "Fails" {
			{ Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.TemplateFail.NoName.xml") } | Should Throw
		}
	}
	Context "Configuration passed with template missing VHD Path." {
		It "Fails" {
			{ Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.TemplateFail.NoVHD.xml") } | Should Throw
		}
	}
	Context "Configuration passed with template with Source VHD set to non-existent file." {
		It "Fails" {
			{ Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.TemplateFail.BadSourceVHD.xml") } | Should Throw
		}
	}
	Context "Valid configuration is passed" {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$Templates = Get-LabVMTemplates -Configuration $Config 
		# Set-Content -Path "$($ENV:Temp)\VMTemplates.json" -Value ($Templates | ConvertTo-Json -Depth 2)
		It "Returns Template Object that matches Expected Object" {
		$ExpectedTemplates = [string] @"
[
    {
        "processorcount":  "1",
        "templatevhd":  "C:\\Pester Lab\\Virtual Hard Disk Templates\\Windows Server 2012 R2 Datacenter Full.vhdx",
        "memorystartupbytes":  null,
        "ostype":  "Server",
        "datavhdsize":  null,
        "name":  "Pester Windows Server 2012 R2 Datacenter Full",
        "administratorpassword":  "None",
        "installiso":  ".\\Tests\\PesterTestConfig\\9600.16384.130821-1623_x64fre_Server_EN-US_IRM_SSS_DV5.iso",
        "productkey":  "AAAAA-AAAAA-AAAAA-AAAAA-AAAAA",
        "edition":  "Windows Server 2012 R2 SERVERDATACENTER",
        "vhd":  "Windows Server 2012 R2 Datacenter Full.vhdx",
        "timezone":  "Pacific Standard Time",
        "sourcevhd":  ".\\Tests\\PesterTestConfig\\Windows Server 2012 R2 Datacenter Full.vhdx",
        "allowcreate":  "Y"
    },
    {
        "processorcount":  "1",
        "templatevhd":  "C:\\Pester Lab\\Virtual Hard Disk Templates\\Windows Server 2012 R2 Datacenter Core.vhdx",
        "memorystartupbytes":  null,
        "ostype":  "Server",
        "datavhdsize":  null,
        "name":  "Pester Windows Server 2012 R2 Datacenter Core",
        "administratorpassword":  "None",
        "installiso":  ".\\Tests\\PesterTestConfig\\9600.16384.130821-1623_x64fre_Server_EN-US_IRM_SSS_DV5.iso",
        "productkey":  "BBBBB-BBBBB-BBBBB-BBBBB-BBBBB",
        "edition":  "Windows Server 2012 R2 SERVERDATACENTERCORE",
        "vhd":  "Windows Server 2012 R2 Datacenter Core.vhdx",
        "timezone":  "Pacific Standard Time",
        "sourcevhd":  ".\\Tests\\PesterTestConfig\\Windows Server 2012 R2 Datacenter Full.vhdx",
        "allowcreate":  "Y"
    },
    {
        "processorcount":  "1",
        "templatevhd":  "C:\\Pester Lab\\Virtual Hard Disk Templates\\Windows 10 Enterprise.vhdx",
        "memorystartupbytes":  null,
        "ostype":  "Client",
        "datavhdsize":  null,
        "name":  "Pester Windows 10 Enterprise",
        "administratorpassword":  "None",
        "installiso":  ".\\Tests\\PesterTestConfig\\10240.16384.150709-1700.TH1_CLIENTENTERPRISE_VOL_X64FRE_EN-US.iso",
        "productkey":  "CCCCC-CCCCC-CCCCC-CCCCC-CCCCC",
        "edition":  "Windows 10 Enterprise",
        "vhd":  "Windows 10 Enterprise.vhdx",
        "timezone":  "Pacific Standard Time",
        "sourcevhd":  ".\\Tests\\PesterTestConfig\\Windows 10 Enterprise.vhdx",
        "allowcreate":  "Y"
    }
]
"@
			[String]::Compare(($Templates | ConvertTo-Json -Depth 2),$ExpectedTemplates,$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabVMTemplates" {
	#region Mocks
    Mock Optimize-VHD
    Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
    Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
    #endregion

	Context "No parameters passed" {
		It "Fails" {
			{ Initialize-LabVMTemplates } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
		New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue
		$VMTemplates = Get-LabVMTemplates -Configuration $Config

		It "Returns True" {
			Initialize-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates | Should Be $True
		}
		It "Creates file C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Full.vhdx" {
			Test-Path "C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Full.vhdx" | Should Be $True
		}
		It "Creates file C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Core.vhdx" {
			Test-Path "C:\Pester Lab\Virtual Hard Disk Templates\Windows Server 2012 R2 Datacenter Core.vhdx" | Should Be $True
		}
		It "Creates file C:\Pester Lab\Virtual Hard Disk Templates\Windows 10 Enterprise.vhdx" {
			Test-Path "C:\Pester Lab\Virtual Hard Disk Templates\Windows 10 Enterprise.vhdx" | Should Be $True
		}
		It "Calls Mocked commands" {
			Assert-MockCalled Optimize-VHD -Exactly 3
			Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
			Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
		}

		Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Remove-LabVMTemplates" {
	#region Mocks
    Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
    Mock Remove-Item
    Mock Test-Path -MockWith { $True }
    #endregion

	Context "No parameters passed" {
		It "Fails" {
			{ Remove-LabVMTemplates } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$VMTemplates = Get-LabVMTemplates -Configuration $Config
		New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
		New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue
		
		It "Returns True" {
			Remove-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates | Should Be $True
		}
		It "Calls Mocked commands" {
			Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
			Assert-MockCalled Remove-Item -Exactly 3
		}

		Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Set-LabDSCMOFFile" {
    Remove-Item -Path "C:\Pester Lab\PESTER01\LabBuilder Files" -Recurse -Force -ErrorAction SilentlyContinue

	#region Mocks
    Mock Import-Certificate -MockWith {
		[PSCustomObject]@{
			Thumbprint = '1234567890ABCDEF'
		}
    } # Mock
    Mock Remove-Item -ParameterFilter {$path -eq 'Cert:LocalMachine\My\1234567890ABCDEF'}
    #endregion

	Context "No parameters passed" {
		It "Fails" {
			{ Set-LabDSCMOFFile } | Should Throw
		}
	}
 	Context "Valid Parameters Passed" {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config
		$VMTemplates = Get-LabVMTemplates -Configuration $Config
		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
		$Result = Set-LabDSCMOFFile -Configuration $Config -VM $VMs
		It "Returns True" {
			$Result | Should Be $True
		}
		It "Appropriate Lab Builder Files Should be produced" {
			Test-Path -Path 'C:\Pester Lab\PESTER01\LabBuilder Files\Pester01.mof' | Should Be $True
			Test-Path -Path 'C:\Pester Lab\PESTER01\LabBuilder Files\Pester01.meta.mof' | Should Be $True
			Test-Path -Path 'C:\Pester Lab\PESTER01\LabBuilder Files\DSC.ps1' | Should Be $True
			Test-Path -Path 'C:\Pester Lab\PESTER01\LabBuilder Files\DSCConfigData.psd1' | Should Be $True
			Test-Path -Path 'C:\Pester Lab\PESTER01\LabBuilder Files\DSCNetworking.ps1' | Should Be $True
		}
	}
    Remove-Item -Path "C:\Pester Lab\PESTER01\LabBuilder Files" -Recurse -Force -ErrorAction SilentlyContinue

}
##########################################################################################################################################

##########################################################################################################################################
Describe "Set-LabDSCStartFile" {
	#region Mocks
    Mock Get-VMNetworkAdapter -MockWith { [PSObject]@{ Name = 'Dummy'; MacAddress = '00-11-22-33-44-55'; } }
    Mock Set-Content
    #endregion
	Context "No parameters passed" {
		It "Fails" {
			{ Set-LabDSCStartFile } | Should Throw
		}
	}
	Context "Valid Parameters Passed" {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config
		$VMTemplates = Get-LabVMTemplates -Configuration $Config

		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
		[String]$DSCStartFile = Set-LabDSCStartFile -Configuration $Config -VM $VMs
		It "Returns Expected File Content" {
			$DSCStartFile | Should Be $True
		}
		It "Calls Mocked commands" {
			Assert-MockCalled Get-VMNetworkAdapter -Exactly 4
			Assert-MockCalled Set-Content -Exactly 1
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabUnattendFile" {
	Context "No parameters passed" {
		It "Fails" {
			{ Get-LabUnattendFile } | Should Throw
		}
	}
	Context "Valid Parameters Passed" {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config
		$VMTemplates = Get-LabVMTemplates -Configuration $Config
		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
		$ExpectedUnattendFile = [String] @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
	<settings pass="offlineServicing">
		<component name="Microsoft-Windows-LUA-Settings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<EnableLUA>false</EnableLUA>
		</component>
	</settings>
	<settings pass="generalize">
		<component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<SkipRearm>1</SkipRearm>
		</component>
	</settings>
	<settings pass="specialize">
		<component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<InputLocale>0409:00000409</InputLocale>
			<SystemLocale>en-US</SystemLocale>
			<UILanguage>en-US</UILanguage>
			<UILanguageFallback>en-US</UILanguageFallback>
			<UserLocale>en-US</UserLocale>
		</component>
		<component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<SkipAutoActivation>true</SkipAutoActivation>
		</component>
		<component name="Microsoft-Windows-SQMApi" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<CEIPEnabled>0</CEIPEnabled>
		</component>
		<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<ComputerName>PESTER01</ComputerName>
			<ProductKey>DDDDD-DDDDD-DDDDD-DDDDD-DDDDD</ProductKey>
		</component>
	</settings>
	<settings pass="oobeSystem">
		<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<OOBE>
				<HideEULAPage>true</HideEULAPage>
				<HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
				<HideOnlineAccountScreens>true</HideOnlineAccountScreens>
				<HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
				<NetworkLocation>Work</NetworkLocation>
				<ProtectYourPC>1</ProtectYourPC>
				<SkipUserOOBE>true</SkipUserOOBE>
				<SkipMachineOOBE>true</SkipMachineOOBE>
			</OOBE>
			<UserAccounts>
			   <AdministratorPassword>
				  <Value>Something</Value>
				  <PlainText>true</PlainText>
			   </AdministratorPassword>
			</UserAccounts>
			<RegisteredOrganization>PESTER.LOCAL</RegisteredOrganization>
			<RegisteredOwner>tester@pester.local</RegisteredOwner>
			<DisableAutoDaylightTimeSet>false</DisableAutoDaylightTimeSet>
			<TimeZone>Pacific Standard Time</TimeZone>
		</component>
		<component name="Microsoft-Windows-ehome-reg-inf" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="NonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<RestartEnabled>true</RestartEnabled>
		</component>
		<component name="Microsoft-Windows-ehome-reg-inf" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="NonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<RestartEnabled>true</RestartEnabled>
		</component>
	</settings>
</unattend>
"@
		[String]$UnattendFile = Get-LabUnattendFile -Configuration $Config -VM $VMs
		# Set-Content -Path "$($ENV:Temp)\UnattendFile.xml" -Value $UnattendFile
		It "Returns Expected File Content" {
			$UnattendFile | Should Be $True
			[String]::Compare($UnattendFile,$ExpectedUnattendFile,$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Set-LabVMInitializationFiles" {
	#region Mocks
    Mock Mount-WindowsImage
    Mock Dismount-WindowsImage
    Mock Invoke-WebRequest
    Mock Add-WindowsPackage
    Mock Set-Content
    Mock Copy-Item
    #endregion
	Context "No parameters passed" {
		It "Fails" {
			{ Set-LabVMInitializationFiles } | Should Throw
		}
    }
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
		New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

		$Templates = Get-LabVMTemplates -Configuration $Config
		$Switches = Get-LabSwitches -Configuration $Config
		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
				
		It "Returns True" {
			Set-LabVMInitializationFiles -Configuration $Config -VM $VMs -VMBootDiskPath 'c:\Dummy\' | Should Be $True
		}
		It "Calls Mocked commands" {
			Assert-MockCalled Mount-WindowsImage -Exactly 1
			Assert-MockCalled Dismount-WindowsImage -Exactly 1
			Assert-MockCalled Invoke-WebRequest -Exactly 1
			Assert-MockCalled Add-WindowsPackage -Exactly 1
			Assert-MockCalled Set-Content -Exactly 6
			Assert-MockCalled Copy-Item -Exactly 1
		}

		Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabVMs" {

	Context "No parameters passed" {
		It "Fails" {
			{ Get-LabVMs } | Should Throw
		}
	}
	Context "Configuration passed with VM missing VM Name." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.NoName.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM missing Template." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.NoTemplate.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM invalid Template." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadTemplate.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM missing adapter name." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.NoAdapterName.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM missing adapter switch name." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.NoAdapterSwitch.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM invalid adapter switch name." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadAdapterSwitch.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM unattend file that can't be found." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadUnattendFile.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM setup complete file that can't be found." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadSetupCompleteFile.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM setup complete file with an invalid file extension." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadSetupCompleteFileType.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM DSC Config File that can't be found." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadDSCConfigFile.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM DSC Config File with an invalid file extension." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadDSCConfigFileType.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}
	Context "Configuration passed with VM DSC Config File but no DSC Name." {
		It "Fails" {
			$Config = Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.VMFail.BadDSCNameMissing.xml"
			$Switches = Get-LabSwitches -Configuration $Config
			$VMTemplates = Get-LabVMTemplates -Configuration $Config
			{ Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches } | Should Throw
		}
	}

	Context "Valid configuration is passed" {
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$Switches = Get-LabSwitches -Configuration $Config
		$VMTemplates = Get-LabVMTemplates -Configuration $Config
		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
		# Set-Content -Path "$($ENV:Temp)\VMs.json" -Value ($VMs | ConvertTo-Json -Depth 4)
		It "Returns Template Object that matches Expected Object" {
			$ExpectedVMs = [String] @"
{
    "TemplateVHD":  "C:\\Pester Lab\\Virtual Hard Disk Templates\\Windows Server 2012 R2 Datacenter Full.vhdx",
    "ProcessorCount":  1,
    "TimeZone":  "Pacific Standard Time",
    "Template":  "Pester Windows Server 2012 R2 Datacenter Full",
    "MemoryStartupBytes":  10737418240,
    "SetupComplete":  "",
    "OSType":  "Server",
    "DSCConfigName":  "STANDALONE_DEFAULT",
    "DSCParameters":  "\r\n          Dummy = \"Dummy\"\r\n        ",
    "UseDifferencingDisk":  "Y",
    "DSCConfigFile":  "C:\\Users\\Daniel\\Source\\GitHub\\LabBuilder\\LabBuilder\\Tests\\PesterTestConfig\\PesterTest.DSC.ps1",
    "ComputerName":  "PESTER01",
    "ProductKey":  "DDDDD-DDDDD-DDDDD-DDDDD-DDDDD",
    "DataVHDSize":  0,
    "Name":  "PESTER01",
    "UnattendFile":  "",
    "AdministratorPassword":  "Something",
    "Adapters":  [
                     {
                         "IPv6":  {
                                      "dnsserver":  "fd53:ccc5:895a:0000::1",
                                      "subnetmask":  "64",
                                      "Address":  "fd53:ccc5:895a:0000::1",
                                      "defaultgateway":  ""
                                  },
                         "Name":  "Pester Test Private Vlan",
                         "SwitchName":  "Pester Test Private Vlan",
                         "VLan":  "2",
                         "IPv4":  {
                                      "dnsserver":  "192.168.16.1",
                                      "subnetmask":  "24",
                                      "Address":  "192.168.16.1",
                                      "defaultgateway":  ""
                                  },
                         "MACAddress":  "00155D010801"
                     },
                     {
                         "IPv6":  {
                                      "dnsserver":  "fd53:ccc5:895a:0000::2",
                                      "subnetmask":  "64",
                                      "Address":  "fd53:ccc5:895a:0000::2",
                                      "defaultgateway":  ""
                                  },
                         "Name":  "Pester Test Internal Vlan",
                         "SwitchName":  "Pester Test Internal Vlan",
                         "VLan":  "3",
                         "IPv4":  {
                                      "dnsserver":  "192.168.16.2",
                                      "subnetmask":  "24",
                                      "Address":  "192.168.16.2",
                                      "defaultgateway":  ""
                                  },
                         "MACAddress":  "00155D010802"
                     },
                     {
                         "IPv6":  {
                                      "dnsserver":  "fd53:ccc5:895a:0000::3",
                                      "subnetmask":  "64",
                                      "Address":  "fd53:ccc5:895a:0000::3",
                                      "defaultgateway":  ""
                                  },
                         "Name":  "Pester Test Private",
                         "SwitchName":  "Pester Test Private",
                         "VLan":  "3",
                         "IPv4":  {
                                      "dnsserver":  "192.168.16.3",
                                      "subnetmask":  "24",
                                      "Address":  "192.168.16.3",
                                      "defaultgateway":  ""
                                  },
                         "MACAddress":  "00155D010803"
                     },
                     {
                         "IPv6":  {
                                      "dnsserver":  "fd53:ccc5:895a:0000::4",
                                      "subnetmask":  "64",
                                      "Address":  "fd53:ccc5:895a:0000::4",
                                      "defaultgateway":  ""
                                  },
                         "Name":  "Pester Test Internal",
                         "SwitchName":  "Pester Test Internal",
                         "VLan":  "4",
                         "IPv4":  {
                                      "dnsserver":  "192.168.16.4",
                                      "subnetmask":  "24",
                                      "Address":  "192.168.16.4",
                                      "defaultgateway":  ""
                                  },
                         "MACAddress":  "00155D010804"
                     }
                 ],
    "InstallMSU":  [
                       "http://download.microsoft.com/download/1/D/8/1D8B5022-5477-4B9A-8104-6A71FF9D98AB/WindowsTH-KB2693643-x64.msu"
                   ]
}
"@
			[String]::Compare(($VMs | ConvertTo-Json -Depth 4),$ExpectedVMs,$true) | Should Be 0
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Get-LabVMSelfSignedCert" {
	Context "No parameters passed" {
		It "Fails" {
			{ Get-LabVMSelfSignedCert } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Initialize-LabVMs" {
	#region Mocks
    Mock New-VHD
    Mock New-VM
    Mock Get-VM -MockWith { [PSObject]@{ ProcessorCount = '2'; State = 'Off' } }
    Mock Set-VM
    Mock Get-VMHardDiskDrive
    Mock Set-LabVMInitializationFiles
    Mock Get-VMNetworkAdapter
    Mock Add-VMNetworkAdapter
    Mock Start-VM
    Mock Wait-LabVMInit -MockWith { $True }
    Mock Get-LabVMSelfSignedCert
    Mock Initialize-LabVMDSC
    Mock Start-LabVMDSC
    #endregion

	Context "No parameters passed" {
		It "Fails" {
			{ Initialize-LabVMs } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
		New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

		$Templates = Get-LabVMTemplates -Configuration $Config
		$Switches = Get-LabSwitches -Configuration $Config
		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
				
		It "Returns True" {
			Initialize-LabVMs -Configuration $Config -VMs $VMs | Should Be $True
		}
		It "Calls Mocked commands" {
			Assert-MockCalled New-VHD -Exactly 1
			Assert-MockCalled New-VM -Exactly 1
			Assert-MockCalled Set-VM -Exactly 1
			Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
			Assert-MockCalled Set-LabVMInitializationFiles -Exactly 1
            Assert-MockCalled Get-VMNetworkAdapter -Exactly 9
            Assert-MockCalled Add-VMNetworkAdapter -Exactly 4
            Assert-MockCalled Start-VM -Exactly 1
            Assert-MockCalled Wait-LabVMInit -Exactly 1
            Assert-MockCalled Get-LabVMSelfSignedCert -Exactly 1
            Assert-MockCalled Initialize-LabVMDSC -Exactly 1
            Assert-MockCalled Start-LabVMDSC -Exactly 1
		}
        
		Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Remove-LabVMs" {
	#region Mocks
    Mock Get-VM -MockWith { [PSObject]@{ Name = 'PESTER01'; State = 'Running'; } }
    Mock Stop-VM
    Mock Wait-LabVMOff -MockWith { Return $True }
    Mock Get-VMHardDiskDrive
    Mock Remove-VM
    #endregion

   	Context "No parameters passed" {
		It "Fails" {
			{ Remove-LabVMs } | Should Throw
		}
	}
	Context "Valid configuration is passed" {	
		$Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
		$Templates = Get-LabVMTemplates -Configuration $Config
		$Switches = Get-LabSwitches -Configuration $Config
		$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches

		# Create the dummy VM's that the Remove-LabVMs function 
		It "Returns True" {
			Remove-LabVMs -Configuration $Config -VMs $VMs | Should Be $True
		}
		It "Calls Mocked commands" {
			Assert-MockCalled Get-VM -Exactly 4
			Assert-MockCalled Stop-VM -Exactly 1
			Assert-MockCalled Wait-LabVMOff -Exactly 1
			Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
			Assert-MockCalled Remove-VM -Exactly 1
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Wait-LabVMInit" {
	Context "No parameters passed" {
		It "Fails" {
			{ Wait-LabVMInit } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Wait-LabVMStart" {
	Context "No parameters passed" {
		It "Fails" {
			{ Wait-LabVMStart } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Wait-LabVMOff" {
	Context "No parameters passed" {
		It "Fails" {
			{ Wait-LabVMOff } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Install-Lab" {
	Context "No parameters passed" {
		It "Fails" {
			{ Install-Lab } | Should Throw
		}
	}
}
##########################################################################################################################################

##########################################################################################################################################
Describe "Uninstall-Lab" {
	Context "No parameters passed" {
		It "Fails" {
			{ Uninstall-Lab } | Should Throw
		}
	}
}
##########################################################################################################################################
}