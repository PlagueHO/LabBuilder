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
function Copy-LabOdjFile {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM] $VM,

        [Int] $Timeout = 300
    )
    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $false
    [Boolean] $ODJCopyComplete = $false
    [System.String] $ODJFilename = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath "$($VM.ComputerName).txt"

    # If ODJ file does not exist then return
    if (-not (Test-Path -Path $ODJFilename))
    {
        return
    } # if

    # Get Path to LabBuilder files
    [System.String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    While ((-not $Complete) `
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
                errorId = 'ODJCopyError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.ODJCopyError `
                    -f $VM.Name,$ODJFilename)
            }
            New-LabException @exceptionParameters
            return
        } # if

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $ODJCopyComplete))
        {
            $CopyParameters = @{
                Destination = 'C:\Windows\Setup\ODJFiles\'
                ToSession = $Session
                Force = $true
                ErrorAction = 'Stop'
            }

            # Connection has been made OK, upload the ODJ files
            While ((-not $ODJCopyComplete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                Try
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMMessage `
                        -f $VM.Name,'ODJ')

                     Copy-Item `
                        @CopyParameters `
                        -Path (Join-Path `
                            -Path $VMLabBuilderFiles `
                            -ChildPath "$($VM.ComputerName).txt") `
                        -Verbose
                    $ODJCopyComplete = $true
                }
                Catch
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMFailedMessage `
                        -f $VM.Name,'ODJ',$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # try
            } # while
        } # if

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $ODJCopyComplete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $exceptionParameters = @{
                errorId = 'ODJCopyError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.ODJCopyError `
                    -f $VM.Name,$ODJFilename)
            }
            New-LabException @exceptionParameters
        } # if


            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $Complete = $true
    } # while
}
