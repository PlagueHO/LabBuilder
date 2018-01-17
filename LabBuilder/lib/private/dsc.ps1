<#
    .SYNOPSIS
        Get a list of all Resources imported in a DSC Config

    .DESCRIPTION
        Uses RegEx to pull a list of Resources that are imported in a DSC Configuration using the
        Import-DSCResource cmdlet.

        If The -ModuleVersion parameter is included then the ModuleVersion property in the returned
        LabDSCModule object will be set, otherwise it will be null.

    .PARAMETER DSCConfigFile
        Contains the path to the DSC Config file to extract resource module names from.

    .PARAMETER DSCConfigContent
        Contains the content of the DSC Config to extract resource module names from.

    .EXAMPLE
        Get-ModulesInDSCConfig -DSCConfigFile c:\mydsc\Server01.ps1
        Return the DSC Resource module list from file c:\mydsc\server01.ps1

    .EXAMPLE
        Get-ModulesInDSCConfig -DSCConfigContent $DSCConfig
        Return the DSC Resource module list from the DSC Config in $DSCConfig.

    .OUTPUTS
        An array of LabDSCModule objects containing the DSC Resource modules required by this DSC
        configuration file.
#>
function Get-ModulesInDSCConfig
{
    [CmdLetBinding(DefaultParameterSetName = "Content")]
    [OutputType([Object[]])]
    Param
    (
        [parameter(
            Position = 1,
            ParameterSetName = "Content",
            Mandatory = $true)]
        [System.String] $DSCConfigContent,

        [parameter(
            Position = 2,
            ParameterSetName = "File",
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $DSCConfigFile
    )

    [LabDSCModule[]] $modules = $null

    if ($PSCmdlet.ParameterSetName -eq 'File')
    {
        $dscConfigContent = Get-Content -Path $DSCConfigFile -Raw
    } # if

    $regex = "[ \t]*?Import\-DscResource[ \t]+(?:\-ModuleName[ \t])?'?`"?([A-Za-z0-9._-]+)`"?'?(([ \t]+-ModuleVersion)?[ \t]+'?`"?([0-9.]+)`"?`?)?[ \t]*?[\r\n]+?"
    $moduleMatches = [regex]::matches($dscConfigContent, $regex, 'IgnoreCase')

    foreach ($moduleMatch in $moduleMatches)
    {
        $moduleName = $moduleMatch.Groups[1].Value
        $moduleVersion = $moduleMatch.Groups[4].Value
        # Make sure this module isn't already in the list

        if ($moduleName -notin $Modules.ModuleName)
        {
            $module = [LabDSCModule]::New($moduleName)

            if (-not [System.String]::IsNullOrWhitespace($moduleVersion))
            {
                $module.moduleVersion = [Version] $moduleVersion
            } # if

            $modules += @( $module )
        } # if
    } # foreach

    return $modules
} # Get-ModulesInDSCConfig


<#
    .SYNOPSIS
        Sets the Modules Resources that should be imported in a DSC Config.

    .DESCRIPTION
        It will completely replace the list of Imported DSCResources with this new list.

    .PARAMETER DSCConfigFile
        Contains the path to the DSC Config file to set resource module names in.

    .PARAMETER DSCConfigContent
        Contains the content of the DSC Config to set resource module names in.

    .PARAMETER Modules
        Contains an array of LabDSCModule objects to replace set in the Configuration.

    .EXAMPLE
        Set-ModulesInDSCConfig -DSCConfigFile c:\mydsc\Server01.ps1 -Modules $Modules
        Set the DSC Resource module in the content from file c:\mydsc\server01.ps1

    .EXAMPLE
        Set-ModulesInDSCConfig -DSCConfigContent $DSCConfig -Modules $Modules
        Set the DSC Resource module in the content $DSCConfig

    .OUTPUTS
        A string containing the content of the DSC Config file with the updated
        module names in it.
#>
function Set-ModulesInDSCConfig
{
    [CmdLetBinding(DefaultParameterSetName = "Content")]
    [OutputType([System.String])]
    Param
    (
        [parameter(
            Position = 1,
            ParameterSetName = "Content",
            Mandatory = $true)]
        [System.String] $DSCConfigContent,

        [parameter(
            Position = 2,
            ParameterSetName = "File",
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $DSCConfigFile,

        [parameter(
            Position = 3,
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [LabDSCModule[]] $Modules
    )

    if ($PSCmdlet.ParameterSetName -eq 'File')
    {
        $dscConfigContent = Get-Content -Path $DSCConfigFile -Raw
    } # if

    $regex = "[ \t]*?Import\-DscResource[ \t]+(?:\-ModuleName[ \t]+)?'?`"?([A-Za-z0-9._-]+)`"?'?([ \t]+(-ModuleVersion[ \t]+)?'?`"?([0-9.]+)`"?'?)?[ \t]*[\r\n]+"
    $moduleMatches = [regex]::matches($dscConfigContent, $regex, 'IgnoreCase')

    foreach ($module in $Modules)
    {
        $importCommand = "Import-DscResource -ModuleName '$($module.ModuleName)'"
        if ($module.ModuleVersion)
        {
            $importCommand = "$importCommand -ModuleVersion '$($module.ModuleVersion)'"
        } # if

        $importCommand = "    $importCommand`r`n"

        # is this module already in there?
        $found = $false

        foreach ($moduleMatch in $moduleMatches)
        {
            if ($moduleMatch.Groups[1].Value -eq $module.ModuleName)
            {
                # Found the module - so replace it
                $dscConfigContent = ("{0}{1}{2}" -f `
                    $dscConfigContent.Substring(0, $moduleMatch.Index), `
                    $importCommand, `
                    $dscConfigContent.Substring($moduleMatch.Index + $moduleMatch.Length))

                $moduleMatches = [regex]::matches($dscConfigContent, $regex, 'IgnoreCase')
                $found = $True
                break
            } # if
        } # foreach

        if (-not $found)
        {
            if ($moduleMatches.Count -gt 0)
            {
                # Add this to the end of the existing Import-DSCResource lines
                $moduleMatch = $moduleMatches[$moduleMatches.count - 1]
            }
            else
            {
                # There are no existing DSC Resource lines, so add it after
                # Configuration ... { line
                $moduleMatch = [regex]::matches($dscConfigContent, "[ \t]*?Configuration[ \t]+?'?`"?[A-Za-z0-9._-]+`"?'?[ \t]*?[\r\n]*?{[\r\n]*?", 'IgnoreCase')

                if (-not $moduleMatch)
                {
                    $ExceptionParameters = @{
                        errorId       = 'DSCConfiguartionMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage  = $($LocalizedData.DSCConfiguartionMissingError)
                    }
                    New-Exception @ExceptionParameters
                }
            } # if

            $dscConfigContent = ("{0}{1}{2}" -f `
                $dscConfigContent.Substring(0, $moduleMatch.Index + $moduleMatch.Length), `
                $importCommand, `
                $dscConfigContent.Substring($moduleMatch.Index + $moduleMatch.Length))

            $moduleMatches = [regex]::matches($dscConfigContent, $regex, 'IgnoreCase')
        } # Module not found so add it to the end
    } # foreach

    return $dscConfigContent
} # Set-ModulesInDSCConfig


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
        CreateDSCMOFFiless -Lab $Lab -VM $VMs[0]
        Prepare the first VM in the Lab c:\mylab\config.xml for DSC configuration.

    .OUTPUTS
        None.
#>
function CreateDSCMOFFiles
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM] $VM
    )

    [System.String] $DSCMOFFile = ''
    [System.String] $DSCMOFMetaFile = ''

    # Get the root path of the VM
    [System.String] $VMRootPath = $VM.VMRootPath

    # Get Path to LabBuilder files
    [System.String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    if (-not $VM.DSC.ConfigFile)
    {
        # This VM doesn't have a DSC Configuration
        return
    }

    # Make sure all the modules required to create the MOF file are installed
    $InstalledModules = Get-Module -ListAvailable
    Write-LabMessage -Message $($LocalizedData.DSCConfigIdentifyModulesMessage `
            -f $VM.DSC.ConfigFile, $VM.Name)

    [System.String] $DSCConfigContent = Get-Content `
        -Path $($VM.DSC.ConfigFile) `
        -RAW
    [LabDSCModule[]] $DSCModules = Get-ModulesInDSCConfig `
        -DSCConfigContent $DSCConfigContent

    # Add the xNetworking DSC Resource because it is always used
    $Module = [LabDSCModule]::New('xNetworking')
    # It must be 5.0.0.0 or greater
    $Module.MinimumVersion = [Version] '5.0.0.0'
    $DSCModules += @( $Module )

    foreach ($DSCModule in $DSCModules)
    {
        $ModuleName = $DSCModule.ModuleName
        $ModuleSplat = @{ Name = $ModuleName }
        $ModuleVersion = $DSCModule.ModuleVersion
        $MinimumVersion = $DSCModule.MinimumVersion
        if ($ModuleVersion)
        {
            $FilterScript = { ($_.Name -eq $ModuleName) -and ($ModuleVersion -eq $_.Version) }
            $ModuleSplat += @{ RequiredVersion = $ModuleVersion }
        }
        elseif ($MinimumVersion)
        {
            $FilterScript = { ($_.Name -eq $ModuleName) -and ($_.Version -ge $MinimumVersion) }
            $ModuleSplat += @{ MinimumVersion = $MinimumVersion }
        }
        else
        {
            $FilterScript = { ($_.Name -eq $ModuleName) }
        }

        $Module = ($InstalledModules |
                Where-Object -FilterScript $FilterScript |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1)

        if ($Module)
        {
            # The module already exists, load the version number into the Module
            # to force the version number to be set in the DSC Config file
            $DSCModule.ModuleVersion = $Module.Version
        }
        else
        {
            # The Module isn't available on this computer, so try and install it
            Write-LabMessage -Message $($LocalizedData.DSCConfigSearchingForModuleMessage `
                    -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)
            $NewModule = Find-Module `
                @ModuleSplat

            if ($NewModule)
            {
                Write-LabMessage -Message $($LocalizedData.DSCConfigInstallingModuleMessage `
                        -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)

                try
                {
                    $NewModule | Install-Module
                }
                catch
                {
                    $ExceptionParameters = @{
                        errorId       = 'DSCModuleDownloadError'
                        errorCategory = 'InvalidArgument'
                        errorMessage  = $($LocalizedData.DSCModuleDownloadError `
                                -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)
                    }
                    New-Exception @ExceptionParameters
                }
            }
            else
            {
                $ExceptionParameters = @{
                    errorId       = 'DSCModuleDownloadError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.DSCModuleDownloadError `
                            -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)
                }
                New-Exception @ExceptionParameters
            }
            $DSCModule.ModuleVersion = $NewModule.Version
        } # if

        Write-LabMessage -Message $($LocalizedData.DSCConfigSavingModuleMessage `
                -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)

        # Find where the module is actually stored
        [System.String] $ModulePath = ''
        foreach ($Path in $ENV:PSModulePath.Split(';'))
        {
            if (-not [System.String]::IsNullOrEmpty($Path))
            {
                $ModulePath = Join-Path `
                    -Path $Path `
                    -ChildPath $ModuleName

                if (Test-Path -Path $ModulePath)
                {
                    break
                } # If
            }
        } # Foreach

        if (-not (Test-Path -Path $ModulePath))
        {
            $ExceptionParameters = @{
                errorId       = 'DSCModuleNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.DSCModuleNotFoundError `
                        -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName)
            }
            New-Exception @ExceptionParameters
        }

        $DestinationPath = Join-Path -Path $VMLabBuilderFiles -ChildPath 'DSC Modules\'
        if (-not (Test-Path -Path $DestinationPath))
        {
            # Create the DSC Modules folder if it doesn't exist.
            New-Item -Path $DestinationPath -ItemType Directory -Force
        } # if

        Write-LabMessage -Message $($LocalizedData.DSCConfigCopyingModuleMessage `
                -f $VM.DSC.ConfigFile, $VM.Name, $ModuleName, $ModulePath, $DestinationPath)
        Copy-Item `
            -Path $ModulePath `
            -Destination $DestinationPath `
            -Recurse `
            -Force
    } # Foreach

    if ($VM.CertificateSource -eq [LabCertificateSource]::Guest)
    {
        # Recreate the certificate if it the source is the Guest
        if (-not (Request-SelfSignedCertificate -Lab $Lab -VM $VM))
        {
            $ExceptionParameters = @{
                errorId       = 'CertificateCreateError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.CertificateCreateError `
                        -f $VM.Name)
            }
            New-Exception @ExceptionParameters
        }

        # Remove any old self-signed certifcates for this VM
        Get-ChildItem -Path cert:\LocalMachine\My `
            | Where-Object { $_.FriendlyName -eq $Script:DSCCertificateFriendlyName } `
            | Remove-Item
    } # if

    # Add the VM Self-Signed Certificate to the Local Machine store and get the Thumbprint
    [System.String] $CertificateFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath $Script:DSCEncryptionCert
    $Certificate = Import-Certificate `
        -FilePath $CertificateFile `
        -CertStoreLocation 'Cert:LocalMachine\My'
    [System.String] $CertificateThumbprint = $Certificate.Thumbprint

    # Set the predicted MOF File name
    $DSCMOFFile = Join-Path `
        -Path $ENV:Temp `
        -ChildPath "$($VM.ComputerName).mof"
    $DSCMOFMetaFile = ([System.IO.Path]::ChangeExtension($DSCMOFFile, 'meta.mof'))

    # Generate the LCM MOF File
    Write-LabMessage -Message $($LocalizedData.DSCConfigCreatingLCMMOFMessage `
            -f $DSCMOFMetaFile, $VM.Name)

    $null = ConfigLCM `
        -OutputPath $($ENV:Temp) `
        -ComputerName $($VM.ComputerName) `
        -Thumbprint $CertificateThumbprint
    if (-not (Test-Path -Path $DSCMOFMetaFile))
    {
        $ExceptionParameters = @{
            errorId       = 'DSCConfigMetaMOFCreateError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.DSCConfigMetaMOFCreateError `
                    -f $VM.Name)
        }
        New-Exception @ExceptionParameters
    } # If

    # A DSC Config File was provided so create a MOF File out of it.
    Write-LabMessage -Message $($LocalizedData.DSCConfigCreatingMOFMessage `
            -f $VM.DSC.ConfigFile, $VM.Name)

    # Now create the Networking DSC Config file
    [System.String] $DSCNetworkingConfig = GetDSCNetworkingConfig `
        -Lab $Lab -VM $VM
    [System.String] $NetworkingDSCFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'DSCNetworking.ps1'
    $null = Set-Content `
        -Path $NetworkingDSCFile `
        -Value $DSCNetworkingConfig
    . $NetworkingDSCFile
    [System.String] $DSCFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'DSC.ps1'

    # Set the Modules List in the DSC Configuration
    $DSCConfigContent = Set-ModulesInDSCConfig `
        -DSCConfigContent $DSCConfigContent `
        -Modules $DSCModules

    if (-not ($DSCConfigContent -match 'Networking Network {}'))
    {
        # Add the Networking Configuration item to the base DSC Config File
        # Find the location of the line containing "Node $AllNodes.NodeName {"
        [System.String] $Regex = '\s*Node\s.*{.*'
        $Matches = [regex]::matches($DSCConfigContent, $Regex, 'IgnoreCase')
        if ($Matches.Count -eq 1)
        {
            $DSCConfigContent = $DSCConfigContent.`
                Insert($Matches[0].Index + $Matches[0].Length, "`r`nNetworking Network {}`r`n")
        }
        Else
        {
            $ExceptionParameters = @{
                errorId       = 'DSCConfigMoreThanOneNodeError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.DSCConfigMoreThanOneNodeError `
                        -f $VM.DSC.ConfigFile, $VM.Name)
            }
            New-Exception @ExceptionParameters
        } # If
    } # If

    # Save the DSC Content
    $null = Set-Content `
        -Path $DSCFile `
        -Value $DSCConfigContent `
        -Force

    # Hook the Networking DSC File into the main DSC File
    . $DSCFile

    [System.String] $DSCConfigName = $VM.DSC.ConfigName

    Write-LabMessage -Message $($LocalizedData.DSCConfigPrepareMessage `
            -f $DSCConfigname, $VM.Name)

    # Generate the Configuration Nodes data that always gets passed to the DSC configuration.
    [System.String] $ConfigData = @"
@{
    AllNodes = @(
        @{
            NodeName = '$($VM.ComputerName)'
            CertificateFile = '$CertificateFile'
            Thumbprint = '$CertificateThumbprint'
            LocalAdminPassword = '$($VM.administratorpassword)'
            $($VM.DSC.Parameters)
        }
    )
}
"@
    # Write it to a temp file
    [System.String] $ConfigFile = Join-Path `
        -Path $VMLabBuilderFiles `
        -ChildPath 'DSCConfigData.psd1'
    if (Test-Path -Path $ConfigFile)
    {
        $null = Remove-Item `
            -Path $ConfigFile `
            -Force
    }
    Set-Content -Path $ConfigFile -Value $ConfigData

    # Generate the MOF file from the configuration
    $null = & "$DSCConfigName" -OutputPath $($ENV:Temp) -ConfigurationData $ConfigFile
    if (-not (Test-Path -Path $DSCMOFFile))
    {
        $ExceptionParameters = @{
            errorId       = 'DSCConfigMOFCreateError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.DSCConfigMOFCreateError `
                    -f $VM.DSC.ConfigFile, $VM.Name)
        }
        New-Exception @ExceptionParameters
    } # If

    # Remove the VM Self-Signed Certificate from the Local Machine Store
    $null = Remove-Item `
        -Path "Cert:LocalMachine\My\$CertificateThumbprint" `
        -Force

    Write-LabMessage -Message $($LocalizedData.DSCConfigMOFCreatedMessage `
            -f $VM.DSC.ConfigFile, $VM.Name)

    # Copy the files to the LabBuilder Files folder
    $null = Copy-Item `
        -Path $DSCMOFFile `
        -Destination (Join-Path `
            -Path $VMLabBuilderFiles `
            -ChildPath "$($VM.ComputerName).mof") `
        -Force

    if (-not $VM.DSC.MOFFile)
    {
        # Remove Temporary files created by DSC
        $null = Remove-Item `
            -Path $DSCMOFFile `
            -Force
    }

    if (Test-Path -Path $DSCMOFMetaFile)
    {
        $null = Copy-Item `
            -Path $DSCMOFMetaFile `
            -Destination (Join-Path `
                -Path $VMLabBuilderFiles `
                -ChildPath "$($VM.ComputerName).meta.mof") `
            -Force
        if (-not $VM.DSC.MOFFile)
        {
            # Remove Temporary files created by DSC
            $null = Remove-Item `
                -Path $DSCMOFMetaFile `
                -Force
        }
    } # If
} # CreateDSCMOFFiles


<#
.SYNOPSIS
    This function prepares the PowerShell scripts used for starting up DSC on a VM.
.DESCRIPTION
    Two PowerShell scripts will be created by this function in the LabBuilder Files
    folder of the VM:
        1. StartDSC.ps1 - the script that is called automatically to start up DSC.
        2. StartDSCDebug.ps1 - a debug script that will start up DSC in debug mode.
    These scripts will contain code to perform the following operations:
        1. Configure the names of the Network Adapters so that they will match the
            names in the DSC Configuration files.
        2. Enable/Disable DSC Event Logging.
        3. Apply Configuration to the Local Configuration Manager.
        4. Start DSC.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    SetDSCStartFile -Lab $Lab -VM $VMs[0]
    Prepare the first VM in the Lab c:\mylab\config.xml for DSC start up.
.OUTPUTS
    None.
#>
function SetDSCStartFile
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM] $VM
    )

    [System.String] $DSCStartPs = ''

    # Get Path to LabBuilder files
    [System.String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    # Relabel the Network Adapters so that they match what the DSC Networking config will use
    # This is because unfortunately the Hyper-V Device Naming feature doesn't work.
    [System.String] $ManagementSwitchName = GetManagementSwitchName `
        -Lab $Lab
    $Adapters = [String[]] ($VM.Adapters).Name
    $Adapters += @($ManagementSwitchName)

    foreach ($Adapter in $Adapters)
    {
        $NetAdapter = Get-VMNetworkAdapter -VMName $($VM.Name) -Name $Adapter
        if (-not $NetAdapter)
        {
            $ExceptionParameters = @{
                errorId       = 'NetworkAdapterNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.NetworkAdapterNotFoundError `
                        -f $Adapter, $VM.Name)
            }
            New-Exception @ExceptionParameters
        } # If
        $MacAddress = $NetAdapter.MacAddress
        if (-not $MacAddress)
        {
            $ExceptionParameters = @{
                errorId       = 'NetworkAdapterBlankMacError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.NetworkAdapterBlankMacError `
                        -f $Adapter, $VM.Name)
            }
            New-Exception @ExceptionParameters
        } # If
        $DSCStartPs += @"
Get-NetAdapter ``
    | Where-Object { `$_.MacAddress.Replace('-','') -eq '$MacAddress' } ``
    | Rename-NetAdapter -NewName '$($Adapter)'

"@
    } # Foreach

    # Enable DSC logging (as long as it hasn't been already)
    # Nano Server doesn't have the Microsoft-Windows-Dsc/Analytic channels so
    # Logging can't be enabled.
    if ($VM.OSType -ne [LabOSType]::Nano)
    {
        [System.String] $Logging = ($VM.DSC.Logging).ToString()
        $DSCStartPs += @"
`$Result = & "wevtutil.exe" get-log "Microsoft-Windows-Dsc/Analytic"
if (-not (`$Result -like '*enabled: true*')) {
    & "wevtutil.exe" set-log "Microsoft-Windows-Dsc/Analytic" /q:true /e:$Logging
}
`$Result = & "wevtutil.exe" get-log "Microsoft-Windows-Dsc/Debug"
if (-not (`$Result -like '*enabled: true*')) {
    & "wevtutil.exe" set-log "Microsoft-Windows-Dsc/Debug" /q:true /e:$Logging
}

"@
    } # if

    # Start the actual DSC Configuration
    $DSCStartPs += @"
Set-DscLocalConfigurationManager ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\`" ``
    -Verbose  *>> `"`$(`$ENV:SystemRoot)\Setup\Scripts\DSC.log`"
Start-DSCConfiguration ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\`" ``
    -Force ``
    -Verbose  *>> `"`$(`$ENV:SystemRoot)\Setup\Scripts\DSC.log`"

"@
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'StartDSC.ps1') `
        -Value $DSCStartPs -Force

    $DSCStartPsDebug = @"
param (
    [boolean] `$WaitForDebugger
)
Set-DscLocalConfigurationManager ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\`" ``
    -Verbose
if (`$WaitForDebugger)
{
    Enable-DscDebug ``
        -BreakAll
}
Start-DSCConfiguration ``
    -Path `"`$(`$ENV:SystemRoot)\Setup\Scripts\`" ``
    -Force ``
    -Debug ``
    -Wait ``
    -Verbose
if (`$WaitForDebugger)
{
    Disable-DscDebug
}
"@
    $null = Set-Content `
        -Path (Join-Path -Path $VMLabBuilderFiles -ChildPath 'StartDSCDebug.ps1') `
        -Value $DSCStartPsDebug -Force
} # SetDSCStartFile


<#
.SYNOPSIS
    This function prepares all files require to configure a VM using Desired State
    Configuration (DSC).
.DESCRIPTION
    Calling this function will cause the LabBuilder folder to be populated/updated
    with all files required to configure a Virtual Machine with DSC.
    This includes:
        1. Required DSC Resouce Modules.
        2. DSC Credential Encryption certificate.
        3. DSC Configuration files.
        4. DSC MOF Files for general config and for LCM config.
        5. Start up scripts.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    InitializeDSC -Lab $Lab -VM $VMs[0]
    Prepares all files required to start up Desired State Configuration for the
    first VM in the Lab c:\mylab\config.xml for DSC start up.
.OUTPUTS
    None.
#>
function InitializeDSC
{
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM] $VM
    )

    # Are there any DSC Settings to manage?
    CreateDSCMOFFiles -Lab $Lab -VM $VM

    # Generate the DSC Start up Script file
    SetDSCStartFile -Lab $Lab -VM $VM
} # InitializeDSC


<#
.SYNOPSIS
    Uploads prepared Modules and MOF files to a VM and starts up Desired State
    Configuration (DSC) on it.
.DESCRIPTION
    This function will perform the following tasks:
        1. Connect to the VM via remoting.
        2. Upload the DSC and LCM MOF files to the c:\windows\setup\scripts folder of the VM.
        3. Upload DSC Start up scripts to the c:\windows\setup\scripts folder of the VM.
        4. Upload all required modules to the c:\program files\WindowsPowerShell\Modules\ folder
            of the VM.
        5. Invoke the StartDSC.ps1 script on the VM to start DSC processing.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.PARAMETER Timeout
    The maximum amount of time that this function can take to perform DSC start-up.
    If the timeout is reached before the process is complete an error will be thrown.
    The timeout defaults to 300 seconds.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    StartDSC -Lab $Lab -VM $VMs[0]
    Starts up Desired State Configuration for the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
    None.
#>
function StartDSC
{
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM] $VM,

        [Int] $Timeout = 300
    )
    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [Boolean] $Complete = $False
    [Boolean] $ConfigCopyComplete = $False
    [Boolean] $ModuleCopyComplete = $False

    # Get Path to LabBuilder files
    [System.String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

    While ((-not $Complete) `
            -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
    {
        # Connect to the VM
        $Session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        # Failed to connnect to the VM
        if (-not $Session)
        {
            $ExceptionParameters = @{
                errorId       = 'DSCInitializationError'
                errorCategory = 'OperationTimeout'
                errorMessage  = $($LocalizedData.DSCInitializationError `
                        -f $VM.Name)
            }
            New-Exception @ExceptionParameters
            return
        }

        if (($Session) `
                -and ($Session.State -eq 'Opened') `
                -and (-not $ConfigCopyComplete))
        {
            $CopyParameters = @{
                Destination = 'c:\Windows\Setup\Scripts'
                ToSession   = $Session
                Force       = $True
                ErrorAction = 'Stop'
            }

            # Connection has been made OK, upload the DSC files
            While ((-not $ConfigCopyComplete) `
                    -and (((Get-Date) - $StartTime).TotalSeconds) -lt $TimeOut)
            {
                Try
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMMessage `
                            -f $VM.Name, 'DSC')

                    $null = Copy-Item `
                        @CopyParameters `
                        -Path (Join-Path `
                            -Path $VMLabBuilderFiles `
                            -ChildPath "$($VM.ComputerName).mof")
                    if (Test-Path `
                            -Path "$VMLabBuilderFiles\$($VM.ComputerName).meta.mof")
                    {
                        $null = Copy-Item `
                            @CopyParameters `
                            -Path (Join-Path `
                                -Path $VMLabBuilderFiles `
                                -ChildPath "$($VM.ComputerName).meta.mof")
                    } # If
                    $null = Copy-Item `
                        @CopyParameters `
                        -Path (Join-Path `
                            -Path $VMLabBuilderFiles `
                            -ChildPath 'StartDSC.ps1')
                    $null = Copy-Item `
                        @CopyParameters `
                        -Path (Join-Path `
                            -Path $VMLabBuilderFiles `
                            -ChildPath 'StartDSCDebug.ps1')
                    $ConfigCopyComplete = $True
                }
                Catch
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMFailedMessage `
                            -f $VM.Name, 'DSC', $Script:RetryConnectSeconds)

                    Start-Sleep -Seconds $Script:RetryConnectSeconds
                } # try
            } # while
        } # if

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $ConfigCopyComplete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $ExceptionParameters = @{
                errorId       = 'DSCInitializationError'
                errorCategory = 'OperationTimeout'
                errorMessage  = $($LocalizedData.DSCInitializationError `
                        -f $VM.Name)
            }
            New-Exception @ExceptionParameters
        } # if

        # Upload any required modules to the VM
        if (($Session) `
                -and ($Session.State -eq 'Opened') `
                -and (-not $ModuleCopyComplete))
        {
            [System.String] $DSCContent = Get-Content `
                -Path $($VM.DSC.ConfigFile) `
                -RAW
            [LabDSCModule[]] $DSCModules = Get-ModulesInDSCConfig `
                -DSCConfigContent $DSCContent

            # Add the xNetworking DSC Resource because it is always used
            $Module = [LabDSCModule]::New('xNetworking')
            $DSCModules += @( $Module )

            foreach ($DSCModule in $DSCModules)
            {
                $ModuleName = $DSCModule.ModuleName
                # Upload all but PSDesiredStateConfiguration because it
                # should always exist on client node.
                if ($ModuleName -ne 'PSDesiredStateConfiguration')
                {
                    $ModuleVersion = $DSCModule.Version
                    try
                    {
                        Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMMessage `
                                -f $VM.Name, "DSC Module $ModuleName")

                        $null = Copy-Item `
                            -Path (Join-Path `
                                -Path $VMLabBuilderFiles `
                                -ChildPath "DSC Modules\$ModuleName\") `
                            -Destination "$($env:ProgramFiles)\WindowsPowerShell\Modules\" `
                            -ToSession $Session `
                            -Force `
                            -Recurse `
                            -ErrorAction Stop
                    }
                    catch
                    {
                        Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMFailedMessage `
                                -f $VM.Name, "DSC Module $ModuleName", $Script:RetryConnectSeconds)

                        Start-Sleep -Seconds $Script:RetryConnectSeconds
                    } # try
                } # if
            } # foreach
            $ModuleCopyComplete = $True
        } # if

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $ModuleCopyComplete) `
                -and (((Get-Date) - $StartTime).TotalSeconds) -ge $TimeOut)
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $ExceptionParameters = @{
                errorId       = 'DSCInitializationError'
                errorCategory = 'OperationTimeout'
                errorMessage  = $($LocalizedData.DSCInitializationError `
                        -f $VM.Name)
            }
            New-Exception @ExceptionParameters
        } # if

        # Finally, Start DSC up!
        if (($Session) `
                -and ($Session.State -eq 'Opened') `
                -and ($ConfigCopyComplete) `
                -and ($ModuleCopyComplete))
        {
            Write-LabMessage -Message $($LocalizedData.StartingDSCMessage `
                    -f $VM.Name)

            Invoke-Command -Session $Session { c:\windows\setup\scripts\StartDSC.ps1 }

            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $Complete = $True
        } # if
    } # while
} # StartDSC


<#
.SYNOPSIS
    Assemble the content of the Networking DSC config file.
.DESCRIPTION
    This function creates the content that will be written to the Networking DSC Config file
    from the networking details stored in the VM object.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    $NetworkingDSC = GetDSCNetworkingConfig -Lab $Lab -VM $VMs[0]
    Return the Networking DSC for the first VM in the Lab c:\mylab\config.xml for DSC configuration.
.PARAMETER Lab
    Contains the Lab object that was produced by the Get-Lab cmdlet.
.PARAMETER VM
    A LabVM object pulled from the Lab Configuration file using Get-LabVM
.OUTPUTS
    A string containing the DSC Networking config.
#>
function GetDSCNetworkingConfig
{
    [CmdLetBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM] $VM
    )
    $xNetworkingVersion = (`
            Get-Module xNetworking -ListAvailable `
            | Sort-Object version -Descending `
            | Select-Object -First 1 `
    ).Version.ToString()
    [System.String] $DSCNetworkingConfig = @"
Configuration Networking {
    Import-DscResource -ModuleName xNetworking -ModuleVersion $xNetworkingVersion

"@
    [Int] $AdapterCount = 0
    foreach ($Adapter in $VM.Adapters)
    {
        $AdapterCount++
        if ($Adapter.IPv4)
        {
            if (-not [System.String]::IsNullOrWhitespace($Adapter.IPv4.Address))
            {
                $DSCNetworkingConfig += @"
    xIPAddress IPv4_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
        IPAddress      = '$($Adapter.IPv4.Address.Replace(',',"','"))/$($Adapter.IPv4.SubnetMask)'
    }

"@
                if (-not [System.String]::IsNullOrWhitespace($Adapter.IPv4.DefaultGateway))
                {
                    $DSCNetworkingConfig += @"
    xDefaultGatewayAddress IPv4G_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
        Address        = '$($Adapter.IPv4.DefaultGateway)'
    }

"@
                }
                Else
                {
                    $DSCNetworkingConfig += @"
    xDefaultGatewayAddress IPv4G_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
    }

"@
                } # If
            }
            Else
            {
                $DSCNetworkingConfig += @"
    xDhcpClient IPv4DHCP_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
        State          = 'Enabled'
    }

"@

            } # If
            if (-not [System.String]::IsNullOrWhitespace($Adapter.IPv4.DNSServer))
            {
                $DSCNetworkingConfig += @"
    xDnsServerAddress IPv4D_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv4'
        Address        = '$($Adapter.IPv4.DNSServer.Replace(',',"','"))'
    }

"@
            } # If
        } # If
        if ($Adapter.IPv6)
        {
            if (-not [System.String]::IsNullOrWhitespace($Adapter.IPv6.Address))
            {
                $DSCNetworkingConfig += @"
    xIPAddress IPv6_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
        IPAddress      = '$($Adapter.IPv6.Address.Replace(',',"','"))/$($Adapter.IPv6.SubnetMask)'
    }

"@
                if (-not [System.String]::IsNullOrWhitespace($Adapter.IPv6.DefaultGateway))
                {
                    $DSCNetworkingConfig += @"
    xDefaultGatewayAddress IPv6G_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
        Address        = '$($Adapter.IPv6.DefaultGateway)'
    }

"@
                }
                Else
                {
                    $DSCNetworkingConfig += @"
    xDefaultGatewayAddress IPv6G_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
    }

"@
                } # If
            }
            Else
            {
                $DSCNetworkingConfig += @"
    xDhcpClient IPv6DHCP_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
        State          = 'Enabled'
    }

"@

            } # If
            if (-not [System.String]::IsNullOrWhitespace($Adapter.IPv6.DNSServer))
            {
                $DSCNetworkingConfig += @"
    xDnsServerAddress IPv6D_$AdapterCount {
        InterfaceAlias = '$($Adapter.Name)'
        AddressFamily  = 'IPv6'
        Address        = '$($Adapter.IPv6.DNSServer.Replace(',',"','"))'
    }

"@
            } # If
        } # If
    } # Endfor
    $DSCNetworkingConfig += @"
}
"@
    Return $DSCNetworkingConfig
} # GetDSCNetworkingConfig


[DSCLocalConfigurationManager()]
Configuration ConfigLCM {
    param (
        [System.String] $ComputerName,
        [System.String] $Thumbprint
    )
    Node $ComputerName {
        Settings
        {
            RefreshMode                    = 'Push'
            ConfigurationMode              = 'ApplyAndAutoCorrect'
            CertificateId                  = $Thumbprint
            ConfigurationModeFrequencyMins = 15
            RefreshFrequencyMins           = 30
            RebootNodeIfNeeded             = $True
            ActionAfterReboot              = 'ContinueConfiguration'
        }
    }
}
