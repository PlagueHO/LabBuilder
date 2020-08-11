<#
    .SYNOPSIS
        This function prepares all the files and modules necessary for a VM to be configured using
        Desired State Configuration (DSC).

    .DESCRIPTION
        This funcion performs the following tasks in preparation for starting Desired State
        Configuration on a Virtual Machine:
            1. Ensures the folder structure for the Virtual Machine DSC files is available.
            2. Gets a list of all Modules required by the DSC configuration to be applied.
            3. Download and Install any missing DSC modules required for the DSC configuration.
            4. Copy all modules required for the DSC configuration to the VM folder.
            5. Cause a self-signed cetficiate to be created and downloaded on the Lab VM.
            6. Create a Networking DSC configuration file and ensure the DSC config file calss it.
            7. Create the MOF file from the config and an LCM config.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Update-LabDSC -Lab $Lab -VM $VMs[0]
        Prepare the first VM in the Lab c:\mylab\config.xml for DSC configuration.

    .OUTPUTS
        None.
#>
function Update-LabDSC
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

    $dscMOFFile = ''
    $dscMOFMetaFile = ''

    # Get Path to LabBuilder files
    $vmLabBuilderFiles = $VM.LabBuilderFilesPath

    if (-not $VM.DSC.ConfigFile)
    {
        # This VM doesn't have a DSC Configuration
        return
    }

    # Make sure all the modules required to create the MOF file are installed
    $installedModules = Get-Module -ListAvailable

    Write-LabMessage -Message $($LocalizedData.DSCConfigIdentifyModulesMessage `
            -f $VM.DSC.ConfigFile, $VM.Name)

    $dscConfigContent = Get-Content `
        -Path $($VM.DSC.ConfigFile) `
        -Raw

    [LabDSCModule[]] $dscModules = Get-LabModulesInDSCConfig `
        -DSCConfigContent $dscConfigContent

    # Add the NetworkingDsc DSC Resource because it is always used
    $module = [LabDSCModule]::New('NetworkingDsc')

    # It must be 7.0.0.0 or greater
    $module.MinimumVersion = [Version] '7.0.0.0'
    $dscModules += @( $module )

    foreach ($dscModule in $dscModules)
    {
        $moduleName = $dscModule.ModuleName
        $moduleParameters = @{ Name = $ModuleName }
        $moduleVersion = $dscModule.ModuleVersion
        $minimumVersion = $dscModule.MinimumVersion

        if ($moduleVersion)
        {
            $filterScript = {
                ($_.Name -eq $ModuleName) -and ($moduleVersion -eq $_.Version)
            }

            $moduleParameters += @{
                RequiredVersion = $moduleVersion
            }
        }
        elseif ($minimumVersion)
        {
            $filterScript = {
                ($_.Name -eq $ModuleName) -and ($_.Version -ge $minimumVersion)
            }

            $moduleParameters += @{
                MinimumVersion = $minimumVersion
            }
        }
        else
        {
            $filterScript = {
                $_.Name -eq $ModuleName
            }
        }

        $module = ($installedModules |
            Where-Object -FilterScript $filterScript |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1)

        if ($module)
        {
            # The module already exists, load the version number into the Module
            # to force the version number to be set in the DSC Config file
            $dscModule.ModuleVersion = $module.Version
        }
        else
        {
            # The Module isn't available on this computer, so try and install it
            Write-LabMessage -Message $($LocalizedData.DSCConfigSearchingForModuleMessage `
                    -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)

            $newModule = Find-Module `
                @moduleParameters

            if ($newModule)
            {
                Write-LabMessage -Message $($LocalizedData.DSCConfigInstallingModuleMessage `
                        -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)

                try
                {
                    $newModule | Install-Module
                }
                catch
                {
                    $exceptionParameters = @{
                        errorId       = 'DSCModuleDownloadError'
                        errorCategory = 'InvalidArgument'
                        errorMessage  = $($LocalizedData.DSCModuleDownloadError `
                                -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)
                    }
                    New-LabException @exceptionParameters
                }
            }
            else
            {
                $exceptionParameters = @{
                    errorId       = 'DSCModuleDownloadError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.DSCModuleDownloadError `
                            -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)
                }
                New-LabException @exceptionParameters
            }

            $dscModule.ModuleVersion = $newModule.Version
        } # if

        Write-LabMessage -Message $($LocalizedData.DSCConfigSavingModuleMessage `
                -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)

        # Find where the module is actually stored
        $modulePath = ''

        foreach ($Path in $ENV:PSModulePath.Split(';'))
        {
            if (-not [System.String]::IsNullOrEmpty($Path))
            {
                $modulePath = Join-Path `
                    -Path $Path `
                    -ChildPath $ModuleName

                if (Test-Path -Path $modulePath)
                {
                    break
                } # If
            }
        } # Foreach

        if (-not (Test-Path -Path $modulePath))
        {
            $exceptionParameters = @{
                errorId       = 'DSCModuleNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.DSCModuleNotFoundError `
                        -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)
            }
            New-LabException @exceptionParameters
        }

        $destinationPath = Join-Path -Path $vmLabBuilderFiles -ChildPath 'DSC Modules\'

        if (-not (Test-Path -Path $destinationPath))
        {
            # Create the DSC Modules folder if it doesn't exist.
            $null = New-Item -Path $destinationPath -ItemType Directory -Force
        } # if

        Write-LabMessage -Message $($LocalizedData.DSCConfigCopyingModuleMessage `
                -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName, $modulePath, $destinationPath)
        Copy-Item `
            -Path $modulePath `
            -Destination $destinationPath `
            -Recurse `
            -Force `
            -ErrorAction Continue
    } # Foreach

    if ($VM.CertificateSource -eq [LabCertificateSource]::Guest)
    {
        # Recreate the certificate if it the source is the Guest
        if (-not (Request-LabSelfSignedCertificate -Lab $Lab -VM $VM))
        {
            $exceptionParameters = @{
                errorId       = 'CertificateCreateError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.CertificateCreateError `
                        -f $VM.Name)
            }
            New-LabException @exceptionParameters
        }

        # Remove any old self-signed certifcates for this VM
        Get-ChildItem -Path cert:\LocalMachine\My |
            Where-Object { $_.FriendlyName -eq $script:DSCCertificateFriendlyName } |
            Remove-Item
    } # if

    # Add the VM Self-Signed Certificate to the Local Machine store and get the Thumbprint
    $certificateFile = Join-Path `
        -Path $vmLabBuilderFiles `
        -ChildPath $script:DSCEncryptionCert
    $certificate = Import-Certificate `
        -FilePath $certificateFile `
        -CertStoreLocation 'Cert:LocalMachine\My'
    $certificateThumbprint = $certificate.Thumbprint

    # Set the predicted MOF File name
    $dscMOFFile = Join-Path `
        -Path $ENV:Temp `
        -ChildPath "$($VM.ComputerName).mof"
    $dscMOFMetaFile = ([System.IO.Path]::ChangeExtension($dscMOFFile, 'meta.mof'))

    # Generate the LCM MOF File
    Write-LabMessage -Message $($LocalizedData.DSCConfigCreatingLCMMOFMessage -f $dscMOFMetaFile, $VM.Name)

    $null = ConfigLCM `
        -OutputPath $ENV:Temp `
        -ComputerName $($VM.ComputerName) `
        -Thumbprint $certificateThumbprint

    if (-not (Test-Path -Path $dscMOFMetaFile))
    {
        $exceptionParameters = @{
            errorId       = 'DSCConfigMetaMOFCreateError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.DSCConfigMetaMOFCreateError `
                    -f $VM.Name)
        }
        New-LabException @exceptionParameters
    } # If

    # A DSC Config File was provided so create a MOF File out of it.
    Write-LabMessage -Message $($LocalizedData.DSCConfigCreatingMOFMessage -f $VM.DSC.ConfigFile, $VM.Name)

    # Now create the Networking DSC Config file
    $dscNetworkingConfig = Get-LabDSCNetworkingConfig `
        -Lab $Lab -VM $VM
    $NetworkingDscFile = Join-Path `
        -Path $vmLabBuilderFiles `
        -ChildPath 'DSCNetworking.ps1'
    $null = Set-Content `
        -Path $NetworkingDscFile `
        -Value $dscNetworkingConfig
    . $NetworkingDscFile
    $dscFile = Join-Path `
        -Path $vmLabBuilderFiles `
        -ChildPath 'DSC.ps1'

    # Set the Modules List in the DSC Configuration
    $dscConfigContent = Set-LabModulesInDSCConfig `
        -DSCConfigContent $dscConfigContent `
        -Modules $dscModules

    if (-not ($dscConfigContent -match 'Networking Network {}'))
    {
        # Add the Networking Configuration item to the base DSC Config File
        # Find the location of the line containing "Node $AllNodes.NodeName {"
        [System.String] $Regex = '\s*Node\s.*{.*'
        $Matches = [regex]::matches($dscConfigContent, $Regex, 'IgnoreCase')

        if ($Matches.Count -eq 1)
        {
            $dscConfigContent = $dscConfigContent.`
                Insert($Matches[0].Index + $Matches[0].Length, "`r`nNetworking Network {}`r`n")
        }
        else
        {
            $exceptionParameters = @{
                errorId       = 'DSCConfigMoreThanOneNodeError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.DSCConfigMoreThanOneNodeError `
                        -f $VM.DSC.ConfigFile, $VM.Name)
            }
            New-LabException @exceptionParameters
        } # if
    } # if

    # Save the DSC Content
    $null = Set-Content `
        -Path $dscFile `
        -Value $dscConfigContent `
        -Force

    # Hook the Networking DSC File into the main DSC File
    . $dscFile

    $dscConfigName = $VM.DSC.ConfigName

    Write-LabMessage -Message $($LocalizedData.DSCConfigPrepareMessage -f $dscConfigName, $VM.Name)

    # Generate the Configuration Nodes data that always gets passed to the DSC configuration.
    $dscConfigData = @"
@{
    AllNodes = @(
        @{
            NodeName = '$($VM.ComputerName)'
            CertificateFile = '$certificateFile'
            Thumbprint = '$certificateThumbprint'
            LocalAdminPassword = '$($VM.administratorpassword)'
            $($VM.DSC.Parameters)
        }
    )
}
"@
    # Write it to a temp file
    $dscConfigFile = Join-Path `
        -Path $vmLabBuilderFiles `
        -ChildPath 'DSCConfigData.psd1'

    if (Test-Path -Path $dscConfigFile)
    {
        $null = Remove-Item `
            -Path $dscConfigFile `
            -Force
    }

    $null = Set-Content -Path $dscConfigFile -Value $dscConfigData

    # Read the config data into a Hash Table
    $dscConfigData = Import-LocalizedData -BaseDirectory $vmLabBuilderFiles -FileName 'DSCConfigData.psd1'

    # Generate the MOF file from the configuration
    $null = & $dscConfigName `
        -OutputPath $ENV:Temp `
        -ConfigurationData $dscConfigData `
        -ErrorAction Stop

    if (-not (Test-Path -Path $dscMOFFile))
    {
        $exceptionParameters = @{
            errorId       = 'DSCConfigMOFCreateError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.DSCConfigMOFCreateError -f $VM.DSC.ConfigFile, $VM.Name)
        }
        New-LabException @exceptionParameters
    } # If

    # Remove the VM Self-Signed Certificate from the Local Machine Store
    $null = Remove-Item `
        -Path "Cert:LocalMachine\My\$certificateThumbprint" `
        -Force

    Write-LabMessage -Message $($LocalizedData.DSCConfigMOFCreatedMessage -f $VM.DSC.ConfigFile, $VM.Name)

    # Copy the files to the LabBuilder Files folder
    $dscMOFDestinationFile = Join-Path -Path $vmLabBuilderFiles -ChildPath "$($VM.ComputerName).mof"
    $null = Copy-Item `
        -Path $dscMOFFile `
        -Destination $dscMOFDestinationFile `
        -Force

    if (-not $VM.DSC.MOFFile)
    {
        # Remove Temporary files created by DSC
        $null = Remove-Item `
            -Path $dscMOFFile `
            -Force
    }

    if (Test-Path -Path $dscMOFMetaFile)
    {
        $dscMOFMetaDestinationFile = Join-Path -Path $vmLabBuilderFiles -ChildPath "$($VM.ComputerName).meta.mof"
        $null = Copy-Item `
            -Path $dscMOFMetaFile `
            -Destination $dscMOFMetaDestinationFile `
            -Force

        if (-not $VM.DSC.MOFFile)
        {
            # Remove Temporary files created by DSC
            $null = Remove-Item `
                -Path $dscMOFMetaFile `
                -Force
        }
    } # if
}
