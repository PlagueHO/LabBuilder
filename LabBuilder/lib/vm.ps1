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
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   CreateVMInitializationFiles -Config $Config -VM $VMs[0]
   Prepare the first VM in the Lab c:\mylab\config.xml for initial boot.
.OUTPUTS
   None.
#>
function CreateVMInitializationFiles {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )

    # Get Path to LabBuilder files
    [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath 
    
    # Generate an unattended setup file
    [String] $UnattendFile = GetUnattendFileContent -Config $Config -VM $VM       
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'Unattend.xml') `
        -Value $UnattendFile -Force

    # Assemble the SetupComplete.* scripts.
    [String] $GetCertPs = Get-LabGetCertificatePs -Config $Config -VM $VM
    [String] $SetupCompleteCmd = ''
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
    if ($VM.OsType -eq 'Nano')
    {
        $SetupCompleteCmd = @"
@echo SetupComplete.cmd Script Started... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
$SetupCompleteCmd
powerShell.exe -Command `"%SYSTEMROOT%\Setup\Scripts\SetupComplete.ps1`"
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
                
    Write-Verbose -Message $($LocalizedData.CreatedVMInitializationFiles `
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
.PARAMETER Configuration
   Contains the Lab Builder configuration object that was loaded by the Get-LabConfiguration
   object.
.PARAMETER VM
   A Virtual Machine object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
   $Config = Get-LabConfiguration -Path c:\mylab\config.xml
   $VMs = Get-LabVM -Config $Config
   GetUnattendFileContent -Config $Config -VM $VMs[0]
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
        [XML] $Config,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable] $VM
    )
    if ($VM.UnattendFile)
    {
        [String] $UnattendContent = Get-Content -Path $VM.UnattendFile
    }
    Else
    {
        [String] $DomainName = $Config.labbuilderconfig.settings.domainname
        [String] $Email = $Config.labbuilderconfig.settings.email
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
		

        if ($VM.OSType -eq 'Client')
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
