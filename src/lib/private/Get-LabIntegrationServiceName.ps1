<#
    .SYNOPSIS
        Get list of Integration Service names (localized)

    .DESCRIPTION
        This cmdlet will get the list of Integration services available on a Hyper-V host.
        The list of Integration Services will contain the localized names.

    .EXAMPLE
        Get-LabIntegrationServiceName

    .OUTPUTS
        An array of localized Integration Serivce names.
#>
function Get-LabIntegrationServiceName
{
    [CmdLetBinding()]
    param
    (
    )

    $captions = @()
    $classes = @(
        'Msvm_VssComponentSettingData'
        'Msvm_ShutdownComponentSettingData'
        'Msvm_TimeSyncComponentSettingData'
        'Msvm_HeartbeatComponentSettingData'
        'Msvm_GuestServiceInterfaceComponentSettingData'
        'Msvm_KvpExchangeComponentSettingData'
    )

    <#
        This Integration Service is registered in CIM but is not exposed in Hyper-V:
        'Msvm_RdvComponentSettingData'
    #>

    foreach ($class in $classes)
    {
        $captions += (Get-CimInstance `
            -Class $class `
            -Namespace Root\Virtualization\V2 `
            -Property Caption | Select-Object -First 1).Caption
    } # foreach

    return $captions
}
