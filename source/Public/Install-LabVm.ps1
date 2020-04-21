function Install-LabVM
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [LabVM] $VM
    )

    [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # The VM is now ready to be started
    if ((Get-VM -Name $VM.Name).State -eq 'Off')
    {
        Write-LabMessage -Message $($LocalizedData.StartingVMMessage `
            -f $VM.Name)

        Start-VM -VMName $VM.Name
    } # if

    # We only perform this section of VM Initialization (DSC, Cert, etc) with Server OS
    if ($VM.DSC.ConfigFile)
    {
        # Has this VM been initialized before (do we have a cert for it)
        if (-not (Test-Path "$LabPath\$($VM.Name)\LabBuilder Files\$script:DSCEncryptionCert"))
        {
            # No, so check it is initialized and download the cert if required
            if (Wait-LabVMInitializationComplete -VM $VM -ErrorAction Continue)
            {
                Write-LabMessage -Message $($LocalizedData.CertificateDownloadStartedMessage `
                    -f $VM.Name)

                if ($VM.CertificateSource -eq [LabCertificateSource]::Guest)
                {
                    if (Recieve-LabSelfSignedCertificate -Lab $Lab -VM $VM)
                    {
                        Write-LabMessage -Message $($LocalizedData.CertificateDownloadCompleteMessage `
                            -f $VM.Name)
                    }
                    else
                    {
                        $exceptionParameters = @{
                            errorId = 'CertificateDownloadError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.CertificateDownloadError `
                                -f $VM.name)
                        }
                        New-LabException @exceptionParameters
                    } # if
                } # if
            }
            else
            {
                $exceptionParameters = @{
                    errorId = 'InitializationDidNotCompleteError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InitializationDidNotCompleteError `
                        -f $VM.name)
                }
                New-LabException @exceptionParameters
            } # if
        } # if

        if ($VM.OSType -in ([LabOStype]::Nano))
        {
        # Copy ODJ Files if it Exists
            Copy-LabOdjFile `
                -Lab $Lab `
                -VM $VM
        } # if

        # Create any DSC Files for the VM
        Initialize-LabDSC `
            -Lab $Lab `
            -VM $VM

        # Attempt to start DSC on the VM
        Start-LabDSC `
            -Lab $Lab `
            -VM $VM
    } # if
} # Install-LabVM
