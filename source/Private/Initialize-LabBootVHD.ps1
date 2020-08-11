<#
    .SYNOPSIS
        Initialized a VM VHD for first boot by applying any required files to the image.

    .DESCRIPTION
        This function mounts a VM boot VHD image and applies the following files from the
        LabBuilder Files folder to it:
            1. Unattend.xml - a Windows Unattend.xml file.
            2. SetupComplete.cmd - the command file that gets run after the Windows OOBE is complete.
            3. SetupComplete.ps1 - this PowerShell script file that is run at the the end of the
                                    SetupComplete.cmd.
        The files should have already been prepared by the New-LabVMInitializationFile function.
        The VM VHD image should contain an installed copy of Windows still in OOBE mode.

        This function also applies optional MSU package files from the Lab resource folder if
        specified in the packages list in the VM.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A VMLab object pulled from the Lab Configuration file using Get-LabVM.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Initialize-LabBootVHD `
            -Lab $Lab `
            -VM $VMs[0] `
            -VMBootDiskPath $BootVHD[0]
        Prepare the boot VHD in for the first VM in the Lab c:\mylab\config.xml for initial boot.

    .OUTPUTS
        None.
#>
function Initialize-LabBootVHD
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM,

        [Parameter(Mandatory = $true)]
        [System.String]
        $VMBootDiskPath
    )

    # Get path to Lab
    [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Get Path to LabBuilder files
    [System.String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    # Mount the VMs Boot VHD so that files can be loaded into it
    Write-LabMessage -Message $($LocalizedData.MountingVMBootDiskMessage `
        -f $VM.Name,$VMBootDiskPath)

    # Create a mount point for mounting the Boot VHD
    [System.String] $MountPoint = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'Mount'

    if (-not (Test-Path -Path $MountPoint -PathType Container))
    {
        $null = New-Item `
            -Path $MountPoint `
            -ItemType Directory
    }

    # Mount the VHD to the Mount point
    $null = Mount-WindowsImage `
        -ImagePath $VMBootDiskPath `
        -Path $MountPoint `
        -Index 1

    try
    {
        $Packages = $VM.Packages
        if ($VM.OSType -eq [LabOSType]::Nano)
        {
            # Now specify the Nano Server packages to add.
            [System.String] $NanoPackagesFolder = Join-Path `
                -Path $LabPath `
                -ChildPath 'NanoServerPackages'
            if (-not (Test-Path -Path $NanoPackagesFolder))
            {
                $exceptionParameters = @{
                    errorId = 'NanoServerPackagesFolderMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NanoServerPackagesFolderMissingError `
                    -f $NanoPackagesFolder)
                }
                New-LabException @exceptionParameters
            }
            # Add DSC Package to packages list if missing
            if ([System.String]::IsNullOrWhitespace($Packages))
            {
                $Packages = 'Microsoft-NanoServer-DSC-Package.cab'
            }
            else
            {
                if (@($Packages -split ',') -notcontains 'Microsoft-NanoServer-DSC-Package.cab')
                {
                    $Packages = "$Packages,Microsoft-NanoServer-DSC-Package.cab"
                } # if
            } # if
        } # if

        # Apply any listed packages to the Image
        if (-not [System.String]::IsNullOrWhitespace($Packages))
        {
            # Get the list of Lab Resource MSUs
            $ResourceMSUs = Get-LabResourceMSU `
                -Lab $Lab

            foreach ($Package in @($Packages -split ','))
            {
                if (([System.IO.Path]::GetExtension($Package) -eq '.cab') `
                    -and ($VM.OSType -eq [LabOSType]::Nano))
                {
                    # This is a Nano Server .CAB package
                    # Generate the path to the Nano Package
                    $PackagePath = Join-Path `
                        -Path $NanoPackagesFolder `
                        -ChildPath $Package

                    # Does it exist?
                    if (-not (Test-Path -Path $PackagePath))
                    {
                        $exceptionParameters = @{
                            errorId = 'NanoPackageNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.NanoPackageNotFoundError `
                            -f $PackagePath)
                        }
                        New-LabException @exceptionParameters
                    }

                    # Add the package
                    Write-LabMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
                        -f $VM.Name,$Package,$PackagePath)

                    $null = Add-WindowsPackage `
                        -PackagePath $PackagePath `
                        -Path $MountPoint

                    # Generate the path to the Nano Language Package
                    $PackageLangFile = $Package -replace '.cab',"_$($script:NanoPackageCulture).cab"
                    $PackageLangFile = Join-Path `
                        -Path $NanoPackagesFolder `
                        -ChildPath "$($script:NanoPackageCulture)\$PackageLangFile"

                    # Does it exist?
                    if (-not (Test-Path -Path $PackageLangFile))
                    {
                        $exceptionParameters = @{
                            errorId = 'NanoPackageNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.NanoPackageNotFoundError `
                            -f $PackageLangFile)
                        }
                        New-LabException @exceptionParameters
                    }

                    Write-LabMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
                        -f $VM.Name,$Package,$PackageLangFile)

                    # Add the package
                    $null = Add-WindowsPackage `
                        -PackagePath $PackageLangFile `
                        -Path $MountPoint
                }
                else
                {
                    # Tihs is a ResourceMSU type package
                    [System.Boolean] $Found = $false
                    foreach ($ResourceMSU in $ResourceMSUs)
                    {
                        if ($ResourceMSU.Name -eq $Package)
                        {
                            # Found the package
                            $Found = $true
                            break
                        } # if
                    } # foreach
                    if (-not $Found)
                    {
                        $exceptionParameters = @{
                            errorId = 'PackageNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.PackageNotFoundError `
                            -f $Package)
                        }
                        New-LabException @exceptionParameters
                    } # if

                    $PackagePath = $ResourceMSU.Filename
                    if (-not (Test-Path -Path $PackagePath))
                    {
                        $exceptionParameters = @{
                            errorId = 'PackageMSUNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.PackageMSUNotFoundError `
                            -f $Package,$PackagePath)
                        }
                        New-LabException @exceptionParameters
                    } # if
                    # Apply a Package
                    Write-LabMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
                        -f $VM.Name,$Package,$PackagePath)

                    $null = Add-WindowsPackage `
                        -PackagePath $PackagePath `
                        -Path $MountPoint
                } # if
            } # foreach
        } # if
    }
    catch
    {
        # Dismount Disk Image before throwing exception
        Write-LabMessage -Message $($LocalizedData.DismountingVMBootDiskMessage `
            -f $VM.Name,$VMBootDiskPath)
        $null = Dismount-WindowsImage -Path $MountPoint -Save
        $null = Remove-Item -Path $MountPoint -Recurse -Force

        Throw $_
    } # try

    # Create the scripts folder where setup scripts will be put
    $null = New-Item `
        -Path "$MountPoint\Windows\Setup\Scripts" `
        -ItemType Directory

    # Create the ODJ folder where Offline domain join files can be put
    $null = New-Item `
        -Path "$MountPoint\Windows\Setup\ODJFiles" `
        -ItemType Directory

    # Apply an unattended setup file
    Write-LabMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Unattend','Unattend.xml')

    if (-not (Test-Path -Path "$MountPoint\Windows\Panther" -PathType Container))
    {
        Write-LabMessage -Message $($LocalizedData.CreatingVMBootDiskPantherFolderMessage `
            -f $VM.Name)

        $null = New-Item `
            -Path "$MountPoint\Windows\Panther" `
            -ItemType Directory
    } # if
    $null = Copy-Item `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'Unattend.xml') `
        -Destination "$MountPoint\Windows\Panther\Unattend.xml" `
        -Force

    # If a Certificate PFX file is available, copy it into the c:\Windows
    # folder of the VM.
    $CertificatePfxPath = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath $script:DSCEncryptionPfxCert
    if (Test-Path -Path $CertificatePfxPath)
    {
        # Apply the CMD Setup Complete File
        Write-LabMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
            -f $VM.Name,'Credential Certificate PFX',$script:DSCEncryptionPfxCert)
        $null = Copy-Item `
            -Path $CertificatePfxPath `
            -Destination "$MountPoint\Windows\$script:DSCEncryptionPfxCert" `
            -Force
    }

    # Apply the CMD Setup Complete File
    Write-LabMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Setup Complete CMD','SetupComplete.cmd')
    $null = Copy-Item `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.cmd') `
        -Destination "$MountPoint\Windows\Setup\Scripts\SetupComplete.cmd" `
        -Force

    # Apply the PowerShell Setup Complete file
    Write-LabMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
        -f $VM.Name,'Setup Complete PowerShell','SetupComplete.ps1')
    $null = Copy-Item `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'SetupComplete.ps1') `
        -Destination "$MountPoint\Windows\Setup\Scripts\SetupComplete.ps1" `
        -Force

    # Apply the Certificate Generator script if not a Nano Server
    if ($VM.OSType -ne [LabOSType]::Nano)
    {
        $CertGenFilename = Split-Path -Path $script:SupportGertGenPath -Leaf
        Write-LabMessage -Message $($LocalizedData.ApplyingVMBootDiskFileMessage `
            -f $VM.Name,'Certificate Create Script',$CertGenFilename)
        $null = Copy-Item `
            -Path $script:SupportGertGenPath `
            -Destination "$MountPoint\Windows\Setup\Scripts\"`
            -Force
    }

    # Dismount the VHD in preparation for boot
    Write-LabMessage -Message $($LocalizedData.DismountingVMBootDiskMessage `
        -f $VM.Name,$VMBootDiskPath)
    $null = Dismount-WindowsImage -Path $MountPoint -Save
    $null = Remove-Item -Path $MountPoint -Recurse -Force
}
