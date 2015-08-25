#Requires -version 5.0

##########################################################################################################################################
# Helper functions that aren't exposed
##########################################################################################################################################
Function IsElevated {
	[System.Security.Principal.WindowsPrincipal]$SecurityPrincipal = new-object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
	Return $SecurityPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
##########################################################################################################################################

##########################################################################################################################################
# Main CmdLets
##########################################################################################################################################
function Get-LabConfiguration {
	[CmdLetBinding(DefaultParameterSetName="Path")]
	[OutputType([XML])]
	param (
		[parameter(
			Mandatory=$True,
			ParameterSetName="Path",
			Position=0)]
		[ValidateNotNullOrEmpty()]
		[String]$Path,

		[parameter(
			Mandatory=$True,
			ParameterSetName="Content")]
		[ValidateNotNullOrEmpty()]
		[String]$Content
	) # Param
	If ($Path) {
		# The Path parameter was provided...
		If (-not (Test-Path -Path $Path)) {
			Throw "Configuration file $Path is not found."
		} # If
		$Content = Get-Content -Path $Path -Raw
	} # If
	If (-not $Content) {
		Throw "Configuration is empty."
	} # If
	[XML]$Configuration = New-Object -TypeName XML
	$Configuration.LoadXML($Content)
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

	# Check folders exist
	[String]$VMPath = $Configuration.labbuilderconfig.SelectNodes('settings').vmpath
	If (-not $VMPath) {
		Throw "<settings>\<vmpath> is missing or empty in the configuration."
	}

	If (-not (Test-Path -Path $VMPath)) {
		Throw "The VM Path $VMPath is not found."
	}

	[String]$VHDParentPath = $Configuration.labbuilderconfig.SelectNodes('settings').vhdparentpath
	If (-not $VHDParentPath) {
		Throw "<settings>\<vhdparentpath> is missing or empty in the configuration."
	}

	If (-not (Test-Path -Path $VHDParentPath)) {
		Throw "The VHD Parent Path $VHDParentPath is not found."
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

	Set-VMHost -MacAddressMinimum $MacAddressMinimum -MacAddressMaximum $MacAddressMaximum

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
					New-VMSwitch -Name $SwitchName -NetAdapterName (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 -ExpandProperty Name)
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
					New-VMSwitch -Name $SwitchName -SwitchType Private
					Break
				} # 'Private'
				'Internal' {
					New-VMSwitch -Name $SwitchName -SwitchType Internal
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
		}
		If (-not $Template.VHD) {
			Throw "The Template VHD name in Template $($Template.Name) can't be empty."
		}
		If ($Template.SourceVHD) {
			# A Source VHD file was specified - does it exist?
			If (-not (Test-Path -Path $Templates.SourceVHD)) {
				Throw "The Template Source VHD in Template $($Template.Name) could not be found."
			}
		}
		# Does the template already exist in the list?
		[Boolean]$Found = $False
		Foreach ($VMTemplate in $VMTemplates) {
			If ($VMTemplate.Name -eq $Template.Name) {
				# The template already exists - so don't add it again, but update the VHD path if provided
				If ($Template.VHD) {
					If (-not $Template.VHD) {
						Throw "The VHD file in template $($Template.Name) cannot be empty."
					}
					$VMTemplate.VHD = $Template.VHD
					$VMTemplate.TemplateVHD = "$VHDParentPath\$([System.IO.Path]::GetFileName($Template.VHD))"
				}
				$VMTemplate.SourceVHD = $Templates.SourceVHD
				$VMTemplate.InstallISO = $Template.InstallISO
				$VMTemplate.Edition = $Template.Edtion
				$VMTemplate.AllowCreate = $Template.AllowCreate
				$Found = $True
				Break
			} # If
		} # Foreach
		If (-not $Found) {
			# The template wasn't found in the list of templates so add it
			$VMTemplates += @{
				name = $Template.Name;
				vhd = $Template.VHD;
				sourcevhd = $Template.SourceVHD;
				templatevhd = "$VHDParentPath\$([System.IO.Path]::GetFileName($Template.VHD))";
				installiso = $Template.InstallISO;
				edition = $Template.Edition;
				allowcreate = $Template.AllowCreate;
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
	[String]$VHDParentPath = $Configuration.labbuilderconfig.SelectNodes('settings').vhdparentpath
	$VMs = $Configuration.labbuilderconfig.SelectNodes('vms').vm
	[Microsoft.HyperV.PowerShell.VMSwitch[]]$CurrentSwitches = Get-VMSwitch

	Foreach ($VM in $VMs) {
		If ($VM.Name -eq 'VM')
		{
			throw "The VM name cannot be 'VM' or empty."
		}
		If (-not $VM.Template)
		{
			throw "The template name in VM $($VM.Name) cannot be empty."
		}

		# Find the template that this VM uses and get the VHD Path
		[String]$TemplateVHDPath =''
		[Boolean]$Found = $false
		Foreach ($VMTemplate in $VMTemplates) {
			If ($VMTemplate.Name -eq $VM.Template) {
				$TemplateVHDPath = $VMTemplate.templatevhd
				$Found = $true
				Break
			}
		}
		If (-not $Found)
		{
			throw "The template $($VM.Template) specified in VM $($VM.Name) could not be found."
		}
		# Check the VHD File path in the template is not empty
		If (-not $TemplateVHDPath)
		{
			throw "The template VHD path set in template $($VM.Template) cannot be empty."
		}

		# Assemble the Network adapters that this VM will use
		[System.Collections.Hashtable[]]$VMAdapters = @()
		Foreach ($VMAdapter in $VM.Adapters.Adapter) {
			If (-not $VMAdapter.Name) {
				Throw "The Adapter Name in VM $($VM.Name) cannot be empty."
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
			$VLan = $VMAdapter.VLan
			If (-not $VLan) {
				$VLan = $SwitchVLan
			}
			$VMAdapters += @{ Name = $VMAdapter.Name; SwitchName = $VMAdapter.SwitchName; MACAddress = $VMAdapter.macaddress; VLan = $VLan }
		}

		[String]$UnattendFile = $VM.UnattendFile
		If (($UnattendFile) -and -not (Test-Path $UnattendFile)) {
			Throw "The Unattend File $UnattendFile specified in VM ($VM.Name) can not be found."
		}
		$LabVMs += @{
			Name = $VM.name;
			Template = $VM.template;
			TemplateVHD = $TemplateVHDPath;
			UseDifferencingDisk = $VM.usedifferencingbootdisk;
			MemoryStartupBytes = (Invoke-Expression $VM.memorystartupbytes);
			ProcessorCount = $VM.processorcount;
			AdministratorPassword = $VM.administratorpassword;
			ProductKey = $VM.productkey;
			TimeZone = $VM.timezone;
			Adapters = $VMAdapters;
			DataVHDSize = (Invoke-Expression $VM.DataVHDSize);
			UnattendFile = $UnattendFile;
		}
	} # Foreach        

	Return $LabVMs
} # Get-LabVMs
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
			If ($VM.ProcessorCount -ne (Get-VM -Name $VMs.Name).ProcessorCount) {
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
			$Vlan = $VMAdapter.VLan
			If ($VLan) {
				Write-Verbose "VM $($VM.Name) network adapter $($VMAdapter.Name) VLAN is set to $Vlan ..."
				Get-VMNetworkAdapter -VMName $VM.Name -Name $VMAdapter.Name | Set-VMNetworkAdapterVlan -Access -VlanId $Vlan | Out-Null
			} Else {
				Write-Verbose "VM $($VM.Name) network adapter $($VMAdapter.Name) VLAN is cleared ..."
				Get-VMNetworkAdapter -VMName $VM.Name -Name $VMAdapter.Name | Set-VMNetworkAdapterVlan -Untagged | Out-Null
			} # If
			If ($VMAdapter.MACAddress) {
				Get-VMNetworkAdapter -VMName $VM.Name -Name $VMAdapter.Name | Set-VMNetworkAdapter -StaticMacAddress $VMAdapter.MACAddress | Out-Null
			} Else {
				Get-VMNetworkAdapter -VMName $VM.Name -Name $VMAdapter.Name | Set-VMNetworkAdapter -DynamicMacAddress | Out-Null
			} # If
		} # Foreach
		
		# The VM is now ready to be started
		If ((Get-VM -Name $VMs.Name).State -eq 'Off') {
			Write-Verbose "VM $($VM.Name) is starting ..."
			$StartTime = Get-Date

			Start-VM -VMName $VM.Name
			# Wait for the VM to become ready so any post build configuration (e.g. DSC) can be applied.
			
			Wait-LabVMStart -VM $VM | Out-Null

			$EndTime = Get-Date
			Write-Verbose "VM $($VM.Name) started in $(($EndTime - $StartTime).Seconds) seconds ..."

			# Even though the VM has started it might still be in the process installing (after a sysprep).
			# So will need to wait for this process to complete
		} # If

		# Now it is time to assign any post initialize scripts/DSC etc.
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
	[String]$DomainName = $Configuration.labbuilderconfig.SelectNodes('settings').domainname
	[String]$Email = $Configuration.labbuilderconfig.SelectNodes('settings').email
	# Has a custom unattend file been specified for this VM?
	If ($VM.UnattendFile) {
		[String]$UnattendContent = Get-Content -Path $VM.UnattendFile
	} Else {
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
	Write-Verbose "Applying VM $($VM.Name) Unattend File ..."

	# Mount the VMs Boot VHD so that files can be loaded into it
	[String]$MountPount = "C:\TempMount"
	New-Item -Path $MountPount -ItemType Directory | Out-Null
	Mount-WindowsImage -ImagePath $VMBootDiskPath -Path $MountPount -Index 1 | Out-Null

	# Apply any files that are needed
	Set-Content -Path "$MountPount\Windows\Panther\UnattendFile.xml" -Value $UnattendContent | Out-Null
	
	# Dismount the VHD in preparation for boot
	Dismount-WindowsImage -Path $MountPount -Save | Out-Null
	Remove-Item -Path $MountPount | Out-Null
	Remove-Item -Path $UnattendFile | Out-Null
} # Set-LabVMInitializationFiles
##########################################################################################################################################

##########################################################################################################################################
function Set-LabVMInitalDSCPushMode {
	[CmdLetBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[XML]$Configuration,

		[Parameter(Mandatory=$true)]
		[String]$VMBootDiskPath,

		[Parameter(Mandatory=$true)]
		[System.Collections.Hashtable]$VM
	)
	Write-Verbose "Starting VM $($VM.Name) DSC Push Mode ..."
	[String]$UnattendFile = $ENV:Temp+"\Unattend.xml"
	[String]$MountPount = "C:\TempMount"
	Set-Content -Path $UnattendFile -Value $UnattendContent | Out-Null
	New-Item -Path $MountPount -ItemType Directory | Out-Null
	Mount-WindowsImage -ImagePath $VMBootDiskPath -Path $MountPount -Index 1 | Out-Null
	Copy-Item -Path $UnattendFile -Destination c:\tempMount\Windows\Panther\ -Force | Out-Null
	Dismount-WindowsImage -Path $MountPount -Save | Out-Null
	Remove-Item -Path $MountPount | Out-Null
	Remove-Item -Path $UnattendFile | Out-Null
} # Set-LabVMUnattendFile
##########################################################################################################################################

##########################################################################################################################################
Function Install-Lab {
	[CmdLetBinding(DefaultParameterSetName="Path")]
	param (
		[parameter(Mandatory=$true, ParameterSetName="Path")]
		[String]$Path,

		[parameter(Mandatory=$true, ParameterSetName="Content")]
		[String]$Content,

		[Switch]$CheckEnvironment
	) # Param

	If ($Path) {
		[XML]$Config = Get-LabConfiguration -Path $Path
	} Else {
		[XML]$Config = Get-LabConfiguration -Content $Content
	}
	# Make sure everything is OK to install the lab
	If (-not (Test-LabConfiguration -Configuration $Config)) {
		return
	}
	   
	If ($CheckEnvironment) {
		Install-LabHyperV
	}
	Initialize-LabHyperV -Configuration $Config

	Initialize-LabDSC -Configuration $Config

	$Switches = Get-LabSwitches -Configuration $Config
	Initialize-LabSwitches -Configuration $Config -Switches $Switches

	$VMTemplates = Get-LabVMTemplates -Configuration $Config
	Initialize-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates

	$VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
	Initialize-LabVMs -Configuration $Config -VMs $VMs
} # Build-Lab
##########################################################################################################################################

##########################################################################################################################################
Function Uninstall-Lab {
	[CmdLetBinding(DefaultParameterSetName="Path")]
	param (
		[parameter(Mandatory=$true, ParameterSetName="Path")]
		[String]$Path,

		[parameter(Mandatory=$true, ParameterSetName="Content")]
		[String]$Content,

		[Switch]$RemoveSwitches,

		[Switch]$RemoveTemplates,

		[Switch]$RemoveVHDs
	) # Param

	If ($Path) {
		[XML]$Config = Get-LabConfiguration -Path $Path
	} Else {
		[XML]$Config = Get-LabConfiguration -Content $Content
	}
	# Make sure everything is OK to install the lab
	If (-not (Test-LabConfiguration -Configuration $Config)) {
		return
	} # If

	$VMTemplates = Get-LabVMTemplates -Configuration $Config

	$Switches = Get-LabSwitches -Configuration $Config

	$VMs = Get-LabVMs -Configuration $Config -VMTemplates $VMTemplates -Switches $Switches
	If ($RemoveVHDs) {
		Remove-LabVMs -Configuration $Config -VMs $VMs -RemoveVHDs
	} Else {
		Remove-LabVMs -Configuration $Config -VMs $VMs
	} # If

	If ($RemoveTemplates) {
		Remove-LabVMTemplates -Configuration $Config -VMTemplates $VMTemplates
	} # If

	If ($RemoveSwitches) {
		Remove-LabSwitches -Configuration $Config -Switches $Switches
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
	Wait-LabVMStart, Wait-LabVMOff, `
	Set-LabVMInitializationFiles, Set-LabVMInitalDSCPushMode, `
	Install-Lab,Uninstall-Lab
##########################################################################################################################################
