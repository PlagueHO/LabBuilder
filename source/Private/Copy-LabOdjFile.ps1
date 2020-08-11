<#
    .SYNOPSIS
        Uploads Precreated ODJ files to Nano systems or others as required.

    .DESCRIPTION
        This function will perform the following tasks:
            1. Connect to the VM via remoting.
            2. Upload the ODJ file to c:\windows\setup\ODJFiles folder of the VM.
        If the ODJ file does not exist in the LabFiles folder for the VM then the
        copy will not be performed.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .PARAMETER Timeout
        The maximum amount of time that this function can take to perform the copy.
        If the timeout is reached before the process is complete an error will be thrown.
        The timeout defaults to 300 seconds.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Copy-LabOdjFile -Lab $Lab -VM $VMs[0]

    .OUTPUTS
        None.
#>
function Copy-LabOdjFile
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM,

        [System.Int32]
        $Timeout = 300
    )

    $startTime = Get-Date
    $session = $null
    $complete = $false
    $odjCopyComplete = $false
    $odjFilename = Join-Path `
        -Path $vmLabBuilderFiles `
        -ChildPath "$($VM.ComputerName).txt"

    # If ODJ file does not exist then return
    if (-not (Test-Path -Path $odjFilename))
    {
        return
    } # if

    # Get Path to LabBuilder files
    $vmLabBuilderFiles = $VM.LabBuilderFilesPath

    while ((-not $complete) `
        -and (((Get-Date) - $startTime).TotalSeconds) -lt $TimeOut)
    {
        # Connect to the VM
        $session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        # Failed to connnect to the VM
        if (-not $session)
        {
            $exceptionParameters = @{
                errorId = 'ODJCopyError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.ODJCopyError `
                    -f $VM.Name,$odjFilename)
            }
            New-LabException @exceptionParameters
            return
        } # if

        if (($session) `
            -and ($session.State -eq 'Opened') `
            -and (-not $odjCopyComplete))
        {
            $CopyParameters = @{
                Destination = 'C:\Windows\Setup\ODJFiles\'
                ToSession = $session
                Force = $true
                ErrorAction = 'Stop'
            }

            # Connection has been made OK, upload the ODJ files
            while ((-not $odjCopyComplete) `
                -and (((Get-Date) - $startTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMMessage `
                        -f $VM.Name,'ODJ')

                     Copy-Item `
                        @CopyParameters `
                        -Path (Join-Path `
                            -Path $vmLabBuilderFiles `
                            -ChildPath "$($VM.ComputerName).txt") `
                        -Verbose
                    $odjCopyComplete = $true
                }
                catch
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMFailedMessage `
                        -f $VM.Name,'ODJ',$script:RetryConnectSeconds)

                    Start-Sleep -Seconds $script:RetryConnectSeconds
                } # try
            } # while
        } # if

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $odjCopyComplete) `
            -and (((Get-Date) - $startTime).TotalSeconds) -ge $TimeOut)
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $exceptionParameters = @{
                errorId = 'ODJCopyError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.ODJCopyError `
                    -f $VM.Name,$odjFilename)
            }
            New-LabException @exceptionParameters
        } # if


        # Disconnect from the VM
        Disconnect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        $complete = $true
    } # while
}
