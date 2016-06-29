<#
.SYNOPSIS
    Creates the folder structure that will contain a Lab Virtual Machine.
.DESCRIPTION
    Creates a standard Hyper-V Virtual Machine folder structure as well as additional folders
    for containing configuration files for DSC.
.PARAMETER vmpath
    The path to the folder where the Virtual Machine files are stored.
.EXAMPLE
    InitializeVMPaths -VMPath 'c:\VMs\Lab\Virtual Machine 1'
    The command will create the Virtual Machine structure for a Lab VM in the folder:
    'c:\VMs\Lab\Virtual Machine 1'
.OUTPUTS
    None.
#>
function InitializeVMPaths {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $VMPath
    )

    if (-not (Test-Path -Path $VMPath))
    {
        $Null = New-Item `
            -Path $VMPath `
            -ItemType Directory
    } # if
    if (-not (Test-Path -Path "$VMPath\Virtual Machines"))
    {
        $Null = New-Item `
            -Path "$VMPath\Virtual Machines" `
            -ItemType Directory
    } # if
    if (-not (Test-Path -Path "$VMPath\Virtual Hard Disks"))
    {
        $Null = New-Item `
        -Path "$VMPath\Virtual Hard Disks" `
        -ItemType Directory
    } # if
    if (-not (Test-Path -Path "$VMPath\LabBuilder Files"))
    {
        $Null = New-Item `
            -Path "$VMPath\LabBuilder Files" `
            -ItemType Directory
    } # if
    if (-not (Test-Path -Path "$VMPath\LabBuilder Files\DSC Modules"))
    {
        $Null = New-Item `
            -Path "$VMPath\LabBuilder Files\DSC Modules" `
            -ItemType Directory
    } # if
} # InitializeVMPaths


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
        [Parameter(Mandatory)]
        $Lab,

        [Parameter(Mandatory)]
        [LabVM] $VM
    )

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    # Generate an unattended setup file
    [String] $UnattendFile = GetUnattendFileContent `
        -Lab $Lab `
        -VM $VM
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'Unattend.xml') `
        -Value $UnattendFile -Force

    # Assemble the SetupComplete.* scripts.
    [String] $SetupCompleteCmd = ''

    # Write out the PS1 Setup Complete File
    if ($VM.OSType -eq [LabOSType]::Nano)
    {
        # For a Nano Server we also need to create the certificates
        # to upload to it (because it Nano Server can't generate them)
        $null = CreateHostSelfSignedCertificate `
            -Lab $Lab `
            -VM $VM

        # PowerShell currently can't find any basic Cmdlets when executed by
        # SetupComplete.cmd during the initialization phase, so create an empty
        # a SetupComplete.ps1
        [String] $SetupCompletePs = ''
    }
    else
    {
        if ($VM.CertificateSource -eq [LabCertificateSource]::Host)
        {
            # Generate the PFX certificate on the host
            $null = CreateHostSelfSignedCertificate `
                -Lab $Lab `
                -VM $VM
        }
        [String] $GetCertPs = GetCertificatePsFileContent `
            -Lab $Lab `
            -VM $VM
        [String] $SetupCompletePs = @"
Add-Content ``
    -Path "C:\WINDOWS\Setup\Scripts\SetupComplete.log" ``
    -Value 'SetupComplete.ps1 Script Started...' ``
    -Encoding Ascii
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
        [String] $SetupComplete = $VM.SetupComplete
        if (-not (Test-Path -Path $SetupComplete))
        {
            $ExceptionParameters = @{
                errorId = 'SetupCompleteScriptMissingError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.SetupCompleteScriptMissingError `
                    -f $VM.name,$SetupComplete)
            }
            ThrowException @ExceptionParameters
        }
        [String] $Extension = [System.IO.Path]::GetExtension($SetupComplete)
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
Timeout 30
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

    WriteMessage -Message $($LocalizedData.CreatedVMInitializationFiles `
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
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory)]
        $Lab,

        [Parameter(Mandatory)]
        [LabVM] $VM
    )
    if ($VM.UnattendFile)
    {
        [String] $UnattendContent = Get-Content -Path $VM.UnattendFile
    }
    Else
    {
        [String] $DomainName = $Lab.labbuilderconfig.settings.domainname
        [String] $Email = $Lab.labbuilderconfig.settings.email
        $UnattendContent = [String] @"
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
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory)]
        $Lab,

        [Parameter(Mandatory)]
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
        [String] $CreateCertificatePs = @"
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
        [String] $CreateCertificatePs = @"
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
    GetSelfSignedCertificate -Lab $Lab -VM $VMs[0]
    Downloads the existing Self-signed certificate for the VM to the Labbuilder files folder of the
    VM.
.OUTPUTS
    The path to the certificate file that was downloaded.
#>
function GetSelfSignedCertificate
{
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory)]
        $Lab,

        [Parameter(Mandatory)]
        [LabVM] $VM,

        [Int] $Timeout = 300
    )
    [String] $LabPath = $Lab.labbuilderconfig.SelectNodes('settings').labpath
    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False

    # Load path variables
    [String] $VMRootPath = $VM.VMRootPath

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    while ((-not $Complete) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
    {
        $Session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        # Failed to connnect to the VM
        if (-not $Session)
        {
            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
            return
        } # if

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $Complete))
        {
            # We connected OK - download the Certificate file
            while ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    $null = Copy-Item `
                        -Path "c:\windows\$Script:DSCEncryptionCert" `
                        -Destination $VMLabBuilderFiles `
                        -FromSession $Session `
                        -ErrorAction Stop
                    $Complete = $True
                }
                catch
                {
                    WriteMessage -Message $($LocalizedData.WaitingForCertificateMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # try
            } # while
        } # if

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $Complete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
        } # if

        # Close the Session if it is opened and the download is complete
        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and ($Complete))
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue
        } # if
    } # while
    return (Get-Item -Path "$VMLabBuilderFiles\$($Script:DSCEncryptionCert)")
} # GetSelfSignedCertificate


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
    RecreateSelfSignedCertificate -Lab $Lab -VM $VMs[0]
    Causes a new self-signed certificate on the VM and download it to the Labbuilder files folder
    of th VM.
.OUTPUTS
    The path to the certificate file that was downloaded.
#>
function RecreateSelfSignedCertificate
{
    [CmdLetBinding()]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory)]
        $Lab,

        [Parameter(Mandatory)]
        [LabVM] $VM,

        [Int] $Timeout = 300
    )
    [DateTime] $StartTime = Get-Date
    [String] $LabPath = $Lab.labbuilderconfig.SelectNodes('settings').labpath
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False

    # Load path variables
    [String] $VMRootPath = $VM.VMRootPath

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    # Ensure the certificate generation script has been created
    [String] $GetCertPs = GetCertificatePsFileContent `
        -Lab $Lab `
        -VM $VM `
        -CertificateSource Guest

    $null = Set-Content `
        -Path "$VMLabBuilderFiles\GetDSCEncryptionCert.ps1" `
        -Value $GetCertPs `
        -Force

    while ((-not $Complete) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
    {
        $Session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        # Failed to connnect to the VM
        if (-not $Session)
        {
            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
            return
        } # if

        $Complete = $False

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $Complete))
        {
            # We connected OK - Upload the script
            while ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    Copy-Item `
                        -Path "$VMLabBuilderFiles\GetDSCEncryptionCert.ps1" `
                        -Destination 'c:\windows\setup\scripts\' `
                        -ToSession $Session `
                        -Force `
                        -ErrorAction Stop
                    $Complete = $True
                }
                catch
                {
                    WriteMessage -Message $($LocalizedData.FailedToUploadCertificateCreateScriptMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # try
            } # while
        } # if

        $Complete = $False

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $Complete))
        {
            # Script uploaded, run it
            while ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try
                {
                    Invoke-Command -Session $Session -ScriptBlock {
                        C:\Windows\Setup\Scripts\GetDSCEncryptionCert.ps1
                    }
                    $Complete = $True
                }
                catch
                {
                    WriteMessage -Message $($LocalizedData.FailedToExecuteCertificateCreateScriptMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # try
            } # while
        } # if

        $Complete = $False

        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and (-not $Complete))
        {
            # Now download the Certificate
            while ((-not $Complete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                try {
                    $null = Copy-Item `
                        -Path "c:\windows\$($Script:DSCEncryptionCert)" `
                        -Destination $VMLabBuilderFiles `
                        -FromSession $Session `
                        -ErrorAction Stop
                    $Complete = $True
                }
                catch
                {
                    WriteMessage -Message $($LocalizedData.FailedToDownloadCertificateMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # Try
            } # While
        } # If

        # If the process didn't complete and we're out of time throw an exception
        if ((-not $Complete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            if ($Session)
            {
                Remove-PSSession -Session $Session
            }

            $ExceptionParameters = @{
                errorId = 'CertificateDownloadError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.CertificateDownloadError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
        }

        # Close the Session if it is opened and the download is complete
        if (($Session) `
            -and ($Session.State -eq 'Opened') `
            -and ($Complete))
        {
            Remove-PSSession -Session $Session
        } # If
    } # While
    return (Get-Item -Path "$VMLabBuilderFiles\$($Script:DSCEncryptionCert)")
} # RecreateSelfSignedCertificate


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
    CreateHostSelfSignedCertificate -Lab $Lab -VM $VMs[0]
    Causes a new self-signed certificate for the VM and stores it to the Labbuilder files folder
    of th VM.
.OUTPUTS
    The path to the certificate file that was created.
#>
function CreateHostSelfSignedCertificate
{
    [CmdLetBinding()]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory)]
        $Lab,

        [Parameter(Mandatory)]
        [LabVM] $VM
    )

    # Load path variables
    [String] $VMRootPath = $VM.VMRootPath

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    $CertificateFriendlyName = $Script:DSCCertificateFriendlyName
    $CertificateSubject = "CN=$($VM.ComputerName)"

    # Create the self-signed certificate for the destination VM
    . $Script:SupportGertGenPath
    New-SelfsignedCertificateEx `
        -Subject $CertificateSubject `
        -EKU 'Document Encryption','Server Authentication','Client Authentication' `
        -KeyUsage 'DigitalSignature, KeyEncipherment, DataEncipherment' `
        -SAN $VM.ComputerName `
        -FriendlyName $CertificateFriendlyName `
        -Exportable `
        -StoreLocation 'LocalMachine' `
        -StoreName 'My' `
        -KeyLength $Script:SelfSignedCertKeyLength `
        -ProviderName $Script:SelfSignedCertProviderName `
        -AlgorithmName $Script:SelfSignedCertAlgorithmName `
        -SignatureAlgorithm $Script:SelfSignedCertSignatureAlgorithm `
        -ErrorAction Stop

    # Locate the newly created certificate
    $Certificate = Get-ChildItem -Path cert:\LocalMachine\My `
        | Where-Object {
            ($_.FriendlyName -eq $CertificateFriendlyName) `
            -and ($_.Subject -eq $CertificateSubject)
        } | Select-Object -First 1

    # Export the certificate with the Private key in
    # preparation for upload to the VM
    $CertificatePassword = ConvertTo-SecureString `
        -String $Script:DSCCertificatePassword `
        -Force `
        -AsPlainText
    $CertificatePfxDestination = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath $Script:DSCEncryptionPfxCert
    $null = Export-PfxCertificate `
        -FilePath $CertificatePfxDestination `
        -Cert $Certificate `
        -Password $CertificatePassword `
        -ErrorAction Stop

    # Export the certificate without a private key
    $CertificateDestination = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath $Script:DSCEncryptionCert
    $null = Export-Certificate `
        -Type CERT `
        -FilePath $CertificateDestination `
        -Cert $Certificate `
        -ErrorAction Stop

    # Remove the certificate from the Local Machine store
    $Certificate | Remove-Item
    return (Get-Item -Path $CertificateDestination)
} # CreateHostSelfSignedCertificate


<#
.SYNOPSIS
    Gets the Management IP Address for a running Lab VM.
.DESCRIPTION
    This function will return the IPv4 address assigned to the network adapter that
    is connected to the Management switch for the specified VM. The VM must be
    running, otherwise an error will be thrown.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    $IPAddress = GetVMManagementIPAddress -Lab $Lab -VM $VM[0]
.OUTPUTS
    The IP Managment IP Address.
#>
function GetVMManagementIPAddress {
    [CmdLetBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        $Lab,

        [Parameter(Mandatory)]
        [LabVM] $VM
    )
    [String] $ManagementSwitchName = GetManagementSwitchName `
        -Lab $Lab
    [String] $IPAddress = (Get-VMNetworkAdapter -VMName $VM.Name).`
        Where({$_.SwitchName -eq $ManagementSwitchName}).`
        IPAddresses.Where({$_.Contains('.')})
    if (-not $IPAddress) {
        $ExceptionParameters = @{
            errorId = 'ManagmentIPAddressError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ManagmentIPAddressError `
                -f $ManagementSwitchName,$VM.Name)
        }
        ThrowException @ExceptionParameters
    } # if
    return $IPAddress
} # GetVMManagementIPAddress


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
    WaitVMInitializationComplete -VM $VMs[0]
    Waits for the initial setup to complete on the first VM in the config.xml.
.OUTPUTS
    The path to the local copy of the Initial Setup complete file in the Labbuilder files folder
    for this VM.
#>
function WaitVMInitializationComplete
{
    [CmdLetBinding()]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory)]
        [LabVM] $VM,

        [Int] $Timeout = 300
    )

    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False

    # Get the root path of the VM
    [String] $VMRootPath = $VM.VMRootPath

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    # Make sure the VM has started
    WaitVMStarted -VM $VM

    [String] $InitialSetupCompletePath = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'InitialSetupCompleted.txt'

    # Check the initial setup on this VM hasn't already completed
    if (Test-Path -Path $InitialSetupCompletePath)
    {
        WriteMessage -Message $($LocalizedData.InitialSetupIsAlreadyCompleteMessaage `
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
        if (! $Session)
        {
            $ExceptionParameters = @{
                errorId = 'InitialSetupCompleteError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.InitialSetupCompleteError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
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
                    $Complete = $True
                }
                catch
                {
                    WriteMessage -Message $($LocalizedData.WaitingForInitialSetupCompleteMessage `
                        -f $VM.Name,$Script:RetryConnectSeconds)
                    Start-Sleep `
                        -Seconds $Script:RetryConnectSeconds
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

            $ExceptionParameters = @{
                errorId = 'InitialSetupCompleteError'
                errorCategory = 'OperationTimeout'
                errorMessage = $($LocalizedData.InitialSetupCompleteError `
                    -f $VM.Name)
            }
            ThrowException @ExceptionParameters
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
} # WaitVMInitializationComplete


<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
    Example of how to use this cmdlet
.OUTPUTS
    None.
#>
function WaitVMStarted {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [LabVM] $VM
    )

	#Names of IntegrationServices are not culture neutral, but have an ID
	$HeartbeatCultureNeutral = ( Get-VMIntegrationService -VMName $VM.Name | Where-Object { $_.ID -match "84EAAE65-2F2E-45F5-9BB5-0E857DC8EB47" } ).Name
	$Heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name $HeartbeatCultureNeutral
    while ($Heartbeat.PrimaryStatusDescription -ne 'OK')
    {
        $Heartbeat = Get-VMIntegrationService -VMName $VM.Name -Name $HeartbeatCultureNeutral
        Start-Sleep -Seconds $Script:RetryHeartbeatSeconds
    } # while
} # WaitVMStarted


<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
    Example of how to use this cmdlet
.OUTPUTS
    None.
#>
function WaitVMOff {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [LabVM] $VM
    )
    $RunningVM = Get-VM -Name $VM.Name
    while ($RunningVM.State -ne 'Off')
    {
        $RunningVM = Get-VM -Name $VM.Name
        Start-Sleep -Seconds $Script:RetryHeartbeatSeconds
    } # while
} # WaitVMOff


<#
.SYNOPSIS
    Get list of Integration Service names (localized)
.DESCRIPTION
    This cmdlet will get the list of Integration services available on a Hyper-V host.
    The list of Integration Services will contain the localized names.
.EXAMPLE
    GetIntegrationServiceNames
.OUTPUTS
    An array of localized Integration Serivce names.
#>
function GetIntegrationServiceNames {
    [CmdLetBinding()]
    param
    (
    )
    $Captions = @()
    $Classes = @(
        'Msvm_VssComponentSettingData'
        'Msvm_ShutdownComponentSettingData'
        'Msvm_TimeSyncComponentSettingData'
        'Msvm_HeartbeatComponentSettingData'
        'Msvm_GuestServiceInterfaceComponentSettingData'
        'Msvm_KvpExchangeComponentSettingData'
    )
    foreach ($Class in $Classes)
    {
        $Captions += (Get-CimInstance `
            -Class $Class `
            -Namespace Root\Virtualization\V2 `
            -Property Caption | Select-Object -First 1).Caption
    } # foreach
    # This Integration Service is registered in CIM but are not exposed in Hyper-V
    # 'Msvm_RdvComponentSettingData'
    return $Captions
} # GetIntegrationServiceNames


<#
.SYNOPSIS
    Updates the VM Integration Services to match the VM Configuration.
.DESCRIPTION
    This cmdlet will take the VM object provided and ensure the integration services specified
    in it are enabled.

    The function will use comma delimited list of integration services in the VM object passed
    and enable the integration services listed for this VM.

    If the IntegrationServices property of the VM is not set or set to null then ALL integration
    services will be ENABLED.

    If the IntegrationServices property of the VM is set but is blank then ALL integration
    services will be DISABLED.

    The IntegrationServices property should contain a comma delimited list of Integration Services
    that should be enabled.

    The currently available Integration Services are:
    - Guest Service Interface
    - Heartbeat
    - Key-Value Pair Exchange
    - Shutdown
    - Time Synchronization
    - VSS
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    UpdateVMIntegrationServices -VM VM[0]
    This will update the Integration Services for the first VM in the configuration file c:\mylab\config.xml.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.OUTPUTS
    None.
#>
function UpdateVMIntegrationServices {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [LabVM] $VM
    )
    # Configure the Integration services
    $IntegrationServices = $VM.IntegrationServices
    if ($null -eq $IntegrationServices)
    {
        # Get the full list of Integration Service names localized
        $IntegrationServices = ((GetIntegrationServiceNames) -Join ',')
    }
    $EnabledIntegrationServices = $IntegrationServices -split ','
    $ExistingIntegrationServices = Get-VMIntegrationService `
        -VMName $VM.Name `
        -ErrorAction Stop
    # Loop through listed integration services and enable them
    foreach ($ExistingIntegrationService in $ExistingIntegrationServices)
    {
        if ($ExistingIntegrationService.Name -in $EnabledIntegrationServices)
        {
            # This integration service should be enabled
            if (-not $ExistingIntegrationService.Enabled)
            {
                # It is disabled so enable it
                $ExistingIntegrationService | Enable-VMIntegrationService

                WriteMessage -Message $($LocalizedData.EnableVMIntegrationServiceMessage `
                    -f $VM.Name,$ExistingIntegrationService.Name)
            } # if
        }
        else
        {
            # This integration service should be disabled
            if ($ExistingIntegrationService.Enabled)
            {
                # It is enabled so disable it
                $ExistingIntegrationService | Disable-VMIntegrationService

                WriteMessage -Message $($LocalizedData.DisableVMIntegrationServiceMessage `
                    -f $VM.Name,$ExistingIntegrationService.Name)
            } # if
        } # if
    } # foreach
} # UpdateVMIntegrationServices


<#
.SYNOPSIS
    Updates the VM Data Disks to match the VM Configuration.
.DESCRIPTION
    This cmdlet will take the VM configuration provided and ensure that that data disks that are
    attached to the VM.

    The function will use the array of items in the DataVHDs property of the VM to create and
    attach any data disk VHDs that are missing.

    If the data disk VHD file exists but is not attached it will be attached to the VM. If the
    data disk VHD file does not exist then it will be created and attached.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    UpdateVMDataDisks -Lab $Lab -VM VM[0]
    This will update the data disks for the first VM in the configuration file c:\mylab\config.xml.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.OUTPUTS
    None.
#>
function UpdateVMDataDisks {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [LabVM] $VM
    )

    # If there are no data VHDs just return
    if (-not $VM.DataVHDs)
    {
        return
    }

    # Get the root path of the VM
    [String] $VMRootPath = $VM.VMRootPath

    # Get the Virtual Hard Disk Path
    [String] $VHDPath = Join-Path `
        -Path $VMRootPath `
        -ChildPath 'Virtual Hard Disks'

    foreach ($DataVhd in @($VM.DataVHDs))
    {
        $Vhd = $DataVhd.Vhd
        if (Test-Path -Path $Vhd)
        {
            WriteMessage -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                -f $VM.Name,$Vhd,'Data')

            # Check the parameters of the VHD match
            $ExistingVhd = Get-VHD -Path $Vhd

            # Check the VHD Type
            if (($DataVhd.VhdType) `
                -and ($ExistingVhd.VhdType.ToString() -ne $DataVhd.VhdType.ToString()))
            {
                # The type of disk can't be changed.
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDConvertError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDConvertError `
                        -f $VM.name,$Vhd,$DataVhd.VhdType)
                }
                ThrowException @ExceptionParameters
            }

            # Check the size
            if ($DataVhd.Size)
            {
                if ($ExistingVhd.Size -lt $DataVhd.Size)
                {
                    # Expand the disk
                    WriteMessage -Message $($LocalizedData.ExpandingVMDiskMessage `
                        -f $VM.Name,$Vhd,'Data',$DataVhd.Size)

                    $null = Resize-VHD `
                        -Path $Vhd `
                        -SizeBytes $DataVhd.Size
                }
                elseif ($ExistingVhd.Size -gt $DataVhd.Size)
                {
                    # The disk size can't be reduced.
                    # This could be revisited later.
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskVHDShrinkError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskVHDShrinkError `
                            -f $VM.name,$Vhd,$DataVhd.Size)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if
        }
        else
        {
            # The data disk VHD does not exist so create it
            $SourceVhd = $DataVhd.SourceVhd
            if ($SourceVhd)
            {
                # A source VHD was specified to create the new VHD using
                if (! (Test-Path -Path $SourceVhd))
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                            -f $VM.name,$SourceVhd)
                    }
                    ThrowException @ExceptionParameters
                } # if
                # Should the Source VHD be copied or moved
                if ($DataVhd.MoveSourceVHD)
                {
                    WriteMessage -Message $($LocalizedData.CreatingVMDiskByMovingSourceVHDMessage `
                        -f $VM.Name,$Vhd,$SourceVhd)

                    $null = Move-Item `
                        -Path $SourceVhd `
                        -Destination $VHDPath `
                        -Force `
                        -ErrorAction Stop
                }
                else
                {
                    WriteMessage -Message $($LocalizedData.CreatingVMDiskByCopyingSourceVHDMessage `
                        -f $VM.Name,$Vhd,$SourceVhd)

                    $null = Copy-Item `
                        -Path $SourceVhd `
                        -Destination $VHDPath `
                        -Force `
                        -ErrorAction Stop
                } # if
            }
            else
            {
                $Size = $DataVhd.size
                switch ($DataVhd.VhdType)
                {
                    'fixed'
                    {
                        # Create a new Fixed VHD
                        WriteMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$Vhd,'Fixed Data')

                        $null = New-VHD `
                            -Path $Vhd `
                            -SizeBytes $Size `
                            -Fixed `
                            -ErrorAction Stop
                        break;
                    } # 'fixed'
                    'dynamic'
                    {
                        # Create a new Dynamic VHD
                        WriteMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$Vhd,'Dynamic Data')

                        $null = New-VHD `
                            -Path $Vhd `
                            -SizeBytes $Size `
                            -Dynamic `
                            -ErrorAction Stop
                        break;
                    } # 'dynamic'
                    'differencing'
                    {
                        # A differencing disk is specified so check the Parent VHD
                        # is specified and exists
                        $ParentVhd = $DataVhd.ParentVhd
                        if (-not $ParentVhd)
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDMissingError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                                    -f $VM.name)
                            }
                            ThrowException @ExceptionParameters
                        } # if
                        if (-not (Test-Path -Path $ParentVhd))
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskParentVHDNotFoundError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                                    -f $VM.name,$ParentVhd)
                            }
                            ThrowException @ExceptionParameters
                        } # if

                        # Create a new Differencing VHD
                        WriteMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                            -f $VM.Name,$Vhd,"Differencing Data using Parent '$ParentVhd'")

                        $null = New-VHD `
                            -Path $Vhd `
                            -SizeBytes $Size `
                            -Differencing `
                            -ParentPath $ParentVhd `
                            -ErrorAction Stop
                        break;
                    } # 'differencing'
                    default
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskUnknownTypeError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                                -f $VM.Name,$Vhd,$DataVhd.VhdType)
                        }
                        ThrowException @ExceptionParameters
                    } # default
                } # switch
            } # if

            # Do folders need to be copied to this Data Disk?
            if ($null -ne $DataVhd.CopyFolders)
            {
                # Files need to be copied to this Data VHD so
                # set up a mount folder for it to be mounted to.
                # Get Path to LabBuilder files
                [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

                [String] $MountPoint = Join-Path `
                    -Path $VMLabBuilderFiles `
                    -ChildPath 'VHDMount'

                if (-not (Test-Path -Path $MountPoint -PathType Container))
                {
                    $null = New-Item `
                        -Path $MountPoint `
                        -ItemType Directory
                }
                # Yes, initialize the disk (or check it is)
                $InitializeVHDParams = @{
                    Path = $VHD
                    AccessPath = $MountPoint
                }
                # Are we allowed to initialize/format the disk?
                if ($DataVHD.PartitionStyle -and $DataVHD.FileSystem)
                {
                    # Yes, initialize the disk
                    $InitializeVHDParams += @{
                        PartitionStyle = $DataVHD.PartitionStyle
                        FileSystem = $DataVHD.FileSystem
                    }
                    # Set a FileSystemLabel too?
                    if ($DataVHD.FileSystemLabel)
                    {
                        $InitializeVHDParams += @{
                            FileSystemLabel = $DataVHD.FileSystemLabel
                        }
                    }
                }
                WriteMessage -Message $($LocalizedData.InitializingVMDiskMessage `
                    -f $VM.Name,$VHD)

                InitializeVHD `
                    @InitializeVHDParams `
                    -ErrorAction Stop

                # Copy each folder to the VM Data Disk
                foreach ($CopyFolder in @($DataVHD.CopyFolders))
                {
                    WriteMessage -Message $($LocalizedData.CopyingFoldersToVMDiskMessage `
                        -f $VM.Name,$VHD,$CopyFolder)

                    Copy-item `
                        -Path $CopyFolder `
                        -Destination $MountFolder `
                        -Recurse `
                        -Force
                }

                # Dismount the VM Data Disk
                WriteMessage -Message $($LocalizedData.DismountingVMDiskMessage `
                    -f $VM.Name,$VHD)

                Dismount-VHD `
                    -Path $VHD `
                    -ErrorAction Stop
            }
            else
            {
                # No folders need to be copied but check if we
                # need to initialize the new disk.
                if ($DataVHD.PartitionStyle -and $DataVHD.FileSystem)
                {
                    $InitializeVHDParams = @{
                        Path = $VHD
                        PartitionStyle = $DataVHD.PartitionStyle
                        FileSystem = $DataVHD.FileSystem
                    }

                    if ($DataVHD.FileSystemLabel)
                    {
                        $InitializeVHDParams += @{
                            FileSystemLabel = $DataVHD.FileSystemLabel
                        }
                    } # if

                    WriteMessage -Message $($LocalizedData.InitializingVMDiskMessage `
                        -f $VM.Name,$VHD)

                    InitializeVHD `
                        @InitializeVHDParams `
                        -ErrorAction Stop

                    # Dismount the VM Data Disk
                    WriteMessage -Message $($LocalizedData.DismountingVMDiskMessage `
                        -f $VM.Name,$VHD)

                    Dismount-VHD `
                        -Path $VHD `
                        -ErrorAction Stop
                } # if
            } # if
        } # if

        # Get a list of disks attached to the VM
        $VMHardDiskDrives = Get-VMHardDiskDrive `
            -VMName $VM.Name

        # The data disk VHD will now exist so ensure it is attached
        if (($VMHardDiskDrives | Where-Object -Property Path -eq $Vhd).Count -eq 0)
        {
            # The data disk is not yet attached
            WriteMessage -Message $($LocalizedData.AddingVMDiskMessage `
                -f $VM.Name,$Vhd,'Data')

            # Determine the ControllerLocation and ControllerNumber to
            # attach the VHD to.
            $ControllerLocation = ($VMHardDiskDrives |
                Measure-Object -Property ControllerLocation -Maximum).Maximum + 1

            $NewHardDiskParams = @{
                VMName = $VM.Name
                Path = $Vhd
                ControllerType = 'SCSI'
                ControllerLocation = $ControllerLocation
                ControllerNumber = 0
                ErrorAction = 'Stop'
            }
            if ($DataVhd.Shared)
            {
                $NewHardDiskParams += @{
                    ShareVirtualDisk = $true
                }
                if ($DataVhd.SupportPR)
                {
                    $NewHardDiskParams += @{
                        SupportPersistentReservations = $true
                    }
                } # if
            } # if
            $Null = Add-VMHardDiskDrive @NewHardDiskParams
        } # if
    } # foreach
} # UpdateVMDataDisks


<#
.SYNOPSIS
    Updates the VM DVD Drives to match the VM Configuration.
.DESCRIPTION
    This cmdlet will take the VM configuration provided and ensure that the DVD Drives are
    attached to the VM and with the specified ISO.

    The function will use the array of items in the DVDDrives property of the VM to create and
    attach any DVD Drives that are missing.

    If an ISO File is specified in the DVD Drive then it will be mounted to the DVD Drive.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    UpdateVMDVDDrives -Lab $Lab -VM VM[0]
    This will update the DVD Drives for the first VM in the configuration file c:\mylab\config.xml.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.OUTPUTS
    None.
#>
function UpdateVMDVDDrives {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [LabVM] $VM
    )

    # If there are no DVD Drives just return
    if (-not $VM.DVDDrives)
    {
        return
    }

    [int] $DVDDriveCount = 0
    foreach ($DVDDrive in @($VM.DVDDrives))
    {
        # Get a list of DVD Drives attached to the VM
        $VMDVDDrives = @(Get-VMDVDDrive `
            -VMName $VM.Name)

        # The DVD Drive will now exist so ensure it is attached
        if ($VMDVDDrives[$DVDDriveCount])
        {
            # The DVD Drive is already attached then make sure the correct ISO
            if ($VMDVDDrives[$DVDDriveCount].Path -ne $DVDDrive.Path)
            {
                if ($DVDDrive.Path)
                {
                    WriteMessage -Message $($LocalizedData.MountingVMDVDDriveISOMessage `
                        -f $VM.Name,$DVDDrive.Path)
                }
                else
                {
                    WriteMessage -Message $($LocalizedData.DismountingVMDVDDriveISOMessage `
                        -f $VM.Name,$VMDVDDrives[$DVDDriveCount].Path)
                } # if
                Set-VMDVDDrive `
                    -VMName $VM.Name `
                    -ControllerNumber $VMDVDDrives[$DVDDriveCount].ControllerNumber `
                    -ControllerLocation $VMDVDDrives[$DVDDriveCount].ControllerLocation `
                    -Path $DVDDrive.Path
            } # if
        }
        else
        {
            # The DVD Drive does not exist
            WriteMessage -Message $($LocalizedData.AddingVMDVDDriveMessage `
                -f $VM.Name)

            $NewDVDDriveParams = @{
                VMName = $VM.Name
                ErrorAction = 'Stop'
            }

            if ($DVDDrive.Path)
            {
                WriteMessage -Message $($LocalizedData.MountingVMDVDDriveISOMessage `
                    -f $VM.Name,$DVDDrive.Path)

                $NewDVDDriveParams += @{
                    Path = $DVDDrive.Path
                }
            } # if
            $null = Add-VMDVDDrive @NewDVDDriveParams
        } # if
        $DVDDriveCount++
    } # foreach
} # UpdateVMDVDDrives