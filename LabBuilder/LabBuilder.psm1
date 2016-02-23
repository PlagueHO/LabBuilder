#Requires -version 5.0
#Requires -RunAsAdministrator

$moduleRoot = Split-Path `
    -Path $MyInvocation.MyCommand.Path `
    -Parent

#region LocalizedData
$Culture = 'en-us'
if (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath $PSUICulture))
{
    $Culture = $PSUICulture
}
Import-LocalizedData `
    -BindingVariable LocalizedData `
    -Filename LabBuilder_LocalizedData.psd1 `
    -BaseDirectory $moduleRoot `
    -UICulture $Culture
#endregion


#region ImportFunctions
# Dot source any functions in the libs folder
$Libs = Get-ChildItem `
    -Path (Join-Path -Path $moduleRoot -ChildPath 'lib') `
    -Include '*.ps1' `
    -Recurse
$Libs.Foreach(
    {
        Write-Verbose -Message ($LocalizedData.ImportingLibFileMessage `
            -f $_.Fullname)
        . $_.Fullname    
    }
)
#endregion


#region ModuleVariables
[String] $Script:WorkingFolder = $ENV:Temp

# Supporting files
[String] $Script:SupportConvertWindowsImagePath = Join-Path -Path $PSScriptRoot -ChildPath 'Support\Convert-WindowsImage.ps1'
[String] $Script:SupportGertGenPath = Join-Path -Path $PSScriptRoot -ChildPath 'Support\New-SelfSignedCertificateEx.ps1'

# Virtual Networking Parameters
[Int] $Script:DefaultManagementVLan = 99

# Self-signed Certificate Parameters
[Int] $Script:SelfSignedCertKeyLength = 2048
# Warning - using KSP causes the Private Key to not be accessible to PS.
[String] $Script:SelfSignedCertProviderName = 'Microsoft Enhanced Cryptographic Provider v1.0' # 'Microsoft Software Key Storage Provider'
[String] $Script:SelfSignedCertAlgorithmName = 'RSA' # 'ECDH_P256' Or 'ECDH_P384' Or 'ECDH_P521'
[String] $Script:SelfSignedCertSignatureAlgorithm = 'SHA256' # 'SHA1'
[String] $Script:DSCEncryptionCert = 'DSCEncryption.cer'
[String] $Script:DSCEncryptionPfxCert = 'DSCEncryption.pfx'
[String] $Script:DSCCertificateFriendlyName = 'DSC Credential Encryption'
[String] $Script:DSCCertificatePassword = 'E3jdNkd903mDn43NEk2nbDENjw'
[Int] $Script:RetryConnectSeconds = 5
[Int] $Script:RetryHeartbeatSeconds = 1

# The current list of Nano Servers available with TP4.
[Array] $Script:NanoServerPackageList = @(
    @{ Name = 'Compute'; Filename = 'Microsoft-NanoServer-Compute-Package.cab' },
    @{ Name = 'OEM-Drivers'; Filename = 'Microsoft-NanoServer-OEM-Drivers-Package.cab' },
    @{ Name = 'Storage'; Filename = 'Microsoft-NanoServer-Storage-Package.cab' },
    @{ Name = 'FailoverCluster'; Filename = 'Microsoft-NanoServer-FailoverCluster-Package.cab' },
    @{ Name = 'ReverseForwarders'; Filename = 'Microsoft-OneCore-ReverseForwarders-Package.cab' },
    @{ Name = 'Guest'; Filename = 'Microsoft-NanoServer-Guest-Package.cab' },
    @{ Name = 'Containers'; Filename = 'Microsoft-NanoServer-Containers-Package.cab' },
    @{ Name = 'Defender'; Filename = 'Microsoft-NanoServer-Defender-Package.cab' },
    @{ Name = 'DCB'; Filename = 'Microsoft-NanoServer-DCB-Package.cab' },
    @{ Name = 'DNS'; Filename = 'Microsoft-NanoServer-DNS-Package.cab' },
    @{ Name = 'DSC'; Filename = 'Microsoft-NanoServer-DSC-Package.cab' },
    @{ Name = 'IIS'; Filename = 'Microsoft-NanoServer-IIS-Package.cab' },
    @{ Name = 'NPDS'; Filename = 'Microsoft-NanoServer-NPDS-Package.cab' },
    @{ Name = 'SCVMM'; Filename = 'Microsoft-Windows-Server-SCVMM-Package.cab' },
    @{ Name = 'SCVMM-Compute'; Filename = 'Microsoft-Windows-Server-SCVMM-Compute-Package.cab' }
)
#endregion


#region LabConfigurationFunctions
<#
.SYNOPSIS
    Loads a Lab Builder Configuration file and returns a Configuration object
.PARAMETER Path
    This is the path to the Lab Builder configuration file to load.
.EXAMPLE
    $MyLab = Get-LabConfiguration -Path c:\MyLab\LabConfig1.xml
    Loads the LabConfig1.xml configuration into variable MyLab
.OUTPUTS
    XML Object containing the Lab Configuration that was loaded.
#>
function Get-LabConfiguration {
    [CmdLetBinding()]
    [OutputType([XML])]
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Path
    ) # Param
    if (-not (Test-Path -Path $Path))
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationFileNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileNotFoundError `
                -f $Path)
        }
        ThrowException @ExceptionParameters
    } # If
    $Content = Get-Content -Path $Path -Raw
    if (-not $Content)
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationFileEmptyError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileEmptyError `
                -f $Path)
        }
        ThrowException @ExceptionParameters
    } # If
    [XML] $Config = New-Object System.Xml.XmlDocument
    $Config.PreserveWhitespace = $true
    $Config.LoadXML($Content)
    
    # Figure out the Config path and load it into the XML object (if we can)
    # This path is used to find any additional configuration files that might
    # be provided with config
    [String] $ConfigPath = [System.IO.Path]::GetDirectoryName($Path)
    [String] $XMLConfigPath = $Config.labbuilderconfig.settings.configpath
    if ($XMLConfigPath) {
        if (! [System.IO.Path]::IsPathRooted($XMLConfigurationPath))
        {
            # A relative path was provided in the config path so add the actual path of the
            # XML to it
            [String] $FullConfigPath = Join-Path -Path $ConfigPath -ChildPath $XMLConfigPath
        } # If
    }
    else
    {
        [String] $FullConfigPath = $ConfigPath
    }
    $Config.labbuilderconfig.settings.setattribute('fullconfigpath',$FullConfigPath)

    # Check the LabPath because we need to use it.
    [String] $LabPath = $Config.labbuilderconfig.settings.labpath
    if (-not $LabPath)
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationMissingElementError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationMissingElementError `
                -f '<settings>\<labpath>')
        }
        ThrowException @ExceptionParameters
    }

    # Get the VHDParentPath - if it isn't supplied default
    [String] $VHDParentPath = $Config.labbuilderconfig.settings.vhdparentpath
    if (-not $VHDParentPath)
    {
        $VHDParentPath = 'Virtual Hard Disk Templates'
    }
    # if the resulting parent path is not rooted make the root
    # the Full config path
    if (-not ([System.IO.Path]::IsPathRooted($VHDParentPath)))
    {
        $VHDParentPath = Join-Path `
            -Path $LabPath `
            -ChildPath $VHDParentPath        
    }    
    $Config.labbuilderconfig.settings.setattribute('vhdparentpath',$VHDParentPath)

    if ((-not $Config.labbuilderconfig) `
        -or (-not $Config.labbuilderconfig.settings))
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationInvalidError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationInvalidError)
        }
        ThrowException @ExceptionParameters
    }
    
    Return $Config
} # Get-LabConfiguration


<#
.SYNOPSIS
   Initializes the system from information provided in the Lab Configuration object provided.
.DESCRIPTION
   This function should be run after loading a Lab Configuration file. It will ensure any required
   modules and files are downloaded and also that the Hyper-V system on this machine is configured
   with any required settings (MAC Addresses range) provided in the configuration object.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Initialize-LabConfiguration -Config $Config
   Loads a Lab Builder configuration and applies the base system settings.
.OUTPUTS
   None.
#>
function Initialize-LabConfiguration {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config
    )
    
    # Check Lab Folder structure
    Write-Verbose -Message ($LocalizedData.InitializingLabFoldersMesage)

    # Check folders are defined
    [String] $LabPath = $Config.labbuilderconfig.settings.labpath
    if (-not (Test-Path -Path $LabPath))
    {
        Write-Verbose -Message ($LocalizedData.CreatingLabFolderMessage `
            -f 'LabPath',$LabPath)

        $null = New-Item `
            -Path $LabPath `
            -Type Directory
    }

    [String] $VHDParentPath = $Config.labbuilderconfig.settings.vhdparentpath
    if (-not (Test-Path -Path $VHDParentPath))
    {
        Write-Verbose -Message ($LocalizedData.CreatingLabFolderMessage `
            -f 'VHDParentPath',$VHDParentPath)

        $null = New-Item `
            -Path $VHDParentPath `
            -Type Directory
    }
    
    # Install Hyper-V Components
    Write-Verbose -Message ($LocalizedData.InitializingHyperVComponentsMesage)

    # Create the LabBuilder Management Network switch and assign VLAN
    # Used by host to communicate with Lab VMs
    [String] $ManagementSwitchName = ('LabBuilder Management {0}' `
        -f $Config.labbuilderconfig.name)
    if ($Config.labbuilderconfig.switches.ManagementVlan)
    {
        [Int32] $ManagementVlan = $Config.labbuilderconfig.switches.ManagementVlan
    }
    else
    {
        [Int32] $ManagementVlan = $Script:DefaultManagementVLan
    }
    if ((Get-VMSwitch | Where-Object -Property Name -eq $ManagementSwitchName).Count -eq 0)
    {
        $null = New-VMSwitch -Name $ManagementSwitchName -SwitchType Internal

        Write-Verbose -Message ($LocalizedData.CreatingLabManagementSwitchMessage `
            -f $ManagementSwitchName,$ManagementVlan)
    }
    # Check the Vlan ID of the adapter on the switch
    $ExistingManagementAdapter = Get-VMNetworkAdapter `
		-ManagementOS `
		-Name $ManagementSwitchName
    $ExistingVlan = (Get-VMNetworkAdapterVlan `
		-VMNetworkAdaptername $ExistingManagementAdapter.Name `
		-ManagementOS).AccessVlanId

    if ($ExistingVlan -ne $ManagementVlan)
    {
        Write-Verbose -Message ($LocalizedData.UpdatingLabManagementSwitchMessage `
            -f $ManagementSwitchName,$ManagementVlan)

        Set-VMNetworkAdapterVlan `
            -VMNetworkAdapterName $ManagementSwitchName `
            -ManagementOS `
            -Access `
            -VlanId $ManagementVlan
    }
    # Download any other resources required by this lab
    DownloadResources -Config $Config	

} # Initialize-LabConfiguration
#endregion


#region LabSwitchFunctions
<#
.SYNOPSIS
   Gets an array of switches from a Lab Configuration file.
.DESCRIPTION
   Takes a provided Lab Configuration file and returns the list of switches required for this Lab.
   This list is usually passed to Initialize-LabSwitch to configure the swtiches required for this
   lab.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabSwitch -Config $Config
   Loads a Lab Builder configuration and pulls the array of switches from it.
.OUTPUTS
   Returns an array of switches.
#>
function Get-LabSwitch {
    [OutputType([Array])]
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config
    )

    [Array] $Switches = @() 
    $ConfigSwitches = $Config.labbuilderconfig.SelectNodes('switches').Switch
    foreach ($ConfigSwitch in $ConfigSwitches)
    {
        # It can't be switch because if the name attrib/node is missing the name property on the
        # XML object defaults to the name of the parent. So we can't easily tell if no name was
        # specified or if they actually specified 'switch' as the name.
        if ($ConfigSwitch.Name -eq 'switch')
        {
            $ExceptionParameters = @{
                errorId = 'SwitchNameIsEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
            }
            ThrowException @ExceptionParameters
        }
        if ($ConfigSwitch.Type -notin 'Private','Internal','External','NAT')
        {
            $ExceptionParameters = @{
                errorId = 'UnknownSwitchTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                    -f $ConfigSwitch.Type,$ConfigSwitch.Name)
            }
            ThrowException @ExceptionParameters
        }
        # Assemble the list of Adapters if any are specified for this switch (only if an external
        # switch)
        if ($ConfigSwitch.Adapters)
        {
            [System.Collections.Hashtable[]] $ConfigAdapters = @()
            foreach ($Adapter in $ConfigSwitch.Adapters.Adapter)
            {
                $ConfigAdapters += @{ name = $Adapter.Name; macaddress = $Adapter.MacAddress }
            }
            if (($ConfigAdapters.Count -gt 0) -and ($ConfigSwitch.Type -ne 'External'))
            {
                $ExceptionParameters = @{
                    errorId = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.AdapterSpecifiedError `
                        -f $ConfigSwitch.Type,$ConfigSwitch.Name)
                }
                ThrowException @ExceptionParameters
            }
        }
        Else
        {
            $ConfigAdapters = $null
        }
        $Switches += [PSObject]@{
            name = $ConfigSwitch.Name;
            type = $ConfigSwitch.Type;
            vlan = $ConfigSwitch.Vlan;
            natsubnetaddress = $ConfigSwitch.NatSubnetAddress;
            adapters = $ConfigAdapters }
    }
    return $Switches
} # Get-LabSwitch


<#
.SYNOPSIS
   Creates Hyper-V Virtual Switches from a provided array.
.DESCRIPTION
   Takes an array of switches that were pulled from a Lab Configuration object by calling
   Get-LabSwitch
   and ensures that they Hyper-V Virtual Switches on the system are configured to match.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER Switches
   The array of switches pulled from the Lab Configuration file using Get-LabSwitch.
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabSwitch -Config $Config
   Initialize-LabSwitch -Config $Config -Switches $Switches
   Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Initialize-LabSwitch -Config $Config
   Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Initialize-LabSwitch {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [Array] $Switches
    )

    # If swtiches was not passed, pull it.
    if (-not $Switches)
    {
        $Switches = Get-LabSwitch `
            -Config $Config
    }
    
    # Create Hyper-V Switches
    foreach ($VMSwitch in $Switches)
    {
        if ((Get-VMSwitch | Where-Object -Property Name -eq $($VMSwitch.Name)).Count -eq 0)
        {
            [String] $SwitchName = $VMSwitch.Name
            if (-not $SwitchName)
            {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                ThrowException @ExceptionParameters
            }
            [string] $SwitchType = $VMSwitch.Type
            Write-Verbose -Message $($LocalizedData.CreatingVirtualSwitchMessage `
                -f $SwitchType,$SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -NetAdapterName (`
                            Get-NetAdapter | `
                            Where-Object { $_.Status -eq 'Up' } | `
                            Select-Object -First 1 -ExpandProperty Name `
                            )
                    if ($VMSwitch.Adapters)
                    {
                        foreach ($Adapter in $VMSwitch.Adapters)
                        {
                            if ($VMSwitch.VLan)
                            {
                                # A default VLAN is assigned to this Switch so assign it to the
                                # management adapters
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress) `
                                    
                                    -Passthru | `
                                    Set-VMNetworkAdapterVlan -Access -VlanId $($Switch.Vlan)
                            }
                            Else
                            { 
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress)
                            } # If
                        } # Foreach
                    } # If
                    Break
                } # 'External'
                'Private'
                {
                    $null = New-VMSwitch -Name $SwitchName -SwitchType Private
                    Break
                } # 'Private'
                'Internal'
                {
                    $null = New-VMSwitch -Name $SwitchName -SwitchType Internal
                    if ($VMSwitch.Adapters)
                    {
                        foreach ($Adapter in $VMSwitch.Adapters)
                        {
                            if ($VMSwitch.VLan)
                            {
                                # A default VLAN is assigned to this Switch so assign it to the
                                # management adapters
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress) `
                                    -Passthru | `
                                    Set-VMNetworkAdapterVlan -Access -VlanId $($Switch.Vlan)
                            }
                            Else
                            { 
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $($Adapter.Name) `
                                    -StaticMacAddress $($Adapter.MacAddress)
                            } # If
                        } # Foreach
                    } # If
                    Break
                } # 'Internal'
                'NAT'
                {
                    $NatSubnetAddress = $VMSwitch.NatSubnetAddress
                    if (-not $NatSubnetAddress) {
                        $ExceptionParameters = @{
                            errorId = 'NatSubnetAddressEmptyError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.NatSubnetAddressEmptyError `
                                -f $SwitchName)
                        }
                        ThrowException @ExceptionParameters
                    }
                    $null = New-VMSwitch `
                        -Name $SwitchName `
                        -SwitchType NAT `
                        -NATSubnetAddress $NatSubnetAddress
                    $null = New-NetNat `
                        -Name $SwitchName `
                        -InternalIPInterfaceAddressPrefix $NatSubnetAddress
                    Break
                } # 'NAT'
                Default
                {
                    $ExceptionParameters = @{
                        errorId = 'UnknownSwitchTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                            -f $SwitchType,$SwitchName)
                    }
                    ThrowException @ExceptionParameters
                }
            } # Switch
        } # If
    } # Foreach       
} # Initialize-LabSwitch


<#
.SYNOPSIS
   Removes all Hyper-V Virtual Switches provided.
.DESCRIPTION
   This cmdlet is used to remove any Hyper-V Virtual Switches that were created by
   the Initialize-LabSwitch cmdlet.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER Switches
   The array of switches pulled from the Lab Configuration file using Get-LabSwitch
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $Switches = Get-LabSwitch -Config $Config
   Remove-LabSwitch -Config $Config -Switches $Switches
   Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Remove-LabSwitch -Config $Config
   Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Remove-LabSwitch {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [System.Collections.Hashtable[]] $Switches
    )

    # If swtiches were not passed so pull them
    if (-not $Switches)
    {
        $Switches = Get-LabSwitch `
            -Config $Config
    }

    # Delete Hyper-V Switches
    foreach ($Switch in $Switches)
    {
        if ((Get-VMSwitch | Where-Object -Property Name -eq $Switch.Name).Count -ne 0)
        {
            [String] $SwitchName = $Switch.Name
            if (-not $SwitchName)
            {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                ThrowException @ExceptionParameters
            }
            [string] $SwitchType = $Switch.Type
            Write-Verbose -Message $($LocalizedData.DeleteingVirtualSwitchMessage `
                -f $SwitchType,$SwitchName)
            Switch ($SwitchType)
            {
                'External'
                {
                    if ($Switch.Adapters)
                    {
                        $Switch.Adapters.foreach( {
                            $null = Remove-VMNetworkAdapter -ManagementOS -Name $_.Name
                        } )
                    } # If
                    Remove-VMSwitch -Name $SwitchName
                    Break
                } # 'External'
                'Private'
                {
                    Remove-VMSwitch -Name $SwitchName
                    Break
                } # 'Private'
                'Internal'
                {
                    Remove-VMSwitch -Name $SwitchName
                    if ($Switch.Adapters)
                    {
                        $Switch.Adapters.foreach( {
                            $null = Remove-VMNetworkAdapter -ManagementOS -Name $_.Name
                        } )
                    } # If
                    Break
                } # 'Internal'
                'NAT'
                {
                    Remove-NetNAT -Name $SwitchName
                    Remove-VMSwitch -Name $SwitchName
                    Break
                } # 'Internal'

                Default
                {
                    $ExceptionParameters = @{
                        errorId = 'UnknownSwitchTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                            -f $SwitchType,$SwitchName)
                    }
                    ThrowException @ExceptionParameters
                }
            } # Switch
        } # If
    } # Foreach        
} # Remove-LabSwitch
#endregion


#region LabVMTemplateVHDFunctions
<#
.SYNOPSIS
   Gets an Array of TemplateVHDs for a Lab configuration.
.DESCRIPTION
   Takes a provided Lab Configuration file and returns the list of Template Disks
   that will be used to create the Virtual Machines in this lab. This list is usually passed to
   Initialize-LabVMTemplateVHD.
   
   It will validate the paths to the ISO folder as well as to the ISO files themselves.
   
   If any ISO files references can't be found an exception will be thrown.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config
   Loads a Lab Builder configuration and pulls the array of TemplateVHDs from it.
.OUTPUTS
   Returns an array of TemplateVHDs. It will return Null if the TemplateVHDs node does
   not exist or contains no TemplateVHD nodes.
#>
function Get-LabVMTemplateVHD {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config
    )

    # return null if the TemplateVHDs node does not exist
    if (-not $Config.labbuilderconfig.TemplateVHDs)
    {
        return
    }
    
    # Determine the ISORootPath where the ISO files should be found
    # If no path is specified then look in the same path as the config
    # If a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $ISORootPath = $Config.labbuilderconfig.TemplateVHDs.ISOPath
    if (-not $ISORootPath)
    {
        $ISORootPath = $Config.labbuilderconfig.settings.fullconfigpath
    }
    else
    {
        if (-not [System.IO.Path]::IsPathRooted($ISORootPath))
        {
            $ISORootPath = Join-Path `
                -Path $Config.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $ISORootPath
        }
    }
    if (-not (Test-Path -Path $ISORootPath -Type Container))
    {
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDISORootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                -f $ISORootPath)
        }
        ThrowException @ExceptionParameters
    }

    # Determine the VHDRootPath where the VHD files should be put
    # If no path is specified then look in the same path as the config
    # If a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $VHDRootPath = $Config.labbuilderconfig.TemplateVHDs.VHDPath
    if (-not $VHDRootPath)
    {
        $VHDRootPath = $Config.labbuilderconfig.settings.fullconfigpath
    }
    else
    {
        if (-not [System.IO.Path]::IsPathRooted($VHDRootPath))
        {
            $VHDRootPath = Join-Path `
                -Path $Config.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VHDRootPath
        }
    }
    if (-not (Test-Path -Path $VHDRootPath -Type Container))
    {
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDRootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                -f $VHDRootPath)
        }
        ThrowException @ExceptionParameters
    }

    $TemplatePrefix = $Config.labbuilderconfig.templatevhds.prefix

    # Read the list of templateVHD from the configuration file
    $TemplateVHDs = $Config.labbuilderconfig.SelectNodes('templatevhds').templatevhd
    [System.Collections.Hashtable[]] $VMTemplateVHDs = @()
    foreach ($TemplateVHD in $TemplateVHDs)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'templatevhd' as the name.
        $Name = $TemplateVHD.Name
        if (($Name -eq 'TemplateVHD') `
            -or ([String]::IsNullOrWhiteSpace($Name)))
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDNameError)
            }
            ThrowException @ExceptionParameters
        } # If
        
        # Get the ISO Path
        [String] $ISOPath = $TemplateVHD.ISO
        if (-not $ISOPath)
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDISOPathError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDISOPathError `
                    -f $TemplateVHD.Name)
            }
            ThrowException @ExceptionParameters
        }

        # Adjust the ISO Path if required
        if (-not [System.IO.Path]::IsPathRooted($ISOPath))
        {
            $ISOPath = Join-Path `
                -Path $ISORootPath `
                -ChildPath $ISOPath
        }
        
        # Does the ISO Exist?
        if (-not (Test-Path -Path $ISOPath))
        {
            $URL = $TemplateVHD.URL
            if ($URL)
            {
                Write-Host `
                    -ForegroundColor Yellow `
                    -Object $($LocalizedData.ISONotFoundDownloadURLMessage `
                        -f $TemplateVHD.Name,$ISOPath,$URL)
            }
            $ExceptionParameters = @{
                errorId = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                    -f $TemplateVHD.Name,$ISOPath)
            }
            ThrowException @ExceptionParameters            
        }
        
        # Get the VHD Path
        [String] $VHDPath = $TemplateVHD.VHD
        if (-not $VHDPath)
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDPathError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDPathError `
                    -f $TemplateVHD.Name)
            }
            ThrowException @ExceptionParameters
        }

        # Adjust the VHD Path if required
        if (-not [System.IO.Path]::IsPathRooted($VHDPath))
        {
            $VHDPath = Join-Path `
                -Path $VHDRootPath `
                -ChildPath $VHDPath
        }
        
        # Add the template prefix to the VHD name.
        if ([String]::IsNullOrWhitespace($TemplatePrefix))
        {
             $VHDPath = Join-Path `
                -Path (Split-Path -Path $VHDPath)`
                -ChildPath ("$TemplatePrefix$(Split-Path -Path $VHDPath -Leaf)")
        }
        
        # Get the Template OS Type 
        [String] $OSType = 'Server'
        if ($TemplateVHD.OSType)
        {
            $OSType = $TemplateVHD.OSType
        } # If
        if ($OSType -notin @('Server','Client','Nano') )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDOSTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDOSTypeError `
                    -f $TemplateVHD.Name,$OSType)
            }
            ThrowException @ExceptionParameters            
        }

		# Get the Template Wim Image to use
        $Edition = $null
        if ($TemplateVHD.Edition)
        {
            $Edition = $TemplateVHD.Edition
        } # If

        # Get the Template VHD Format 
        [String] $VHDFormat = 'VHDX'
        if ($TemplateVHD.VHDFormat)
        {
            $VHDFormat = $TemplateVHD.VHDFormat
        } # If
        if ($VHDFormat -notin @('VHDx','VHD') )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDVHDFormatError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDFormatError `
                    -f $TemplateVHD.Name,$VHDFormat)
            }
            ThrowException @ExceptionParameters            
        }

        # Get the Template VHD Type 
        [String] $VHDType = 'Dynamic'
        if ($TemplateVHD.VHDType)
        {
            $VHDType = $TemplateVHD.VHDType
        } # If
        if ($VHDType -notin @('Dynamic','Fixed') )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDVHDTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDTypeError `
                    -f $TemplateVHD.Name,$VHDType)
            }
            ThrowException @ExceptionParameters            
        }
        
        # Get the disk size if provided
        [Int64] $Size = 25GB
        if ($TemplateVHD.VHDSize)
        {
            $VHDSize = (Invoke-Expression $TemplateVHD.VHDSize)         
        }

        # Get the Template VM Generation 
        [int] $Generation = 2
        if ($TemplateVHD.Generation)
        {
            $Generation = $TemplateVHD.Generation
        } # If
        if ($Generation -notin @(1,2) )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDGenerationError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDGenerationError `
                    -f $TemplateVHD.Name,$Generation)
            }
            ThrowException @ExceptionParameters            
        }

        # Get the Template Packages
        if ($TemplateVHD.packages)
        {
            $Packages = $TemplateVHD.Packages
        } # If

        # Get the Template Features
        if ($TemplateVHD.features)
        {
            $Features = $TemplateVHD.Features
        } # If

		# Add template VHD to the list
            $VMTemplateVHDs += @{
                Name = $Name;
                ISOPath = $ISOPath;
                VHDPath = $VHDPath;
                OSType = $OSType;
                Edition = $Edition;
                Generation = $Generation;
                VHDFormat = $VHDFormat;
                VHDType = $VHDType;
                VHDSize = $VHDSize;
                Packages = $Packages;
                Features = $Features;
            }
     } # Foreach
    Return $VMTemplateVHDs
} # Get-LabVMTemplateVHD


<#
.SYNOPSIS
	Scans through a list of VM Template VHDs and creates them from the ISO if missing.
.DESCRIPTION
	This function will take a list of VM Template VHDs from a configuration file or it will
    extract the list itself if it is not provided and ensure that each VHD file is available.
    
    If the VHD file is not available then it will attempt to create it from the ISO.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER VMTemplateVHDs
   The array of VMTemplateVHDs pulled from the Lab Configuration file using Get-LabVMTemplateVHD
   
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config
   Initialize-LabVMTemplateVHD -Config $Config -VMTemplateVHDs $VMTemplateVHDs
   Loads a Lab Builder configuration and pulls the array of VM Template VHDs from it and then
   ensures all the VHDs are available.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Initialize-LabVMTemplateVHD -Config $Config
   Loads a Lab Builder configuration and then ensures VM Template VHDs all the VHDs are available.
.OUTPUTS
    None. 
#>
function Initialize-LabVMTemplateVHD
{
   param
   (
        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

	    [System.Collections.Hashtable[]] $VMTemplateVHDs
    )

    # If VMTeplateVHDs array not passed, pull it from config.
    if (-not $VMTemplateVHDs)
    {
        $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config        
    }

    # If there are no VMTemplateVHDs just return
    if ($VMTemplateVHDs -eq $null)
    {
        return
    }
    
    [String] $LabPath = $Config.labbuilderconfig.settings.labpath

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [String] $Name = $VMTemplateVHD.Name
        [String] $VHDPath = $VMTemplateVHD.VHDPath
        
        if (Test-Path -Path ($VHDPath))
        {
            # The SourceVHD already exists
            Write-Verbose -Message ($LocalizedData.SkipVMTemplateVHDFileMessage `
                -f $Name,$VHDPath)

            continue
        }
        
        # Create the VHD
        Write-Verbose -Message ($LocalizedData.CreatingVMTemplateVHDMessage `
            -f $Name,$VHDPath)
            
        # Check the ISO exists.
        [String] $ISOPath = $VMTemplateVHD.ISOPath
        if (-not (Test-Path -Path $ISOPath))
        {
            $ExceptionParameters = @{
                errorId = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                    -f $Name,$ISOPath)
            }
            ThrowException @ExceptionParameters            
        }
        
        # Mount the ISO so we can read the files.
        Write-Verbose -Message ($LocalizedData.MountingVMTemplateVHDISOMessage `
                -f $Name,$ISOPath)
                
        $null = Mount-DiskImage `
            -ImagePath $ISOPath `
            -StorageType ISO `
            -Access Readonly
    
        $DiskImage = Get-DiskImage -ImagePath $ISOPath
        [String] $DriveLetter = ( Get-Volume -DiskImage $DiskImage ).DriveLetter
        [String] $ISODrive = "$([string]$DriveLetter):"

        # Determine the path to the WIM
        [String] $SourcePath = "$ISODrive\Sources\Install.WIM"
        if ($VMTemplateVHD.OSType -eq 'Nano')
        {
            $SourcePath = "$ISODrive\Nanoserver\NanoServer.WIM"
        }

        # This will have to change depending on the version
        # of Convert-WindowsImage being used. 
        [String] $VHDFormat = $VMTemplateVHD.VHDFormat       
        [String] $VHDType = $VMTemplateVHD.VHDType       
        [String] $VHDDiskLayout = 'UEFI'
        if ($VMTemplateVHD.Generation -eq 1)
        {
            $VHDDiskLayout = 'BIOS'
        }

        [String] $Edition = $VMTemplateVHD.Edition
        # If edition is not set then use Get-WindowsImage to get the name
        # of the first image in the WIM.
        if ([String]::IsNullOrWhiteSpace($Edition))
        {
            $Edition = (Get-WindowsImage `
                -ImagePath $SourcePath `
                -Index 1).ImageName
        }

        $ConvertParams = @{
            sourcepath = $SourcePath
            vhdpath = $VHDpath
            vhdformat = $VHDFormat
            # vhdtype = $VHDType
            edition = $Edition
            disklayout = $VHDDiskLayout
            erroraction = 'Stop'
        }
        
        # Set the size
        if ($VMTemplateVHD.VHDSize -ne $null)
        {
            $ConvertParams += @{
                sizebytes = $VMTemplateVHD.VHDSize
            }
        }
        
        # Are any features specified?
        if (-not [String]::IsNullOrWhitespace($VMTemplateVHD.Features))
        {
            $Features = @($VMTemplateVHD.Features -split ',')
            $ConvertParams += @{
                feature = $Features
            }
        }
        
        # Perform Nano Server package prep
        if ($VMTemplateVHD.OSType -eq 'Nano')
        {
            # Make a copy of the all the Nano packages in the VHD root folder
            # So that if any VMs need to add more packages they are accessible
            # once the ISO has been dismounted.
            [String] $VHDFolder = Split-Path `
                -Path $VHDPath `
                -Parent

            [String] $VHDPackagesFolder = Join-Path `
                -Path $VHDFolder `
                -ChildPath 'NanoServerPackages'
            
            if (-not (Test-Path -Path $VHDPackagesFolder -Type Container))
            {
                Write-Verbose -Message ($LocalizedData.CachingNanoServerPackagesMessage `
                        -f "$ISODrive\Nanoserver\Packages",$VHDPackagesFolder)
                Copy-Item `
                    -Path "$ISODrive\Nanoserver\Packages" `
                    -Destination $VHDFolder `
                    -Recurse `
                    -Force
                Rename-Item `
                    -Path "$VHDFolder\Packages" `
                    -NewName 'NanoServerPackages'
            }
                                        
            # Now specify the Nano Server packages to add.
            if (-not [String]::IsNullOrWhitespace($VMTemplateVHD.Packages))
            {
                $Packages = @()
                $NanoPackages = @($VMTemplateVHD.Packages -split ',')

                foreach ($Package in $Script:NanoServerPackageList) 
                {
                    If ($Package.Name -in $NanoPackages) 
                    {
                        $Packages += @(Join-Path -Path $LabPackagesFolder -ChildPath $Package.Filename)
                        $Packages += @(Join-Path -Path $LabPackagesFolder -ChildPath "en-us\$($Package.Filename)")
                    } # if
                } # foreach
                $ConvertParams += @{
                    package = $Packages
                }
            } # if
        } # if 
        
        Write-Verbose -Message ($LocalizedData.ConvertingWIMtoVHDMessage `
            -f $SourcePath,$VHDPath,$VHDFormat,$Edition,$VHDPartitionStyle,$VHDType)

        # Work around an issue with Convert-WindowsImage not seeing the drive
        Get-PSDrive `
            -PSProvider FileSystem  
        
        # Dot source the Convert-WindowsImage script
        # Should only be done once 
        if (-not (Test-Path -Path Function:Convert-WindowsImage))
        {
            . $Script:SupportConvertWindowsImagePath
        }
        
        # Call the Convert-WindowsImage script
        Convert-WindowsImage @ConvertParams

        # Dismount the ISO.
        Write-Verbose -Message ($LocalizedData.DismountingVMTemplateVHDISOMessage `
                -f $Name,$ISOPath)

        $null = Dismount-DiskImage `
            -ImagePath $ISOPath

    } # endfor
} # Initialize-LabVMTemplateVHD


<#
.SYNOPSIS
   Gets an Array of VM Templates for a Lab configuration.
.DESCRIPTION
   Takes the provided Lab Configuration file and returns the list of Virtul Machine template machines
   that will be used to create the Virtual Machines in this lab. This list is usually passed to
   Initialize-LabVMTemplate.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER VMTemplateVHDs
   The array of VMTemplateVHDs pulled from the Lab Configuration file using Get-LabVMTemplateVHD
   
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Config $Config
   Loads a Lab Builder configuration and pulls the array of VMTemplates from it.
.OUTPUTS
   Returns an array of VM Templates.
#>
function Get-LabVMTemplate {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,
        
        [System.Collections.Hashtable[]] $VMTemplateVHDs        
    )

    [System.Collections.Hashtable[]] $VMTemplates = @()
    [String] $VHDParentPath = $Config.labbuilderconfig.SelectNodes('settings').vhdparentpath
    
    # If VMTeplateVHDs array not passed, pull it from config.
    if (-not $VMTemplateVHDs)
    {
        $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config
    }
    
    # Get a list of all templates in the Hyper-V system matching the phrase found in the fromvm
    # config setting
    [String] $FromVM=$Config.labbuilderconfig.SelectNodes('templates').fromvm
    if ($FromVM)
    {
        $Templates = @(Get-VM -Name $FromVM)
        foreach ($Template in $Templates)
        {
            [String] $VHDFilepath = (Get-VMHardDiskDrive -VMName $Template.Name).Path
            [String] $VHDFilename = [System.IO.Path]::GetFileName($VHDFilepath)
            $VMTemplates += @{
                name = $Template.Name
                vhd = $VHDFilename
                sourcevhd = $VHDFilepath
                parentvhd = (Join-Path -Path $VHDParentPath -ChildPath $VHDFilename)
            }
        } # foreach
    } # if
    
    # Read the list of templates from the configuration file
    $Templates = $Config.labbuilderconfig.SelectNodes('templates').template
    foreach ($Template in $Templates)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'template' as the name.
        $TemplateName = $Template.Name
        if ($TemplateName -eq 'template')
        {
            $ExceptionParameters = @{
                errorId = 'EmptyTemplateNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyTemplateNameError)
            }
            ThrowException @ExceptionParameters
        } # if
        
        # Does the template already exist in the list?
        [Boolean] $Found = $False
        foreach ($VMTemplate in $VMTemplates)
        {
            if ($VMTemplate.Name -eq $TemplateName)
            {
                # The template already exists - so don't add it again,
                $Found = $True
                Break
            } # If
        } # Foreach
        if (-not $Found)
        {
            # The template wasn't found in the list of templates so add it
            $VMTemplate = @{
                name = $TemplateName;
            }
            $VMTemplates += $VMTemplate
        } # if
        
        # Determine the Source VHD, Template VHD and VHD
        [String] $SourceVHD = $Template.SourceVHD
        [String] $TemplateVHD = $Template.TemplateVHD

        # Throw an error if both a TemplateVHD and SourceVHD are provided
        if ($TemplateVHD -and $SourceVHD)
        {
            $ExceptionParameters = @{
                errorId = 'TemplateSourceVHDAndTemplateVHDConflictError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.TemplateSourceVHDAndTemplateVHDConflictError `
                    -f $TemplateName)
            }
            ThrowException @ExceptionParameters            
        } # if
        
        if ($TemplateVHD)
        {
            # A TemplateVHD was provided so look it up.
            $VMTemplateVHD = `
                $VMTemplateVHDs | Where-Object -Property Name -EQ $TemplateVHD
            if ($VMTemplateVHD)
            {
                # The TemplateVHD was found
                $VMTemplate.sourcevhd = $VMTemplateVHD.VHDPath

                # If a VHD filename wasn't specified in the TemplateVHD
                # Just use the leaf of the SourceVHD
                if ($VMTemplateVHD.VHD)
                {
                    $VMTemplate.vhd = $VMTemplateVHD.VHD
                }
                else
                {
                    $VMTemplate.vhd = Split-Path `
                        -Path $VMTemplate.sourcevhd `
                        -Leaf
                } # if
            }
            else
            {
                # The TemplateVHD could not be found in the list
                $ExceptionParameters = @{
                    errorId = 'TemplateTemplateVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateTemplateVHDNotFoundError `
                        -f $TemplateName,$TemplateVHD)
                }
                ThrowException @ExceptionParameters
            } # if
        }
        elseif ($SourceVHD)
        {
            # A Source VHD was provided so use that.
            # If this is a relative path, add it to the config path
            if ([System.IO.Path]::IsPathRooted($SourceVHD))
            {
                $VMTemplate.sourcevhd = $SourceVHD                
            }
            else
            {
                $VMTemplate.sourcevhd = Join-Path `
                    -Path $Config.labbuilderconfig.settings.fullconfigpath `
                    -ChildPath $SourceVHD
            }

            # A Source VHD file was specified - does it exist?
            if (-not (Test-Path -Path $VMTemplate.sourcevhd))
            {
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $TemplateName,$VMTemplate.sourcevhd)
                }
                ThrowException @ExceptionParameters
            } # if
            
            # If a VHD filename wasn't specified in the Template
            # Just use the leaf of the SourceVHD
            if ($Template.VHD)
            {
                $VMTemplate.vhd = $Template.VHD
            }
            else
            {
                $VMTemplate.vhd = Split-Path `
                    -Path $VMTemplate.sourcevhd `
                    -Leaf
            } 
        }
        else
        {
            # Neither a SourceVHD or TemplateVHD was provided
            # So throw an exception            
            $ExceptionParameters = @{
                errorId = 'TemplateSourceVHDandTemplateVHDMissingError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.TemplateSourceVHDandTemplateVHDMissingError `
                    -f $TemplateName)
            }
            ThrowException @ExceptionParameters
        } # if
                
        # Ensure the ParentVHD is up-to-date
        $VMTemplate.parentvhd = Join-Path `
            -Path $VHDParentPath `
            -ChildPath ([System.IO.Path]::GetFileName($VMTemplate.vhd))

        # Write any template specific default VM attributes
        [Int64] $MemoryStartupBytes = 1GB
        if ($Template.MemoryStartupBytes)
        {
            $MemoryStartupBytes = (Invoke-Expression $Template.MemoryStartupBytes)
        } # if
        if ($MemoryStartupBytes -gt 0)
        {
            $VMTemplate.memorystartupbytes = $MemoryStartupBytes
        } # if
        if ($Template.DynamicMemoryEnabled)
        {
            $VMTemplate.dynamicmemoryenabled = $Template.DynamicMemoryEnabled
        }
        elseif (-not $VMTemplate.DynamicMemoryEnabled)
        {
            $VMTemplate.dynamicmemoryenabled = 'Y'
        }
         # if
        if ($Template.ProcessorCount)
        {
            $VMTemplate.ProcessorCount = $Template.ProcessorCount
        } # if
        if ($Template.ExposeVirtualizationExtensions)
        {
            $VMTemplate.exposevirtualizationextensions = $Template.ExposeVirtualizationExtensions
        } 
        # if
        if ($Template.AdministratorPassword)
        {
            $VMTemplate.administratorpassword = $Template.AdministratorPassword
        } # if
        if ($Template.ProductKey)
        {
            $VMTemplate.productkey = $Template.ProductKey
        } # if
        if ($Template.TimeZone)
        {
            $VMTemplate.timezone = $Template.TimeZone
        } # if
        if ($Template.OSType)
        {
            $VMTemplate.ostype = $Template.OSType
        }
        elseif (-not $VMTemplate.OSType)
        {
            $VMTemplate.ostype = 'Server'
        } # if
        if ($Template.IntegrationServices)
        {
            $VMTemplate.integrationservices = $Template.IntegrationServices
        }
        else
        {
            $VMTemplate.integrationservices = $null
        } # if
        if ($Template.Packages)
        {
            $VMTemplate.packages = $Template.Packages
        }
        else
        {
            $VMTemplate.packages = $null
        } # if
    } # Foreach
    Return $VMTemplates
} # Get-LabVMTemplate
#region


#region LabVMTemplateFunctions
<#
.SYNOPSIS
   Initializes the Virtual Machine templates used by a Lab from a provided array.
.DESCRIPTION
   Takes an array of Virtual Machine templates that were configured in the Lab Configuration
   file. The Virtual Machine templates are used to create the Virtual Machines specified in
   a Lab Configuration. The Virtual Machine template VHD files are copied to a folder where
   they will be copied to create new Virtual Machines or as parent difference disks for new
   Virtual Machines.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER VMTemplates
   The array of VM Templates pulled from the Lab Configuration file using Get-LabVMTemplate
   If not provided it will attempt to pull the list from the configuration file.
.PARAMETER VMTemplateVHDs
   The array of VM Templates pulled from the Lab Configuration file using Get-LabVMTemplate
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Config $Config
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Config $Config
   Initialize-LabVMTemplate `
    -Config $Config `
    -VMTemplates $VMTemplates `
    -VMTemplateVHDs $VMTemplateVHDs
   Initializes the Virtual Machine templates in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Initialize-LabVMTemplate -Config $Config
   Initializes the Virtual Machine templates in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Initialize-LabVMTemplate {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [System.Collections.Hashtable[]] $VMTemplates
    )
    
    # Get the VM Templates if they weren't passed
    if (-not $VMTemplates)
    {
        $VMTemplates = Get-LabVMTemplate `
            -Config $Config
    }

    [String] $LabPath = $Config.labbuilderconfig.settings.labpath
    
    # Check each Parent VHD exists in the Parent VHDs folder for the
    # Lab. If it isn't, try and copy it from the SourceVHD
    # Location.
    foreach ($VMTemplate in $VMTemplates)
    {
        if (-not (Test-Path $VMTemplate.parentvhd))
        {
            # The Parent VHD isn't in the VHD Parent folder
            # so copy it there, optimize it and mark it read-only.
            if (-not (Test-Path $VMTemplate.sourcevhd))
            {  
                # The source VHD could not be found.
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f $VMTemplate.Name,$VMTemplate.sourcevhd)
                }
                ThrowException @ExceptionParameters                
			}
            
			Write-Verbose -Message $($LocalizedData.CopyingTemplateSourceVHDMessage `
                -f $VMTemplate.sourcevhd,$VMTemplate.parentvhd)
            Copy-Item `
                -Path $VMTemplate.sourcevhd `
                -Destination $VMTemplate.parentvhd
            Write-Verbose -Message $($LocalizedData.OptimizingParentVHDMessage `
                -f $VMTemplate.parentvhd)
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $False
            Optimize-VHD `
                -Path $VMTemplate.parentvhd `
                -Mode Full
            Write-Verbose -Message $($LocalizedData.SettingParentVHDReadonlyMessage `
                -f $VMTemplate.parentvhd)
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $True
        }
        Else
        {
            Write-Verbose -Message $($LocalizedData.SkipParentVHDFileMessage `
                -f $VMTemplate.Name,$VMTemplate.parentvhd)
        }

        # If this is a Nano Server template, we need to ensure that the
        # NanoServerPackages folder is copied to our Lab folder
        if ($VMTemplate.OSType -eq 'Nano')
        {
            [String] $VHDPackagesFolder = Join-Path `
                -Path (Split-Path -Path $VMTemplate.sourcevhd -Parent)`
                -ChildPath 'NanoServerPackages'

            [String] $LabPackagesFolder = Join-Path `
                -Path $LabPath `
                -ChildPath 'NanoServerPackages'

            if (-not (Test-Path -Path $LabPackagesFolder -Type Container))
            {
                Write-Verbose -Message ($LocalizedData.CachingNanoServerPackagesMessage `
                        -f $VHDPackagesFolder,$LabPackagesFolder)
                Copy-Item `
                    -Path $VHDPackagesFolder `
                    -Destination $LabPath `
                    -Recurse `
                    -Force
            }
        }
    }
} # Initialize-LabVMTemplate


<#
.SYNOPSIS
   Removes all Lab Virtual Machine Template VHDs.
.DESCRIPTION
   This cmdlet is used to remove any Virtual Machine Template VHDs that were copied when
   creating this Lab.
   
   This function should never be run unless the Lab has no Differencing Disks using these
   Template VHDs or the Lab is being completely removed. Removing these Template VHDs if
   Lab Virtual Machines are using these templates as differencing disk parents will cause
   the Lab Virtual Hard Drives to become corrupt.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VMTemplates
   The array of Virtual Machine Templates pulled from the Lab Configuration file using
   Get-LabVMTemplate
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Config $Config
   Remove-LabVMTemplate -Config $Config -VMTemplates $VMTemplates
   Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   Remove-LabVMTemplate -Config $Config
   Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Remove-LabVMTemplate {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [System.Collections.Hashtable[]] $VMTemplates
    )

    # The VMTemplates were not passed so pull them
    if (-not $VMTemplates)
    {
        $VMTemplates = Get-LabVMTemplate `
            -Config $Config
    }    
    foreach ($VMTemplate in $VMTemplates)
    {
        if (Test-Path $VMTemplate.parentvhd)
        {
            Set-ItemProperty -Path $VMTemplate.parentvhd -Name IsReadOnly -Value $False
            Write-Verbose -Message $($LocalizedData.DeletingParentVHDMessage `
                -f $VMTemplate.parentvhd)
            Remove-Item -Path $VMTemplate.parentvhd -Confirm:$false -Force
        }
    }
} # Remove-LabVMTemplate
#region


#region LabVMFunctions
<#
.SYNOPSIS
   Gets an Array of VMs from a Lab configuration.
.DESCRIPTION
   Takes the provided Lab Configuration file and returns the list of Virtul Machines
   that will be created in this lab. This list is usually passed to Initialize-LabVM.
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration object.
.PARAMETER VMTemplates
   Contains the array of VM Templates returned by Get-LabVMTemplate from this configuration.
   If not provided it will attempt to pull the list from the configuration file.
.PARAMETER Switches
   Contains the array of Virtual Switches returned by Get-LabSwitch from this configuration.
   If not provided it will attempt to pull the list from the configuration file.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Config $Config
   $Switches = Get-LabSwitch -Config $Config
   $VMs = Get-LabVM -Config $Config -VMTemplates $VMTemplates -Switches $Switches
   Loads a Lab Builder configuration and pulls the array of VMs from it.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Loads a Lab Builder configuration and pulls the array of VMs from it.
.OUTPUTS
   Returns an array of VMs.
#>
function Get-LabVM {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]] $VMTemplates,

        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]] $Switches
    )

    # If the list of VMTemplates was not passed so pull it
    if (-not $VMTemplates)
    {
        $VMTemplates = Get-LabVMTemplate -Config $Config
    }

    # If the list of Switches was not passed so pull it
    if (-not $Switches)
    {
        $Switches = Get-LabSwitch -Config $Config
    }

    [System.Collections.Hashtable[]] $LabVMs = @()
    [String] $LabPath = $Config.labbuilderconfig.settings.labpath
    [String] $VHDParentPath = $Config.labbuilderconfig.settings.vhdparentpath
    $VMs = $Config.labbuilderconfig.SelectNodes('vms').vm

    foreach ($VM in $VMs) 
	{
        if ($VM.Name -eq 'VM')
		{
            $ExceptionParameters = @{
                errorId = 'VMNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMNameError)
            }
            ThrowException @ExceptionParameters
        } # If
        if (-not $VM.Template) 
		{
            $ExceptionParameters = @{
                errorId = 'VMTemplateNameEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                    -f $VM.name)
            }
            ThrowException @ExceptionParameters
        } # If

        # Find the template that this VM uses and get the VHD Path
        [String] $ParentVHDPath =''
        [Boolean] $Found = $false
        foreach ($VMTemplate in $VMTemplates) {
            if ($VMTemplate.Name -eq $VM.Template) {
                $ParentVHDPath = $VMTemplate.parentVHD
                $Found = $true
                Break
            } # If
        } # Foreach

        if (-not $Found) 
		{
            $ExceptionParameters = @{
                errorId = 'VMTemplateNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                    -f $VM.name,$VM.template)
            }
            ThrowException @ExceptionParameters
        } # If

        # Assemble the Network adapters that this VM will use
        [System.Collections.Hashtable[]] $VMAdapters = @()
        [Int] $AdapterCount = 0
        foreach ($VMAdapter in $VM.Adapters.Adapter) 
		{
            $AdapterCount++
            if ($VMAdapter.Name -eq 'adapter') 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterNameError `
                        -f $VM.name)
                }
                ThrowException @ExceptionParameters
            }
            if (-not $VMAdapter.SwitchName) 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                        -f $VM.name,$VMAdapter.name)
                }
                ThrowException @ExceptionParameters
            }
            # Check the switch is in the switch list
            [Boolean] $Found = $False
            foreach ($Switch in $Switches) 
			{
                if ($Switch.Name -eq $VMAdapter.SwitchName) 
				{
                    # The switch is found in the switch list - record the VLAN (if there is one)
                    $Found = $True
                    $SwitchVLan = $Switch.Vlan
                    Break
                } # If
            } # Foreach
            if (-not $Found) 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNotFoundError `
                        -f $VM.name,$VMAdapter.name,$VMAdapter.switchname)
                }
                ThrowException @ExceptionParameters
            } # If
            
            # Figure out the VLan - If defined in the VM use it, otherwise use the one defined in the Switch, otherwise keep blank.
            [String] $VLan = $VMAdapter.VLan
            if (-not $VLan) 
			{
                $VLan = $SwitchVLan
            } # If
            
            [String] $MACAddressSpoofing = 'Off'
            if ($VMAdapter.macaddressspoofing -eq 'On') 
			{
                $MACAddressSpoofing = 'On'
            }
            
            # Have we got any IPv4 settings?
            [System.Collections.Hashtable] $IPv4 = @{}
            if ($VMAdapter.IPv4) 
			{
                $IPv4 = @{
                    Address = $VMAdapter.IPv4.Address;
                    defaultgateway = $VMAdapter.IPv4.DefaultGateway;
                    subnetmask = $VMAdapter.IPv4.SubnetMask;
                    dnsserver = $VMAdapter.IPv4.DNSServer
                }
            }

            # Have we got any IPv6 settings?
            [System.Collections.Hashtable] $IPv6 = @{}

            if ($VMAdapter.IPv6) 
			{
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
                MACAddressSpoofing = $MACAddressSpoofing;
                VLan = $VLan;
                IPv4 = $IPv4;
                IPv6 = $IPv6
            }
        } # Foreach

        # Assemble the Data Disks this VM will use
        [System.Collections.Hashtable[]] $DataVhds = @()
        [Int] $DataVhdCount = 0
        foreach ($VMDataVhd in $VM.DataVhds.DataVhd)
        {
            $DataVhdCount++
            # Load all the VHD properties and check they are valid
            [String] $Vhd = $VMDataVhd.VHD
            if (! $Vhd)
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                        -f $VM.name)
                }
                ThrowException @ExceptionParameters
            }
            # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
            # if it doesn't contain a root (e.g. c:\)
            if (! [System.IO.Path]::IsPathRooted($Vhd))
            {
                $Vhd = Join-Path -Path $LabPath -ChildPath "$($VM.Name)\Virtual Hard Disks\$Vhd"
            }
            
            # Does the VHD already exist?
            $Exists = Test-Path -Path $Vhd

            # Get the Parent VHD and check it exists if passed
            Remove-Variable -Name ParentVhd -ErrorAction SilentlyContinue
            if ($VMDataVhd.ParentVHD)
            {
                [String] $ParentVhd = $VMDataVhd.ParentVHD
                # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                # if it doesn't contain a root (e.g. c:\)
                if (! [System.IO.Path]::IsPathRooted($ParentVhd))
                {
                    $ParentVhd = Join-Path `
                        -Path $Config.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $ParentVhd
                }
                if (-not (Test-Path -Path $ParentVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskParentVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                            -f $VM.name,$ParentVhd)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Get the Source VHD and check it exists if passed
            Remove-Variable -Name SourceVhd -ErrorAction SilentlyContinue
            if ($VMDataVhd.SourceVHD)
            {
                [String] $SourceVhd = $VMDataVhd.SourceVHD
                # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                # if it doesn't contain a root (e.g. c:\)
                if (! [System.IO.Path]::IsPathRooted($SourceVhd))
                {
                    $SourceVhd = Join-Path `
                        -Path $Config.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $SourceVhd
                }
                if (! (Test-Path -Path $SourceVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                            -f $VM.name,$SourceVhd)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Get the disk size if provided
            Remove-Variable -Name Size -ErrorAction SilentlyContinue
            if ($VMDataVhd.Size)
            {
                $Size = (Invoke-Expression $VMDataVhd.size)         
            }

            [Boolean] $Shared = ($VMDataVhd.shared -eq 'Y')

            # Validate the data disk type specified
            Remove-Variable -Name Type -ErrorAction SilentlyContinue
            if ($VMDataVhd.type)
            {
                [String] $Type = $VMDataVhd.type
                switch ($type)
                {
                    'fixed'
                    {
                        break;
                    }
                    'dynamic'
                    {
                        break;
                    }
                    'differencing'
                    {
                        if (-not $ParentVhd)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDMissingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                                    -f $VM.name)
                            }
                            ThrowException @ExceptionParameters
                        }
                        if ($Shared)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskSharedDifferencingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                                    -f $VM.Name,$VHD)
                            }
                            ThrowException @ExceptionParameters                            
                        }
                    }
                    Default
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskUnknownTypeError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                                -f $VM.Name,$VHD,$type)
                        }
                        ThrowException @ExceptionParameters
                    }
                }
            }

            # Get the Support Persistent Reservations
            [Boolean] $SupportPR = ($VMDataVhd.supportPR -eq 'Y')
            if ($SupportPR -and -not $Shared)
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSupportPRError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSupportPRError `
                        -f $VM.Name,$VHD)
                }
                ThrowException @ExceptionParameters
            }

            # Get Partition Style for the new disk.
            Remove-Variable -Name PartitionStyle -ErrorAction SilentlyContinue
            if ($VMDataVhd.partitionstyle)
            {
                [String] $PartitionStyle = $VMDataVhd.partitionstyle
                if ($PartitionStyle -and ($PartitionStyle -notin 'MBR','GPT'))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskPartitionStyleError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskPartitionStyleError `
                            -f $VM.Name,$VHD,$PartitionStyle)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Get file system for the new disk.
            Remove-Variable -Name FileSystem -ErrorAction SilentlyContinue
            if ($VMDataVhd.filesystem)
            {
                [String] $FileSystem = $VMDataVhd.filesystem
                if ($FileSystem -notin 'FAT','FAT32','exFAT','NTFS','ReFS')
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskFileSystemError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskFileSystemError `
                            -f $VM.Name,$VHD,$FileSystem)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Has a file system label been provided?
            Remove-Variable -Name FileSystemLabel -ErrorAction SilentlyContinue
            if ($VMDataVhd.filesystemlabel)
            {
                [String] $FileSystemLabel = $VMDataVhd.filesystemlabel
            }
            
            # If the Partition Style, File System or File System Label has been
            # provided then ensure Partition Style and File System are set.
            if ($PartitionStyle -or $FileSystem -or $FileSystemLabel)
            {
                if (-not $PartitionStyle)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskPartitionStyleMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                            -f $VM.Name,$VHD)
                    }
                    ThrowException @ExceptionParameters
                }
                if (-not $FileSystem)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskFileSystemMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                            -f $VM.Name,$VHD)
                    }
                    ThrowException @ExceptionParameters
                }
            }

            # Get the Folder to copy and check it exists if passed
            Remove-Variable -Name CopyFolders -ErrorAction SilentlyContinue
            if ($VMDataVhd.CopyFolders)
            {
                [String]$CopyFolders = $VMDataVhd.CopyFolders
                foreach ($CopyFolder in ($CopyFolders -Split ','))
                {
                    # Adjust the path to be relative to the configuration folder 
                    # if it doesn't contain a root (e.g. c:\)
                    if (-not [System.IO.Path]::IsPathRooted($CopyFolder))
                    {
                        $CopyFolder = Join-Path `
                            -Path $Config.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $CopyFolder
                    }
                    if (-not (Test-Path -Path $CopyFolder -Type Container))
                    {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskCopyFolderMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskCopyFolderMissingError `
                            -f $VM.Name,$VHD,$CopyFolder)
                        }
                    ThrowException @ExceptionParameters 
                    }                   
                }
            } 
            
            # Should the Source VHD be moved rather than copied
            Remove-Variable -Name MoveSourceVHD -ErrorAction SilentlyContinue
            if ($VMDataVhd.MoveSourceVHD)
            {
                [Boolean] $MoveSourceVHD = ($VMDataVhd.MoveSourceVHD -eq 'Y')
                if (! $SourceVHD)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDIfMoveError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                            -f $VM.Name,$VHD)
                    }
                    ThrowException @ExceptionParameters                        
                }
            }

            # If the data disk file doesn't exist then some basic parameters MUST be provided
            if (-not $Exists `
                -and ((( $Type -notin ('fixed','dynamic','differencing') ) -or $Size -eq $null -or $Size -eq 0 ) `
                -and -not $SourceVhd ))
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $VM.Name,$VHD)
                }
                ThrowException @ExceptionParameters                    
            }
                        
            # Write the values to the array
            $DataVhds += @{
                vhd = $Vhd;
                type = $Type;
                size = $Size
                sourcevhd = $SourceVHD;
                parentvhd = $ParentVHD;
                shared = $Shared;
                supportPR = $SupportPR;
                moveSourceVHD = $MoveSourceVHD;
                copyfolders = $CopyFolders;
                partitionstyle = $PartitionStyle;
                filesystem = $FileSystem;
                filesystemlabel = $FileSystemLabel;
            }
        } # Foreach

        # Does the VM have an Unattend file specified?
        [String] $UnattendFile = ''
        if ($VM.UnattendFile) 
		{
            $UnattendFile = Join-Path `
                -Path $Config.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.UnattendFile
            if (-not (Test-Path $UnattendFile)) 
			{
                $ExceptionParameters = @{
                    errorId = 'UnattendFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnattendFileMissingError `
                        -f $VM.name,$UnattendFile)
                }
                ThrowException @ExceptionParameters
            } # If
        } # If
        
        # Does the VM specify a Setup Complete Script?
        [String] $SetupComplete = ''
        if ($VM.SetupComplete) 
		{
            $SetupComplete = Join-Path `
                -Path $Config.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.SetupComplete
            if ([System.IO.Path]::GetExtension($SetupComplete).ToLower() -notin '.ps1','.cmd' )
            {
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                        -f $VM.name,$SetupComplete)
                }
                ThrowException @ExceptionParameters
            } # If
            if (-not (Test-Path $SetupComplete))
            {
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                        -f $VM.name,$SetupComplete)
                }
                ThrowException @ExceptionParameters
            } # If
        } # If

        # Load the DSC Config File setting and check it
        [String] $DSCConfigFile = ''
        if ($VM.DSC.ConfigFile) 
		{
            [String] $DSCLibraryPath = $Config.labbuilderconfig.settings.dsclibrarypath
            if ($DSCLibraryPath)
            {
                if ([System.IO.Path]::IsPathRooted($DSCLibraryPath))
                {
                    $DSCConfigFile = Join-Path `
                        -Path $DSCLibraryPath `
                        -ChildPath $VM.DSC.ConfigFile
                }
                else
                {
                    $DSCConfigFile = Join-Path `
                        -Path $Config.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $DSCLibraryPath
                    $DSCConfigFile = Join-Path `
                        -Path $DSCConfigFile `
                        -ChildPath $VM.DSC.ConfigFile
                }
            }
            if ([System.IO.Path]::GetExtension($DSCConfigFile).ToLower() -ne '.ps1' )
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                        -f $VM.name,$DSCConfigFile)
                }
                ThrowException @ExceptionParameters
            }

            if (-not (Test-Path $DSCConfigFile))
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                        -f $VM.name,$DSCConfigFile)
                }
                ThrowException @ExceptionParameters
            }
            if (-not $VM.DSC.ConfigName)
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                        -f $VM.name)
                }
                ThrowException @ExceptionParameters
            }
        }
        
        # Load the DSC Parameters
        [String] $DSCParameters = ''
        if ($VM.DSC.Parameters)
        {
            # Correct any LFs into CRLFs to ensure the new line format is the same when
            # pulled from the XML.
            $DSCParameters = ($VM.DSC.Parameters -replace "`r`n","`n") -replace "`n","`r`n"
        } # if

        # Load the DSC Parameters
        [Boolean] $DSCLogging = $False
        if ($VM.DSC.Logging -eq 'Y')
        {
            $DSCLogging = $True
        } # if

        # Get the Memory Startup Bytes (from the template or VM)
        [Int64] $MemoryStartupBytes = 1GB
        if ($VM.memorystartupbytes)
        {
            $MemoryStartupBytes = (Invoke-Expression $VM.memorystartupbytes)
        }
        elseif ($VMTemplate.memorystartupbytes)
        {
            $MemoryStartupBytes = $VMTemplate.memorystartupbytes
        } # if

        # Get the Dynamic Memory Enabled flag
        [String] $DynamicMemoryEnabled = ''
        if ($VM.DynamicMemoryEnabled)
        {
            $DynamicMemoryEnabled = $VM.DynamicMemoryEnabled
        }        
        elseif ($VMTemplate.DynamicMemoryEnabled)
        {
            $DynamicMemoryEnabled = $VMTemplate.DynamicMemoryEnabled
        } #if
        
        # Get the Memory Startup Bytes (from the template or VM)
        [Int] $ProcessorCount = 1
        if ($VM.processorcount) 
		{
            $ProcessorCount = (Invoke-Expression $VM.processorcount)
        }
        elseif ($VMTemplate.processorcount) 
		{
            $ProcessorCount = $VMTemplate.processorcount
        } # if

        # Get the Expose Virtualization Extensions flag
        [String] $ExposeVirtualizationExtensions = $null
        if ($VM.ExposeVirtualizationExtensions)
        {
            $ExposeVirtualizationExtensions = $VM.ExposeVirtualizationExtensions
        }
        elseif ($VMTemplate.ExposeVirtualizationExtensions)
		{
            $ExposeVirtualizationExtensions=$VMTemplate.ExposeVirtualizationExtensions
        } # if
        
        # Get the Integration Services flags
        if ($VM.IntegrationServices -ne $null)
        {
            $IntegrationServices = $VM.IntegrationServices
        } 
        elseif ($VMTemplate.IntegrationServices -ne $null)
        {
            $IntegrationServices = $VMTemplate.IntegrationServices
        } # if
        
        # Get the Administrator password (from the template or VM)
        [String] $AdministratorPassword = ''
        if ($VM.administratorpassword) 
		{
            $AdministratorPassword = $VM.administratorpassword
        }
        elseif ($VMTemplate.administratorpassword) 
		{
            $AdministratorPassword = $VMTemplate.administratorpassword
        } # if

        # Get the Product Key (from the template or VM)
        [String] $ProductKey = ''
        if ($VM.productkey) 
		{
            $ProductKey = $VM.productkey
        }
        elseif ($VMTemplate.productkey) 
		{
            $ProductKey = $VMTemplate.productkey
        } # If

        # Get the Timezone (from the template or VM)
        [String] $Timezone = 'Pacific Standard Time'
        if ($VM.timezone) 
		{
            $Timezone = $VM.timezone
        }
        elseif ($VMTemplate.timezone) 
		{
            $Timezone = $VMTemplate.timezone
        } # If

        # Get the OS Type
        [String] $OSType = 'Server'
        if ($VM.ostype) 
		{
            $OSType = $VM.ostype
        }
        elseif ($VMTemplate.ostype) 
		{
            $OSType = $VMTemplate.ostype
        } # if 

        # Get the Packages
        [String] $Packages = $null
        if ($VM.packages) 
		{
            $Packages = $VM.packages
        }
        elseif ($VMTemplate.packages) 
		{
            $Packages = $VMTemplate.packages
        } # if 

        # Do we have any MSU files that are listed as needing to be applied to the OS before
        # first boot up?
        [String[]] $InstallMSU = @()
        foreach ($Update in $VM.Install.MSU) 
		{
            $InstallMSU += $Update.URL
        } # Foreach

        $LabVMs += @{
            Name = $VM.name;
            ComputerName = $VM.ComputerName;
            Template = $VM.template;
            ParentVHD = $ParentVHDPath;
            UseDifferencingDisk = $VM.usedifferencingbootdisk;
            MemoryStartupBytes = $MemoryStartupBytes;
            DynamicMemoryEnabled = $DynamicMemoryEnabled;
            ProcessorCount = $ProcessorCount;
            ExposeVirtualizationExtensions = $ExposeVirtualizationExtensions;
            IntegrationServices = $IntegrationServices;
            AdministratorPassword = $AdministratorPassword;
            ProductKey = $ProductKey;
            TimeZone =$Timezone;
            Adapters = $VMAdapters;
            DataVHDs = $DataVHDs;
            UnattendFile = $UnattendFile;
            SetupComplete = $SetupComplete;
            DSCConfigFile = $DSCConfigFile;
            DSCConfigName = $VM.DSC.ConfigName;
            DSCParameters = $DSCParameters;
            DSCLogging = $DSCLogging;
            OSType = $OSType;
            Packages = $Packages;
            InstallMSU = $InstallMSU;
            VMRootPath = (Join-Path -Path $LabPath -ChildPath $VM.name);
            LabBuilderFilesPath = (Join-Path -Path $LabPath -ChildPath "$($VM.name)\LabBuilder Files");
        }
    } # Foreach        

    Return $LabVMs
} # Get-LabVM


<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VMs
   Array of Virtual Machines pulled from a configuration object.
.OUTPUTS
   None
#>
function Initialize-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [System.Collections.Hashtable[]] $VMs
    )
    
    # If the VMs list was not passed pull it
    if (-not $VMs)
    {
        $VMs = Get-LabVM -Config $Config
    }
    
    # If there are not VMs just return
    if (-not $VMs)
    {
        return
    }
    
    $CurrentVMs = Get-VM

    [String] $LabPath = $Config.labbuilderconfig.settings.labpath

    # Figure out the name of the LabBuilder control switch
    $ManagementSwitchName = ('LabBuilder Management {0}' -f $Config.labbuilderconfig.name)
    if ($Config.labbuilderconfig.switches.ManagementVlan)
    {
        [Int32] $ManagementVlan = $Config.labbuilderconfig.switches.ManagementVlan
    }
    else
    {
        [Int32] $ManagementVlan = $Script:DefaultManagementVLan
    }

    foreach ($VM in $VMs)
    {
        # Get the root path of the VM
        [String] $VMRootPath = $VM.VMRootPath

        # Get the Virtual Machine Path
        [String] $VMPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Machines'
            
        # Get the Virtual Hard Disk Path
        [String] $VHDPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Hard Disks'

        # Get Path to LabBuilder files
        [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -eq 0)
        {
            Write-Verbose -Message $($LocalizedData.CreatingVMMessage `
                -f $VM.Name)

            # Make sure the appropriate folders exist
            InitializeVMPaths `
                -VMPath $VMRootPath

            # Create the boot disk
            $VMBootDiskPath = "$VHDPath\$($VM.Name) Boot Disk.vhdx"
            if (-not (Test-Path -Path $VMBootDiskPath))
            {
                if ($VM.UseDifferencingDisk -eq 'Y')
                {
                    Write-Verbose -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Differencing Boot')

                    $Null = New-VHD -Differencing -Path $VMBootDiskPath -ParentPath $VM.ParentVHD
                }
                else
                {
                    Write-Verbose -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Boot')

                    $Null = Copy-Item `
                        -Path $VM.ParentVHD `
                        -Destination $VMBootDiskPath
                }
                
                # Create all the required initialization files for this VM
                CreateVMInitializationFiles `
                    -Config $Config `
                    -VM $VM

                # Because this is a new boot disk apply any required initialization
                InitializeBootVHD `
                    -Config $Config `
                    -VM $VM `
                    -VMBootDiskPath $VMBootDiskPath
            }
            else
            {
                Write-Verbose -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                    -f $VM.Name,$VMBootDiskPath,'Boot')
            } # If

            $null = New-VM `
                -Name $VM.Name `
                -MemoryStartupBytes $VM.MemoryStartupBytes `
                -Generation 2 `
                -Path $LabPath `
                -VHDPath $VMBootDiskPath
            # Remove the default network adapter created with the VM because we don't need it
            Remove-VMNetworkAdapter `
                -VMName $VM.Name `
                -Name 'Network Adapter'
        }

        # Set the processor count if different to default and if specified in config file
        if ($VM.ProcessorCount)
        {
            if ($VM.ProcessorCount -ne (Get-VM -Name $VM.Name).ProcessorCount)
            {
                Set-VM `
                    -Name $VM.Name `
                    -ProcessorCount $VM.ProcessorCount
            } # If
        } # If
        
        # Enable/Disable Dynamic Memory
        if ($VM.DynamicMemoryEnabled)
        {
            [Boolean] $DynamicMemoryEnabled = ($VM.DynamicMemoryEnabled -ne 'N')
            if ($DynamicMemoryEnabled -ne (Get-VMMemory -VMName $VM.Name).DynamicMemoryEnabled)
            {
                Set-VMMemory `
                    -VMName $VM.Name `
                    -DynamicMemoryEnabled:$DynamicMemoryEnabled
            } # If
        } # If

        
        # If the ExposeVirtualizationExtensions is configured then try and set this on 
        # Virtual Processor. Only supported in certain builds on Windows 10/Server 2016 TP4.
        if ($VM.ExposeVirtualizationExtensions)
        {
            [Boolean] $ExposeVirtualizationExtensions = ($VM.ExposeVirtualizationExtensions -eq 'Y') 
            if ($ExposeVirtualizationExtensions -ne (Get-VMProcessor -VMName $VM.Name).ExposeVirtualizationExtensions)
            {
                Set-VMProcessor `
                    -VMName $VM.Name `
                    -ExposeVirtualizationExtensions:$ExposeVirtualizationExtensions                
            }   
        }

        # Enable/Disable the Integration Services
        UpdateVMIntegrationServices `
            -VM $VM
        
        # Update the data disks for the VM
        UpdateVMDataDisks `
            -Config $Config `
            -VM $VM        
            
        # Create/Update the Management Network Adapter
        if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $ManagementSwitchName).Count -eq 0)
        {
            Write-Verbose -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                -f $VM.Name,$ManagementSwitchName,'Management')

            Add-VMNetworkAdapter -VMName $VM.Name -SwitchName $ManagementSwitchName -Name $ManagementSwitchName
        }
        $VMNetworkAdapter = Get-VMNetworkAdapter `
            -VMName $VM.Name `
            -Name $ManagementSwitchName
        $null = $VMNetworkAdapter | Set-VMNetworkAdapterVlan -Access -VlanId $ManagementVlan

        Write-Verbose -Message $($LocalizedData.SettingVMNetworkAdapterVlanMessage `
            -f $VM.Name,$ManagementSwitchName,'Management',$ManagementVlan)

        # Create any network adapters
        foreach ($VMAdapter in $VM.Adapters)
        {
            if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $VMAdapter.Name).Count -eq 0)
            {
                Write-Verbose -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                    -f $VM.Name,$VMAdapter.SwitchName,$VMAdapter.Name)

                Add-VMNetworkAdapter `
                    -VMName $VM.Name `
                    -SwitchName $VMAdapter.SwitchName `
                    -Name $VMAdapter.Name
            } # If

            $VMNetworkAdapter = Get-VMNetworkAdapter -VMName $VM.Name -Name $VMAdapter.Name
            $Vlan = $VMAdapter.VLan
            if ($VLan)
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapterVlan -Access -VlanId $Vlan

                Write-Verbose -Message $($LocalizedData.SettingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'',$Vlan)
            }
            else
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapterVlan -Untagged

                Write-Verbose -Message $($LocalizedData.ClearingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'')
            } # If

            if ($VMAdapter.MACAddress)
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -StaticMacAddress $VMAdapter.MACAddress
            }
            else
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -DynamicMacAddress
            } # If

            # Enable Device Naming
            if ((Get-Command -Name Set-VMNetworkAdapter).Parameters.ContainsKey('DeviceNaming'))
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -DeviceNaming On
            }
            if ($VMAdapter.MACAddressSpoofing -ne $VMNetworkAdapter.MACAddressSpoofing)
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -MacAddressSpoofing $VMAdapter.MACAddressSpoofing
            }                
        } # Foreach

        Start-LabVM `
            -Config $Config `
            -VM $VM
    } # Foreach
} # Initialize-LabVM


<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
#>
function Start-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $VM
    )

    [String] $LabPath = $Config.labbuilderconfig.settings.labpath

    # The VM is now ready to be started
    if ((Get-VM -Name $VM.Name).State -eq 'Off')
    {
        Write-Verbose -Message $($LocalizedData.StartingVMMessage `
            -f $VM.Name)

        Start-VM -VMName $VM.Name
    } # If

    # We only perform this section of VM Initialization (DSC, Cert, etc) with Server OS
    if ($VM.OSType -eq 'Server')
    {
        # Has this VM been initialized before (do we have a cert for it)
        if (-not (Test-Path "$LabPath\$($VM.Name)\LabBuilder Files\$Script:DSCEncryptionCert"))
        {
            # No, so check it is initialized and download the cert.
            if (WaitVMInitializationComplete -VM $VM -ErrorAction Continue)
            {
                Write-Verbose -Message $($LocalizedData.CertificateDownloadStartedMessage `
                    -f $VM.Name)
                    
                if (GetSelfSignedCertificate -Config $Config -VM $VM)
                {
                    Write-Verbose -Message $($LocalizedData.CertificateDownloadCompleteMessage `
                        -f $VM.Name)
                }
                else
                {
                    $ExceptionParameters = @{
                        errorId = 'CertificateDownloadError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.CertificateDownloadError `
                            -f $VM.name)
                    }
                    ThrowException @ExceptionParameters
                } # If
            }
            else
            {
                $ExceptionParameters = @{
                    errorId = 'InitializationDidNotCompleteError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InitializationDidNotCompleteError `
                        -f $VM.name)
                }
                ThrowException @ExceptionParameters
            } # If
        } # If

        # Create any DSC Files for the VM
        InitializeDSC `
            -Config $Config `
            -VM $VM

        # Attempt to start DSC on the VM
        StartDSC `
            -Config $Config `
            -VM $VM
    } # If
} # Start-LabVM


<#
.SYNOPSIS
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
#>
function Remove-LabVM {
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [XML] $Config,

        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]] $VMs,

        [Switch] $RemoveVHDs
    )
    
    # If VMs not passed then pull them from the config
    if (-not $VMs)
    {
        $VMs = Get-LabVM -Config $Config
    }
    
    $CurrentVMs = Get-VM

    # Get the LabPath
    [String] $LabPath = $Config.labbuilderconfig.settings.labpath
    
    foreach ($VM in $VMs)
    {
        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -ne 0)
        {
            # If the VM is running we need to shut it down.
            if ((Get-VM -Name $VM.Name).State -eq 'Running')
            {
                Write-Verbose -Message $($LocalizedData.StoppingVMMessage `
                    -f $VM.Name)

                Stop-VM -Name $VM.Name
                # Wait for it to completely shut down and report that it is off.
                WaitVMOff -VM $VM
            }

            Write-Verbose -Message $($LocalizedData.RemovingVMMessage `
                -f $VM.Name)

            # Should we also delete the VHDs from the VM?
            if ($RemoveVHDs)
            {
                Write-Verbose -Message $($LocalizedData.DeletingVMAllDisksMessage `
                    -f $VM.Name)

                $null = Get-VMHardDiskDrive -VMName $VM.Name | Select-Object -Property Path | Remove-Item
            }
            
            # Now delete the actual VM
            Get-VM -Name $VM.Name | Remove-VM -Confirm:$false

            Write-Verbose -Message $($LocalizedData.RemovedVMMessage `
                -f $VM.Name)
        }
        else
        {
            Write-Verbose -Message $($LocalizedData.VMNotFoundMessage `
                -f $VM.Name)
        }
    }
    Return $true
} # Remove-LabVM


<#
.SYNOPSIS
   Connects to a running VM.
.DESCRIPTION
   This cmdlet will connect to a running VM using PSRemoting. A PSSession object will be returned
   if the connection was successful.
   
   If the connection fails, it will be retried until the ConnectTimeout is reached. If the
   ConnectTimeout is reached and a connection has not been established then a ConnectionError 
   exception will be thrown.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   $Session = Connect-LabVM -VM $VMs[0]
   Connect to the first VM in the Lab c:\mylab\config.xml.
.PARAMETER VM
   The VM Object referring to the VM to connect to.
.PARAMETER ConnectTimeout
   The number of seconds the connection will attempt to be established for. Defaults to 300 seconds.
.OUTPUTS
   The PSSession object of the remote connect or null if the connection failed.
#>
function Connect-LabVM
{
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM,
        
        [Int] $ConnectTimeout = 300
    )

    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [PSCredential] $AdminCredential = CreateCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword
    [Boolean] $FatalException = $False
    
    while (($Session -eq $null) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $ConnectTimeout `
        -and -not $FatalException)
    {
        try
        {                
            # Get the Management IP Address of the VM
            # We repeat this because the IP Address will only be assiged 
            # once the VM is fully booted.
            $IPAddress = GetVMManagementIPAddress `
                -Config $Config `
                -VM $VM
            
            # Add the IP Address to trusted hosts if not already in it
            # This could be avoided if able to use SSL or if PS Direct is used.
            # Also, don't add if TrustedHosts is already *
            $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
            if (($TrustedHosts -notlike "*$IPAddress*") -and ($TrustedHosts -ne '*'))
            {
                if ([String]::IsNullOrWhitespace($TrustedHosts))
                {
                    $TrustedHosts = $IPAddress
                }
                else
                {
                    $TrustedHosts = "$TrustedHosts,$IPAddress"
                }
                Set-Item `
                    -Path WSMAN::localhost\Client\TrustedHosts `
                    -Value $TrustedHosts `
                    -Force
                Write-Verbose -Message $($LocalizedData.AddingIPAddressToTrustedHostsMessage `
                    -f $VM.Name,$IPAddress)
            }
        
            Write-Verbose -Message $($LocalizedData.ConnectingVMMessage `
                -f $VM.Name,$IPAddress)

            # TODO: Convert to PS Direct once supported for this cmdlet.
            $Session = New-PSSession `
                -Name 'LabBuilder' `
                -ComputerName $IPAddress `
                -Credential $AdminCredential `
                -ErrorAction Stop
        }
        catch
        {
            if (-not $IPAddress)
            {
                Write-Verbose -Message $($LocalizedData.WaitingForIPAddressAssignedMessage `
                    -f $VM.Name,$Script:RetryConnectSeconds)                                
            }
            else
            {
                Write-Verbose -Message $($LocalizedData.ConnectingVMFailedMessage `
                    -f $VM.Name,$Script:RetryConnectSeconds,$_.Exception.Message)
            }
            Start-Sleep -Seconds $Script:RetryConnectSeconds
        } # Try
    } # While
    
    # If a fatal exception occured or the connection just couldn't be established
    # then throw an exception so it can be caught by the calling code.
    if ($FatalException -or ($Session -eq $null))
    {
        # The connection failed so throw an error
        $ExceptionParameters = @{
            errorId = 'RemotingConnectionError'
            errorCategory = 'ConnectionError'
            errorMessage = $($LocalizedData.RemotingConnectionError `
                -f $VM.Name)
        }
        ThrowException @ExceptionParameters
    }
    Return $Session
} # Connect-LabVM


<#
.SYNOPSIS
   Disconnects from a running VM.
.DESCRIPTION
   This cmdlet will disconnect a session from a running VM using PSRemoting.
.PARAMETER VM
   The VM Object referring to the VM to connect to.
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   Disconnect-LabVM -VM $VMs[0]
   Disconnect from the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
   None
#>
function Disconnect-LabVM
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )

    [PSCredential] $AdminCredential = CreateCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword

    # Get the Management IP Address of the VM
    $IPAddress = GetVMManagementIPAddress `
        -Config $Config `
        -VM $VM

    try
    {                
        # Look for the session
        $Session = Get-PSSession `
            -Name 'LabBuilder' `
            -ComputerName $IPAddress `
            -Credential $AdminCredential `
            -ErrorAction Stop       

        if (-not $Session)
        {
            # No session found to this machine so nothing to do.
            Write-Verbose -Message $($LocalizedData.VMSessionDoesNotExistMessage `
                -f $VM.Name)        
        }
        else
        {
            if ($Session.State -eq 'Opened')
            {
                # Disconnect the session
                $null = $Session | Disconnect-PSSession
                Write-Verbose -Message $($LocalizedData.DisconnectingVMMessage `
                    -f $VM.Name,$IPAddress)                    
            }
            # Remove the session
            $null = $Session | Remove-PSSession 
        }
    }
    catch
    {
        Throw $_
    }
    finally
    {
        # Remove the entry from TrustedHosts
        $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
        if (($TrustedHosts -like "*$IPAddress*") -and ($TrustedHosts -ne '*'))
        {
            # Lazy code to remove IP address if it is in the middle
            # at the end or the beginning of the TrustedHosts list
            $TrustedHosts = $TrustedHosts -replace ",$IPAddress,",','
            $TrustedHosts = $TrustedHosts -replace "$IPAddress,",''
            $TrustedHosts = $TrustedHosts -replace ",$IPAddress",''
            Set-Item `
                -Path WSMAN::localhost\Client\TrustedHosts `
                -Value $TrustedHosts `
                -Force
            Write-Verbose -Message $($LocalizedData.RemovingIPAddressFromTrustedHostsMessage `
                -f $VM.Name,$IPAddress)
        }
    } # try
} # Disconnect-LabVM


#region LabInstallationFunctions
<#
.SYNOPSIS
    Install or Update a Lab.
.DESCRIPTION
    This cmdlet will install an entire Hyper-V lab environment defined by the
    LabBuilder configuration file provided.
    
    If components of the Lab already exist, they will be updated if they differ
    from the settings in the Configuration file.
   
    The Hyper-V component can also be optionally installed if it is not.
.PARAMETER Path
    The path to the LabBuilder configuration XML file.
.PARAMETER CheckEnvironment
    Whether or not to check if Hyper-V is installed and install it if missing.
.EXAMPLE
    Install-Lab -Path c:\mylab\config.xml
    Install the lab defined in the c:\mylab\config.xml LabBuilder configuraiton file.
.OUTPUTS
    None
#>
Function Install-Lab {
    [CmdLetBinding()]
    param
    (
        [parameter(Mandatory)]
        [String] $Path,

        [Switch] $CheckEnvironment
    ) # Param

    # Read the configuration
    [XML] $Config = Get-LabConfiguration `
        -Path $Path
    
    if ($CheckEnvironment)
    {
        # Check Hyper-V
        Install-LabHyperV
    }

    # Initialize the Lab Config
    Initialize-LabConfiguration `
        -Config $Config

    # Initialize the Switches
    $Switches = Get-LabSwitch `
        -Config $Config
    Initialize-LabSwitch `
        -Config $Config `
        -Switches $Switches

    # Initialize the VM Template VHDs
    $VMTemplateVHDs = Get-LabVMTemplateVHD `
        -Config $Config
    Initialize-LabVMTemplateVHD `
        -Config $Config `
        -VMTemplateVHDs $VMTemplateVHDs

    # Initialize the VM Templates
    $VMTemplates = Get-LabVMTemplate `
        -Config $Config
    Initialize-LabVMTemplate `
        -Config $Config `
        -VMTemplates $VMTemplates

    # Initialize the VMs
    $VMs = Get-LabVM `
        -Config $Config `
        -VMTemplates $VMTemplates `
        -Switches $Switches
    Initialize-LabVM `
        -Config $Config `
        -VMs $VMs 
} # Install-Lab


<#
.SYNOPSIS
   Uninstall the components of an existing Lab.
.DESCRIPTION
   This function will attempt to remove the components of the lab specified
   in the provided LabBuilder configuration file.
   
   It will always remove any Lab Virtual Machines, but can also optionally
   remove:
   Switches
   VM Templates
   VM Template VHDs
.PARAMETER Path
    The path to the LabBuilder configuration XML file.
.PARAMETER RemoveSwitches
    Whether to remove the swtiches defined by this Lab.
.PARAMETER RemoveVMTemplates
    Whether to remove the VM Templates created by this Lab.
.PARAMETER RemoveVHDs
    Whether to remove any VHD files attached to the Lab virtual
    machines.
.PARAMETER RemoveVMTemplateVHDs
    Whether to remove any created VM Template VHDs.
.EXAMPLE
    Uninstall-Lab `
        -Path c:\mylab\config.xml `
        -RemoveSwitches`
        -RemoveVMTemplates `
        -RemoveVHDs `
        -RemoveVMTemplateVHDs
    Completely uninstall all components in the lab defined in the
    c:\mylab\config.xml LabBuilder configuraiton file.
.OUTPUTS
   None
#>
Function Uninstall-Lab {
    [CmdLetBinding()]
    param
    (
        [parameter(Mandatory)]
        [String] $Path,

        [Switch] $RemoveSwitches,

        [Switch] $RemoveVMTemplates,

        [Switch] $RemoveVHDs,
        
        [Swtich] $RemoveVMTemplateVHDs
    ) # Param

    # Read the configuration
    [XML] $Config = Get-LabConfiguration `
        -Path $Path

    # Remove the VMs
    $VMSplat = @{} 
    if ($RemoveVHDs)
    {
        $VMSplat += @{ RemoveVHDs = $true }
    }
    $null = Remove-LabVM `
        -Config $Config `
        -VMs $VMs `
        @VMSplat

    # Remove the VM Templates
    if ($RemoveVMTemplates)
    {
        $null = Remove-LabVMTemplate `
            -Config $Config
    } # If

    # Remove the VM Switches
    if ($RemoveSwitches)
    {
        $null = Remove-LabSwitch `
            -Config $Config
    } # If

    # Remove the VM Template VHDs
    if ($RemoveVMTemplateVHDs)
    {
        # TODO: Requires Remove-LabVMTemplateVHD function
    } # If
} # Uninstall-Lab
#endregion