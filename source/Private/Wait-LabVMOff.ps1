<#
    .SYNOPSIS
        Wait for VM to enter the Off state.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM.

    .OUTPUTS
        None.
#>
function Wait-LabVMOff
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM
    )

    $runningVM = Get-VM -Name $VM.Name
    while ($runningVM.State -ne 'Off')
    {
        $runningVM = Get-VM -Name $VM.Name
        Start-Sleep -Seconds $script:RetryHeartbeatSeconds
    } # while
}
