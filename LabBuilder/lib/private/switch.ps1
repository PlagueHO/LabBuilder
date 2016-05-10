<#
.SYNOPSIS
    Returns the name of the Management Switch to use for this lab.
.DESCRIPTION
    Each lab has a unique private management switch created for it.
    All Virtual Machines in the Lab are connected to the switch.
    This function returns the name of this swtich for the provided
    lab configuration.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $ManagementSwtich = GetManagementSwitchName -Lab $Lab
    Returns the Management Switch for the Lab c:\mylab\config.xml.
.OUTPUTS
    A management switch name.
#>
function GetManagementSwitchName {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        $Lab
    )

    [String] $LabId = $Lab.labbuilderconfig.settings.labid 
    if (-not $LabId)
    {
        $LabId = $Lab.labbuilderconfig.name
    } # if
    $ManagementSwitchName = ('{0} Lab Management' `
        -f $LabId)

    return $ManagementSwitchName
} # GetManagementSwitchName

<#
.SYNOPSIS
    Ensures that the Management OS virtual adapter is attached to a Virtual Switch.
.DESCRIPTION
    This function is used to add or update the specified virtual network adapter
    that is used by the Management OS to connect to the specifed virtual switch.
.PARAMETER Name
    Contains the name of the virtual network adapter to add.
.PARAMETER SwitchName
    Contains the name of the virtual switch to connect this adapter to.
.PARAMETER StaticMacAddress
    This optional parameter contains the static MAC address to assign to the virtual
    network adapter.
.PARAMETER VlanId
    This optional parameter contains the VLan Id to assign to this network adapter.
.EXAMPLE
    UpdateSwitchManagementAdapter -Name 'Domain Nat SMB' -SwitchName 'Domain Nat' -VlanId 25 
.OUTPUTS
    None.
#>
function UpdateSwitchManagementAdapter {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [String] $Name,

        [Parameter(Mandatory)]
        [String] $SwitchName,

        [String] $StaticMacAddress,

        [Byte] $VLanId
    )
    # Remove VLanId Parameter so this can be splatted
    $PSBoundParameters.Remove('VLanId')
    $PSBoundParameters.Remove('StaticMacAddress')

    $Adapter = Get-VMNetworkAdapter `
        -ManagementOS `
        @PSBoundParameters `
        -ErrorAction Stop
    if (-not $Adapter)
    {
        # Adapter does not exist so add it
        $Adapter = Add-VMNetworkAdapter `
            -ManagementOS `
            @PSBoundParameters `
            -Passthru
    } # if

    # Set or clear the static mac address
    if ([String]::IsNullOrEmpty($StaticMacAddress))
    {
        $MacSplat = @{ DynamicMacAddress = $true }
    }
    else
    { 
        $MacSplat = @{ StaticMacAddress = $StaticMacAddress }
    } # if
    $Adapter | Set-VMNetworkAdapter `
        @MacSplat `
        -ErrorAction Stop

    # Set or clear the VLanId
    if ($VLanId)
    {
        $VlanSplat = @{ VlanId = $VlanId }
    }
    else
    { 
        $VlanSplat = @{ Untagged = $True }
    } # if
    $Adapter | Set-VMNetworkAdapterVlan `
        -Access `
        @VlanSplat `
        -ErrorAction Stop
} # UpdateSwitchManagementAdapter
