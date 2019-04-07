<#
.SYNOPSIS
    Prepares the the files for initializing a new VM.
.DESCRIPTION
    This function creates the following files in the LabBuilder Files for the a VM in preparation
    for them to be applied to the VM VHD before it is booted up for the first time:
        1. Unattend.xml - a Windows Unattend.xml file.
        2. SetupComplete.cmd - the command file that gets run after the Windows OOBE is complete.
        3. SetupComplete.ps1 - this PowerShell script file that is run at the the end of the
                               SetupComplete.cmd.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    CreateVMInitializationFiles -Lab $Lab -VM $VMs[0]
    Prepare the first VM in the Lab c:\mylab\config.xml for initial boot.
.OUTPUTS
    None.
#>
function CreateVMInitializationFiles {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM] $VM
    )

    # Get Path to LabBuilder files
    [System.String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    # Generate an unattended setup file
    [System.String] $UnattendFile = GetUnattendFileContent `
        -Lab $Lab `
        -VM $VM
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'Unattend.xml') `
        -Value $UnattendFile -Force

    # Assemble the SetupComplete.* scripts.
    [System.String] $SetupCompleteCmd = ''

    # Write out the PS1 Setup Complete File
    if ($VM.OSType -eq [LabOSType]::Nano)
    {
        # For a Nano Server we also need to create the certificates
        # to upload to it (because it Nano Server can't generate them)
        $null = New-LabHostSelfSignedCertificate `
            -Lab $Lab `
            -VM $VM

        # PowerShell currently can't find any basic Cmdlets when executed by
        # SetupComplete.cmd during the initialization phase, so create an empty
        # a SetupComplete.ps1
        [System.String] $SetupCompletePs = ''

    }
    else
    {
        if ($VM.CertificateSource -eq [LabCertificateSource]::Host)
        {
            # Generate the PFX certificate on the host
            $null = New-LabHostSelfSignedCertificate `
                -Lab $Lab `
                -VM $VM
        }
        [System.String] $GetCertPs = GetCertificatePsFileContent `
            -Lab $Lab `
            -VM $VM
        [System.String] $SetupCompletePs = @"
Add-Content ``
    -Path "C:\WINDOWS\Setup\Scripts\SetupComplete.log" ``
    -Value 'SetupComplete.ps1 Script Started...' ``
    -Encoding Ascii
Start-Sleep -Seconds 30
$GetCertPs
Add-Content ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'Certificate identified and saved to C:\Windows\$Script:DSCEncryptionCert ...' ``
    -Encoding Ascii
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Add-Content ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'Windows Remoting Enabled ...' ``
    -Encoding Ascii
"@
    } # if

    if ($VM.SetupComplete)
    {
        [System.String] $SetupComplete = $VM.SetupComplete

        if (-not (Test-Path -Path $SetupComplete))
        {
            $exceptionParameters = @{
                errorId = 'SetupCompleteScriptMissingError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.SetupCompleteScriptMissingError `
                    -f $VM.name,$SetupComplete)
            }
            New-LabException @exceptionParameters
        }

        [System.String] $Extension = [System.IO.Path]::GetExtension($SetupComplete)

        Switch ($Extension.ToLower())
        {
            '.ps1'
            {
                $SetupCompletePs += Get-Content -Path $SetupComplete
                Break
            } # 'ps1'

            '.cmd'
            {
                $SetupCompleteCmd += Get-Content -Path $SetupComplete
                Break
            } # 'cmd'
        } # Switch
    } # If

    # Write out the CMD Setup Complete File
    if ($VM.OSType -eq [LabOSType]::Nano)
    {
        $SetupCompleteCmd = @"
@echo SetupComplete.cmd Script Started... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
$SetupCompleteCmd
certoc.exe -ImportPFX -p $Script:DSCCertificatePassword root $ENV:SystemRoot\$Script:DSCEncryptionPfxCert >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
@echo SetupComplete.cmd Script Finished... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
@echo Initial Setup Completed - this file indicates that setup has completed. >> %SYSTEMROOT%\Setup\Scripts\InitialSetupCompleted.txt
"@
    }
    else
    {
        $SetupCompleteCmd = @"
@echo SetupComplete.cmd Script Started... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log`r
$SetupCompleteCmd
@echo SetupComplete.cmd Execute SetupComplete.ps1... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log`r
powerShell.exe -ExecutionPolicy Unrestricted -Command `"%SYSTEMROOT%\Setup\Scripts\SetupComplete.ps1`" `r
@echo SetupComplete.cmd Script Finished... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
@echo Initial Setup Completed - this file indicates that setup has completed. >> %SYSTEMROOT%\Setup\Scripts\InitialSetupCompleted.txt
"@
    }

    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.cmd') `
        -Value $SetupCompleteCmd -Force

    # Write out the PowerShell Setup Complete file
    $SetupCompletePs = @"
Add-Content ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'SetupComplete.ps1 Script Started...' ``
    -Encoding Ascii
$SetupCompletePs
Add-Content ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'SetupComplete.ps1 Script Finished...' ``
    -Encoding Ascii
"@
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.ps1') `
        -Value $SetupCompletePs -Force

    # If ODJ file specified copy it to the labuilder path.
    if ($VM.OSType -eq [LabOSType]::Nano `
        -and -not [System.String]::IsNullOrWhiteSpace($VM.NanoODJPath))
    {
        if ([System.IO.Path]::IsPathRooted($VM.NanoODJPath))
        {
            $NanoODJPath = $VM.NanoODJPath
        }
        else
        {
            $NanoODJPath = Join-Path `
                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.NanoODJPath
        } # if

        $null = Copy-Item `
            -Path (Join-Path -Path $NanoODJPath -ChildPath "$($VM.ComputerName).txt") `
            -Destination $VMLabBuilderFiles `
            -ErrorAction Stop
    } # if

    Write-LabMessage -Message $($LocalizedData.CreatedVMInitializationFiles `
        -f $VM.Name)
} # CreateVMInitializationFiles


<#
.SYNOPSIS
    Assembles the content of a Unattend XML file that should be used to initialize
    Windows on the specified VM.
.DESCRIPTION
    This function will return the content of a standard Windows Unattend XML file
    that can be written to an VHD containing a copy of Windows that is still in
    OOBE mode.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    GetUnattendFileContent -Lab $Lab -VM $VMs[0]
    Returns the content of the Unattend File for the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
    The content of the Unattend File for the VM.
#>
function GetUnattendFileContent {
    [CmdLetBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM] $VM
    )
    if ($VM.UnattendFile)
    {
        [System.String] $UnattendContent = Get-Content -Path $VM.UnattendFile
    }
    Else
    {
        [System.String] $DomainName = $Lab.labbuilderconfig.settings.domainname
        [System.String] $Email = $Lab.labbuilderconfig.settings.email
        $UnattendContent = [System.String] @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="offlineServicing">
        <component name="Microsoft-Windows-LUA-Settings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <EnableLUA>false</EnableLUA>
        </component>
    </settings>
    <settings pass="generalize">
        <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipRearm>1</SkipRearm>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0409:00000409</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipAutoActivation>true</SkipAutoActivation>
        </component>
        <component name="Microsoft-Windows-SQMApi" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <CEIPEnabled>0</CEIPEnabled>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$($VM.ComputerName)</ComputerName>
        </component>
"@


        if ($VM.OSType -eq [LabOSType]::Client)
        {
            $UnattendContent += @"
            <component name="Microsoft-Windows-Deployment" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <RunSynchronous>
                    <RunSynchronousCommand wcm:action="add">
                        <Order>1</Order>
                        <Path>net user administrator /active:yes</Path>
                    </RunSynchronousCommand>
                </RunSynchronous>
            </component>

"@
        } # If
        $UnattendContent += @"
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <UserAccounts>
               <AdministratorPassword>
                  <Value>$($VM.AdministratorPassword)</Value>
                  <PlainText>true</PlainText>
               </AdministratorPassword>
            </UserAccounts>
            <RegisteredOrganization>$($DomainName)</RegisteredOrganization>
            <RegisteredOwner>$($Email)</RegisteredOwner>
            <DisableAutoDaylightTimeSet>false</DisableAutoDaylightTimeSet>
            <TimeZone>$($VM.TimeZone)</TimeZone>
        </component>
        <component name="Microsoft-Windows-ehome-reg-inf" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="NonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RestartEnabled>true</RestartEnabled>
        </component>
        <component name="Microsoft-Windows-ehome-reg-inf" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="NonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RestartEnabled>true</RestartEnabled>
        </component>
    </settings>
</unattend>
"@
    }
    Return $UnattendContent
} # GetUnattendFileContent


<#
.SYNOPSIS
    Assemble the the PowerShell commands required to create a self-signed certificate.
.DESCRIPTION
    This function creates the content that can be written into a PS1 file to create a self-signed
    certificate.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    $CertificatePS = GetCertificatePsFileContent -Lab $Lab -VM $VMs[0]
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
function GetCertificatePsFileContent {
    [CmdLetBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM] $VM,

        [LabCertificateSource] $CertificateSource
    )
    # If a CertificateSource is not provided get it from the VM.
    if (-not $CertificateSource)
    {
        $CertificateSource = $VM.CertificateSource
    } # if
    if ($CertificateSource -eq [LabCertificateSource]::Guest)
    {
        [System.String] $CreateCertificatePs = @"
`$CertificateFriendlyName = '$($Script:DSCCertificateFriendlyName)'
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
        -KeyLength $($Script:SelfSignedCertKeyLength) ``
        -ProviderName '$($Script:SelfSignedCertProviderName)' ``
        -AlgorithmName $($Script:SelfSignedCertAlgorithmName) ``
        -SignatureAlgorithm $($Script:SelfSignedCertSignatureAlgorithm)
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
    -FilePath `"`$(`$ENV:SystemRoot)\$Script:DSCEncryptionCert`"
Add-Content ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'Encryption Certificate Imported from CER ...' ``
    -Encoding Ascii
"@
    }
    else
    {
        [System.String] $CreateCertificatePs = @"
if (Test-Path -Path `"`$(`$ENV:SystemRoot)\$Script:DSCEncryptionPfxCert`")
{
    `$CertificatePassword = ConvertTo-SecureString ``
        -String '$Script:DSCCertificatePassword' ``
        -Force ``
        -AsPlainText
    Add-Content ``
        -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
        -Value 'Importing Encryption Certificate from PFX ...' ``
        -Encoding Ascii
    Import-PfxCertificate ``
        -Password '$Script:DSCCertificatePassword' ``
        -FilePath `"`$(`$ENV:SystemRoot)\$Script:DSCEncryptionPfxCert`" ``
        -CertStoreLocation cert:\localMachine\root
    Add-Content ``
        -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
        -Value 'Encryption Certificate from PFX Imported...' ``
        -Encoding Ascii
}
"@
    } # if
    Return $CreateCertificatePs
} # GetCertificatePsFileContent
