<#
    .SYNOPSIS
        Assemble the the PowerShell commands required to create a self-signed certificate.

    .DESCRIPTION
        This function creates the content that can be written into a PS1 file to create a self-signed
        certificate.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        $CertificatePS = Get-LabCertificatePsFileContent -Lab $Lab -VM $VMs[0]
        Return the Create Self-Signed Certificate script for the first VM in the
        Lab c:\mylab\config.xml for DSC configuration.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .PARAMETER CertificateSource
        A CertificateSource to use instead of the one contained in the VM.

    .OUTPUTS
        A string containing the Create Self-Signed Certificate PowerShell code.
#>
function Get-LabCertificatePsFileContent
{
    [CmdLetBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM,

        [Parameter()]
        [LabCertificateSource]
        $CertificateSource
    )

    # If a CertificateSource is not provided get it from the VM.
    if (-not $CertificateSource)
    {
        $CertificateSource = $VM.CertificateSource
    } # if

    if ($CertificateSource -eq [LabCertificateSource]::Guest)
    {
        $createCertificatePs = @"
`$CertificateFriendlyName = '$($script:DSCCertificateFriendlyName)'
`$Cert = Get-ChildItem -Path cert:\LocalMachine\My ``
    | Where-Object { `$_.FriendlyName -eq `$CertificateFriendlyName } ``
    | Select-Object -First 1
if (-not `$Cert)
{
    . `"`$(`$ENV:SystemRoot)\Setup\Scripts\New-SelfSignedCertificateEx.ps1`"
    New-SelfsignedCertificateEx ``
        -Subject 'CN=$($VM.ComputerName)' ``
        -EKU '1.3.6.1.4.1.311.80.1','1.3.6.1.5.5.7.3.1','1.3.6.1.5.5.7.3.2' ``
        -KeyUsage 'DigitalSignature, KeyEncipherment, DataEncipherment' ``
        -SAN '$($VM.ComputerName)' ``
        -FriendlyName `$CertificateFriendlyName ``
        -Exportable ``
        -StoreLocation 'LocalMachine' ``
        -StoreName 'My' ``
        -KeyLength $($script:SelfSignedCertKeyLength) ``
        -ProviderName '$($script:SelfSignedCertProviderName)' ``
        -AlgorithmName $($script:SelfSignedCertAlgorithmName) ``
        -SignatureAlgorithm $($script:SelfSignedCertSignatureAlgorithm)
    # There is a slight delay before new cert shows up in Cert:
    # So wait for it to show.
    While (-not `$Cert)
    {
        `$Cert = Get-ChildItem -Path cert:\LocalMachine\My ``
            | Where-Object { `$_.FriendlyName -eq `$CertificateFriendlyName }
    }
}
Export-Certificate ``
    -Type CERT ``
    -Cert `$Cert ``
    -FilePath `"`$(`$ENV:SystemRoot)\$script:DSCEncryptionCert`"
Add-Content ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'Encryption Certificate Imported from CER ...' ``
    -Encoding Ascii
"@
    }
    else
    {
        [System.String] $createCertificatePs = @"
if (Test-Path -Path `"`$(`$ENV:SystemRoot)\$script:DSCEncryptionPfxCert`")
{
    `$CertificatePassword = ConvertTo-SecureString ``
        -String '$script:DSCCertificatePassword' ``
        -Force ``
        -AsPlainText
    Add-Content ``
        -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
        -Value 'Importing Encryption Certificate from PFX ...' ``
        -Encoding Ascii
    Import-PfxCertificate ``
        -Password '$script:DSCCertificatePassword' ``
        -FilePath `"`$(`$ENV:SystemRoot)\$script:DSCEncryptionPfxCert`" ``
        -CertStoreLocation cert:\localMachine\root
    Add-Content ``
        -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
        -Value 'Encryption Certificate from PFX Imported...' ``
        -Encoding Ascii
}
"@
    } # if

    return $createCertificatePs
}
