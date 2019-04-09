<#
    .SYNOPSIS
        Updates the VM Integration Services to match the VM Configuration.

    .DESCRIPTION
        This cmdlet will take the VM object provided and ensure the integration services specified
        in it are enabled.

        The function will use comma delimited list of integration services in the VM object passed
        and enable the integration services listed for this VM.

        If the IntegrationServices property of the VM is not set or set to null then ALL integration
        services will be ENABLED.

        If the IntegrationServices property of the VM is set but is blank then ALL integration
        services will be DISABLED.

        The IntegrationServices property should contain a comma delimited list of Integration Services
        that should be enabled.

        The currently available Integration Services are:
        - Guest Service Interface
        - Heartbeat
        - Key-Value Pair Exchange
        - Shutdown
        - Time Synchronization
        - VSS

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Update-LabVMIntegrationService -VM VM[0]
        This will update the Integration Services for the first VM in the configuration file c:\mylab\config.xml.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .OUTPUTS
        None.
#>
function Update-LabVMIntegrationService
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [LabVM]
        $VM
    )

    # Configure the Integration services
    $integrationServices = $VM.IntegrationServices
    if ($null -eq $integrationServices)
    {
        # Get the full list of Integration Service names localized
        $integrationServices = ((Get-LabIntegrationServiceName) -Join ',')
    }

    $enabledIntegrationServices = $integrationServices -split ','
    $existingIntegrationServices = Get-VMIntegrationService `
        -VMName $VM.Name `
        -ErrorAction Stop

    # Loop through listed integration services and enable them
    foreach ($existingIntegrationService in $existingIntegrationServices)
    {
        if ($existingIntegrationService.Name -in $enabledIntegrationServices)
        {
            # This integration service should be enabled
            if (-not $existingIntegrationService.Enabled)
            {
                # It is disabled so enable it
                $existingIntegrationService | Enable-VMIntegrationService

                Write-LabMessage -Message $($LocalizedData.EnableVMIntegrationServiceMessage `
                    -f $VM.Name,$existingIntegrationService.Name)
            } # if
        }
        else
        {
            # This integration service should be disabled
            if ($existingIntegrationService.Enabled)
            {
                # It is enabled so disable it
                $existingIntegrationService | Disable-VMIntegrationService

                Write-LabMessage -Message $($LocalizedData.DisableVMIntegrationServiceMessage `
                    -f $VM.Name,$existingIntegrationService.Name)
            } # if
        } # if
    } # foreach
}
