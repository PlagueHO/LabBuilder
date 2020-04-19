<#
    .SYNOPSIS
        This function prepares the PowerShell scripts used for starting up DSC on a VM.

    .DESCRIPTION
        Two PowerShell scripts will be created by this function in the LabBuilder Files
        folder of the VM:
            1. StartDSC.ps1 - the script that is called automatically to start up DSC.
            2. StartDSCDebug.ps1 - a debug script that will start up DSC in debug mode.
        These scripts will contain code to perform the following operations:
            1. Configure the names of the Network Adapters so that they will match the
                names in the DSC Configuration files.
            2. Enable/Disable DSC Event Logging.
            3. Apply Configuration to the Local Configuration Manager.
            4. Start DSC.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Set-LabDSC -Lab $Lab -VM $VMs[0]
        Prepare the first VM in the Lab c:\mylab\config.xml for DSC start up.

    .OUTPUTS
        None.
#>
function Set-LabDSC
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM
    )

    $dscStartPs = ''

    # Get Path to LabBuilder files
    $vmLabBuilderFiles = $VM.LabBuilderFilesPath

    <#
        Relabel the Network Adapters so that they match what the DSC Networking config will use
        This is because unfortunately the Hyper-V Device Naming feature doesn't work.
    #>
    $managementSwitchName = Get-LabManagementSwitchName -Lab $Lab
    $adapters = [System.String[]] ($VM.Adapters).Name
    $adapters += @($managementSwitchName)

    foreach ($adapter in $adapters)
    {
        $netAdapter = Get-VMNetworkAdapter -VMName $($VM.Name) -Name $adapter

        if (-not $netAdapter)
        {
            $exceptionParameters = @{
                errorId       = 'NetworkAdapterNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.NetworkAdapterNotFoundError `
                        -f $adapter, $VM.Name)
            }
            New-LabException @exceptionParameters
        } # if

        $macAddress = $netAdapter.MacAddress

        if (-not $macAddress)
        {
            $exceptionParameters = @{
                errorId       = 'NetworkAdapterBlankMacError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.NetworkAdapterBlankMacError `
                        -f $adapter, $VM.Name)
            }
            New-LabException @exceptionParameters
        } # If

        $dscStartPs += @"
Get-NetAdapter ``
    | Where-Object { `$_.MacAddress.Replace('-','') -eq '$macAddress' } ``
    | Rename-NetAdapter -NewName '$($adapter)'

"@
    } # Foreach

    <#
        Enable DSC logging (as long as it hasn't been already)
        Nano Server doesn't have the Microsoft-Windows-Dsc/Analytic channels so
        Logging can't be enabled.
    #>
    if ($VM.OSType -ne [LabOSType]::Nano)
    {
        $logging = ($VM.DSC.Logging).ToString()

        $dscStartPs += @"
`$Result = & "wevtutil.exe" get-log "Microsoft-Windows-Dsc/Analytic"
if (-not (`$Result -like '*enabled: true*')) {
    & "wevtutil.exe" set-log "Microsoft-Windows-Dsc/Analytic" /q:true /e:$logging
}
`$Result = & "wevtutil.exe" get-log "Microsoft-Windows-Dsc/Debug"
if (-not (`$Result -like '*enabled: true*')) {
    & "wevtutil.exe" set-log "Microsoft-Windows-Dsc/Debug" /q:true /e:$logging
}

"@
    } # if

    # Start the actual DSC Configuration
    $dscStartPs += @"
Set-DscLocalConfigurationManager ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\`" ``
    -Verbose  *>> `"`$(`$ENV:SystemRoot)\Setup\Scripts\DSC.log`"
Start-DSCConfiguration ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\`" ``
    -Force ``
    -Verbose  *>> `"`$(`$ENV:SystemRoot)\Setup\Scripts\DSC.log`"

"@
    $null = Set-Content `
        -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath 'StartDSC.ps1') `
        -Value $dscStartPs -Force

    $dscStartPsDebug = @"
param (
    [System.Boolean] `$WaitForDebugger
)
Set-DscLocalConfigurationManager ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\`" ``
    -Verbose
if (`$WaitForDebugger)
{
    Enable-DscDebug ``
        -BreakAll
}
Start-DSCConfiguration ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\`" ``
    -Force ``
    -Debug ``
    -Wait ``
    -Verbose
if (`$WaitForDebugger)
{
    Disable-DscDebug
}
"@

    $null = Set-Content `
        -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath 'StartDSCDebug.ps1') `
        -Value $dscStartPsDebug -Force
}
