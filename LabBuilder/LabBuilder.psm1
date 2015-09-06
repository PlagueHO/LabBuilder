#Requires -version 5.0

##########################################################################################################################################
# Module Variables
##########################################################################################################################################
# This is the URL to the WMF Production Preview
[String]$Script:WorkingFolder = $ENV:Temp
[String]$Script:WMF5DownloadURL = 'http://download.microsoft.com/download/3/F/D/3FD04B49-26F9-4D9A-8C34-4533B9D5B020/Win8.1AndW2K12R2-KB3066437-x64.msu'
[String]$Script:WMF5InstallerFilename = ($Script:WMF5DownloadURL).Substring(($Script:WMF5DownloadURL).LastIndexOf("/") + 1)
[String]$Script:WMF5InstallerPath = Join-Path -Path $Script:WorkingFolder -ChildPath $Script:WMF5InstallerFilename
[String]$Script:CertGenDownloadURL = 'https://gallery.technet.microsoft.com/scriptcenter/Self-signed-certificate-5920a7c6/file/101251/1/New-SelfSignedCertificateEx.zip'
[String]$Script:CertGenZipFilename = ($Script:CertGenDownloadURL).Substring(($Script:CertGenDownloadURL).LastIndexOf("/") + 1)
[String]$Script:CertGenZipPath = Join-Path -Path $Script:WorkingFolder -ChildPath $Script:CertGenZipFilename
[String]$Script:CertGenPS1Filename = 'New-SelfSignedCertificateEx.ps1'
[String]$Script:CertGenPS1Path = Join-Path -Path $Script:WorkingFolder -ChildPath $Script:CertGenPS1Filename
##########################################################################################################################################
# Helper functions that aren't exported
##########################################################################################################################################
function Test-Admin()
{
    # Get the ID and security principal of the current user account
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
  
    # Get the security principal for the Administrator role
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
  
    # Check to see if we are currently running "as Administrator"
    Return ($myWindowsPrincipal.IsInRole($adminRole))
}
##########################################################################################################################################
function Download-WMF5Installer()
{
    # Only downloads for Win8.1/WS2K12R2
	[String]$URL = $Script:WMF5DownloadURL
	If (-not (Test-Path -Path $Script:WMF5InstallerPath)) {
		Try {
			Invoke-WebRequest -Uri $URL -OutFile $Script:WMF5InstallerPath
		} Catch {
			Return $False
		}
	}
    Return $True
} # Download-WMF5Installer
##########################################################################################################################################
function Download-CertGenerator()
{
	[String]$URL = $Script:CertGenDownloadURL
	If (-not (Test-Path -Path $Script:CertGenZipPath)) {
		Try {
			Invoke-WebRequest -Uri $URL -OutFile $Script:CertGenZipPath
		} Catch {
			Return $False
		} # Try
	} # If
	If (-not (Test-Path -Path $Script:CertGenPS1Path)) {
		Try {
			Expand-Archive -Path $Script:CertGenZipPath -DestinationPath $Script:WorkingFolder
		} Catch {
			Return $False
		} # Try
	} # If
	
    Return $True
} # Download-CertGenerator
##########################################################################################################################################
function Get-ModulesInDSCConfig()
{
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(
			Mandatory=$True,
			Position=0)]
		[ValidateNotNullOrEmpty()]	
		[String]$DSCConfigFile
	)
	[String[]]$Modules = $Null
	[String]$Content = Get-Content -Path $DSCConfigFile
	$Regex = "Import\-DscResource\s(?:\-ModuleName\s)?'?`"?([A-Za-z0-9]+)`"?'?"
	$Matches = [regex]::matches($Content, $Regex, "IgnoreCase")
	Foreach ($Match in $Matches) {
		If ($Match.Groups[1].Value -ne 'PSDesiredStateConfiguration') {
			$Modules += $Match.Groups[1].Value
		} # If
	} # Foreach
	# Add the xNetworking DSC Resource because it is always used
	$Modules += "xNetworking"
	Return $Modules
} # Get-ModulesInDSCConfig
##########################################################################################################################################

##########################################################################################################################################
# Main CmdLets
##########################################################################################################################################
function Get-LabConfiguration {
	[CmdLetBinding()]
	[OutputType([XML])]
	param (
		[parameter(
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[String]$Path
	) # Param
	If (-not $Path) {
		Throw "Configuration file parameter is missing."
	} # If
	If (-not (Test-Path -Path $Path)) {
		Throw "Configuration file $Path is not found."
	} # If
	$Content = Get-Content -Path $Path -Raw
	If (-not $Content) {
		Throw "Configuration file $Path is empty."
	} # If
	[XML]$Configuration = New-Object -TypeName XML
	$Configuration.LoadXML($Content)
	# Figure out the Config path and load it into the XML object (if we can)
	# This path is used to find any additional configuration files that might
	# be provided with config
	[String]$ConfigPath = [System.IO.Path]::GetDirectoryName($Path)
	[String]$XMLConfigPath = $Configuration.labbuilderconfig.settings.configpath
    If ($XMLConfigPath) {
		If ($XMLConfigPath.Substring(0,1) -eq '.') {
			# A relative path was provided in the config path so add the actual path of the XML to it
			[String]$FullConfigPath = Join-Path -Path $ConfigPath -ChildPath $XMLConfigPath
		} # If
	} Else {
        [String]$FullConfigPath = $ConfigPath
    }
	$Configuration.labbuilderconfig.settings.setattribute('fullconfigpath',$FullConfigPath)
	Return $Configuration
} # Get-LabConfiguration
##########################################################################################################################################

##########################################################################################################################################
function Test-LabConfiguration {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(
			Mandatory=$True,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration
	)

	If ($Configuration.labbuilderconfig -eq $null) {
		Throw "Configuration is invalid."
	}

	If ($Configuration.labbuilderconfig.settings -eq $null) {
		Throw "Configuration is invalid."
	}

	# Check folders exist
	[String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath
	If (-not $VMPath) {
		Throw "<settings>\<vmpath> is missing or empty in the configuration."
	}

	If (-not (Test-Path -Path $VMPath)) {
		Throw "The VM Path $VMPath is not found."
	}

	[String]$VHDParentPath = $Configuration.labbuilderconfig.settings.vhdparentpath
	If (-not $VHDParentPath) {
		Throw "<settings>\<vhdparentpath> is missing or empty in the configuration."
	}

	If (-not (Test-Path -Path $VHDParentPath)) {
		Throw "The VHD Parent Path $VHDParentPath is not found."
	}

	[String]$FullConfigPath = $Configuration.labbuilderconfig.settings.fullconfigpath
	If (-not (Test-Path -Path $FullConfigPath)) {
		Throw "The Config Path $FullConfigPath could not be found."
	}

	Return $True
} # Test-LabConfiguration
##########################################################################################################################################

##########################################################################################################################################
function Install-LabHyperV {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	Param ()

	# Install Hyper-V Components
	If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
		# Desktop OS
		$Feature = Get-WindowsOptionalFeature -Online -FeatureName '*Hyper-V*' | Where-Object -Property State -Eq 'Disabled'
		If ($Feature.Count -gt 0 ) {
			Write-Verbose "Installing Lab Desktop Hyper-V Components ..."
			$Feature | Enable-WindowsOptionalFeature -Online
		}
	} Else {
		# Server OS
		$Geature = Get-WindowsFeature -Name Hyper-V | Where-Object -Property Installed -EQ $False
		If ($Feature.Count -gt 0 ) {
			Write-Verbose "Installing Lab Server Hyper-V Components ..."
			$Feature | Install-WindowsFeature -IncludeAllSubFeature -IncludeManagementTools
		}
	}

	Return $True
} # Install-LabHyperV
##########################################################################################################################################

##########################################################################################################################################
function Initialize-LabHyperV {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(
			Mandatory=$True,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration
	)
	
	If ($Configuration.labbuilderconfig -eq $null) {
		Throw "Configuration is invalid."
	}

	# Install Hyper-V Components
	Write-Verbose "Initializing Lab Hyper-V Components ..."
	
	[String]$MacAddressMinimum = $Configuration.labbuilderconfig.SelectNodes('settings').macaddressminimum
	If (-not $MacAddressMinimum) {
		$MacAddressMinimum = '00155D010600'
	}

	[String]$MacAddressMaximum = $Configuration.labbuilderconfig.SelectNodes('settings').macaddressmaximum
	If (-not $MacAddressMaximum) {
		$MacAddressMaximum = '00155D0106FF'
	}

	Set-VMHost -MacAddressMinimum $MacAddressMinimum -MacAddressMaximum $MacAddressMaximum | Out-Null

	# Download the New-SelfSignedCertificateEx.ps1 script
	Download-CertGenerator

	Return $True
} # Initialize-LabHyperV
##########################################################################################################################################

##########################################################################################################################################
function Initialize-LabDSC {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(
			Mandatory=$True,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration
	)
	
	If ($Configuration.labbuilderconfig -eq $null) {
		Throw "Configuration is invalid."
	}
	
	# Download WMF 5.0 in case any VMs need it
	If (-not (Download-WMF5Installer)) {
		Throw "An error occurred downloading the WMF 5.0 Installer."
	}

	# Install DSC Components
	Write-Verbose "Configuring Lab DSC Components ..."
	
	Return $True
} # Initialize-LabDSC
##########################################################################################################################################

##########################################################################################################################################
function Get-LabSwitches {
	[OutputType([System.Collections.Hashtable[]])]
	[CmdLetBinding()]
	param (
		[Parameter(
			Mandatory=$True,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration
	)

	If ($Configuration.labbuilderconfig -eq $null) {
		Throw "Configuration is invalid."
	}

	[System.Collections.Hashtable[]]$Switches = @()
	$ConfigSwitches = $Configuration.labbuilderconfig.SelectNodes('switches').Switch
	Foreach ($ConfigSwitch in $ConfigSwitches) {
		# It can't be switch because if the name attrib/node is missing the name property on the XML object defaults to the name
		# Of the parent. So we can't easily tell if no name was specified or if they actually specified 'switch' as the name.
		If ($ConfigSwitch.Name -eq 'switch') {
			Throw "The switch name cannot be 'switch' or empty."
		}
		If ($ConfigSwitch.Type -notin 'Private','Internal','External') {
			Throw "The switch type must be Private, Internal or External."
		}
		# Assemble the list of Adapters if any are specified for this switch (only if an external switch)
		If ($ConfigSwitch.Adapters) {
			[System.Collections.Hashtable[]]$ConfigAdapters = @()
			Foreach ($Adapter in $ConfigSwitch.Adapters.Adapter) {
				$ConfigAdapters += @{ name = $Adapter.Name; macaddress = $Adapter.MacAddress }
			}
			If (($ConfigAdapters.Count -gt 0) -and ($ConfigSwitch.Type -ne 'External')) {
				Throw "Adapters can only be specified for External type switches."
			}
		} Else {
			$ConfigAdapters = $null
		}
		$Switches += @{
			name = $ConfigSwitch.Name;
			type = $ConfigSwitch.Type;
			vlan = $ConfigSwitch.Vlan;
			adapters = $ConfigAdapters } 
	}
	return $Switches
} # Get-LabSwitches
##########################################################################################################################################

##########################################################################################################################################
function Initialize-LabSwitches {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration,

		[Parameter(
			Mandatory=$true,
			Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$Switches
	)

	# Create Hyper-V Switches
	Foreach ($Switch in $Switches) {
		If ((Get-VMSwitch | Where-Object -Property Name -eq $Switch.Name).Count -eq 0) {
			[String]$SwitchName = $Switch.Name
			[string]$SwitchType = $Switch.Type
			Write-Verbose "Creating Virtual Switch '$SwitchName' ..."
			Switch ($SwitchType) {
				'External' {
					New-VMSwitch -Name $SwitchName -NetAdapterName (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 -ExpandProperty Name) | Out-Null
					If ($Switch.Adapters) {
						Foreach ($Adapter in $Switch.Adapters) {
							If ($Switch.VLan) {
								# A default VLAN is assigned to this Switch so assign it to the management adapters
								Add-VMNetworkAdapter -ManagementOS -SwitchName $Switch.Name -Name $Adapter.Name -StaticMacAddress $Adapter.MacAddress -Passthru | Set-VMNetworkAdapterVlan -Access -VlanId $Switch.Vlan | Out-Nul
							} Else { 
								Add-VMNetworkAdapter -ManagementOS -SwitchName $Switch.Name -Name $Adapter.Name -StaticMacAddress $Adapter.MacAddress | Out-Null
							} # If
						} # Foreach
					} # If
					Break
				} # 'External'
				'Private' {
					New-VMSwitch -Name $SwitchName -SwitchType Private | Out-Null
					Break
				} # 'Private'
				'Internal' {
					New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
					Break
				} # 'Internal'
				Default {
					Throw "Unknown Switch Type $SwitchType."
				}
			} # Switch
		} # If
	} # Foreach       
	Return $True 
} # Initialize-LabSwitches
##########################################################################################################################################

##########################################################################################################################################
function Remove-LabSwitches {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration,

		[Parameter(
			Mandatory=$true,
			Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$Switches
	)

	# Delete Hyper-V Switches
	Foreach ($Switch in $Switches) {
		If ((Get-VMSwitch | Where-Object -Property Name -eq $Switch.Name).Count -ne 0) {
			[String]$SwitchName = $Switch.Name
			If (-not $SwitchName) {
				Throw "The Switch Name can't be empty."
			}
			[string]$SwitchType = $Switch.Type
			Write-Verbose "Deleting Virtual Switch '$SwitchName' ..."
			Switch ($SwitchType) {
				'External' {
					If ($Switch.Adapters) {
						Foreach ($Adapter in $Switch.Adapters) {
								Remove-VMNetworkAdapter -ManagementOS -Name $Adapter.Name | Out-Null
						} # Foreach
					} # If
					Remove-VMSwitch -Name $SwitchName
					Break
				} # 'External'
				'Private' {
					Remove-VMSwitch -Name $SwitchName
					Break
				} # 'Private'
				'Internal' {
					Remove-VMSwitch -Name $SwitchName
					Break
				} # 'Internal'
				Default {
					Throw "Unknown Switch Type $SwitchType."
				}
			} # Switch
		} # If
	} # Foreach        
	Return $True
} # Remove-LabSwitches
##########################################################################################################################################

##########################################################################################################################################
function Get-LabVMTemplates {
	[OutputType([System.Collections.Hashtable[]])]
	[CmdLetBinding()]
	param (
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration
	)

	[System.Collections.Hashtable[]]$VMTemplates = @()
	[String]$VHDParentPath = $Configuration.labbuilderconfig.SelectNodes('settings').vhdparentpath

	# Get a list of all templates in the Hyper-V system matching the phrase found in the fromvm config setting
	[String]$FromVM=$Configuration.labbuilderconfig.SelectNodes('templates').fromvm
	If (($FromVM -ne $null) -and ($FromVM -ne '')) {
		$Templates = Get-VM -Name $FromVM
		Foreach ($Template in $Templates) {
			[String]$VHDFilepath = ($Template | Get-VMHardDiskDrive).Path
			[String]$VHDFilename = [System.IO.Path]::GetFileName($VHDFilepath)
			$VMTemplates += @{
				name = $Template.Name;
				vhd = $VHDFilename;
				sourcevhd = $VHDFilepath;
				templatevhd = "$VHDParentPath\$VHDFilename";
			}
		} # Foreach
	} # If
	
	# Read the list of templates from the configuration file
	$Templates = $Configuration.labbuilderconfig.SelectNodes('templates').template
	Foreach ($Template in $Templates) {
		# It can't be template because if the name attrib/node is missing the name property on the XML object defaults to the name
		# Of the parent. So we can't easily tell if no name was specified or if they actually specified 'template' as the name.
		If ($Template.Name -eq 'template') {
			Throw "The Template Name can't be 'template' or empty."
		} # If
		If ($Template.SourceVHD) {
			# A Source VHD file was specified - does it exist?
			If (-not (Test-Path -Path $Templates.SourceVHD)) {
				Throw "The Template Source VHD in Template $($Template.Name) could not be found."
			} # If
		} # If
		
		# Get the Template Default Startup Bytes
		[Int64]$MemortStartupBytes = 0
		If ($Template.MemoryStartupBytes) {
			$MemortStartupBytes = (Invoke-Expression $Template.MemoryStartupBytes)
		} # If

		# Get the Template Default Data VHD Size
		[Int64]$DataVHDSize = 0
		If ($Template.DataVHDSize) {
			$DataVHDSize = (Invoke-Expression $Template.DataVHDSize)
		} # If
				
		# Does the template already exist in the list?
		[Boolean]$Found = $False
		Foreach ($VMTemplate in $VMTemplates) {
			If ($VMTemplate.Name -eq $Template.Name) {
				# The template already exists - so don't add it again, but update the VHD path if provided
				If ($Template.VHD) {
					$VMTemplate.VHD = $Template.VHD
					$VMTemplate.TemplateVHD = "$VHDParentPath\$([System.IO.Path]::GetFileName($Template.VHD))"
				} # If
				# Check that we do end up with a VHD filename in the template
				If (-not $VMTemplate.VHD) {
					Throw "The VHD name in template $($Template.Name) cannot be empty."
				} # If
				$VMTemplate.SourceVHD = $Templates.SourceVHD
				$VMTemplate.InstallISO = $Template.InstallISO
				$VMTemplate.Edition = $Template.Edtion
				$VMTemplate.AllowCreate = $Template.AllowCreate
				# Write any template specific default VM attributes
				If ($MemortStartupBytes) {
					$VMTemplate.MemoryStartupBytes = $MemortStartupBytes
				} # If
				If ($Templates.ProcessorCount) {
					$VMTemplate.ProcessorCount = $Template.ProcessorCount
				} # If
				If ($DataVHDSize) {
					$VMTemplate.DataVHDSize = $DataVHDSize
				} # If
				If ($Templates.AdministratorPassword) {
					$VMTemplate.AdministratorPassword = $Template.AdministratorPassword
				} # If
				If ($Templates.ProductKey) {
					$VMTemplate.ProductKey = $Template.ProductKey
				} # If
				If ($Templates.TimeZone) {
					$VMTemplate.TimeZone = $Template.TimeZone
				} # If

				$Found = $True
				Break
			} # If
		} # Foreach
		If (-not $Found) {
			# Check that we do end up with a VHD filename in the template
			If (-not $Template.VHD) {
				Throw "The VHD name in template $($Template.Name) cannot be empty."
			} # If

			# The template wasn't found in the list of templates so add it
			$VMTemplates += @{
				name = $Template.Name;
				vhd = $Template.VHD;
				sourcevhd = $Template.SourceVHD;
				templatevhd = "$VHDParentPath\$([System.IO.Path]::GetFileName($Template.VHD))";
				installiso = $Template.InstallISO;
				edition = $Template.Edition;
				allowcreate = $Template.AllowCreate;
				memorystartupbytes = $MemoryStartupBytes;
				processorcount = $Template.ProcessorCount;
				datavhdsize = $Template.DataVHDSize;
				administratorpassword = $Template.AdministratorPassword;
				productkey = $Template.ProductKey;
				timezone = $Template.TimeZone;
			}
		} # If
	} # Foreach
	Return $VMTemplates
} # Get-LabVMTemplates
##########################################################################################################################################

##########################################################################################################################################
function Initialize-LabVMTemplates {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration,

		[Parameter(
			Mandatory=$true,
			Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$VMTemplates
	)
	
	Foreach ($VMTemplate in $VMTemplates) {
		If (-not (Test-Path $VMTemplate.TemplateVHD)) {
			# The template VHD isn't in the VHD Parent folder - so copy it there after optimizing it
			If (-not (Test-Path $VMTemplate.SourceVHD)) {
				# The source VHD does not exist - so try and create it from the ISO
				# This feature is not yet supported so will throw an error
				Throw "The template source VHD $($VMTemplate.SourceVHD) could not be found and creating it from an ISO is not yet supported."
			}
			Write-Verbose "Copying template source VHD $($VMTemplate.sourcevhd) to $($VMTemplate.templatevhd) ..."
			Copy-Item -Path $VMTemplate.sourcevhd -Destination $VMTemplate.templatevhd
			Write-Verbose "Optimizing template VHD $($VMTemplate.vhd) ..."
			Set-ItemProperty -Path $VMTemplate.templatevhd -Name IsReadOnly -Value $False
			Optimize-VHD -Path $VMTemplate.templatevhd -Mode Full
			Write-Verbose "Setting template VHD $($VMTemplate.vhd) as readonly ..."
			Set-ItemProperty -Path $VMTemplate.templatevhd -Name IsReadOnly -Value $True
		} Else {
			Write-Verbose "Template VHD file $($VMTemplate.templatevhd) already exists - skipping..."
		}
	}
	Return $True
} # Initialize-LabVMTemplates
##########################################################################################################################################

##########################################################################################################################################
function Remove-LabVMTemplates {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration,

		[Parameter(
			Mandatory=$true,
			Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$VMTemplates
	)
	
	Foreach ($VMTemplate in $VMTemplates) {
		If (Test-Path $VMTemplate.templatevhd) {
			Set-ItemProperty -Path $VMTemplate.vhd -Name IsReadOnly -Value $False
			Write-Verbose "Deleting Template VHD $($VMTemplate.templatevhd) ..."
			Remove-Item -Path $VMTemplate.templatevhd -Confirm:$false -Force
		}
	}
	Return $True
} # Remove-LabVMTemplates
##########################################################################################################################################

##########################################################################################################################################
Configuration ConfigLCM {
	Param (
		[String]$ComputerName,
		[String]$Thumbprint
	)
	Node $ComputerName {
		LocalConfigurationManager {
			ConfigurationMode = 'ApplyAndAutoCorrect'
			CertificateId = $Thumbprint
			RefreshFrequencyMins = 30
			RebootNodeIfNeeded = $True
		} 
	}
}
##########################################################################################################################################

##########################################################################################################################################
function Set-LabDSCMOFFile {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(Mandatory=$true)]
		[XML]$Configuration,

		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM
	)

	[String]$DSCMOFFile = ''
	[String]$DSCMOFMetaFile = ''
	[String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath

	If ($VM.DSCConfigFile) {
		# Make sure all the modules required to create the MOF file are installed
		$InstalledModules = Get-Module -ListAvailable
		Write-Verbose "Identifying Modules used by DSC Config File $($VM.DSCConfigFile) in VM $($VM.Name) ..."
		$DSCModules = Get-ModulesInDSCConfig -DSCConfigFile $($VM.DSCConfigFile)
		Foreach ($ModuleName in $DSCModules) {
			Write-Verbose "Saving Module $ModuleName required by DSC Config File $($VM.DSCConfigFile) in VM $($VM.Name) ..."
			Save-Module -Name $ModuleName -Path "$VMPath\$($VM.Name)\LabBuilder Files\DSC Modules\" -Force
			If (($InstalledModules | Where-Object -Property Name -EQ $ModuleName).Count -eq 0) {
				# The Module isn't available on this computer, so try and install it
				Write-Verbose "Installing Module $ModuleName required by DSC Config File $($VM.DSCConfigFile) in VM $($VM.Name) ..."
				Find-Module -Name $ModuleName | Install-Module -Verbose
			} # If
		} # Foreach

		# Add the VM Self-Signed Certificate to the Local Machine store and get the Thumbprint	
		[String]$CertificateFile = "$VMPath\$($VM.Name)\LabBuilder Files\SelfSigned.cer"
		$Certificate = Import-Certificate -FilePath $CertificateFile -CertStoreLocation "Cert:LocalMachine\My"
		[String]$CertificateThumbprint = $Certificate.Thumbprint

		# Set the predictated MOF File name
		$DSCMOFFile = Join-Path -Path $ENV:Temp -ChildPath "$($VM.ComputerName).mof"
		$DSCMOFMetaFile = ([System.IO.Path]::ChangeExtension($DSCMOFFile,"meta.mof"))
			
		# Generate the LCM MOF File
		Write-Verbose "Creating VM $($VM.Name) DSC LCM MOF File ..."
		ConfigLCM -OutputPath $($ENV:Temp) -ComputerName $($VM.ComputerName) -Thumbprint $CertificateThumbprint | Out-Null
		If (-not (Test-Path -Path $DSCMOFMetaFile)) {
			Throw "A Meta MOF File was not created by the DSC LCM Config for VM $($VM.Name)."
		} # If

		# A DSC Config File was provided so create a MOF File out of it.
		Write-Verbose "Creating VM $($VM.Name) DSC MOF File from DSC Config $($VM.DSCConfigFile) ..."
		
		# Now create the Networking DSC Config file
		[String]$NetworkingDSCConfig = @"
Configuration Networking {
	Import-DscResource -ModuleName xNetworking

"@
		[Int]$AdapterCount = 0
		Foreach ($Adapter in $VM.Adapters) {
			$AdapterCount++
			If ($Adapter.IPv4) {
				If ($Adapter.IPv4.Address) {
$NetworkingDSCConfig += @"
	xIPAddress IPv4_$AdapterCount {
		InterfaceAlias = '$($Adapter.InterfaceAlias)'
		AddressFamily  = 'IPv4'
		IPAddress      = '$($Adapter.IPv4.Address.Replace(",","','"))'
		SubnetMask     = '$($Adapter.IPv4.SubnetMask)'
"@
					If ($Adapter.IPv4.DefaultGateway) {
$NetworkingDSCConfig += @"
		DefaultGateway = '$($Adapter.IPv4.DefaultGateway)'
"@
					}
$NetworkingDSCConfig += @"
			}

"@
				} # If
				If ($Adapter.IPv4.DNSServer) {
$NetworkingDSCConfig += @"
	xDnsServerAddress IPv4D_$AdapterCount {
		InterfaceAlias = '$($Adapter.InterfaceAlias)'
		AddressFamily  = 'IPv4'
		Address        = '$($Adapter.IPv4.DNSServer.Replace(",","','"))'
	}

"@
				} # If
			} # If
# This code is disabled until issue #20 is resolved:
# https://github.com/PowerShell/xNetworking
<#

			If ($Adapter.IPv6) {
				If ($Adapter.IPv6.Address) {
$NetworkingDSCConfig += @"
	xIPAddress IPv6_$AdapterCount {
		InterfaceAlias = '$($Adapter.InterfaceAlias)'
		AddressFamily  = 'IPv6'
		IPAddress      = '$($Adapter.IPv6.Address.Replace(",","','"))'
		SubnetMask     = '$($Adapter.IPv6.SubnetMask)'
"@
					If ($Adapter.IPv6.DefaultGateway) {
$NetworkingDSCConfig += @"
		DefaultGateway = '$($Adapter.IPv6.DefaultGateway)'
"@
					}
$NetworkingDSCConfig += @"
			}

"@
				} # If
				If ($Adapter.IPv6.DNSServer) {
$NetworkingDSCConfig += @"
	xDnsServerAddress IPv6D_$AdapterCount {
		InterfaceAlias = '$($Adapter.InterfaceAlias)'
		AddressFamily  = 'IPv6'
		Address        = '$($Adapter.IPv6.DNSServer.Replace(",","','"))'
	}

"@
				} # If
			} # If
#>
		} # Endfor
$NetworkingDSCConfig += @"
}
"@
		[String]$NetworkingDSCFile = Join-Path -Path "$VMPath\$($VM.Name)\LabBuilder Files" -ChildPath "DSCNetworking.ps1"
		Set-Content -Path $NetworkingDSCFile -Value $NetworkingDSCConfig | Out-Null
		. $NetworkingDSCFile

		[String]$DSCFile = Join-Path -Path "$VMPath\$($VM.Name)\LabBuilder Files" -ChildPath "DSC.ps1"
		[String]$DSCContent = Get-Content -Path $VM.DSCConfigFile -Raw
		
		If (-not ($DSCContent -match "Networking Network {}")) {
			# Add the Networking Configuration item to the base DSC Config File
			# Find the location of the line containing "Node $AllNodes.NodeName {"
			[String]$Regex = '\s*Node\s.*{.*'
			$Matches = [regex]::matches($DSCContent, $Regex, "IgnoreCase")
			If ($Matches.Count -eq 1) {
				$DSCContent = $DSCContent.Insert($Matches[0].Index+$Matches[0].Length,"`r`nNetworking Network {}`r`n")
			} Else {
				Throw "A single Node element cannot be found in the DSC Config File $($VM.DSCCOnfigFile) for VM $($VM.Name)."
			} # If
		} # If
		
		# Save the DSC Content
		Set-Content -Path $DSCFile -Value $DSCContent -Force | Out-Null

		# Hook the Networking DSC File into the main DSC File
		. $DSCFile

		[String]$DSCConfigName = $VM.DSCConfigName
		
		# Generate the Configuration Nodes data that always gets passed to the DSC configuration.
		[String]$ConfigurationData = @"
@{
	AllNodes = @(
		@{
			NodeName = '$($VM.ComputerName)'
			CertificateFile = '$CertificateFile'
            Thumbprint = '$CertificateThumbprint' 
			LocalAdminPassword = '$($VM.administratorpassword)'
			$($VM.DSCParameters)
		}
	)
}
"@
		# Write it to a temp file
		[String]$ConfigurationFile = Join-Path -Path "$VMPath\$($VM.Name)\LabBuilder Files" -ChildPath "DSCConfigData.psd1"
		If (Test-Path -Path $ConfigurationFile) {
			Remove-Item -Path $ConfigurationFile -Force | Out-Null
		}
		Set-Content -Path $ConfigurationFile -Value $ConfigurationData
			
		# Generate the MOF file from the configuration
		& "$DSCConfigName" -OutputPath $($ENV:Temp) -ConfigurationData $ConfigurationFile | Out-Null
		If (-not (Test-Path -Path $DSCMOFFile)) {
			Throw "A MOF File was not created by the DSC Config File $($VM.DSCCOnfigFile) for VM $($VM.Name)."
		} # If

		# Remove the VM Self-Signed Certificate from the Local Machine Store
		Remove-Item -Path "Cert:LocalMachine\My\$CertificateThumbprint" -Force | OUt-Null

		Write-Verbose "DSC MOF File $DSCMOFFile for VM $($VM.Name) was created successfully ..."

		# Copy the files to the LabBuilder Files folder

		Copy-Item -Path $DSCMOFFile -Destination "$VMPath\$($VM.Name)\LabBuilder Files\$($VM.ComputerName).mof" -Force | Out-Null

		If (-not $VM.DSCMOFFile) {
			# Remove Temporary files created by DSC
			Remove-Item -Path $DSCMOFFile -Force | OUt-Null
		}

		If (Test-Path -Path $DSCMOFMetaFile) {
			Copy-Item -Path $DSCMOFMetaFile -Destination "$VMPath\$($VM.Name)\LabBuilder Files\$($VM.ComputerName).meta.mof" -Force | Out-Null
			If (-not $VM.DSCMOFFile) {
				# Remove Temporary files created by DSC
				Remove-Item -Path $DSCMOFMetaFile -Force | OUt-Null
			}
		} # If

		Return $True
	} Else {
		Return $False
	} # If
} # Set-LabDSCMOFFile
##########################################################################################################################################

##########################################################################################################################################
function Set-LabDSCStartFile {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(Mandatory=$true)]
		[XML]$Configuration,

		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM
	)

	[String]$DSCStartPs = ''
	[String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath

	# Start the actual DSC Configuration
	$DSCStartPs += @"
Set-DscLocalConfigurationManager -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" -Verbose  *>> `"$($ENV:SystemRoot)\Setup\Scripts\DSC.log`"
Start-DSCConfiguration -Path `"$($ENV:SystemRoot)\Setup\Scripts\`" -Force -Wait -Verbose  *>> `"$($ENV:SystemRoot)\Setup\Scripts\DSC.log`"

"@
	Set-Content -Path "$VMPath\$($VM.Name)\LabBuilder Files\StartDSC.ps1" -Value $DSCStartPs -Force | Out-Null

	Return $True
} # Set-LabDSCStartFile
##########################################################################################################################################

##########################################################################################################################################
function Initialize-LabVMDSC {
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[XML]$Configuration,

		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM
	)

	# Are there any DSC Settings to manage?
	Set-LabDSCMOFFile -Configuration $Configuration -VM $VM

	# Generate the DSC Start up Script file
	Set-LabDSCStartFile -Configuration $Configuration -VM $VM
} # Initialize-LabVMDSC
##########################################################################################################################################

##########################################################################################################################################
function Start-LabVMDSC {
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[XML]$Configuration,

		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM,

		[Int]$Timeout = 300
	)
	[String]$VMPath = $Configuration.labbuilderconfig.settings.vmpath
	[DateTime]$StartTime = Get-Date
	[System.Management.Automation.Runspaces.PSSession]$Session = $null
	[PSCredential]$AdmininistratorCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $VM.AdministratorPassword -AsPlainText -Force))

	[Boolean]$Complete = $False
	[Boolean]$ConfigCopyComplete = $False
	[Boolean]$ModuleCopyComplete = $False
	
	While ((-not $Complete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
		While (-not ($Session) -or ($Session.State -ne 'Opened')) {
			# Try and connect to the remote VM for up to $Timeout (5 minutes) seconds.
			Try {
				Write-Verbose "Connecting to $($VM.ComputerName) ..."
				$Session = New-PSSession -ComputerName ($VM.ComputerName) -Credential $AdmininistratorCredential -ErrorAction Stop
			} Catch {
				Write-Verbose "Connecting to $($VM.ComputerName) ..."
			}
		} # While

		If (($Session) -and ($Session.State -eq 'Opened') -and (-not $ConfigCopyComplete)) {
			# We are connected OK - upload the MOF files
			While ((-not $ConfigCopyComplete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
				Try {
					Write-Verbose "Copying DSC MOF Files to $($VM.ComputerName) ..."
					Copy-Item -Path "$VMPath\$($VM.Name)\LabBuilder Files\$($VM.ComputerName).mof" -Destination c:\Windows\Setup\Scripts -ToSession $Session -Force -ErrorAction Stop
					If (Test-Path -Path "$VMPath\$($VM.Name)\LabBuilder Files\$($VM.ComputerName).meta.mof") {
						Copy-Item -Path "$VMPath\$($VM.Name)\LabBuilder Files\$($VM.ComputerName).meta.mof" -Destination c:\Windows\Setup\Scripts -ToSession $Session -Force -ErrorAction Stop
					} # If
					Copy-Item -Path "$VMPath\$($VM.Name)\LabBuilder Files\StartDSC.ps1" -Destination c:\Windows\Setup\Scripts -ToSession $Session -Force -ErrorAction Stop
					$ConfigCopyComplete = $True
				} Catch {
					Write-Verbose "Waiting for DSC MOF Files to Copy to $($VM.ComputerName) ..."
					Sleep 5
				} # Try
			} # While
		} # If

		# If the copy didn't complete and we're out of time, exit with a failure.
		If ((-not $ConfigCopyComplete) -and (((Get-Date) - $StartTime).Seconds) -ge $TimeOut) {
			Remove-PSSession -Session $Session
			Return $False
		} # If

		# Now Upload any required modules
		If (($Session) -and ($Session.State -eq 'Opened') -and (-not $ModuleCopyComplete)) {
			$DSCModules = Get-ModulesInDSCConfig -DSCConfigFile $($VM.DSCConfigFile)
			Foreach ($ModuleName in $DSCModules) {
				Try {
					Write-Verbose "Copying DSC Module $ModuleName Files to $($VM.ComputerName) ..."
					Copy-Item -Path "$VMPath\$($VM.Name)\LabBuilder Files\DSC Modules\$ModuleName\" -Destination "$($env:ProgramFiles)\WindowsPowerShell\Modules\" -ToSession $Session -Force -Recurse -ErrorAction Stop | Out-Null
				} Catch {
					Write-Verbose "Waiting for DSC Module $ModuleName Files to Copy to $($VM.ComputerName) ..."
					Sleep 5
				} # Try
			} # Foreach
			$ModuleCopyComplete = $True
		} # If

		If ((-not $ModuleCopyComplete) -and (((Get-Date) - $StartTime).Seconds) -ge $TimeOut) {
			# Timed out
			Remove-PSSession -Session $Session
			Return $False
		}

		# Finally, Start DSC up!
		If (($Session) -and ($Session.State -eq 'Opened') -and ($ConfigCopyComplete) -and ($ModuleCopyComplete)) {
			Write-Verbose "Copying DSC Module $ModuleName Files to $($VM.ComputerName) ..."
			Invoke-Command -Session $Session { c:\windows\setup\scripts\StartDSC.ps1 }
			Remove-PSSession -Session $Session		
			$Complete = $True
		} # If
	} # While

	Return $Complete
} # Start-LabVMDSC
##########################################################################################################################################

##########################################################################################################################################
function Get-LabUnattendFile {
	[CmdLetBinding()]
	[OutputType([String])]
	param (
		[Parameter(Mandatory=$true)]
		[XML]$Configuration,

		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM
	)
	If ($VM.UnattendFile) {
		[String]$UnattendContent = Get-Content -Path $VM.UnattendFile
	} Else {
		[String]$DomainName = $Configuration.labbuilderconfig.settings.domainname
		[String]$Email = $Configuration.labbuilderconfig.settings.email
		$UnattendContent = [String] @"
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
			<ComputerName>$($VM.ComputerName)</ComputerName>
			<ProductKey>$($VM.ProductKey)</ProductKey>
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
				  <Value>$($VM.AdministratorPassword)</Value>
				  <PlainText>true</PlainText>
			   </AdministratorPassword>
			</UserAccounts>
			<RegisteredOrganization>$($DomainName)</RegisteredOrganization>
			<RegisteredOwner>$($Email)</RegisteredOwner>
			<DisableAutoDaylightTimeSet>false</DisableAutoDaylightTimeSet>
			<TimeZone>$($VM.TimeZone)</TimeZone>
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
		}
	Return $UnattendContent
} # Get-LabUnattendFile
##########################################################################################################################################

##########################################################################################################################################
function Set-LabVMInitializationFiles {
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[XML]$Configuration,

		[Parameter(Mandatory=$true)]
		[String]$VMBootDiskPath,

		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM
	)

	# Mount the VMs Boot VHD so that files can be loaded into it
	[String]$MountPoint = Join-Path -Path $ENV:Temp -ChildPath ([System.IO.Path]::GetRandomFileName())
	Write-Verbose "Mounting VM $($VM.Name) Boot Disk VHDx $VMBootDiskPath ..."
	New-Item -Path $MountPoint -ItemType Directory | Out-Null
	Mount-WindowsImage -ImagePath $VMBootDiskPath -Path $MountPoint -Index 1 | Out-Null

	# Copy the WMF 5.0 Installer to the VM in case it is needed
	Write-Verbose "Applying VM $($VM.Name) WMF 5.0 ..."
	# This contains a bug at the moment - waiting for MS to resolve
	# Add-WindowsPackage -PackagePath $Script:WMF5InstallerPath -Path $MountPoint | Out-Null

	# Create the scripts folder where setup scripts will be put
	New-Item -Path "$MountPoint\Windows\Setup\Scripts" -ItemType Directory | Out-Null

	# Generate and apply an unattended setup file
	[String]$UnattendFile = Get-LabUnattendFile -Configuration $Configuration -VM $VM
	Write-Verbose "Applying VM $($VM.Name) Unattend File ..."
	Set-Content -Path "$MountPoint\Windows\Panther\Unattend.xml" -Value $UnattendFile -Force | Out-Null
	Set-Content -Path "$VMPath\$($VM.Name)\LabBuilder Files\Unattend.xml" -Value $UnattendFile -Force | Out-Null
	[String]$SetupCompleteCmd = @"
"@
	[String]$SetupCompletePs = @"
. `"`$(`$ENV:SystemRoot)\Setup\Scripts\New-SelfSignedCertificateEx.ps1`"
New-SelfsignedCertificateEx -Subject 'CN=$($VM.ComputerName)' -EKU 'Server Authentication', 'Client authentication' ``
	-KeyUsage 'KeyEncipherment, DigitalSignature' -SAN '$($VM.ComputerName)' -FriendlyName '$($VM.ComputerName) Self-Signed Certificate' ``
	-Exportable -StoreLocation 'LocalMachine'
`$Cert = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object { `$_.FriendlyName -eq '$($VM.ComputerName) Self-Signed Certificate' }
Export-Certificate -Type CERT -Cert `$Cert -FilePath `"`$(`$ENV:SystemRoot)\SelfSigned.cer`"
Add-Content -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" -Value 'Self-signed certificate created and saved to C:\Windows\SelfSigned.cer ...' -Encoding Ascii
Add-Content -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" -Value 'NuGet Installed ...' -Encoding Ascii
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Add-Content -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" -Value 'Windows Remoting Enabled ...' -Encoding Ascii
"@
	If ($VM.SetupComplete) {
        [String]$SetupComplete = $VM.SetupComplete
        If (-not (Test-Path -Path $SetupComplete)) {
            Throw "SetupComplete Script file $SetupComplete could not be found for VM $($VM.Name)."
        }
		[String]$Extension = [System.IO.Path]::GetExtension($SetupComplete)
		Switch ($Extension.ToLower()) {
			'.ps1' {
				$SetupCompletePs += Get-Content -Path $SetupComplete
				Break
			} # 'ps1'
			'.cmd' {
				$SetupCompleteCmd += Get-Content -Path $SetupComplete
				Break
			} # 'cmd'
		} # Switch
	} # If

	# Write out the CMD Setup Complete File
	Write-Verbose "Applying VM $($VM.Name) Setup Complete CMD File ..."
	$SetupCompleteCmd = @"
@echo SetupComplete.cmd Script Started... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
$SetupCompleteCmd
powerShell.exe -ExecutionPolicy Unrestricted -Command `"%SYSTEMROOT%\Setup\Scripts\SetupComplete.ps1`"
@echo SetupComplete.cmd Script Finished... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
@echo Initial Setup Completed - this file indicates that setup has completed. >> %SYSTEMROOT%\Setup\Scripts\InitialSetupCompleted.txt
"@
	Set-Content -Path "$MountPoint\Windows\Setup\Scripts\SetupComplete.cmd" -Value $SetupCompleteCmd -Force | Out-Null	
	Set-Content -Path "$VMPath\$($VM.Name)\LabBuilder Files\SetupComplete.cmd" -Value $SetupCompleteCmd -Force | Out-Null

	# Write out the PowerShell Setup Complete file
	Write-Verbose "Applying VM $($VM.Name) Setup Complete PowerShell File ..."
	$SetupCompletePs = @"
Add-Content -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" -Value 'SetupComplete.ps1 Script Started...' -Encoding Ascii
$SetupCompletePs
Add-Content -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" -Value 'SetupComplete.ps1 Script Finished...' -Encoding Ascii
"@

	Set-Content -Path "$MountPoint\Windows\Setup\Scripts\SetupComplete.ps1" -Value $SetupCompletePs -Force | Out-Null	
	Set-Content -Path "$VMPath\$($VM.Name)\LabBuilder Files\SetupComplete.ps1" -Value $SetupCompletePs -Force | Out-Null

	Copy-Item -Path $Script:CertGenPS1Path -Destination "$MountPoint\Windows\Setup\Scripts\$($Script:CertGenPS1Filename)" -Force
		
	# Dismount the VHD in preparation for boot
	Write-Verbose "Dismounting VM $($VM.Name) Boot Disk VHDx $VMBootDiskPath ..."
	Dismount-WindowsImage -Path $MountPoint -Save | Out-Null
	Remove-Item -Path $MountPoint -Recurse -Force | Out-Null
} # Set-LabVMInitializationFiles
##########################################################################################################################################

##########################################################################################################################################
function Get-LabVMs {
	[OutputType([System.Collections.Hashtable[]])]
	[CmdLetBinding()]
	param (
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration,

		[Parameter(
			Mandatory=$true,
			Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$VMTemplates,

		[Parameter(
			Mandatory=$true,
			Position=2)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$Switches
	)

	[System.Collections.Hashtable[]]$LabVMs = @()
	[String]$VHDParentPath = $Configuration.labbuilderconfig.settings.vhdparentpath
	$VMs = $Configuration.labbuilderconfig.SelectNodes('vms').vm
	$CurrentSwitches = Get-VMSwitch

	Foreach ($VM in $VMs) {
		If ($VM.Name -eq 'VM') {
			throw "The VM name cannot be 'VM' or empty."
		} # If
		If (-not $VM.Template) {
			throw "The template name in VM $($VM.Name) cannot be empty."
		} # If

		# Find the template that this VM uses and get the VHD Path
		[String]$TemplateVHDPath =''
		[Boolean]$Found = $false
		Foreach ($VMTemplate in $VMTemplates) {
			If ($VMTemplate.Name -eq $VM.Template) {
				$TemplateVHDPath = $VMTemplate.templatevhd
				$Found = $true
				Break
			} # If
		} # Foreach
		If (-not $Found) {
			throw "The template $($VM.Template) specified in VM $($VM.Name) could not be found."
		} # If
		# Check the VHD File path in the template is not empty
		If (-not $TemplateVHDPath) {
			throw "The template VHD path set in template $($VM.Template) cannot be empty."
		} # If

		# Assemble the Network adapters that this VM will use
		[System.Collections.Hashtable[]]$VMAdapters = @()
		[Int]$AdapterCount = 0
		Foreach ($VMAdapter in $VM.Adapters.Adapter) {
			$AdapterCount++
			If ($VMAdapter.Name -eq 'adapter') {
				Throw "The Adapter Name in VM $($VM.Name) cannot be 'adapter' or empty."
			}
			If (-not $VMAdapter.SwitchName) {
				Throw "The Switch Name specified in adapter $($VMAdapter.Name) specified in VM ($VM.Name) cannot be empty."
			}
			# Check the switch is in the switch list
			[Boolean]$Found = $False
			Foreach ($Switch in $Switches) {
				If ($Switch.Name -eq $VMAdapter.SwitchName) {
					# The switch is found in the switch list - record the VLAN (if there is one)
					$Found = $True
					$SwitchVLan = $Switch.Vlan
					Break
				} # If
			} # Foreach
			If (-not $Found) {
				throw "The switch $($VMAdapter.SwitchName) specified in VM ($VM.Name) could not be found in Switches."
			} # If
			
			# Figure out the VLan - If defined in the VM use it, otherwise use the one defined in the Switch, otherwise keep blank.
			[String]$VLan = $VMAdapter.VLan
			If (-not $VLan) {
				$VLan = $SwitchVLan
			} # If

			# Determine the Interface Alias
			[String]$InterfaceAlias = $VMAdapter.InterfaceAlias
			If (-not $InterfaceAlias) {
				If ($AdapterCount -eq 1) {
					$InterfaceAlias = "Ethernet"
				} Else {
					$InterfaceAlias = "Ethernet $AdapterCount"
				}
			} # If

			# Have we got any IPv4 settings?
			[System.Collections.Hashtable]$IPv4 = @{}
			If ($VMAdapter.IPv4) {
				$IPv4 = @{
					Address = $VMAdapter.IPv4.Address;
					defaultgateway = $VMAdapter.IPv4.DefaultGateway;
					subnetmask = $VMAdapter.IPv4.SubnetMask;
					dnsserver = $VMAdapter.IPv4.DNSServer
				}
			}

			# Have we got any IPv6 settings?
			[System.Collections.Hashtable]$IPv6 = @{}
			If ($VMAdapter.IPv6) {
				$IPv6 = @{
					Address = $VMAdapter.IPv6.Address;
					defaultgateway = $VMAdapter.IPv6.DefaultGateway;
					subnetmask = $VMAdapter.IPv6.SubnetMask;
					dnsserver = $VMAdapter.IPv6.DNSServer
				}
			}

			$VMAdapters += @{
				Name = $VMAdapter.Name;
				SwitchName = $VMAdapter.SwitchName;
				MACAddress = $VMAdapter.macaddress;
				VLan = $VLan;
				IPv4 = $IPv4;
				IPv6 = $IPv6;
				InterfaceAlias = $InterfaceAlias
			}
		} # Foreach

		# Does the VM have an Unattend file specified?
		[String]$UnattendFile = ''
		If ($VM.UnattendFile) {
			$UnattendFile = Join-Path -Path $Configuration.labbuilderconfig.settings.fullconfigpath -ChildPath $VM.UnattendFile
			If (-not (Test-Path $UnattendFile)) {
				Throw "The Unattend File $UnattendFile specified in VM $($VM.Name) can not be found."
			} # If
		} # If
		
		# Does the VM specify a Setup Complete Script?
		[String]$SetupComplete = ''
		If ($VM.SetupComplete) {
			$SetupComplete = Join-Path -Path $Configuration.labbuilderconfig.settings.fullconfigpath -ChildPath $VM.SetupComplete
			If (-not (Test-Path $SetupComplete)) {
				Throw "The Setup Complete File $SetupComplete specified in VM $($VM.Name) can not be found."
			} # If
			If ([System.IO.Path]::GetExtension($SetupComplete).ToLower() -notin '.ps1','.cmd' ) {
				Throw "The Setup Complete File $SetupComplete specified in VM $($VM.Name) must be either a PS1 or CMD file."
			} # If
		} # If

		# Load the DSC Config File setting and check it
		[String]$DSCConfigFile = ''
		If ($VM.DSC.ConfigFile) {
			$DSCConfigFile = Join-Path -Path $Configuration.labbuilderconfig.settings.fullconfigpath -ChildPath $VM.DSC.ConfigFile
			If (-not (Test-Path $DSCConfigFile)) {
				Throw "The DSC Config File $DSCConfigFile specified in VM $($VM.Name) can not be found."
			}
			If ([System.IO.Path]::GetExtension($DSCConfigFile).ToLower() -ne '.ps1' ) {
				Throw "The DSC Config File $DSCConfigFile specified in VM $($VM.Name) must be a PS1 file."
			}
			If (-not $VM.DSC.ConfigName) {
				Throw "The DSC Config Name specified in VM $($VM.Name) is empty."
			}
		}
		
		# Load the DSC Parameters
		[String]$DSCParameters = ''
		If ($VM.DSC.Parameters) {
			$DSCParameters = $VM.DSC.Parameters
		} # If

		# Get the Memory Startup Bytes (from the template or VM)
		[Int64]$MemoryStartupBytes = 1GB
		If ($VMTemplate.memorystartupbytes) {
			$MemoryStartupBytes = $VMTemplate.memorystartupbytes
		} # If
		If ($VM.memorystartupbytes) {
			$MemoryStartupBytes = (Invoke-Expression $VM.memorystartupbytes)
		} # If
		
		# Get the Memory Startup Bytes (from the template or VM)
		[Int]$ProcessorCount = 1
		If ($VMTemplate.processorcount) {
			$ProcessorCount = $VMTemplate.processorcount
		} # If
		If ($VM.processorcount) {
			$ProcessorCount = (Invoke-Expression $VM.processorcount)
		} # If

		# Get the data VHD Size (from the template or VM)
		[Int64]$DataVHDSize = 0
		If ($VMTemplate.datavhdsize) {
			$MemoryStartupBytes = $VMTemplate.datavhdsize
		} # If
		If ($VM.DataVHDSize) {
			$MemoryStartupBytes = (Invoke-Expression $VM.DataVHDSize)
		} # If
		
		# Get the Administrator password (from the template or VM)
		[String]$AdministratorPassword = ""
		If ($VMTemplate.administratorpassword) {
			$AdministratorPassword = $VMTemplate.administratorpassword
		} # If
		If ($VM.administratorpassword) {
			$AdministratorPassword = $VM.administratorpassword
		} # If

		# Get the Product Key (from the template or VM)
		[String]$ProductKey = ""
		If ($VMTemplate.productkey) {
			$ProductKey = $VMTemplate.productkey
		} # If
		If ($VM.productkey) {
			$ProductKey = $VM.productkey
		} # If

		# Get the Product Key (from the template or VM)
		[String]$Timezone = "Pacific Standard Time"
		If ($VMTemplate.timezone) {
			$Timezone = $VMTemplate.timezone
		} # If
		If ($VM.timezone) {
			$Timezone = $VM.timezone
		} # If

		$LabVMs += @{
			Name = $VM.name;
			ComputerName = $VM.ComputerName;
			Template = $VM.template;
			TemplateVHD = $TemplateVHDPath;
			UseDifferencingDisk = $VM.usedifferencingbootdisk;
			MemoryStartupBytes = $MemoryStartupBytes;
			ProcessorCount = $ProcessorCount;
			AdministratorPassword = $AdministratorPassword;
			ProductKey = $ProductKey;
			TimeZone =$Timezone;
			Adapters = $VMAdapters;
			DataVHDSize = $DataVHDSize;
			UnattendFile = $UnattendFile;
			SetupComplete = $SetupComplete;
			DSCConfigFile = $DSCConfigFile;
			DSCConfigName = $VM.DSC.ConfigName;
			DSCParameters = $DSCParameters
		}
	} # Foreach        

	Return $LabVMs
} # Get-LabVMs
##########################################################################################################################################

##########################################################################################################################################
function Get-LabVMSelfSignedCert {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(Mandatory=$true)]
		[XML]$Configuration,

		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM,

		[Int]$Timeout = 300
	)
	[String]$VMPath = $Configuration.labbuilderconfig.SelectNodes('settings').vmpath
	[DateTime]$StartTime = Get-Date
	[System.Management.Automation.Runspaces.PSSession]$Session = $null
	[PSCredential]$AdmininistratorCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $VM.AdministratorPassword -AsPlainText -Force))

	[Boolean]$Complete = $False
	While ((-not $Downloaded)  -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
		While (-not ($Session) -or ($Session.State -ne 'Opened')) {
			# Try and connect to the remote VM for up to $Timeout (5 minutes) seconds.
			Try {
				Write-Verbose "Connecting to $($VM.ComputerName) ..."
				$Session = New-PSSession -ComputerName ($VM.ComputerName) -Credential $AdmininistratorCredential -ErrorAction Stop
			} Catch {
				Write-Verbose "Connecting to $($VM.ComputerName) ..."
			} # Try
		} # While

		If (($Session) -and ($Session.State -eq 'Opened') -and (-not $Complete)) {
			# We connected OK - download the Certificate file
			While ((-not $Complete) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
				Try {
					Copy-Item -Path "c:\windows\SelfSigned.cer" -Destination "$VMPath\$($VM.Name)\LabBuilder Files\" -FromSession $Session -ErrorAction Stop
					$Complete = $True
				} Catch {
					Write-Verbose "Waiting for Certificate file on $($VM.ComputerName) ..."
					Sleep 5
				} # Try
			} # While
		} # If

		# Close the Session if it is opened and the download is complete
		If (($Session) -and ($Session.State -eq 'Opened') -and ($Complete)) {
			Remove-PSSession -Session $Session
		} # If
	} # While
	Return $Downloaded

} # Get-LabVMSelfSignedCert
##########################################################################################################################################

##########################################################################################################################################
function Initialize-LabVMs {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration,

		[Parameter(
			Mandatory=$true,
			Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$VMs
	)
	
	$CurrentVMs = Get-VM
	[String]$VMPath = $Configuration.labbuilderconfig.SelectNodes('settings').vmpath

	Foreach ($VM in $VMs) {
		If (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -eq 0) {
			Write-Verbose "Creating VM $($VM.Name) ..."

			# Create the paths for the VM
			If (-not (Test-Path -Path "$VMPath\$($VM.Name)")) {
				New-Item -Path "$VMPath\$($VM.Name)" -ItemType Directory | Out-Null
			}
			If (-not (Test-Path -Path "$VMPath\$($VM.Name)\Virtual Machines")) {
				New-Item -Path "$VMPath\$($VM.Name)\Virtual Machines" -ItemType Directory | Out-Null
			}
			If (-not (Test-Path -Path "$VMPath\$($VM.Name)\Virtual Hard Disks")) {
				New-Item -Path "$VMPath\$($VM.Name)\Virtual Hard Disks" -ItemType Directory | Out-Null
			}
			If (-not (Test-Path -Path "$VMPath\$($VM.Name)\LabBuilder Files")) {
				New-Item -Path "$VMPath\$($VM.Name)\LabBuilder Files" -ItemType Directory | Out-Null
			}
			If (-not (Test-Path -Path "$VMPath\$($VM.Name)\LabBuilder Files\DSC Modules")) {
				New-Item -Path "$VMPath\$($VM.Name)\LabBuilder Files\DSC Modules" -ItemType Directory | Out-Null
			}

			# Create the boot disk
			$VMBootDiskPath = "$VMPath\$($VM.Name)\Virtual Hard Disks\$($VM.Name) Boot Disk.vhdx"
			If (-not (Test-Path -Path $VMBootDiskPath)) {
				If ($VM.UseDifferencingDisk -eq 'Y') {
					Write-Verbose "VM $($VM.Name) differencing boot disk $VMBootDiskPath being created ..."
					New-VHD -Differencing -Path $VMBootDiskPath -ParentPath $VM.TemplateVHD | Out-Null
				} Else {
					Write-Verbose "VM $($VM.Name) boot disk $VMBootDiskPath being created ..."
					Copy-Item -Path $VM.TemplateVHD -Destination $VMBootDiskPath | Out-Null
				}            
				# Because this is a new boot disk assign any required initialization files to it (Unattend.xml etc).
				Set-LabVMInitializationFiles -Configuration $Configuration -VMBootDiskPath $VMBootDiskPath -VM $VM
			} Else {
				Write-Verbose "VM $($VM.Name) boot disk $VMBootDiskPath already exists..."
			} # If
			New-VM -Name $VM.Name -MemoryStartupBytes $VM.MemoryStartupBytes -Generation 2 -Path $VMPath -VHDPath $VMBootDiskPath | Out-Null
			# Just get rid of all network adapters bcause New-VM automatically creates one which we don't need
			Get-VMNetworkAdapter -VMName $VM.Name | Remove-VMNetworkAdapter | Out-Null
		}

		# Set the processor count if different to default and if specified in config file
		If ($VM.ProcessorCount) {
			If ($VM.ProcessorCount -ne (Get-VM -Name $VM.Name).ProcessorCount) {
				Set-VM -Name $VM.Name -ProcessorCount $VM.ProcessorCount
			} # If
		} # If

		# Do we need to add a data disk?
		If ($VM.DataVHDSize -and ($VMs.DataVHDSize -gt 0)) {
			[String]$VMDataDiskPath = "$VMPath\$($VM.Name)\Virtual Hard Disks\$($VM.Name) Data Disk.vhdx"
			# Does the disk already exist?
			If (Test-Path -Path $VMDataDiskPath) {
				Write-Verbose "VM $($VM.Name) data disk $VMDataDiskPath already exists ..."
				# Does the disk need to shrink or grow?
				If ((Get-VHD -Path $VMDataDiskPath).Size -ne $VMs.DataVHDSize) {
					Write-Verbose "VM $($VM.Name) Data Disk $VMDataDiskPath resizing to $($VMs.DataVHDSize) ..."
					Resize-VHD -Path $VMDataDiskPath -SizeBytes $VMs.DataVHDSize | Out-Null
				}
			} Else {
				# Create a new VHD
				Write-Verbose "VM $($VM.Name) data disk $VMDataDiskPath is being created ..."
				New-VHD -Path $VMDataDiskPath -SizeBytes $VM.DataVHDSize -Dynamic | Out-Null
			} # If
			# Does the disk already exist in the VM
			If ((Get-VMHardDiskDrive -VMName $VMs.Name | Where-Object -Property Path -EQ $VMDataDiskPath).Count -EQ 0) {
				Write-Verbose "VM $($VM.Name) data disk $VMDataDiskPath is being added to VM ..."
				Add-VMHardDiskDrive -VMName $VM.Name -Path $VMDataDiskPath -ControllerType SCSI -ControllerLocation 1 -ControllerNumber 0 | Out-Null
			} # If
		} # If
			
		# Create any network adapters
		Foreach ($VMAdapter in $VM.Adapters) {
			If ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $VMAdapter.Name).Count -eq 0) {
				Write-Verbose "VM $($VM.Name) network adapter $($VMAdapter.Name) is being added ..."
				Add-VMNetworkAdapter -VMName $VM.Name -SwitchName $VMAdapter.SwitchName -Name $VMAdapter.Name
			} # If
			$VMNetworkAdapter = Get-VMNetworkAdapter -VMName $VM.Name -Name $VMAdapter.Name
			$Vlan = $VMAdapter.VLan
			If ($VLan) {
				Write-Verbose "VM $($VM.Name) network adapter $($VMAdapter.Name) VLAN is set to $Vlan ..."
				$VMNetworkAdapter | Set-VMNetworkAdapterVlan -Access -VlanId $Vlan | Out-Null
			} Else {
				Write-Verbose "VM $($VM.Name) network adapter $($VMAdapter.Name) VLAN is cleared ..."
				$VMNetworkAdapter | Set-VMNetworkAdapterVlan -Untagged | Out-Null
			} # If
			If ($VMAdapter.MACAddress) {
				$VMNetworkAdapter | Set-VMNetworkAdapter -StaticMacAddress $VMAdapter.MACAddress | Out-Null
			} Else {
				$VMNetworkAdapter | Set-VMNetworkAdapter -DynamicMacAddress | Out-Null
			} # If
			# Enable Device Naming (although the feature is buggy at the moment)
			$VMNetworkAdapter | Set-VMNetworkAdapter -DeviceNaming On | Out-Null
		} # Foreach
		
		# The VM is now ready to be started
		If ((Get-VM -Name $VM.Name).State -eq 'Off') {
			Write-Verbose "VM $($VM.Name) is starting ..."

			Start-VM -VMName $VM.Name
		} # If

		# Has this VM been initialized before (do we have a cer for it)
		If (-not (Test-Path "$VMPath\$($VM.Name)\LabBuilder Files\SelfSigned.cer")) {
			# No, so check it is initialized and download the cert.
			If (Wait-LabVMInit -VM $VM) {
				Write-Verbose "Attempting to download certificate for VM $($VM.Name) ..."
				If (Get-LabVMSelfSignedCert -Configuration $Configuration -VM $VM) {
					Write-Verbose "Certificate for VM $($VM.Name) was downloaded successfully ..."
				} Else {
					Write-Verbose "Certificate for VM $($VM.Name) could not be downloaded ..."
				} # If
			} Else {
				Write-Verbose "Initialization for VM $($VM.Name) did not complete ..."
			} # If
		} # If

		# Create any DSC Files for the VM
		Initialize-LabVMDSC -Configuration $Configuration -VM $VM

		# Attempt to start DSC on the VM
		Start-LabVMDSC -Configuration $Configuration -VM $VM
	} # Foreach
	Return $True
} # Initialize-LabVMs
##########################################################################################################################################

##########################################################################################################################################
function Remove-LabVMs {
	[CmdLetBinding()]
	[OutputType([Boolean])]
	param (
		[Parameter(
			Mandatory=$true,
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[XML]$Configuration,

		[Parameter(
			Mandatory=$true,
			position=1)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$VMs,

		[Switch]$RemoveVHDs
	)
	
	$CurrentVMs = Get-VM
	[String]$VMPath = $Configuration.labbuilderconfig.SelectNodes('settings').vmpath
	
	Foreach ($VM in $VMs) {
		If (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -ne 0) {
			# If the VM is running we need to shut it down.
			If ((Get-VM -Name $VM.Name).State -eq 'Running') {
				Write-Verbose "Stopping VM $($VM.Name) ..."
				Stop-VM -Name $VM.Name
				# Wait for it to completely shut down and report that it is off.
				Wait-LabVMOff -VM $VM | Out-Null
			}
			Write-Verbose "Removing VM $($VM.Name) ..."

			# Should we also delete the VHDs from the VM?
			If ($RemoveVHDs) {
				Write-Verbose "Deleting VM $($VM.Name) hard drive(s) ..."
				Get-VMHardDiskDrive -VMName $VM.Name | Select-Object -Property Path | Remove-Item
			}
			
			# Now delete the actual VM
			Get-VM -Name $VMs.Name | Remove-VM -Confirm:$false

			Write-Verbose "Removed VM $($VM.Name) ..."
		} Else {
			Write-Verbose "VM $($VM.Name) is not in Hyper-V ..."
		}
	}
	Return $true
}
##########################################################################################################################################

##########################################################################################################################################
function Wait-LabVMInit {
	[OutputType([Boolean])]
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM,

		[Int]$Timeout = 300
	)

	[DateTime]$StartTime = Get-Date
	[Boolean]$Found = $False
	[System.Management.Automation.Runspaces.PSSession]$Session = $null
	[PSCredential]$AdmininistratorCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $VM.AdministratorPassword -AsPlainText -Force))

	# Make sure the VM has started
	Wait-LabVMStart -VM $VM

	# Try to connect to it
	While ((-not $Session) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
		# Try and connect to the remote VM for up to $Timeout (5 minutes) seconds.
		Try {
			$Session = New-PSSession -ComputerName ($VM.ComputerName) -Credential $AdmininistratorCredential -ErrorAction Stop
		} Catch {
			Write-Verbose "Trying to connect to $($VM.ComputerName) ..."
		}
	} # While

	If ($Session) {
		# We connected OK - check for init file
		While ((-not $Found) -and (((Get-Date) - $StartTime).Seconds) -lt $TimeOut) {
			Try {
				
				$Found = Invoke-Command -Session $Session {Test-Path "$($ENV:SystemRoot)\Setup\Scripts\InitialSetupCompleted.txt" } -ErrorAction Stop
			} Catch {
				Write-Verbose "Waiting for Initial Setup Complete file on $($VM.ComputerName) ..."
				Sleep 5
			}
		}
		Remove-PSSession -Session $Session
	}
	Return $Found
} # Wait-LabVMInit
##########################################################################################################################################

##########################################################################################################################################
function Wait-LabVMStart {
	[OutputType([Boolean])]
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM
	)
	$Heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name Heartbeat
	while ($Heartbeat.PrimaryStatusDescription -ne "OK")
	{
		$Heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name Heartbeat
		sleep 1
	} # while

	Return $True
} # Wait-LabVMStart
##########################################################################################################################################

##########################################################################################################################################
function Wait-LabVMOff {
	[OutputType([Boolean])]
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM
	)
	$RunningVM = Get-VM -Name $VM.Name
	while ($RunningVM.State -ne "Off")
	{
		$RunningVM = Get-VM -Name $VM.Name
		sleep 1
	} # while

	Return $True
} # Wait-LabVMOff
##########################################################################################################################################

##########################################################################################################################################
Function Install-Lab {
	[CmdLetBinding()]
	param (
		[parameter(
			Mandatory=$true)]
		[String]$Path,

		[Switch]$CheckEnvironment
	) # Param

	[XML]$Config = Get-LabConfiguration -Path $Path
	# Make sure everything is OK to install the lab
	If (-not (Test-LabConfiguration -Configuration $Config)) {
		return
	}
	   
	If ($CheckEnvironment) {
		Install-LabHyperV | Out-Null
	}
	Initialize-LabHyperV -Configuration $Config | Out-Null

	Initialize-LabDSC -Configuration $Config | Out-Null

	$Switches = Get-LabSwitches -Configuration $Config
	Initialize-LabSwitches -Configuration $Config -Switches $Switches | Out-Null

	$VMTemplates = Get-LabVMTemplates -Configuration $Config
	Initialize-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates | Out-Null

	$VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
	Initialize-LabVMs -Configuration $Config -VMs $VMs | Out-Null
} # Build-Lab
##########################################################################################################################################

##########################################################################################################################################
Function Uninstall-Lab {
	[CmdLetBinding()]
	param (
		[parameter(
			Mandatory=$true)]
		[String]$Path,

		[Switch]$RemoveSwitches,

		[Switch]$RemoveTemplates,

		[Switch]$RemoveVHDs
	) # Param

	[XML]$Config = Get-LabConfiguration -Path $Path

	# Make sure everything is OK to install the lab
	If (-not (Test-LabConfiguration -Configuration $Config)) {
		return
	} # If

	$VMTemplates = Get-LabVMTemplates -Configuration $Config

	$Switches = Get-LabSwitches -Configuration $Config

	$VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
	If ($RemoveVHDs) {
		Remove-LabVMs -Configuration $Config -VMs $VMs -RemoveVHDs | Out-Null
	} Else {
		Remove-LabVMs -Configuration $Config -VMs $VMs | Out-Null
	} # If

	If ($RemoveTemplates) {
		Remove-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates | Out-Null
	} # If

	If ($RemoveSwitches) {
		Remove-LabSwitches -Configuration $Config -Switches $Switches | Out-Null
	} # If
} # Uninstall-Lab
##########################################################################################################################################

##########################################################################################################################################
# Export the Module Cmdlets
Export-ModuleMember -Function `
	Get-LabConfiguration,Test-LabConfiguration, `
	Install-LabHyperV,Initialize-LabHyperV,Initialize-LabDSC, `
	Get-LabSwitches,Initialize-LabSwitches,Remove-LabSwitches, `
	Get-LabVMTemplates,Initialize-LabVMTemplates,Remove-LabVMTemplates, `
	Get-LabVMs,Initialize-LabVMs,Remove-LabVMs, `
	Set-LabDSCMOFFile,Set-LabDSCStartFile,Initialize-LabVMDSC, `
	Get-LabUnattendFile, Set-LabVMInitializationFiles, `
	Wait-LabVMStart, Wait-LabVMOff, Wait-LabVMInit, `
	Get-LabVMSelfSignedCert, `
	Install-Lab,Uninstall-Lab
##########################################################################################################################################
