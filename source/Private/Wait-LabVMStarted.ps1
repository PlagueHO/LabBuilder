<#
    .SYNOPSIS
        Wait for the VM to enter the running state.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .OUTPUTS
        None.
#>
function Wait-LabVMStarted
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM
    )

    # If the VM is not running then throw an exception
    if ((Get-VM -VMName $VM.Name).State -ne 'Running') {
        $exceptionParameters = @{
            errorId = 'VMNotRunningHeartbeatMessage'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.VMNotRunningHeartbeatMessage `
                -f $VM.name)
        }
        New-LabException @exceptionParameters
    } # if

    # Names of IntegrationServices are not culture neutral, but have an ID
    $heartbeatCultureNeutral = ( Get-VMIntegrationService -VMName $VM.Name | Where-Object { $_.ID -match "84EAAE65-2F2E-45F5-9BB5-0E857DC8EB47" } ).Name
    $heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name $heartbeatCultureNeutral

    while (($heartbeat.PrimaryStatusDescription -ne 'OK') -and (-not [System.String]::IsNullOrEmpty($heartbeat.PrimaryStatusDescription)))
    {
        $heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name $heartbeatCultureNeutral

        Write-LabMessage -Message $($LocalizedData.WaitingForVMHeartbeatMessage `
            -f $VM.Name,$script:RetryHeartbeatSeconds)

        Start-Sleep -Seconds $script:RetryHeartbeatSeconds
    } # while
}
