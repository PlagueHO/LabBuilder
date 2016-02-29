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
        Write-Verbose -Message $($LocalizedData.ImportingLibFileMessage `
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

# DSC Library
[String] $Script:DSCLibraryPath = Join-Path -Path $PSScriptRoot -ChildPath 'DSCLibrary'

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
[Int] $Script:StartupTimeout = 90
[Int] $Script:ShutdownTimeout = 30

# XML Stuff
[String] $Script:ConfigurationXMLSchema = Join-Path -Path $PSScriptRoot -ChildPath 'schema\labbuilderconfig-schema.xsd'
[String] $Script:ConfigurationXMLTemplate = Join-Path -Path $PSScriptRoot -ChildPath 'template\labbuilderconfig-template.xml'

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


#region LabSwitchFunctions
<#
.SYNOPSIS
   Gets an array of switches from a Lab.
.DESCRIPTION
   Takes a provided Lab and returns the list of switches required for this Lab.
   
   This list is usually passed to Initialize-LabSwitch to configure the switches required for this lab.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of Switch names.
   
   Only Switches matching names in this list will be pulled into the returned in the array.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $Switches = Get-LabSwitch -Lab $Lab
   Loads a Lab and pulls the array of switches from it.
.OUTPUTS
   Returns an array of switches.
#>
function Get-LabSwitch {
    [OutputType([Array])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,
        
        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name
    )

    [String] $LabId = $Lab.labbuilderconfig.settings.labid 
    [Array] $Switches = @() 
#    $XMLNameSpace = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $Lab.NameTable
#    $XMLNameSpace.AddNamespace("labbuilderconfig", $Script:ConfigurationXMLSchema)
    $ConfigSwitches = $Lab.labbuilderconfig.Switches.Switch

    foreach ($ConfigSwitch in $ConfigSwitches)
    {
        # It can't be switch because if the name attrib/node is missing the name property on the
        # XML object defaults to the name of the parent. So we can't easily tell if no name was
        # specified or if they actually specified 'switch' as the name.
        $SwitchName = $ConfigSwitch.Name
        if ($Name -and ($SwitchName -notin $Name))
        {
            # A names list was passed but this swtich wasn't included
            continue
        } # if
        
        $SwitchType = $ConfigSwitch.Type
        if ($SwitchName -eq 'switch')
        {
            $ExceptionParameters = @{
                errorId = 'SwitchNameIsEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
            }
            ThrowException @ExceptionParameters
        }

        # if a LabId is set for the lab, prepend it to the Switch name as long as it isn't
        # an external switch.
        if ($LabId -and ($SwitchType -ne 'External'))
        {
            $SwitchName = "$LabId $SwitchName"
        } # if

        if ($SwitchType -notin 'Private','Internal','External','NAT')
        {
            $ExceptionParameters = @{
                errorId = 'UnknownSwitchTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                    -f $SwitchType,$SwitchName)
            }
            ThrowException @ExceptionParameters
        } # if

        # Assemble the list of Mangement OS Adapters if any are specified for this switch
        # Only Intenal and External switches are allowed Management OS adapters.
        if ($ConfigSwitch.Adapters)
        {
            [System.Collections.Hashtable[]] $ConfigAdapters = @()
            foreach ($Adapter in $ConfigSwitch.Adapters.Adapter)
            {
                $AdapterName = $Adapter.Name
                # if a LabId is set for the lab, prepend it to the adapter name.
                # But only if it is not an External switch.
                if ($LabId -and ($SwitchType -ne 'External'))
                {
                    $AdapterName = "$LabId $AdapterName"
                }

                $ConfigAdapters += @{
                    name = $AdapterName
                    macaddress = $Adapter.MacAddress
                }
            } # foreach
            if (($ConfigAdapters.Count -gt 0) `
                -and ($SwitchType -notin 'External','Internal'))
            {
                $ExceptionParameters = @{
                    errorId = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.AdapterSpecifiedError `
                        -f $SwitchType,$SwitchName)
                }
                ThrowException @ExceptionParameters
            } # if
        }
        else
        {
            $ConfigAdapters = $null
        } # if
        $Switches += [PSObject]@{
            name = $SwitchName
            type = $ConfigSwitch.Type;
            vlan = $ConfigSwitch.Vlan;
            natsubnetaddress = $ConfigSwitch.NatSubnetAddress;
            adapters = $ConfigAdapters }
            
    } # foreach
    return $Switches
} # Get-LabSwitch


<#
.SYNOPSIS
   Creates Hyper-V Virtual Switches from a provided array.
.DESCRIPTION
   Takes an array of switches that were pulled from a Lab object by calling
   Get-LabSwitch and ensures that they Hyper-V Virtual Switches on the system
   are configured to match.
.PARAMETER Lab
   Contains Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of Switch names.
   
   Only Switches matching names in this list will be initialized.
.PARAMETER Switches
   The array of switches pulled from the Lab using Get-LabSwitch.

   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $Switches = Get-LabSwitch -Lab $Lab
   Initialize-LabSwitch -Lab $Lab -Switches $Switches
   Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Initialize-LabSwitch -Lab $Lab
   Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Initialize-LabSwitch {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,
        
        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,

        [Parameter(
            Position=3)]
        [Array] $Switches
    )

    # if switches was not passed, pull it.
    if (-not $PSBoundParameters.ContainsKey('switches'))
    {
        $Switches = Get-LabSwitch `
            @PSBoundParameters
    }
    
    # Create Hyper-V Switches
    foreach ($VMSwitch in $Switches)
    {
        if ($Name -and ($VMSwitch.name -notin $Name))
        {
            # A names list was passed but this swtich wasn't included
            continue
        } # if
        
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
                                    -Name $Adapter.Name `
                                    -StaticMacAddress $Adapter.MacAddress `
                                    
                                    -Passthru | `
                                    Set-VMNetworkAdapterVlan -Access -VlanId $($Switch.Vlan)
                            }
                            Else
                            { 
                                $null = Add-VMNetworkAdapter `
                                    -ManagementOS `
                                    -SwitchName $SwitchName `
                                    -Name $Adapter.Name `
                                    -StaticMacAddress $Adapter.MacAddress
                            } # if
                        } # foreach
                    } # if
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
                            } # if
                        } # foreach
                    } # if
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
        } # if
    } # foreach       
} # Initialize-LabSwitch


<#
.SYNOPSIS
   Removes all Hyper-V Virtual Switches provided.
.DESCRIPTION
   This cmdlet is used to remove any Hyper-V Virtual Switches that were created by
   the Initialize-LabSwitch cmdlet.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of Switch names.
   
   Only Switches matching names in this list will be removed.
.PARAMETER Switches
   The array of switches pulled from the Lab using Get-LabSwitch.

   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $Switches = Get-LabSwitch -Lab $Lab
   Remove-LabSwitch -Lab $Lab -Switches $Switches
   Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Remove-LabSwitch -Lab $Lab
   Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Remove-LabSwitch {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,

        [Parameter(
            Position=3)]
        [Array] $Switches
    )

    # if switches were not passed so pull them
    if (-not $PSBoundParameters.ContainsKey('switches'))
    {
        $Switches = Get-LabSwitch `
            @PSBoundParameters
    }

    # Delete Hyper-V Switches
    foreach ($Switch in $Switches)
    {
        if ($Name -and ($Switch.name -notin $Name))
        {
            # A names list was passed but this swtich wasn't included
            continue
        } # if

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
                    } # if
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
                    } # if
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
        } # if
    } # foreach        
} # Remove-LabSwitch
#endregion


#region LabVMTemplateVHDFunctions
<#
.SYNOPSIS
   Gets an Array of TemplateVHDs for a Lab.
.DESCRIPTION
   Takes a provided Lab and returns the list of Template Disks that will be used to 
   create the Virtual Machines in this lab. This list is usually passed to
   Initialize-LabVMTemplateVHD.
   
   It will validate the paths to the ISO folder as well as to the ISO files themselves.
   
   If any ISO files references can't be found an exception will be thrown.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM Template VHD names.
   
   Only VM Template VHDs matching names in this list will be returned in the array.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
   Loads a Lab and pulls the array of TemplateVHDs from it.
.OUTPUTS
   Returns an array of TemplateVHDs. It will return Null if the TemplateVHDs node does
   not exist or contains no TemplateVHD nodes.
#>
function Get-LabVMTemplateVHD {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter (
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name
    )

    # return null if the TemplateVHDs node does not exist
    if (-not $Lab.labbuilderconfig.TemplateVHDs)
    {
        return
    }
    
    # Determine the ISORootPath where the ISO files should be found
    # if no path is specified then look in the same path as the config
    # if a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $ISORootPath = $Lab.labbuilderconfig.TemplateVHDs.ISOPath
    if (-not $ISORootPath)
    {
        $ISORootPath = $Lab.labbuilderconfig.settings.fullconfigpath
    }
    else
    {
        if (-not [System.IO.Path]::IsPathRooted($ISORootPath))
        {
            $ISORootPath = Join-Path `
                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $ISORootPath
        } # if
    } # if
    if (-not (Test-Path -Path $ISORootPath -Type Container))
    {
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDISORootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDISORootPathNotFoundError `
                -f $ISORootPath)
        }
        ThrowException @ExceptionParameters
    } # if

    # Determine the VHDRootPath where the VHD files should be put
    # if no path is specified then look in the same path as the config
    # if a path is specified but it is relative, make it relative to the
    # config path. Otherwise use it as is.
    [String] $VHDRootPath = $Lab.labbuilderconfig.TemplateVHDs.VHDPath
    if (-not $VHDRootPath)
    {
        $VHDRootPath = $Lab.labbuilderconfig.settings.fullconfigpath
    }
    else
    {
        if (-not [System.IO.Path]::IsPathRooted($VHDRootPath))
        {
            $VHDRootPath = Join-Path `
                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VHDRootPath
        } # if
    } # if
    if (-not (Test-Path -Path $VHDRootPath -Type Container))
    {
        $ExceptionParameters = @{
            errorId = 'VMTemplateVHDRootPathNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMTemplateVHDRootPathNotFoundError `
                -f $VHDRootPath)
        }
        ThrowException @ExceptionParameters
    } # if

    $TemplatePrefix = $Lab.labbuilderconfig.templatevhds.prefix

    # Read the list of templateVHD from the configuration file
    $TemplateVHDs = $Lab.labbuilderconfig.templatevhds.templatevhd
    [System.Collections.Hashtable[]] $VMTemplateVHDs = @()
    foreach ($TemplateVHD in $TemplateVHDs)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'templatevhd' as the name.
        $TemplateVHDName = $TemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        if (($TemplateVHDName -eq 'TemplateVHD') `
            -or ([String]::IsNullOrWhiteSpace($TemplateVHDName)))
        {
            $ExceptionParameters = @{
                errorId = 'EmptyVMTemplateVHDNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.EmptyVMTemplateVHDNameError)
            }
            ThrowException @ExceptionParameters
        } # if
        
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
        } # if

        # Adjust the ISO Path if required
        if (-not [System.IO.Path]::IsPathRooted($ISOPath))
        {
            $ISOPath = Join-Path `
                -Path $ISORootPath `
                -ChildPath $ISOPath
        } # if
        
        # Does the ISO Exist?
        if (-not (Test-Path -Path $ISOPath))
        {
            $URL = $TemplateVHD.URL
            if ($URL)
            {
                Write-Output `
                    -ForegroundColor Yellow `
                    -Object $($LocalizedData.ISONotFoundDownloadURLMessage `
                        -f $TemplateVHD.Name,$ISOPath,$URL)
            } # if
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
        } # if

        # Adjust the VHD Path if required
        if (-not [System.IO.Path]::IsPathRooted($VHDPath))
        {
            $VHDPath = Join-Path `
                -Path $VHDRootPath `
                -ChildPath $VHDPath
        } # if
        
        # Add the template prefix to the VHD name.
        if ([String]::IsNullOrWhitespace($TemplatePrefix))
        {
             $VHDPath = Join-Path `
                -Path (Split-Path -Path $VHDPath)`
                -ChildPath ("$TemplatePrefix$(Split-Path -Path $VHDPath -Leaf)")
        } # if
        
        # Get the Template OS Type 
        [String] $OSType = 'Server'
        if ($TemplateVHD.OSType)
        {
            $OSType = $TemplateVHD.OSType
        } # if
        if ($OSType -notin @('Server','Client','Nano') )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDOSTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDOSTypeError `
                    -f $TemplateVHD.Name,$OSType)
            }
            ThrowException @ExceptionParameters            
        } # if

		# Get the Template Wim Image to use
        $Edition = $null
        if ($TemplateVHD.Edition)
        {
            $Edition = $TemplateVHD.Edition
        } # if

        # Get the Template VHD Format 
        [String] $VHDFormat = 'VHDX'
        if ($TemplateVHD.VHDFormat)
        {
            $VHDFormat = $TemplateVHD.VHDFormat
        } # if
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
        } # if
        if ($VHDType -notin @('Dynamic','Fixed') )
        {
            $ExceptionParameters = @{
                errorId = 'InvalidVMTemplateVHDVHDTypeError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.InvalidVMTemplateVHDVHDTypeError `
                    -f $TemplateVHD.Name,$VHDType)
            }
            ThrowException @ExceptionParameters            
        } # if
        
        # Get the disk size if provided
        [Int64] $Size = 25GB
        if ($TemplateVHD.VHDSize)
        {
            $VHDSize = (Invoke-Expression $TemplateVHD.VHDSize)         
        } # if

        # Get the Template VM Generation 
        [int] $Generation = 2
        if ($TemplateVHD.Generation)
        {
            $Generation = $TemplateVHD.Generation
        } # if
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
        } # if

        # Get the Template Features
        if ($TemplateVHD.features)
        {
            $Features = $TemplateVHD.Features
        } # if

		# Add template VHD to the list
            $VMTemplateVHDs += @{
                Name = $TemplateVHDName;
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
     } # foreach
    Return $VMTemplateVHDs
} # Get-LabVMTemplateVHD


<#
.SYNOPSIS
	Scans through a list of VM Template VHDs and creates them from the ISO if missing.
.DESCRIPTION
	This function will take a list of VM Template VHDs from a Lab or it will
    extract the list itself if it is not provided and ensure that each VHD file is available.
    
    If the VHD file is not available then it will attempt to create it from the ISO.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM Template VHD names.
   
   Only VM Template VHDs matching names in this list will be initialized.
.PARAMETER VMTemplateVHDs
   The array of VMTemplateVHDs pulled from the Lab using Get-LabVMTemplateVHD
   
   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
   Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs
   Loads a Lab and pulls the array of VM Template VHDs from it and then
   ensures all the VHDs are available.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Initialize-LabVMTemplateVHD -Lab $Lab
   Loads a Lab and then ensures VM Template VHDs all the VHDs are available.
.OUTPUTS
    None. 
#>
function Initialize-LabVMTemplateVHD
{
   param
   (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,

        [Parameter(
            Position=3)]
	    [Array] $VMTemplateVHDs
    )

    # if VMTeplateVHDs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplateVHDs'))
    {
        $VMTemplateVHDs = Get-LabVMTemplateVHD `
            @PSBoundParameters        
    } # if

    # if there are no VMTemplateVHDs just return
    if ($null -eq $VMTemplateVHDs)
    {
        return
    } # if
    
    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [String] $TemplateVHDName = $VMTemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        [String] $VHDPath = $VMTemplateVHD.VHDPath
        
        if (Test-Path -Path ($VHDPath))
        {
            # The SourceVHD already exists
            Write-Verbose -Message $($LocalizedData.SkipVMTemplateVHDFileMessage `
                -f $TemplateVHDName,$VHDPath)

            continue
        } # if
        
        # Create the VHD
        Write-Verbose -Message $($LocalizedData.CreatingVMTemplateVHDMessage `
            -f $TemplateVHDName,$VHDPath)
            
        # Check the ISO exists.
        [String] $ISOPath = $VMTemplateVHD.ISOPath
        if (-not (Test-Path -Path $ISOPath))
        {
            $ExceptionParameters = @{
                errorId = 'VMTemplateVHDISOPathNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateVHDISOPathNotFoundError `
                    -f $TemplateVHDName,$ISOPath)
            }
            ThrowException @ExceptionParameters            
        } # if
        
        # Mount the ISO so we can read the files.
        Write-Verbose -Message $($LocalizedData.MountingVMTemplateVHDISOMessage `
                -f $TemplateVHDName,$ISOPath)
                
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
        } # if

        # This will have to change depending on the version
        # of Convert-WindowsImage being used. 
        [String] $VHDFormat = $VMTemplateVHD.VHDFormat       
        [String] $VHDType = $VMTemplateVHD.VHDType       
        [String] $VHDDiskLayout = 'UEFI'
        if ($VMTemplateVHD.Generation -eq 1)
        {
            $VHDDiskLayout = 'BIOS'
        } # if

        [String] $Edition = $VMTemplateVHD.Edition
        # if edition is not set then use Get-WindowsImage to get the name
        # of the first image in the WIM.
        if ([String]::IsNullOrWhiteSpace($Edition))
        {
            $Edition = (Get-WindowsImage `
                -ImagePath $SourcePath `
                -Index 1).ImageName
        } # if

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
        if ($null -ne $VMTemplateVHD.VHDSize)
        {
            $ConvertParams += @{
                sizebytes = $VMTemplateVHD.VHDSize
            }
        } # if
        
        # Are any features specified?
        if (-not [String]::IsNullOrWhitespace($VMTemplateVHD.Features))
        {
            $Features = @($VMTemplateVHD.Features -split ',')
            $ConvertParams += @{
                feature = $Features
            }
        } # if
        
        # Perform Nano Server package prep
        if ($VMTemplateVHD.OSType -eq 'Nano')
        {
            # Make a copy of the all the Nano packages in the VHD root folder
            # So that if any VMs need to add more packages they are accessible
            # once the ISO has been dismounted.
            [String] $VHDFolder = Split-Path `
                -Path $VHDPath `
                -Parent

            [String] $LabPackagesFolder = Join-Path `
                -Path $VHDFolder `
                -ChildPath 'NanoServerPackages'
            
            if (-not (Test-Path -Path $LabPackagesFolder -Type Container))
            {
                Write-Verbose -Message $($LocalizedData.CachingNanoServerPackagesMessage `
                        -f "$ISODrive\Nanoserver\Packages",$LabPackagesFolder)
                Copy-Item `
                    -Path "$ISODrive\Nanoserver\Packages" `
                    -Destination $VHDFolder `
                    -Recurse `
                    -Force
                Rename-Item `
                    -Path "$VHDFolder\Packages" `
                    -NewName 'NanoServerPackages'
            } # if
                                        
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
        } # if
        
        # Call the Convert-WindowsImage script
        Convert-WindowsImage @ConvertParams

        # Dismount the ISO.
        Write-Verbose -Message $($LocalizedData.DismountingVMTemplateVHDISOMessage `
                -f $TemplateVHDName,$ISOPath)

        $null = Dismount-DiskImage `
            -ImagePath $ISOPath

    } # endfor
} # Initialize-LabVMTemplateVHD


<#
.SYNOPSIS
	Scans through a list of VM Template VHDs and removes them if they exist.
.DESCRIPTION
	This function will take a list of VM Template VHDs from a Lab or it will
    extract the list itself if it is not provided and remove the VHD file if it exists.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM Template VHD names.
   
   Only VM Template VHDs matching names in this list will be removed.
.PARAMETER VMTemplateVHDs
   The array of VMTemplateVHDs pulled from the Lab using Get-LabVMTemplateVHD.
   
   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
   Remove-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs
   Loads a Lab and pulls the array of VM Template VHDs from it and then
   ensures all the VM template VHDs are deleted.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Remove-LabVMTemplateVHD -Lab $Lab
   Loads a Lab and then ensures the VM template VHDs are deleted.
.OUTPUTS
    None. 
#>
function Remove-LabVMTemplateVHD
{
   param
   (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,

        [Parameter(
            Position=3)]
	    [Array] $VMTemplateVHDs
    )

    # if VMTeplateVHDs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplateVHDs'))
    {
        $VMTemplateVHDs = Get-LabVMTemplateVHD `
           @PSBoundParameters   
    } # if

    # if there are no VMTemplateVHDs just return
    if ($null -eq $VMTemplateVHDs)
    {
        return
    } # if
    
    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    foreach ($VMTemplateVHD in $VMTemplateVHDs)
    {
        [String] $TemplateVHDName = $VMTemplateVHD.Name
        if ($Name -and ($TemplateVHDName -notin $Name))
        {
            # A names list was passed but this VM Template VHD wasn't included
            continue
        } # if

        [String] $VHDPath = $VMTemplateVHD.VHDPath
        
        if (Test-Path -Path ($VHDPath))
        {
            Remove-Item `
                -Path $VHDPath `
                -Force
            Write-Verbose -Message $($LocalizedData.DeletingVMTemplateVHDFileMessage `
                -f $TemplateVHDName,$VHDPath)
        } # if
    } # endfor
} # Remove-LabVMTemplateVHD


<#
.SYNOPSIS
   Gets an Array of VM Templates for a Lab.
.DESCRIPTION
   Takes the provided Lab and returns the list of Virtul Machine template machines
   that will be used to create the Virtual Machines in this lab.
   
   This list is usually passed to Initialize-LabVMTemplate.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM Template names.
   
   Only VM Templates matching names in this list will be returned in the array.
.PARAMETER VMTemplateVHDs
   The array of VMTemplateVHDs pulled from the Lab using Get-LabVMTemplateVHD.
   
   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Lab $Lab
   Loads a Lab and pulls the array of VMTemplates from it.
.OUTPUTS
   Returns an array of VM Templates.
#>
function Get-LabVMTemplate {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,
        
        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,
        
        [Parameter(
            Position=3)]
        [Array] $VMTemplateVHDs        
    )

    # if VMTeplateVHDs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplateVHDs'))
    {
        $VMTemplateVHDs = Get-LabVMTemplateVHD `
            -Lab $Lab
    }
    
    [System.Collections.Hashtable[]] $VMTemplates = @()
    [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
    
    # Get a list of all templates in the Hyper-V system matching the phrase found in the fromvm
    # config setting
    [String] $FromVM=$Lab.labbuilderconfig.templates.fromvm
    if ($FromVM)
    {
        $Templates = @(Get-VM -Name $FromVM)
        foreach ($Template in $Templates)
        {
            if ($Name -and ($Template.Name -notin $Name))
            {
                # A names list was passed but this VM Template wasn't included
                continue
            } # if

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
    $Templates = $Lab.labbuilderconfig.templates.template
    foreach ($Template in $Templates)
    {
        # It can't be template because if the name attrib/node is missing the name property on
        # the XML object defaults to the name of the parent. So we can't easily tell if no name
        # was specified or if they actually specified 'template' as the name.
        $TemplateName = $Template.Name
        if ($Name -and ($TemplateName -notin $Name))
        {
            # A names list was passed but this VM Template wasn't included
            continue
        } # if

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
            } # if
        } # foreach
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

                # if a VHD filename wasn't specified in the TemplateVHD
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
            # if this is a relative path, add it to the config path
            if ([System.IO.Path]::IsPathRooted($SourceVHD))
            {
                $VMTemplate.sourcevhd = $SourceVHD                
            }
            else
            {
                $VMTemplate.sourcevhd = Join-Path `
                    -Path $Lab.labbuilderconfig.settings.fullconfigpath `
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
            
            # if a VHD filename wasn't specified in the Template
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
    } # foreach
    Return $VMTemplates
} # Get-LabVMTemplate
#region


#region LabVMTemplateFunctions
<#
.SYNOPSIS
   Initializes the Virtual Machine templates used by a Lab from a provided array.
.DESCRIPTION
   Takes an array of Virtual Machine templates that were configured in the Lab.
   
   The Virtual Machine templates are used to create the Virtual Machines specified in
   a Lab. The Virtual Machine template VHD files are copied to a folder where
   they will be copied to create new Virtual Machines or as parent difference disks for new
   Virtual Machines.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM Template names.
   
   Only VM Templates matching names in this list will be initialized.
.PARAMETER VMTemplates
   The array of VM Templates pulled from the Lab using Get-LabVMTemplate.

   If not provided it will attempt to pull the list from the Lab.
.PARAMETER VMTemplateVHDs
   The array of VM Template VHDs pulled from the Lab using Get-LabVMTemplateVHD.

   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Lab $Lab
   $VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
   Initialize-LabVMTemplate `
    -Lab $Lab `
    -VMTemplates $VMTemplates `
    -VMTemplateVHDs $VMTemplateVHDs
   Initializes the Virtual Machine templates in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Initialize-LabVMTemplate -Lab $Lab
   Initializes the Virtual Machine templates in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Initialize-LabVMTemplate {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,
        
        [Parameter(
            Position=3)]
        [Array] $VMTemplates
    )
    
    # if VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        $VMTemplates = Get-LabVMTemplate `
            @PSBoundParameters
    }

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    
    # Check each Parent VHD exists in the Parent VHDs folder for the
    # Lab. If it isn't, try and copy it from the SourceVHD
    # Location.
    foreach ($VMTemplate in $VMTemplates)
    {
        if ($Name -and ($VMTemplate.Name -notin $Name))
        {
            # A names list was passed but this VM Template wasn't included
            continue
        } # if
        
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

        # if this is a Nano Server template, we need to ensure that the
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
                Write-Verbose -Message $($LocalizedData.CachingNanoServerPackagesMessage `
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
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM Template names.
   
   Only VM Templates matching names in this list will be removed.
.PARAMETER VMTemplates
   The array of Virtual Machine Templates pulled from the Lab using Get-LabVMTemplate.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Lab $Lab
   Remove-LabVMTemplate -Lab $Lab -VMTemplates $VMTemplates
   Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Remove-LabVMTemplate -Lab $Lab
   Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Remove-LabVMTemplate {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,

        [Parameter(
            Position=3)]
        [Array] $VMTemplates
    )

    # if VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        $VMTemplates = Get-LabVMTemplate `
           @PSBoundParameters
    } # if
    foreach ($VMTemplate in $VMTemplates)
    {
        if ($Name -and ($VMTemplate.Name -notin $Name))
        {
            # A names list was passed but this VM Template wasn't included
            continue
        } # if

        if (Test-Path $VMTemplate.parentvhd)
        {
            Set-ItemProperty `
                -Path $VMTemplate.parentvhd `
                -Name IsReadOnly `
                -Value $False
            Write-Verbose -Message $($LocalizedData.DeletingParentVHDMessage `
                -f $VMTemplate.parentvhd)
            Remove-Item `
                -Path $VMTemplate.parentvhd `
                -Confirm:$false `
                -Force
        } # if
    } # foreach
} # Remove-LabVMTemplate
#region


#region LabVMFunctions
<#
.SYNOPSIS
   Gets an Array of VMs from a Lab.
.DESCRIPTION
   Takes the provided Lab and returns the list of Virtul Machines
   that will be created in this lab. This list is usually passed to Initialize-LabVM.
.PARAMETER Lab
   Contains the Lab Builder Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM names.
   
   Only VMs matching names in this list will be returned in the array.
.PARAMETER VMTemplates
   Contains the array of VM Templates returned by Get-LabVMTemplate from this Lab.

   If not provided it will attempt to pull the list from the Lab.
.PARAMETER Switches
   Contains the array of Virtual Switches returned by Get-LabSwitch from this Lab.

   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMTemplates = Get-LabVMTemplate -Lab $Lab
   $Switches = Get-LabSwitch -Lab $Lab
   $VMs = Get-LabVM -Lab $Lab -VMTemplates $VMTemplates -Switches $Switches
   Loads a Lab and pulls the array of VMs from it.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
   Loads a Lab and pulls the array of VMs from it.
.OUTPUTS
   Returns an array of VMs.
#>
function Get-LabVM {
    [OutputType([System.Collections.Hashtable[]])]
    [CmdLetBinding()]
    param (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,
        
        [Parameter(
            Position=3)]
        [Array] $VMTemplates,

        [Parameter(
            Position=4)]
        [Array] $Switches
    )

    # if VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        $VMTemplates = Get-LabVMTemplate `
            -Lab $Lab
    }

    # if Switches array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('Switches'))
    {
        $Switches = Get-LabSwitch `
            -Lab $Lab
    }

    [System.Collections.Hashtable[]] $LabVMs = @()
    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
    [String] $LabId = $Lab.labbuilderconfig.settings.labid 
    $VMs = $Lab.labbuilderconfig.vms.vm

    foreach ($VM in $VMs) 
	{
        $VMName = $VM.Name
        if ($Name -and ($VMName -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if

        if ($VMName -eq 'VM')
		{
            $ExceptionParameters = @{
                errorId = 'VMNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMNameError)
            }
            ThrowException @ExceptionParameters
        } # if

        # if a LabId is set for the lab, prepend it to the VM name.
        if ($LabId)
        {
            $VMName = "$LabId $VMName"
        }
        
        if (-not $VM.Template) 
		{
            $ExceptionParameters = @{
                errorId = 'VMTemplateNameEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                    -f $VMName)
            }
            ThrowException @ExceptionParameters
        } # if

        # Find the template that this VM uses and get the VHD Path
        [String] $ParentVHDPath =''
        [Boolean] $Found = $false
        foreach ($VMTemplate in $VMTemplates) {
            if ($VMTemplate.Name -eq $VM.Template) {
                $ParentVHDPath = $VMTemplate.parentVHD
                $Found = $true
                Break
            } # if
        } # foreach

        if (-not $Found) 
		{
            $ExceptionParameters = @{
                errorId = 'VMTemplateNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                    -f $VMName,$VM.template)
            }
            ThrowException @ExceptionParameters
        } # if

        # Assemble the Network adapters that this VM will use
        [System.Collections.Hashtable[]] $VMAdapters = @()
        [Int] $AdapterCount = 0
        foreach ($VMAdapter in $VM.Adapters.Adapter) 
		{
            $AdapterCount++
            $AdapterName = $VMAdapter.Name 
            $AdapterSwitchName = $VMAdapter.SwitchName
            if ($AdapterName -eq 'adapter') 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterNameError `
                        -f $VMName)
                }
                ThrowException @ExceptionParameters
            }
            
            if (-not $AdapterSwitchName) 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                        -f $VMName,$AdapterName)
                }
                ThrowException @ExceptionParameters
            }

            # if a LabId is set for the lab, prepend it to the adapter name
            # name and switch name.
            if ($LabId)
            {
                $AdapterName = "$LabId $AdapterName"
                $AdapterSwitchName = "$LabId $AdapterSwitchName"
            }

            # Check the switch is in the switch list
            [Boolean] $Found = $False
            foreach ($Switch in $Switches) 
			{
                # Match the switch name to the Adapter Switch Name or
                # the LabId and Adapter Switch Name
                if ($Switch.Name -eq $AdapterSwitchName) `
				{
                    # The switch is found in the switch list - record the VLAN (if there is one)
                    $Found = $True
                    $SwitchVLan = $Switch.Vlan
                    Break
                } # if
                elseif ($Switch.Name -eq $VMAdapter.SwitchName)
                {
                    # The switch is found in the switch list - record the VLAN (if there is one)
                    $Found = $True
                    $SwitchVLan = $Switch.Vlan
                    $AdapterSwitchName = $VMAdapter.SwitchName
                    Break
                }
            } # foreach
            if (-not $Found) 
			{
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNotFoundError `
                        -f $VMName,$AdapterName,$AdapterSwitchName)
                }
                ThrowException @ExceptionParameters
            } # if
            
            # Figure out the VLan - If defined in the VM use it, otherwise use the one defined in the Switch, otherwise keep blank.
            [String] $VLan = $VMAdapter.VLan
            if (-not $VLan) 
			{
                $VLan = $SwitchVLan
            } # if
            
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
                Name = $AdapterName;
                SwitchName = $AdapterSwitchName;
                MACAddress = $VMAdapter.macaddress;
                MACAddressSpoofing = $MACAddressSpoofing;
                VLan = $VLan;
                IPv4 = $IPv4;
                IPv6 = $IPv6
            }
        } # foreach

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
                        -f $VMName)
                }
                ThrowException @ExceptionParameters
            }
            # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
            # if it doesn't contain a root (e.g. c:\)
            if (! [System.IO.Path]::IsPathRooted($Vhd))
            {
                $Vhd = Join-Path `
                    -Path $LabPath `
                    -ChildPath "$($VMName)\Virtual Hard Disks\$Vhd"
            }
            
            # Does the VHD already exist?
            $Exists = Test-Path `
                -Path $Vhd

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
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $ParentVhd
                }
                if (-not (Test-Path -Path $ParentVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskParentVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                            -f $VMName,$ParentVhd)
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
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $SourceVhd
                }
                if (! (Test-Path -Path $SourceVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                            -f $VMName,$SourceVhd)
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
                                    -f $VMName)
                            }
                            ThrowException @ExceptionParameters
                        }
                        if ($Shared)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskSharedDifferencingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                                    -f $VMName,$VHD)
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
                                -f $VMName,$VHD,$type)
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
                        -f $VMName,$VHD)
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
                            -f $VMName,$VHD,$PartitionStyle)
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
                            -f $VMName,$VHD,$FileSystem)
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
            
            # if the Partition Style, File System or File System Label has been
            # provided then ensure Partition Style and File System are set.
            if ($PartitionStyle -or $FileSystem -or $FileSystemLabel)
            {
                if (-not $PartitionStyle)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskPartitionStyleMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                            -f $VMName,$VHD)
                    }
                    ThrowException @ExceptionParameters
                }
                if (-not $FileSystem)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskFileSystemMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                            -f $VMName,$VHD)
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
                            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $CopyFolder
                    }
                    if (-not (Test-Path -Path $CopyFolder -Type Container))
                    {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskCopyFolderMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskCopyFolderMissingError `
                            -f $VMName,$VHD,$CopyFolder)
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
                            -f $VMName,$VHD)
                    }
                    ThrowException @ExceptionParameters                        
                }
            }

            # if the data disk file doesn't exist then some basic parameters MUST be provided
            if (-not $Exists `
                -and ((( $Type -notin ('fixed','dynamic','differencing') ) -or ($null -eq $Size) -or ($Size -eq 0) ) `
                -and -not $SourceVhd ))
            {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $VMName,$VHD)
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
        } # foreach

        # Does the VM have an Unattend file specified?
        [String] $UnattendFile = ''
        if ($VM.UnattendFile) 
		{
            $UnattendFile = Join-Path `
                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.UnattendFile
            if (-not (Test-Path $UnattendFile)) 
			{
                $ExceptionParameters = @{
                    errorId = 'UnattendFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnattendFileMissingError `
                        -f $VMName,$UnattendFile)
                }
                ThrowException @ExceptionParameters
            } # if
        } # if
        
        # Does the VM specify a Setup Complete Script?
        [String] $SetupComplete = ''
        if ($VM.SetupComplete) 
		{
            $SetupComplete = Join-Path `
                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.SetupComplete
            if ([System.IO.Path]::GetExtension($SetupComplete).ToLower() -notin '.ps1','.cmd' )
            {
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                        -f $VMName,$SetupComplete)
                }
                ThrowException @ExceptionParameters
            } # if
            if (-not (Test-Path $SetupComplete))
            {
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                        -f $VMName,$SetupComplete)
                }
                ThrowException @ExceptionParameters
            } # if
        } # if

        # Load the DSC Config File setting and check it
        [String] $DSCConfigFile = ''
        if ($VM.DSC.ConfigFile) 
		{
            $DSCConfigFile = Join-Path `
                -Path $Lab.labbuilderconfig.settings.dsclibrarypathfull `
                -ChildPath $VM.DSC.ConfigFile

            if ([System.IO.Path]::GetExtension($DSCConfigFile).ToLower() -ne '.ps1' )
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                        -f $VMName,$DSCConfigFile)
                }
                ThrowException @ExceptionParameters
            }

            if (-not (Test-Path $DSCConfigFile))
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                        -f $VMName,$DSCConfigFile)
                }
                ThrowException @ExceptionParameters
            }
            if (-not $VM.DSC.ConfigName)
            {
                $ExceptionParameters = @{
                    errorId = 'DSCConfigNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                        -f $VMName)
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
        if ($null -ne $VM.IntegrationServices)
        {
            $IntegrationServices = $VM.IntegrationServices
        } 
        elseif ($null -ne $VMTemplate.IntegrationServices)
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
        } # if

        # Get the Timezone (from the template or VM)
        [String] $Timezone = 'Pacific Standard Time'
        if ($VM.timezone) 
		{
            $Timezone = $VM.timezone
        }
        elseif ($VMTemplate.timezone) 
		{
            $Timezone = $VMTemplate.timezone
        } # if

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

        # Get the Bootorder
        [Byte] $Bootorder = [Byte]::MaxValue
        if ($VM.bootorder) 
		{
            $Bootorder = $VM.bootorder
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
        } # foreach

        $LabVMs += @{
            Name = $VMName;
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
            VMRootPath = (Join-Path -Path $LabPath -ChildPath $VMName);
            LabBuilderFilesPath = (Join-Path -Path $LabPath -ChildPath "$VMName\LabBuilder Files");
            Bootorder = $Bootorder;
        }
    } # foreach

    Return $LabVMs
} # Get-LabVM


<#
.SYNOPSIS
   Initializes the Virtual Machines used by a Lab from a provided array.
.DESCRIPTION
   Takes an array of Virtual Machines that were configured in the Lab.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VMs.
   
   Only VMs matching names in this list will be initialized.
.PARAMETER VMs
   Array of Virtual Machines pulled from a Lab object.

   If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $Switches = Get-LabSwtich -Lab $Lab
   $VMTemplates = Get-LabVMTemplate -Lab $Lab
   $VMs = Get-LabVs -Lab $Lab -Switches $Swtiches -VMTemplates $VMTemplates
   Initialize-LabVM `
    -Lab $Lab `
    -VMs $VMs
   Initializes the Virtual Machines in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Initialize-LabVMs -Lab $Lab
   Initializes the Virtual Machines in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Initialize-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,
        
        [Parameter(
            Position=3)]
        [Array] $VMs
    )
    
    # if VMs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMs'))
    {
        $VMs = Get-LabVM `
            @PSBoundParameters
    } # if
    
    # if there are not VMs just return
    if (-not $VMs)
    {
        return
    } # if
    
    $CurrentVMs = Get-VM

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Figure out the name of the LabBuilder control switch
    $ManagementSwitchName = GetManagementSwitchName `
        -Lab $Lab
    if ($Lab.labbuilderconfig.switches.ManagementVlan)
    {
        [Int32] $ManagementVlan = $Lab.labbuilderconfig.switches.ManagementVlan
    }
    else
    {
        [Int32] $ManagementVlan = $Script:DefaultManagementVLan
    } # if

    foreach ($VM in $VMs)
    {
        if ($Name -and ($VM.Name -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if
        
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
                    -Lab $Lab `
                    -VM $VM

                # Because this is a new boot disk apply any required initialization
                InitializeBootVHD `
                    -Lab $Lab `
                    -VM $VM `
                    -VMBootDiskPath $VMBootDiskPath
            }
            else
            {
                Write-Verbose -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                    -f $VM.Name,$VMBootDiskPath,'Boot')
            } # if

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
            } # if
        } # if
        
        # Enable/Disable Dynamic Memory
        if ($VM.DynamicMemoryEnabled)
        {
            [Boolean] $DynamicMemoryEnabled = ($VM.DynamicMemoryEnabled -ne 'N')
            if ($DynamicMemoryEnabled -ne (Get-VMMemory -VMName $VM.Name).DynamicMemoryEnabled)
            {
                Set-VMMemory `
                    -VMName $VM.Name `
                    -DynamicMemoryEnabled:$DynamicMemoryEnabled
            } # if
        } # if

        
        # if the ExposeVirtualizationExtensions is configured then try and set this on 
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
            -Lab $Lab `
            -VM $VM        
            
        # Create/Update the Management Network Adapter
        if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $ManagementSwitchName).Count -eq 0)
        {
            Write-Verbose -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                -f $VM.Name,$ManagementSwitchName,'Management')

            Add-VMNetworkAdapter `
                -VMName $VM.Name `
                -SwitchName $ManagementSwitchName `
                -Name $ManagementSwitchName
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
            } # if

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
            } # if

            if ($VMAdapter.MACAddress)
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -StaticMacAddress $VMAdapter.MACAddress
            }
            else
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -DynamicMacAddress
            } # if

            # Enable Device Naming
            if ((Get-Command -Name Set-VMNetworkAdapter).Parameters.ContainsKey('DeviceNaming'))
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -DeviceNaming On
            }
            if ($VMAdapter.MACAddressSpoofing -ne $VMNetworkAdapter.MACAddressSpoofing)
            {
                $null = $VMNetworkAdapter | Set-VMNetworkAdapter -MacAddressSpoofing $VMAdapter.MACAddressSpoofing
            }                
        } # foreach

        Install-LabVM `
            -Lab $Lab `
            -VM $VM
    } # foreach
} # Initialize-LabVM


<#
.SYNOPSIS
   Removes all Lab Virtual Machines.
.DESCRIPTION
   This cmdlet is used to remove any Virtual Machines that were created as part of this
   Lab.

   It can also optionally delete the folder and all files created as part of this Lab
   Virutal Machine.
.PARAMETER Lab
   Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
   An optional array of VM names.
   
   Only VMs matching names in this list will be removed.
.PARAMETER VMs
   The array of Virtual Machines pulled from the Lab using Get-LabVM.
.PARAMETER RemoveVMFolder
   Causes the folder created to contain the Virtual Machine in this lab to be deleted.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $Switches = Get-LabSwtich -Lab $Lab
   $VMTemplates = Get-LabVMTemplate -Lab $Lab
   $VMs = Get-LabVs -Lab $Lab -Switches $Swtiches -VMTemplates $VMTemplates
   Remove-LabVM -Lab $Lab -VMs $VMs
   Removes any Virtual Machines configured in the Lab c:\mylab\config.xml
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   Remove-LabVM -Lab $Lab
   Removes any Virtual Machines configured in the Lab c:\mylab\config.xml
.OUTPUTS
   None.
#>
function Remove-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,
        
        [Parameter(
            Position=3)]
        [Array] $VMs,

        [Parameter(
            Position=4)]
        [Switch] $RemoveVMFolder
    )
    
    # if VMs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMs'))
    {
        $null = $PSBoundParameters.Remove('RemoveVMFolder')
        $VMs = Get-LabVM `
            @PSBoundParameters
    } # if

    $CurrentVMs = Get-VM

    # Get the LabPath
    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    
    foreach ($VM in $VMs)
    {
        if ($Name -and ($VM.Name -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if

        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -ne 0)
        {
            # if the VM is running we need to shut it down.
            if ((Get-VM -Name $VM.Name).State -eq 'Running')
            {
                Write-Verbose -Message $($LocalizedData.StoppingVMMessage `
                    -f $VM.Name)

                Stop-VM `
                    -Name $VM.Name
                # Wait for it to completely shut down and report that it is off.
                WaitVMOff `
                    -VM $VM
            }

            Write-Verbose -Message $($LocalizedData.RemovingVMMessage `
                -f $VM.Name)
           
            # Now delete the actual VM
            Get-VM `
                -Name $VM.Name | Remove-VM -Force -Confirm:$False

            Write-Verbose -Message $($LocalizedData.RemovedVMMessage `
                -f $VM.Name)
        }
        else
        {
            Write-Verbose -Message $($LocalizedData.VMNotFoundMessage `
                -f $VM.Name)
        }
    }
    # Should we remove the VM Folder?
    if ($RemoveVMFolder)
    {
        if (Test-Path -Path $VM.VMRootPath)
        {
            Write-Verbose -Message $($LocalizedData.DeletingVMFolderMessage `
                -f $VM.Name)

            Remove-Item `
                -Path $VM.VMRootPath `
                -Recurse `
                -Force
        }
    }
} # Remove-LabVM



<#
.SYNOPSIS
   Starts a Lab VM and ensures it has been Initialized.
.DESCRIPTION
   This cmdlet is used to start up a Lab VM for the first time.
   
   It will start the VM if it is off.
   
   If the VM is a Server OS or Nano Server then it will also perform an initial setup:
    - It will ensure that initial setup has been completed and a self-signed certificate has
      been created by the VM and downloaded to the LabBuilder folder.   

    - It will also ensure DSC is configured for the VM.
.PARAMETER VM
   The VM Object referring to the VM to start to.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
   $Session = Install-LabVM -VM $VMs[0]
   Start up the first VM in the Lab c:\mylab\config.xml and initialize it.
.OUTPUTS
   None.
#>
function Install-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [Hashtable] $VM
    )

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # The VM is now ready to be started
    if ((Get-VM -Name $VM.Name).State -eq 'Off')
    {
        Write-Verbose -Message $($LocalizedData.StartingVMMessage `
            -f $VM.Name)

        Start-VM -VMName $VM.Name
    } # if

    # We only perform this section of VM Initialization (DSC, Cert, etc) with Server OS
    if ($VM.OSType -in ('Server','Nano'))
    {
        # Has this VM been initialized before (do we have a cert for it)
        if (-not (Test-Path "$LabPath\$($VM.Name)\LabBuilder Files\$Script:DSCEncryptionCert"))
        {
            # No, so check it is initialized and download the cert.
            if (WaitVMInitializationComplete -VM $VM -ErrorAction Continue)
            {
                Write-Verbose -Message $($LocalizedData.CertificateDownloadStartedMessage `
                    -f $VM.Name)
                    
                if (GetSelfSignedCertificate -Lab $Lab -VM $VM)
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
                } # if
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
            } # if
        } # if

        # Create any DSC Files for the VM
        InitializeDSC `
            -Lab $Lab `
            -VM $VM

        # Attempt to start DSC on the VM
        StartDSC `
            -Lab $Lab `
            -VM $VM
    } # if
} # Install-LabVM



<#
.SYNOPSIS
   Connects to a running Lab VM.
.DESCRIPTION
   This cmdlet will connect to a running VM using PSRemoting. A PSSession object will be returned
   if the connection was successful.
   
   If the connection fails, it will be retried until the ConnectTimeout is reached. If the
   ConnectTimeout is reached and a connection has not been established then a ConnectionError 
   exception will be thrown.
   
   The IP Address to this VM will be added to the WSMan TrustedHosts list if it isn't already
   added or if it isn't set to '*'.
.PARAMETER VM
   The VM Object referring to the VM to connect to.
.PARAMETER ConnectTimeout
   The number of seconds the connection will attempt to be established for.
   
   Defaults to 300 seconds.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
   $Session = Connect-LabVM -VM $VMs[0]
   Connect to the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
   The PSSession object of the remote connect or null if the connection failed.
#>
function Connect-LabVM
{
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [Hashtable] $VM,
        
        [Parameter(
            Position=2)]
        [Int] $ConnectTimeout = 300
    )

    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [PSCredential] $AdminCredential = CreateCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword
    [Boolean] $FatalException = $False
    
    while (($null -eq $Session) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $ConnectTimeout `
        -and -not $FatalException)
    {
        try
        {                
            # Get the Management IP Address of the VM
            # We repeat this because the IP Address will only be assiged 
            # once the VM is fully booted.
            $IPAddress = GetVMManagementIPAddress `
                -Lab $Lab `
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
    
    # if a fatal exception occured or the connection just couldn't be established
    # then throw an exception so it can be caught by the calling code.
    if ($FatalException -or ($null -eq $Session))
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
   Disconnects from a running Lab VM.
.DESCRIPTION
   This cmdlet will disconnect a session from a running VM using PSRemoting.
   
   The IP Address to this VM will be removed from the WSMan TrustedHosts list 
   if it exists in it.   
.PARAMETER VM
   The VM Object referring to the VM to connect to.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
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
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [Hashtable] $VM
    )

    [PSCredential] $AdminCredential = CreateCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword

    # Get the Management IP Address of the VM
    $IPAddress = GetVMManagementIPAddress `
        -Lab $Lab `
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
            $null = $Session | Remove-PSSession -ErrorAction SilentlyContinue
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
    Loads a Lab Builder Configuration file and returns a Lab object
.DESCRIPTION
    Takes the path to a valid LabBuilder Configiration XML file and loads it.
    
    It will perform simple validation on the XML file and throw an exception
    if any of the validation tests fail.
    
    At load time it will also add temporary configuration attributes to the in
    memory configuration that are used by other LabBuilder functions. So loading
    XML Configurartion without using this function is not advised.
.PARAMETER ConfigPath
    This is the path to the Lab Builder configuration file to load.
.PARAMETER LabPath
    This is an optional path that is used to Override the LabPath in the config
    file passed.
.EXAMPLE
    $MyLab = Get-Lab -ConfigPath c:\MyLab\LabConfig1.xml
    Loads the LabConfig1.xml configuration and returns Lab object.
.OUTPUTS
    The Lab object representing the Lab Configuration that was loaded.
#>
function Get-Lab {
    [CmdLetBinding()]
    [OutputType([XML])]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,
        
        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,
        
        [Parameter(
            Position=3)]
        [Switch] $SkipXMLValidation
    ) # Param
    if (-not (Test-Path -Path $ConfigPath))
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationFileNotFoundError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileNotFoundError `
                -f $ConfigPath)
        }
        ThrowException @ExceptionParameters
    } # if
    
    $Content = Get-Content -Path $ConfigPath -Raw
    if (-not $Content)
    {
        $ExceptionParameters = @{
            errorId = 'ConfigurationFileEmptyError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationFileEmptyError `
                -f $ConfigPath)
        }
        ThrowException @ExceptionParameters
    } # if
    
    if (-not $SkipXMLValidation)
    {
        # Validate the XML
        ValidateConfigurationXMLSchema `
            -ConfigPath $ConfigPath `
            -ErrorAction Stop
    }

    # The XML passes the Schema check so load it.
    [XML] $Lab = New-Object System.Xml.XmlDocument
    $Lab.PreserveWhitespace = $true
    $Lab.LoadXML($Content)
    
    # Figure out the Config path and load it into the XML object (if we can)
    # This path is used to find any additional configuration files that might
    # be provided with config
    [String] $ConfigPath = [System.IO.Path]::GetDirectoryName($ConfigPath)
    [String] $XMLConfigPath = $Lab.labbuilderconfig.settings.configpath
    if ($XMLConfigPath) {
        if (! [System.IO.Path]::IsPathRooted($XMLConfigurationPath))
        {
            # A relative path was provided in the config path so add the actual path of the
            # XML to it
            [String] $FullConfigPath = Join-Path `
                -Path $ConfigPath `
                -ChildPath $XMLConfigPath
        } # if
    }
    else
    {
        [String] $FullConfigPath = $ConfigPath
    }
    $Lab.labbuilderconfig.settings.setattribute('fullconfigpath',$FullConfigPath)
    
    # if the LabPath was passed as a parameter, set it in the config
    if ($LabPath)
    {
        $Lab.labbuilderconfig.settings.SetAttribute('labpath',$LabPath)
    }
    else
    {
        [String] $LabPath = $Lab.labbuilderconfig.settings.labpath        
    }
    
    # Get the VHDParentPathFull - if it isn't supplied default
    [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpath
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
    } # if
    $Lab.labbuilderconfig.settings.setattribute('vhdparentpathfull',$VHDParentPath)
    
    # Get the DSCLibraryPathFull - if it isn't supplied default
    [String] $DSCLibraryPath = $Lab.labbuilderconfig.settings.dsclibrarypath
    if (-not $DSCLibraryPath)
    {
        $DSCLibraryPath = 'DSCLibrary'
    } # if
    # if the resulting parent path is not rooted make the root
    # the Full config path
    if (-not [System.IO.Path]::IsPathRooted($DSCLibraryPath))
    {
        $DSCLibraryPath = Join-Path `
            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
            -ChildPath $DSCLibraryPath
    } # if    
    $Lab.labbuilderconfig.settings.setattribute('dsclibrarypathfull',$DSCLibraryPath)

    Return $Lab
} # Get-Lab


<#
.SYNOPSIS
    Creates a new Lab Builder Configuration file and Lab folder.
.DESCRIPTION
    This function will take a path to a new Lab folder and a path or filename 
    for a new Lab Configuration file and creates them using the standard XML
    template.
    
    It will also copy the DSCLibrary folder as well as the create an empty
    ISOFiles and VHDFiles folder in the Lab folder.
    
    After running this function the VMs, VMTemplates, Switches and VMTemplateVHDs
    in the new Lab Configuration file would normally be customized to for the new
    Lab.
.PARAMETER ConfigPath
    This is the path to the Lab Builder configuration file to create. If it is
    not rooted the configuration file is created in the LabPath folder.
.PARAMETER LabPath
    This is a required path of the new Lab to create.
.PARAMETER Name
    This is a required name of the Lab that gets added to the new Lab Configration
    file.
.PARAMETER Version
    This is a required version of the Lab that gets added to the new Lab Configration
    file.
.PARAMETER Id
    This is the optional Lab Id that gets set in the new Lab Configuration
    file.
.PARAMETER Description
    This is the optional Lab description that gets set in the new Lab Configuration
    file.
.PARAMETER DomainName
    This is the optional Lab domain name that gets set in the new Lab Configuration
    file.
.PARAMETER Email
    This is the optional Lab email address that gets set in the new Lab Configuration
    file.
.EXAMPLE
    $MyLab = New-Lab `
        -ConfigPath c:\MyLab\LabConfig1.xml `
        -LabPath c:\MyLab `
        -LabName 'MyLab' `
        -LabVersion '1.2'
    Creates a new Lab Configration file LabConfig1.xml and also a Lab folder
    c:\MyLab and populates it with default DSCLibrary file and supporting folders.
.OUTPUTS
    The Lab object representing the new Lab Configuration that was created.
#>
function New-Lab {
    [CmdLetBinding(
        SupportsShouldProcess = $true)]
    [OutputType([XML])]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,
        
        [Parameter(
            Position=2,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,
        
        [Parameter(
            Position=3,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [Parameter(
            Position=4)]
        [ValidateNotNullOrEmpty()]
        [String] $Version = '1.0',
        
        [Parameter(
            Position=5)]
        [ValidateNotNullOrEmpty()]
        [String] $Id,

        [Parameter(
            Position=6)]
        [ValidateNotNullOrEmpty()]
        [String] $Description,
        
        [Parameter(
            Position=7)]
        [ValidateNotNullOrEmpty()]
        [String] $DomainName,

        [Parameter(
            Position=8)]
        [ValidateNotNullOrEmpty()]
        [String] $Email
    ) # Param

    # Determine the full Lab Path
    if (-not [System.IO.Path]::IsPathRooted($LabPath))
    {
        $LabPath = Join-Path `
            -Path Get-Location `
            -ChildPath $LabPath
    } # if
    
    # Does the Lab Path exist?
    if (Test-Path -Path $LabPath -Type Container)
    {
        # It does - exit if the user declines
        if (-not $PSCmdlet.ShouldProcess( ( $LocalizedData.ShouldOverwriteLab `
            -f $LabPath )))
        {
            return
        }
    }
    else
    {
        Write-Verbose -Message $($LocalizedData.CreatingLabFolderMessage `
            -f 'LabPath',$LabPath)

        New-Item `
            -Path $LabPath `
            -Type Directory
    } # if

    # Determine the full Lab configuration Path
    if (-not [System.IO.Path]::IsPathRooted($ConfigPath))
    {
        $ConfigPath = Join-Path `
            -Path $LabPath `
            -ChildPath $ConfigPath
    } # if

    # Does the lab configuration path already exist?
    if (Test-Path -Path $ConfigPath)
    {
        # It does - exit if the user declines
        if (-not $PSCmdlet.ShouldProcess( ( $LocalizedData.ShouldOverwriteLabConfig `
            -f $ConfigPath )))
        {
            return
        }
    } # if
    
    # Get the Config Template into a variable
    $Content = Get-Content `
        -Path $Script:ConfigurationXMLTemplate

    # The XML passes the Schema check so load it.
    [XML] $Lab = New-Object System.Xml.XmlDocument
    $Lab.PreserveWhitespace = $true
    $Lab.LoadXML($Content)

    # Populate the Lab Entries
    $Lab.labbuilderconfig.name = $Name
    $Lab.labbuilderconfig.version = $Version
    $Lab.labbuilderconfig.settings.labpath = $LabPath
    if ($PSBoundParameters.ContainsKey('Id'))
    {
        $Lab.labbuilderconfig.settings.SetAttribute('Id',$Id)    
    } # if
    if ($PSBoundParameters.ContainsKey('Description'))
    {
        $Lab.labbuilderconfig.description = $Description
    } # if
    if ($PSBoundParameters.ContainsKey('DomainName'))
    {
        $Lab.labbuilderconfig.settings.SetAttribute('DomainName',$DomainName)    
    } # if
    if ($PSBoundParameters.ContainsKey('Email'))
    {
        $Lab.labbuilderconfig.settings.SetAttribute('Email',$Email)    
    } # if

    # Save Configiration XML
    $Lab.Save($ConfigPath)
   
    # Create ISOFiles folder
    New-Item `
        -Path (Join-Path -Path $LabPath -ChildPath 'ISOFiles')`
        -Type Directory `
        -ErrorAction SilentlyContinue 
        
    # Create VDFFiles folder
    New-Item `
        -Path (Join-Path -Path $LabPath -ChildPath 'VHDFiles')`
        -Type Directory `
        -ErrorAction SilentlyContinue 
        
    # Copy the DSCLibrary
    Copy-Item `
        -Path $Script:DSCLibraryPath `
        -Destination $LabPath `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Return (Get-Lab `
        -ConfigPath $ConfigPath `
        -LabPath $LabPath)
} # New-Lab


<#
.SYNOPSIS
    Installs or Update a Lab.
.DESCRIPTION
    This cmdlet will install an entire Hyper-V lab environment defined by the
    LabBuilder configuration file provided.
    
    If components of the Lab already exist, they will be updated if they differ
    from the settings in the Configuration file.
   
    The Hyper-V component can also be optionally installed if it is not.
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to install the Lab to - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to install.    
.PARAMETER CheckEnvironment
    Whether or not to check if Hyper-V is installed and install it if missing.
.EXAMPLE
    Install-Lab -ConfigPath c:\mylab\config.xml
    Install the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Install-Lab
    Install the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
    None
#>
Function Install-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=4)]
        [Switch] $CheckEnvironment
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('CheckEnvironment')
    
        if ($CheckEnvironment)
        {
            # Check Hyper-V
            Install-LabHyperV
        } # if

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters             
        } # if
    } # begin
    
    process
    {
        # Initialize the core Lab components
        # Check Lab Folder structure
        Write-Verbose -Message $($LocalizedData.InitializingLabFoldersMesage)

        # Check folders are defined
        [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
        if (-not (Test-Path -Path $LabPath))
        {
            Write-Verbose -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'LabPath',$LabPath)

            $null = New-Item `
                -Path $LabPath `
                -Type Directory
        }

        [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
        if (-not (Test-Path -Path $VHDParentPath))
        {
            Write-Verbose -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'VHDParentPath',$VHDParentPath)

            $null = New-Item `
                -Path $VHDParentPath `
                -Type Directory
        }
        
        # Install Hyper-V Components
        Write-Verbose -Message $($LocalizedData.InitializingHyperVComponentsMesage)

        # Create the LabBuilder Management Network switch and assign VLAN
        # Used by host to communicate with Lab VMs
        [String] $ManagementSwitchName = GetManagementSwitchName `
            -Lab $Lab
        if ($Lab.labbuilderconfig.switches.ManagementVlan)
        {
            [Int32] $ManagementVlan = $Lab.labbuilderconfig.switches.ManagementVlan
        }
        else
        {
            [Int32] $ManagementVlan = $Script:DefaultManagementVLan
        }
        if ((Get-VMSwitch | Where-Object -Property Name -eq $ManagementSwitchName).Count -eq 0)
        {
            $null = New-VMSwitch -Name $ManagementSwitchName -SwitchType Internal

            Write-Verbose -Message $($LocalizedData.CreatingLabManagementSwitchMessage `
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
            Write-Verbose -Message $($LocalizedData.UpdatingLabManagementSwitchMessage `
                -f $ManagementSwitchName,$ManagementVlan)

            Set-VMNetworkAdapterVlan `
                -VMNetworkAdapterName $ManagementSwitchName `
                -ManagementOS `
                -Access `
                -VlanId $ManagementVlan
        }
        # Download any other resources required by this lab
        DownloadResources `
            -Lab $Lab	
        
        # Initialize the Switches
        $Switches = Get-LabSwitch `
            -Lab $Lab
        Initialize-LabSwitch `
            -Lab $Lab `
            -Switches $Switches

        # Initialize the VM Template VHDs
        $VMTemplateVHDs = Get-LabVMTemplateVHD `
            -Lab $Lab
        Initialize-LabVMTemplateVHD `
            -Lab $Lab `
            -VMTemplateVHDs $VMTemplateVHDs

        # Initialize the VM Templates
        $VMTemplates = Get-LabVMTemplate `
            -Lab $Lab
        Initialize-LabVMTemplate `
            -Lab $Lab `
            -VMTemplates $VMTemplates

        # Initialize the VMs
        $VMs = Get-LabVM `
            -Lab $Lab `
            -VMTemplates $VMTemplates `
            -Switches $Switches
        Initialize-LabVM `
            -Lab $Lab `
            -VMs $VMs 

        Write-Verbose -Message $($LocalizedData.LabInstallCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)
    } # process
    end 
    {
    } # end
} # Install-Lab


<#
.SYNOPSIS
    Update a Lab.
.DESCRIPTION
    This cmdlet will update the existing Hyper-V lab environment defined by the
    LabBuilder configuration file provided.
    
    If components of the Lab are missing they will be added.
    
    If components of the Lab already exist, they will be updated if they differ
    from the settings in the Configuration file.
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to update the Lab in - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to update.    
.EXAMPLE
    Update-Lab -ConfigPath c:\mylab\config.xml
    Update the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Update-Lab
    Update the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
    None
#>
Function Update-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    ) # Param

    begin
    {   
        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters             
        } # if
    } # begin
    
    process
    {
        Install-Lab `
            @PSBoundParameters
    
        Write-Verbose -Message $($LocalizedData.LabUpdateCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)
    } # process

    end 
    {
    } # end
} # Update-Lab


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
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to uninstall the Lab from - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to uninstall. 
.PARAMETER RemoveSwitch
    Causes the switches defined by this to be removed.
.PARAMETER RemoveVMTemplate
    Causes the VM Templates created by this to be be removed. 
.PARAMETER RemoveVMFolder
    Causes the VM folder created to contain the files for any the
    VMs in this Lab to be removed.
.PARAMETER RemoveVMTemplateVHD
    Causes the VM Template VHDs that are used in this lab to be
    deleted.
.PARAMETER RemoveLabFolder
    Causes the entire folder containing this Lab to be deleted.
.EXAMPLE
    Uninstall-Lab `
        -ConfigPath c:\mylab\config.xml `
        -RemoveSwitch`
        -RemoveVMTemplate `
        -RemoveVMFolder `
        -RemoveVMTemplateVHD `
        -RemoveLabFolder
    Completely uninstall all components in the lab defined in the
    c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Uninstall-Lab `
        -RemoveSwitch`
        -RemoveVMTemplate `
        -RemoveVMFolder `
        -RemoveVMTemplateVHD `
        -RemoveLabFolder
    Completely uninstall all components in the lab defined in the
    c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
   None
#>
Function Uninstall-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab",
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=4)]
        [Switch] $RemoveSwitch,

        [Parameter(
            Position=5)]
        [Switch] $RemoveVMTemplate,

        [Parameter(
            Position=6)]
        [Switch] $RemoveVMFolder,
        
        [Parameter(
            Position=7)]
        [Switch] $RemoveVMTemplateVHD,
        
        [Parameter(
            Position=8)]
        [Switch] $RemoveLabFolder
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('RemoveSwitch')
        $null = $PSBoundParameters.Remove('RemoveVMTemplate')
        $null = $PSBoundParameters.Remove('RemoveVMFolder')
        $null = $PSBoundParameters.Remove('RemoveVMTemplateVHD')
        $null = $PSBoundParameters.Remove('RemoveLabFolder')

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters             
        } # if
    } # begin
    
    process
    {
        if ($PSCmdlet.ShouldProcess( ( $LocalizedData.ShouldUninstallLab `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
        {
            # Remove the VMs
            $VMSplat = @{} 
            if ($RemoveVMFolder)
            {
                $VMSplat += @{ RemoveVMFolder = $true }
            } # if
            $null = Remove-LabVM `
                -Lab $Lab `
                @VMSplat

            # Remove the VM Templates
            if ($RemoveVMTemplate)
            {
                if ($PSCmdlet.ShouldProcess( $($LocalizedData.ShouldRemoveVMTemplate `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabVMTemplate `
                        -Lab $Lab
                } # if
            } # if

            # Remove the VM Switches
            if ($RemoveSwitch)
            {
                if ($PSCmdlet.ShouldProcess( $($LocalizedData.ShouldRemoveSwitch `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabSwitch `
                        -Lab $Lab
                } # if
            } # if

            # Remove the VM Template VHDs
            if ($RemoveVMTemplateVHD)
            {
                if ($PSCmdlet.ShouldProcess( $($LocalizedData.ShouldRemoveVMTemplateVHD `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabVMTemplateVHD `
                        -Lab $Lab
                } # if
            } # if
            
            # Remove the Lab Folder
            if ($RemoveLabFolder)
            {
                if (Test-Path -Path $Lab.labbuilderconfig.settings.labpath)
                {
                    if ($PSCmdlet.ShouldProcess( $($LocalizedData.ShouldRemoveLabFolder `
                        -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                    {
                        Remove-Item `
                            -Path $Lab.labbuilderconfig.settings.labpath `
                            -Recurse `
                            -Force
                    } # if
                } # if
            } # if

            Write-Verbose -Message $($LocalizedData.LabUninstallCompleteMessage `
                -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )    
        } # if   
    } # process

    end
    {
    } # end
} # Uninstall-Lab


<#
.SYNOPSIS
    Starts an existing Lab.
.DESCRIPTION
    This cmdlet will start all the Hyper-V virtual machines definied in a Lab
    configuration.
    
    It will use the Bootorder attribute (if defined) for any VMs to determine
    the order they should be booted in. If a Bootorder is not specified for a
    machine, it will be booted after all machines with a defined boot order.
    
    The lower the Bootorder value for a machine the earlier it will be started
    in the start process.
    
    Machines will be booted in series, with each machine starting once the
    previous machine has completed startup and has a management IP address.

    If a Virtual Machine in the Lab is already running, it will be ignored
    and the next machine in series will be started.
    
    If more than one Virtual Machine shares the same Bootorder value, then
    these machines will be booted in parallel, with the boot process only
    continuing onto the next Bootorder when all these machines are booted.
    
    If a Virtual Machine specified in the configuration is not found an
    exception will be thrown.
    
    If a Virtual Machine takes longer than the StartupTimeout then an exception
    will be thown but the Start process will continue.

    If a Bootorder of 0 is specifed then the Virtual Machine will not be booted at
    all. This is useful for things like Root CA VMs that only need to started when
    the Lab is created.
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to install the Lab to - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to start.     
.PARAMETER StartupTimeout
    The maximum number of seconds that the process will wait for a VM to startup.
    Defaults to 90 seconds.
.EXAMPLE
    Start-Lab -ConfigPath c:\mylab\config.xml
    Start the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Start-Lab
    Start the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
    None
#>
Function Start-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,
        
        [Parameter(
            Position=4)]
        [Int] $StartupTimeout = $Script:StartupTimeout
    ) # Param
    
    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('StartupTimeout')

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters             
        } # if        
    } # begin
    
    process 
    {
        # Get the VMs
        $VMs = Get-LabVM `
            -Lab $Lab
            
        # Get the bootorders by lowest first and ignoring 0 and call
        $BootOrders = @( ($VMs |
            Where-Object -FilterScript { ($_.Bootorder -gt 0) } ).Bootorder )
        $BootPhases = @( ($Bootorders |
            Sort-Object -Unique) )

        # Step through each of these "Bootphases" waiting for them to complete
        foreach ($BootPhase in $BootPhases)
        {
            # Process this "Bootphase"
            Write-Verbose -Message $($LocalizedData.StartingBootPhaseVMsMessage `
                -f $BootPhase)

            # Get all VMs in this "Bootphase"
            $BootVMs = @( $VMs |
                Where-Object -FilterScript { ($_.BootOrder -eq $BootPhase) } )
            
            [DateTime] $StartTime = Get-Date
            [boolean] $PhaseComplete = $false
            [boolean] $PhaseAllBooted = $true
            [int] $VMCount = $BootVMs.Count
            [int] $VMNumber = 0
            
            # Loop through all the VMs in this "Bootphase" repeatedly
            # until timeout occurs or PhaseComplete is marked as complete
            while (-not $PhaseComplete `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $StartupTimeout)
            {
                # Get the VM to boot/check
                $VM = $BootVMs[$VMNumber]
                $VMName = $VM.Name
                
                # Get the actual Hyper-V VM object
                $VMObject = Get-VM `
                    -Name $VMName `
                    -ErrorAction SilentlyContinue 
                if (-not $VMObject)
                {
                    # if the VM does not exist then throw a non-terminating exception
                    $ExceptionParameters = @{
                        errorId = 'VMDoesNotExistError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDoesNotExistError `
                            -f $VMName)
                            
                    }
                    ThrowException @ExceptionParameters
                } # if
            
                # Start the VM if it is off
                if ($VMObject.State -eq 'Off')
                {
                    Write-Verbose -Message $($LocalizedData.StartingVMMessage `
                        -f $VMName)
                    Start-VM `
                        -VM $VMObject
                } # if
                
                # Use the allocation of a Management IP Address as an indicator
                # the machine has booted
                $ManagementIP = GetVMManagementIPAddress `
                    -Lab $Lab `
                    -VM $VM `
                    -ErrorAction SilentlyContinue
                if (-not ($ManagementIP))
                {
                    # It has not booted
                    $PhaseAllBooted = $False
                } # if
                $VMNumber++
                if ($VMNumber -eq $VMCount)
                {
                    # We have stepped through all VMs in this Phase so check
                    # if all have booted, otherwise reset the loop.
                    if ($PhaseAllBooted)
                    {
                        # if we have gone through all VMs in this "Bootphase"
                        # and they're all marked as booted then we can mark
                        # this phase as complete and allow moving on to the next one
                        Write-Verbose -Message $($LocalizedData.AllBootPhaseVMsStartedMessage `
                            -f $BootPhase)
                        $PhaseComplete = $True
                    }
                    else
                    {
                        $PhaseAllBooted = $True
                    } # if
                    # Reset the VM Loop
                    $VMNumber = 0
                } # if
            } # while
            
            # Did we timeout?
            if (-not ($PhaseComplete))
            {
                # Yes, throw an exception
                $ExceptionParameters = @{
                    errorId = 'BootPhaseVMsTimeoutError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.BootPhaseStartVMsTimeoutError `
                        -f $BootPhase)
                        
                }
                ThrowException @ExceptionParameters
            }
        } # foreach

        Write-Verbose -Message $($LocalizedData.LabStartCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)    
    } # process
    
    end
    {
    } # end
} # Start-Lab


<#
.SYNOPSIS
    Stop an existing Lab.
.DESCRIPTION
    This cmdlet will stop all the Hyper-V virtual machines definied in a Lab
    configuration.
    
    It will use the Bootorder attribute (if defined) for any VMs to determine
    the order they should be shutdown in. If a Bootorder is not specified for a
    machine, it will be shutdown before all machines with a defined boot order.
    
    The higher the Bootorder value for a machine the earlier it will be shutdown
    in the stop process.

    The Virtual Machines will be shutdown in REVERSE Bootorder.
    
    Machines will be shutdown in series, with each machine shutting down once the
    previous machine has completed shutdown.
    
    If a Virtual Machine in the Lab is already shutdown, it will be ignored
    and the next machine in series will be shutdown.
    
    If more than one Virtual Machine shares the same Bootorder value, then
    these machines will be shutdown in parallel, with the shutdown process only
    continuing onto the next Bootorder when all these machines are shutdown.

    If a Virtual Machine specified in the configuration is not found an
    exception will be thrown.
    
    If a Virtual Machine takes longer than the ShutdownTimeout then an exception
    will be thown but the Stop process will continue.
.PARAMETER ConfigPath
    The path to the LabBuilder configuration XML file.
.PARAMETER LabPath
    The optional path to install the Lab to - overrides the LabPath setting in the
    configuration file.
.PARAMETER Lab
    The Lab object returned by Get-Lab of the lab to start.     
.PARAMETER ShutdownTimeout
    The maximum number of seconds that the process will wait for a VM to shutdown.
    Defaults to 30 seconds.
.EXAMPLE
    Stop-Lab -ConfigPath c:\mylab\config.xml
    Stop the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.EXAMPLE
    Get-Lab -ConfigPath c:\mylab\config.xml | Stop-Lab
    Stop the lab defined in the c:\mylab\config.xml LabBuilder configuration file.
.OUTPUTS
    None
#>
Function Stop-Lab {
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,
        
        [Parameter(
            Position=4)]
        [Int] $ShutdownTimeout = $Script:ShutdownTimeout
    ) # Param
    
    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('ShutdownTimeout')

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters             
        } # if        
    } # begin
    
    process
    {
        # Get the VMs
        $VMs = Get-LabVM `
            -Lab $Lab

        # Get the bootorders by highest first and ignoring 0
        $BootOrders = @( ($VMs |
            Where-Object -FilterScript { ($_.Bootorder -gt 0) } ).Bootorder )
        $BootPhases = @( ($Bootorders |
            Sort-Object -Unique -Descending) )

        # Step through each of these "Bootphases" waiting for them to complete
        foreach ($BootPhase in $BootPhases)
        {
            # Process this "Bootphase"
            Write-Verbose -Message $($LocalizedData.StoppingBootPhaseVMsMessage `
                -f $BootPhase)

            # Get all VMs in this "Bootphase"
            $BootVMs = @( $VMs |
                Where-Object -FilterScript { ($_.BootOrder -eq $BootPhase) } )
            
            [DateTime] $StartTime = Get-Date
            [boolean] $PhaseComplete = $false
            [boolean] $PhaseAllStopped = $true
            [int] $VMCount = $BootVMs.Count
            [int] $VMNumber = 0
            
            # Loop through all the VMs in this "Bootphase" repeatedly
            # until timeout occurs or PhaseComplete is marked as complete
            while (-not $PhaseComplete `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $ShutdownTimeout)
            {
                # Get the VM to boot/check
                $VM = $BootVMs[$VMNumber]
                $VMName = $VM.Name
                
                # Get the actual Hyper-V VM object
                $VMObject = Get-VM `
                    -Name $VMName `
                    -ErrorAction SilentlyContinue 
                if (-not $VMObject)
                {
                    # if the VM does not exist then throw a non-terminating exception
                    $ExceptionParameters = @{
                        errorId = 'VMDoesNotExistError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDoesNotExistError `
                            -f $VMName)
                            
                    }
                    ThrowException @ExceptionParameters
                } # if
            
                # Shutodwn the VM if it is off
                if ($VMObject.State -eq 'Running')
                {
                    Write-Verbose -Message $($LocalizedData.StoppingVMMessage `
                        -f $VMName)
                    Stop-VM `
                        -VM $VMObject
                } # if
                
                # Determine if the VM has stopped.
                if ((Get-VM -VMName $VMName).State -ne 'Off')
                {
                    # It has not stopped
                    $PhaseAllStopped = $False
                } # if
                $VMNumber++
                if ($VMNumber -eq $VMCount)
                {
                    # We have stepped through all VMs in this Phase so check
                    # if all have stopped, otherwise reset the loop.
                    if ($PhaseAllStopped)
                    {
                        # if we have gone through all VMs in this "Bootphase"
                        # and they're all marked as booted then we can mark
                        # this phase as complete and allow moving on to the next one
                        Write-Verbose -Message $($LocalizedData.AllBootPhaseVMsStoppedMessage `
                            -f $BootPhase)
                        $PhaseComplete = $True
                    }
                    else
                    {
                        $PhaseAllStopped = $True
                    } # if
                    # Reset the VM Loop
                    $VMNumber = 0
                } # if
            } # while
            
            # Did we timeout?
            if (-not ($PhaseComplete))
            {
                # Yes, throw an exception
                $ExceptionParameters = @{
                    errorId = 'BootPhaseStopVMsTimeoutError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.BootPhaseStopVMsTimeoutError `
                        -f $BootPhase)
                        
                }
                ThrowException @ExceptionParameters
            }
        } # foreach

        Write-Verbose -Message $($LocalizedData.LabStopCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)    
    } # process

    end
    {
    } # end
} # Stop-Lab
#endregion