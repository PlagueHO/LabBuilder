<#
    .SYNOPSIS
        Download the existing self-signed certificate from a running VM.

    .DESCRIPTION
        This function uses PS Remoting to connect to a running VM and download the an existing
        Self-Signed certificate file that was written to the c:\windows folder of the guest operating
        system by the SetupComplete.ps1 script on the. The certificate will be downloaded to the VM's
        Labbuilder files folder.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .PARAMETER Timeout
        The maximum amount of time that this function can take to download the certificate.
        If the timeout is reached before the process is complete an error will be thrown.
        The timeout defaults to 300 seconds.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Recieve-LabSelfSignedCertificate -Lab $Lab -VM $VMs[0]
        Downloads the existing Self-signed certificate for the VM to the Labbuilder files folder of the
        VM.

    .OUTPUTS
        The path to the certificate file that was downloaded.
#>
function Recieve-LabSelfSignedCertificate
{
    [CmdLetBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM,

        [Parameter()]
        [System.Int32]
        $Timeout = 300
    )

    $startTime = Get-Date
    $session = $null
    $complete = $false

    # Get Path to LabBuilder files
    $vmLabBuilderFiles = $VM.LabBuilderFilesPath

    while ((-not $complete) `
        -and (((Get-Date) - $startTime).TotalSeconds) -lt $TimeOut)
    {
        $session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        # Failed to connnect to the VM
        if (-not $session)
        {
            $exceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            New-LabException @exceptionParameters
            return
        } # if

        if (($session) `
            -and ($session.State -eq 'Opened') `
            -and (-not $complete))
        {
            # We connected OK - download the Certificate file
            while ((-not $complete) `
                -and (((Get-Date) - $startTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    $null = Copy-Item `
                        -Path "c:\windows\$script:DSCEncryptionCert" `
                        -Destination $vmLabBuilderFiles `
                        -FromSession $session `
                        -ErrorAction Stop
                    $complete = $true
                }
                catch
                {
                    Write-LabMessage -Message $($LocalizedData.WaitingForCertificateMessage `
                        -f $VM.Name,$script:RetryConnectSeconds)

                    Start-Sleep -Seconds $script:RetryConnectSeconds
                } # try
            } # while
        } # if

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $complete) `
            -and (((Get-Date) - $startTime).TotalSeconds) -ge $TimeOut)
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $exceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            New-LabException @exceptionParameters
        } # if

        # Close the Session if it is opened and the download is complete
        if (($session) `
            -and ($session.State -eq 'Opened') `
            -and ($complete))
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue
        } # if
    } # while

    return (Get-Item -Path "$vmLabBuilderFiles\$($script:DSCEncryptionCert)")
}
