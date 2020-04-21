<#
    .SYNOPSIS
        Waits for a VM to complete setup.

    .DESCRIPTION
        When a VM starts up for the first time various scripts are run that prepare the Virtual Machine
        to be managed as part of a Lab. This function will wait for these scripts to complete.
        It determines if the setup has been completed by using PowerShell remoting to connect to the
        VM and downloading the c:\windows\Setup\Scripts\InitialSetupCompleted.txt file. If this file
        does not exist then the initial setup has not been completed.

        The cmdlet will wait for a maximum of 300 seconds for this process to be completed.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .PARAMETER Timeout
        The maximum amount of time that this function will wait for the setup to complete.
        If the timeout is reached before the process is complete an error will be thrown.
        The timeout defaults to 300 seconds.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Wait-LabVMInitializationComplete -VM $VMs[0]
        Waits for the initial setup to complete on the first VM in the config.xml.

    .OUTPUTS
        The path to the local copy of the Initial Setup complete file in the Labbuilder files folder
        for this VM.
#>
function Wait-LabVMInitializationComplete
{
    [CmdLetBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM,

        [Parameter()]
        [System.Int32]
        $Timeout = 300
    )

    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [System.Boolean] $Complete = $false

    # Get the root path of the VM
    [System.String] $VMRootPath = $VM.VMRootPath

    # Get Path to LabBuilder files
    [System.String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    # Make sure the VM has started
    Wait-LabVMStarted -VM $VM

    [System.String] $InitialSetupCompletePath = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'InitialSetupCompleted.txt'

    # Check the initial setup on this VM hasn't already completed
    if (Test-Path -Path $InitialSetupCompletePath)
    {
        Write-LabMessage -Message $($LocalizedData.InitialSetupIsAlreadyCompleteMessaage `
                -f $VM.Name)
        return $InitialSetupCompletePath
    }

    while ((-not $Complete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
    {
        # Connect to the VM
        $Session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        # Failed to connnect to the VM
        if (-not $Session)
        {
            $exceptionParameters = @{
                errorId       = 'InitialSetupCompleteError'
                errorCategory = 'OperationTimeout'
                errorMessage  = $($LocalizedData.InitialSetupCompleteError `
                        -f $VM.Name)
            }
            New-LabException @exceptionParameters
            return
        }

        if (($Session) `
                -and ($Session.State -eq 'Opened') `
                -and (-not $Complete))
        {
            # We connected OK - Download the script
            while ((-not $Complete) `
                    -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    $null = Copy-Item `
                        -Path "c:\windows\Setup\Scripts\InitialSetupCompleted.txt" `
                        -Destination $VMLabBuilderFiles `
                        -FromSession $Session `
                        -Force `
                        -ErrorAction Stop
                    $Complete = $true
                }
                catch
                {
                    Write-LabMessage -Message $($LocalizedData.WaitingForInitialSetupCompleteMessage `
                            -f $VM.Name, $script:RetryConnectSeconds)
                    Start-Sleep `
                        -Seconds $script:RetryConnectSeconds
                } # try
            } # while
        } # if

        # If the process didn't complete and we're out of time throw an exception
        if ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $exceptionParameters = @{
                errorId       = 'InitialSetupCompleteError'
                errorCategory = 'OperationTimeout'
                errorMessage  = $($LocalizedData.InitialSetupCompleteError `
                        -f $VM.Name)
            }
            New-LabException @exceptionParameters
        }

        # Close the Session if it is opened
        if (($Session) `
                -and ($Session.State -eq 'Opened'))
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue
        } # if
    } # while

    return $InitialSetupCompletePath
}
