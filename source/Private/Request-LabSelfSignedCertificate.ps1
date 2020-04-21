<#
    .SYNOPSIS
        Generate and download a new credential encryption certificate from a running VM.

    .DESCRIPTION
        This function uses PS Remoting to connect to a running VM and upload the GetDSCEncryptionCert.ps1
        script and then run it. This wil create a new self-signed certificate that is written to the
        c:\windows folder of the guest operating system. The certificate will be downloaded to the VM's
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
        Request-LabSelfSignedCertificate -Lab $Lab -VM $VMs[0]
        Causes a new self-signed certificate on the VM and download it to the Labbuilder files folder
        of th VM.

    .OUTPUTS
        The path to the certificate file that was downloaded.
#>
function Request-LabSelfSignedCertificate
{
    [CmdLetBinding()]
    [OutputType([System.IO.FileInfo])]
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

    # Ensure the certificate generation script has been created
    $getCertPs = Get-LabCertificatePsFileContent `
        -Lab $Lab `
        -VM $VM `
        -CertificateSource Guest

    $null = Set-Content `
        -Path "$VMLabBuilderFiles\GetDSCEncryptionCert.ps1" `
        -Value $getCertPs `
        -Force

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

        $complete = $false

        if (($session) `
            -and ($session.State -eq 'Opened') `
            -and (-not $complete))
        {
            # We connected OK - Upload the script
            while ((-not $complete) `
                -and (((Get-Date) - $startTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    Copy-Item `
                        -Path "$VMLabBuilderFiles\GetDSCEncryptionCert.ps1" `
                        -Destination 'c:\windows\setup\scripts\' `
                        -ToSession $session `
                        -Force `
                        -ErrorAction Stop
                    $complete = $true
                }
                catch
                {
                    Write-LabMessage -Message $($LocalizedData.FailedToUploadCertificateCreateScriptMessage `
                        -f $VM.Name,$script:RetryConnectSeconds)

                    Start-Sleep -Seconds $script:RetryConnectSeconds
                } # try
            } # while
        } # if

        $complete = $false

        if (($session) `
            -and ($session.State -eq 'Opened') `
            -and (-not $complete))
        {
            # Script uploaded, run it
            while ((-not $complete) `
                -and (((Get-Date) - $startTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    Invoke-Command -Session $session -ScriptBlock {
                        C:\Windows\Setup\Scripts\GetDSCEncryptionCert.ps1
                    }

                    $complete = $true
                }
                catch
                {
                    Write-LabMessage -Message $($LocalizedData.FailedToExecuteCertificateCreateScriptMessage `
                        -f $VM.Name,$script:RetryConnectSeconds)

                    Start-Sleep -Seconds $script:RetryConnectSeconds
                } # try
            } # while
        } # if

        $complete = $false

        if (($session) `
            -and ($session.State -eq 'Opened') `
            -and (-not $complete))
        {
            # Now download the Certificate
            while ((-not $complete) `
                -and (((Get-Date) - $startTime).TotalSeconds) -lt $TimeOut)
            {
                try {
                    $null = Copy-Item `
                        -Path "c:\windows\$($script:DSCEncryptionCert)" `
                        -Destination $vmLabBuilderFiles `
                        -FromSession $session `
                        -ErrorAction Stop

                    $complete = $true
                }
                catch
                {
                    Write-LabMessage -Message $($LocalizedData.FailedToDownloadCertificateMessage `
                        -f $VM.Name,$script:RetryConnectSeconds)

                    Start-Sleep -Seconds $script:RetryConnectSeconds
                } # Try
            } # While
        } # If

        # If the process didn't complete and we're out of time throw an exception
        if ((-not $complete) `
            -and (((Get-Date) - $startTime).TotalSeconds) -ge $TimeOut)
        {
            if ($session)
            {
                Remove-PSSession -Session $session
            }

            $exceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            New-LabException @exceptionParameters
        }

        # Close the Session if it is opened and the download is complete
        if (($session) `
            -and ($session.State -eq 'Opened') `
            -and ($complete))
        {
            Remove-PSSession -Session $session
        } # If
    } # While

    return (Get-Item -Path "$vmLabBuilderFiles\$($script:DSCEncryptionCert)")
}
