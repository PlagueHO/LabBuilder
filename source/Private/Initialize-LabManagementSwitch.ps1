<#
    .SYNOPSIS
        Create the LabBuilder Management Network switch and assign VLAN

    .DESCRIPTION
        Each lab needs a unique private management switch created for it.
        All Virtual Machines in the Lab are connected to the switch.
        This function creates the virtual switch and attaches an adapter
        to it and assigns it to a VLAN.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        Initialize-LabManagementSwitch -Lab $Lab
        Creates or updates the Management Switch for the Lab c:\mylab\config.xml.

    .OUTPUTS
        None.
#>
function Initialize-LabManagementSwitch
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab
    )

    # Used by host to communicate with Lab VMs
    $managementSwitchName = Get-LabManagementSwitchName -Lab $Lab

    Write-LabMessage -Message $($LocalizedData.InitializingLabManagementVirtualNetworkMesage `
        -f $managementSwitchName)

    if ($Lab.labbuilderconfig.switches.ManagementVlan)
    {
        $requiredManagementVlan = $Lab.labbuilderconfig.switches.ManagementVlan
    }
    else
    {
        $requiredManagementVlan = $script:DefaultManagementVLan
    }

    $managementSwitch = Get-VMSwitch | Where-Object -Property Name -eq $managementSwitchName

    if ($managementSwitch.Count -eq 0)
    {
        $null = New-VMSwitch `
            -SwitchType Internal `
            -Name $managementSwitchName `
            -ErrorAction Stop

        Write-LabMessage -Message $($LocalizedData.CreatingLabManagementSwitchMessage `
                -f $managementSwitchName, $requiredManagementVlan)
    }

    # Check the Vlan ID of the adapter on the switch
    $existingManagementAdapter = Get-VMNetworkAdapter `
        -ManagementOS `
        -Name $managementSwitchName `
        -SwitchName $managementSwitchName `
        -ErrorAction SilentlyContinue

    if ($null -eq $existingManagementAdapter)
    {
        $existingManagementAdapter = Add-VMNetworkAdapter `
            -ManagementOS `
            -Name $managementSwitchName `
            -SwitchName $managementSwitchName `
            -ErrorAction Stop
    }

    $existingManagementAdapterVlan = Get-VMNetworkAdapterVlan `
        -VMNetworkAdapter $existingManagementAdapter

    $existingManagementVlan = $existingManagementAdapterVlan.AccessVlanId

    if ($existingManagementVlan -ne $requiredManagementVlan)
    {
        Write-LabMessage -Message $($LocalizedData.UpdatingLabManagementSwitchMessage `
            -f $managementSwitchName, $requiredManagementVlan)

        Set-VMNetworkAdapterVlan `
            -VMNetworkAdapter $existingManagementAdapter `
            -Access `
            -VlanId $requiredManagementVlan `
            -ErrorAction Stop
    }
}
