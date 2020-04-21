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
        New-LabVMInitializationFile -Lab $Lab -VM $VMs[0]
        Prepare the first VM in the Lab c:\mylab\config.xml for initial boot.

    .OUTPUTS
        None.
#>
function New-LabVMInitializationFile
{
    [CmdLetBinding()]
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

    # Generate an unattended setup file
    $unattendFile = Get-LabUnattendFileContent `
        -Lab $Lab `
        -VM $VM
    $null = Set-Content `
        -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath 'Unattend.xml') `
        -Value $unattendFile -Force

    # Assemble the SetupComplete.* scripts.
    $setupCompleteCmd = ''

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
        $setupCompletePs = ''
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

        $getCertPs = Get-LabCertificatePsFileContent `
            -Lab $Lab `
            -VM $VM
        $setupCompletePs = @"
Add-Content ``
    -Path "C:\WINDOWS\Setup\Scripts\SetupComplete.log" ``
    -Value 'SetupComplete.ps1 Script Started...' ``
    -Encoding Ascii
Start-Sleep -Seconds 30
$getCertPs
Add-Content ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'Certificate identified and saved to C:\Windows\$script:DSCEncryptionCert ...' ``
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
        $setupComplete = $VM.SetupComplete

        if (-not (Test-Path -Path $setupComplete))
        {
            $exceptionParameters = @{
                errorId = 'SetupCompleteScriptMissingError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.SetupCompleteScriptMissingError `
                    -f $VM.name,$setupComplete)
            }
            New-LabException @exceptionParameters
        }

        $extension = [System.IO.Path]::GetExtension($setupComplete)

        switch ($extension.ToLower())
        {
            '.ps1'
            {
                $setupCompletePs += Get-Content -Path $setupComplete
                Break
            } # 'ps1'

            '.cmd'
            {
                $setupCompleteCmd += Get-Content -Path $setupComplete
                Break
            } # 'cmd'
        } # Switch
    } # If

    # Write out the CMD Setup Complete File
    if ($VM.OSType -eq [LabOSType]::Nano)
    {
        $setupCompleteCmd = @"
@echo SetupComplete.cmd Script Started... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
$setupCompleteCmd
certoc.exe -ImportPFX -p $script:DSCCertificatePassword root $ENV:SystemRoot\$script:DSCEncryptionPfxCert >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
@echo SetupComplete.cmd Script Finished... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
@echo Initial Setup Completed - this file indicates that setup has completed. >> %SYSTEMROOT%\Setup\Scripts\InitialSetupCompleted.txt
"@
    }
    else
    {
        $setupCompleteCmd = @"
@echo SetupComplete.cmd Script Started... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log`r
$setupCompleteCmd
@echo SetupComplete.cmd Execute SetupComplete.ps1... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log`r
powerShell.exe -ExecutionPolicy Unrestricted -Command `"%SYSTEMROOT%\Setup\Scripts\SetupComplete.ps1`" `r
@echo SetupComplete.cmd Script Finished... >> %SYSTEMROOT%\Setup\Scripts\SetupComplete.log
@echo Initial Setup Completed - this file indicates that setup has completed. >> %SYSTEMROOT%\Setup\Scripts\InitialSetupCompleted.txt
"@
    }

    $null = Set-Content `
        -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath 'SetupComplete.cmd') `
        -Value $setupCompleteCmd -Force

    # Write out the PowerShell Setup Complete file
    $setupCompletePs = @"
Add-Content ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'SetupComplete.ps1 Script Started...' ``
    -Encoding Ascii
$setupCompletePs
Add-Content ``
    -Path `"$($ENV:SystemRoot)\Setup\Scripts\SetupComplete.log`" ``
    -Value 'SetupComplete.ps1 Script Finished...' ``
    -Encoding Ascii
"@
    $null = Set-Content `
        -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath 'SetupComplete.ps1') `
        -Value $setupCompletePs -Force

    # If ODJ file specified copy it to the labuilder path.
    if ($VM.OSType -eq [LabOSType]::Nano `
        -and -not [System.String]::IsNullOrWhiteSpace($VM.NanoODJPath))
    {
        if ([System.IO.Path]::IsPathRooted($VM.NanoODJPath))
        {
            $nanoODJPath = $VM.NanoODJPath
        }
        else
        {
            $nanoODJPath = Join-Path `
                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                -ChildPath $VM.NanoODJPath
        } # if

        $null = Copy-Item `
            -Path (Join-Path -Path $nanoODJPath -ChildPath "$($VM.ComputerName).txt") `
            -Destination $vmLabBuilderFiles `
            -ErrorAction Stop
    } # if

    Write-LabMessage -Message $($LocalizedData.CreatedVMInitializationFiles `
        -f $VM.Name)
}
