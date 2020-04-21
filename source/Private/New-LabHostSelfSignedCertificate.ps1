<#
    .SYNOPSIS
        Generate a new credential encryption certificate on the Host for a VM.

    .DESCRIPTION
        This function will create a new self-signed certificate on the host that can be uploaded
        to the VM that it is created for. The certificate will be created in the LabBuilder files
        folder for the specified VM.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        New-LabHostSelfSignedCertificate -Lab $Lab -VM $VMs[0]
        Causes a new self-signed certificate for the VM and stores it to the Labbuilder files folder
        of th VM.

    .OUTPUTS
        The path to the certificate file that was created.
#>
function New-LabHostSelfSignedCertificate
{
    [CmdLetBinding()]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM
    )

    # Get Path to LabBuilder files
    $vmLabBuilderFiles = $VM.LabBuilderFilesPath

    $certificateFriendlyName = $script:DSCCertificateFriendlyName
    $certificateSubject = "CN=$($VM.ComputerName)"

    # Create the self-signed certificate for the destination VM
    . $script:SupportGertGenPath
    New-SelfsignedCertificateEx `
        -Subject $certificateSubject `
        -EKU 'Document Encryption','Server Authentication','Client Authentication' `
        -KeyUsage 'DigitalSignature, KeyEncipherment, DataEncipherment' `
        -SAN $VM.ComputerName `
        -FriendlyName $certificateFriendlyName `
        -Exportable `
        -StoreLocation 'LocalMachine' `
        -StoreName 'My' `
        -KeyLength $script:SelfSignedCertKeyLength `
        -ProviderName $script:SelfSignedCertProviderName `
        -AlgorithmName $script:SelfSignedCertAlgorithmName `
        -SignatureAlgorithm $script:SelfSignedCertSignatureAlgorithm `
        -ErrorAction Stop

    # Locate the newly created certificate
    $certificate = Get-ChildItem -Path cert:\LocalMachine\My `
        | Where-Object {
            ($_.FriendlyName -eq $certificateFriendlyName) `
            -and ($_.Subject -eq $certificateSubject)
        } | Select-Object -First 1

    # Export the certificate with the Private key in
    # preparation for upload to the VM
    $certificatePassword = ConvertTo-SecureString `
        -String $script:DSCCertificatePassword `
        -Force `
        -AsPlainText
    $certificatePfxDestination = Join-Path `
        -Path $vmLabBuilderFiles `
        -ChildPath $script:DSCEncryptionPfxCert
    $null = Export-PfxCertificate `
        -FilePath $certificatePfxDestination `
        -Cert $certificate `
        -Password $certificatePassword `
        -ErrorAction Stop

    # Export the certificate without a private key
    $certificateDestination = Join-Path `
        -Path $vmLabBuilderFiles `
        -ChildPath $script:DSCEncryptionCert
    $null = Export-Certificate `
        -Type CERT `
        -FilePath $certificateDestination `
        -Cert $certificate `
        -ErrorAction Stop

    # Remove the certificate from the Local Machine store
    $certificate | Remove-Item

    return (Get-Item -Path $certificateDestination)
}
