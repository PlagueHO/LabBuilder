<#
    .SYNOPSIS
        Throws a custom exception.

    .DESCRIPTION
        This cmdlet throws a terminating or non-terminating exception.

    .PARAMETER errorId
        The Id of the exception.

    .PARAMETER errorCategory
        The category of the exception. It must be a valid [System.Management.Automation.ErrorCategory]
        value.

    .PARAMETER errorMessage
        The exception message.

    .PARAMETER terminate
        This switch will cause the exception to terminate the cmdlet.

    .EXAMPLE
        $exceptionParameters = @{
            errorId = 'ConnectionFailure'
            errorCategory = 'ConnectionError'
            errorMessage = 'Could not connect'
        }
        New-LabException @exceptionParameters
        Throw a ConnectionError exception with the message 'Could not connect'.

    .OUTPUTS
        None
#>

function New-LabException
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String] $ErrorId,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorCategory] $ErrorCategory,

        [Parameter(Mandatory = $true)]
        [System.String] $ErrorMessage,

        [Switch]
        $Terminate
    )

    $exception = New-Object -TypeName System.Exception `
        -ArgumentList $errorMessage
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $errorId, $errorCategory, $null

    if ($Terminate)
    {
        # This is a terminating exception.
        throw $errorRecord
    }
    else
    {
        # Note: Although this method is called ThrowTerminatingError, it doesn't terminate.
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
} # New-LabException

<#
    .SYNOPSIS
        Download the a file to a folder and optionally unzip it.

    .DESCRIPTION
        If the file is a zip file the file will be downloaded to a temporary
        working folder and then unzipped to the destination, otherwise it
        will be downloaded straight to the destination folder.
#>
function Invoke-LabDownloadAndUnzipFile
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String] $URL,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String] $DestinationPath
    )

    $fileName = [System.IO.Path]::GetFileName($URL)

    if (-not (Test-Path -Path $DestinationPath))
    {
        $exceptionParameters = @{
            errorId       = 'DownloadFolderDoesNotExistError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.DownloadFolderDoesNotExistError `
                    -f $DestinationPath, $fileName)
        }
        New-LabException @exceptionParameters
    }

    $extension = [System.IO.Path]::GetExtension($fileName)

    if ($extension -eq '.zip')
    {
        # Download to a temp folder and unzip
        $downloadPath = Join-Path -Path $Script:WorkingFolder -ChildPath $fileName
    }
    else
    {
        # Download to a temp folder and unzip
        $downloadPath = Join-Path -Path $DestinationPath -ChildPath $fileName
    }

    Write-LabMessage -Message ($LocalizedData.DownloadingFileMessage `
            -f $fileName, $URL, $downloadPath)

    try
    {
        Invoke-WebRequest `
            -Uri $URL `
            -OutFile $downloadPath `
            -ErrorAction Stop
    }
    catch
    {
        $exceptionParameters = @{
            errorId       = 'FileDownloadError'
            errorCategory = 'InvalidOperation'
            errorMessage  = $($LocalizedData.FileDownloadError -f $fileName, $URL, $_.Exception.Message)
        }
        New-LabException @exceptionParameters
    } # try

    if ($extension -eq '.zip')
    {
        Write-LabMessage -Message ($LocalizedData.ExtractingFileMessage `
                -f $fileName, $downloadPath)

        # Extract this to the destination folder
        try
        {
            Expand-Archive `
                -Path $downloadPath `
                -DestinationPath $DestinationPath `
                -Force `
                -ErrorAction Stop
        }
        catch
        {
            $exceptionParameters = @{
                errorId       = 'FileExtractError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.FileExtractError -f $fileName, $_.Exception.Message)
            }
            New-LabException @exceptionParameters
        }
        finally
        {
            # Remove the downloaded zip file
            Remove-Item -Path $downloadPath
        } # try
    }
} # Invoke-LabDownloadAndUnzipFile

<#
    .SYNOPSIS
        Downloads a resource module.

    .DESCRIPTION
        It will download a specific resource module, either from PowerShell Gallery
        or from a URL if the module does not already exist.

    .PARAMETER Name
        Contains the Name of the module to download.

    .PARAMETER URL
        If this parameter is specified, the resource module will be downloaded from a URL
        rather than via PowerShell Gallery. This is a the URL to use to download a zip
        file containing this resource module.

    .PARAMETER Folder
        If this resource module is downloaded using a URL, this is the folder in the zip
        file that contains the resource and will need to be renamed to the name of the
        resource.

    .PARAMETER RequiredVersion
        This is the required version of the Resource Module that is required.
        If this version is not installed the a new version will be downloaded.

    .PARAMETER MinimumVersion
        This is the minimum version of the Resource Module that is required.
        If at least this version is not installed then a new version will be downloaded.

    .EXAMPLE
        Invoke-LabDownloadResourceModule `
            -Name xNetworking `
            -RequiredVersion 2.7.0.0
        Downloads the Resource Module xNetowrking version 2.7.0.0

    .OUTPUTS
        None.
#>
function Invoke-LabDownloadResourceModule
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            position = 1,
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Name,

        [Parameter(
            position = 2)]
        [System.String] $URL,

        [Parameter(
            position = 3)]
        [System.String] $Folder,

        [Parameter(
            position = 4)]
        [System.String] $RequiredVersion,

        [Parameter(
            position = 5)]
        [System.String] $MinimumVersion
    )

    $installedModules = @(Get-Module -ListAvailable)

    # Determine a query that will be used to decide if the module is already installed
    if ($RequiredVersion)
    {
        [ScriptBlock] $Query = {
            ($_.Name -eq $Name) -and ($_.Version -eq $RequiredVersion)
        }

        $versionMessage = $RequiredVersion
    }
    elseif ($MinimumVersion)
    {
        [ScriptBlock] $Query = {
            ($_.Name -eq $Name) -and ($_.Version -ge $MinimumVersion)
        }

        $versionMessage = "min ${MinimumVersion}"
    }
    else
    {
        [ScriptBlock] $Query = {
            $_.Name -eq $Name
        }

        $versionMessage = 'any version'
    }

    # Is the module installed?
    if ($installedModules.Where($Query).Count -eq 0)
    {
        Write-LabMessage -Message ($LocalizedData.ModuleNotInstalledMessage `
                -f $Name, $versionMessage)

        # If a URL was specified, download this module via HTTP
        if ($URL)
        {
            # The module is not installed - so download it
            # This is usually for downloading modules directly from github
            Write-LabMessage -Message ($LocalizedData.DownloadingLabResourceWebMessage `
                    -f $Name, $versionMessage, $URL)

            $modulesFolder = "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\"

            Invoke-LabDownloadAndUnzipFile `
                -URL $URL `
                -DestinationPath $modulesFolder `
                -ErrorAction Stop

            if ($Folder)
            {
                # This zip file contains a folder that is not the name of the module so it must be
                # renamed. This is usually the case with source downloaded directly from GitHub
                $modulePath = Join-Path -Path $modulesFolder -ChildPath $Name

                if (Test-Path -Path $modulePath)
                {
                    Remove-Item -Path $modulePath -Recurse -Force
                }

                Rename-Item `
                    -Path (Join-Path -Path $modulesFolder -ChildPath $Folder) `
                    -NewName $Name `
                    -Force
            } # if

            Write-LabMessage -Message ($LocalizedData.InstalledLabResourceWebMessage `
                    -f $Name, $versionMessage, $modulePath)
        }
        else
        {
            # Install the package via PowerShellGet from the PowerShellGallery
            # Make sure the Nuget Package provider is initialized.
            $null = Get-PackageProvider `
                -name nuget `
                -ForceBootStrap `
                -Force

            # Make sure PSGallery is trusted
            Set-PSRepository `
                -Name PSGallery `
                -InstallationPolicy Trusted

            # Install the module
            $installModuleParameters = [PSObject] @{ Name = $Name }

            if ($RequiredVersion)
            {
                # Is a specific module version required?
                $installModuleParameters += [PSObject] @{
                    RequiredVersion = $RequiredVersion
                }
            }
            elseif ($MinimumVersion)
            {
                # Is a specific module version minimum version?
                $installModuleParameters += [PSObject] @{
                    MinimumVersion = $MinimumVersion
                }
            }

            try
            {
                Install-Module @installModuleParameters -Force -ErrorAction Stop
            }
            catch
            {
                $exceptionParameters = @{
                    errorId       = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.ModuleNotAvailableError `
                            -f $Name, $versionMessage, $_.Exception.Message)
                }
                New-LabException @exceptionParameters
            }
        } # If
    } # If
} # Invoke-LabDownloadResourceModule

<#
    .SYNOPSIS
        Generates a credential object from a username and password.
#>
function New-LabCredential()
{
    [CmdletBinding()]
    [OutputType([PSCredential])]
    Param
    (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Username,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Password
    )

    $credential = New-Object `
        -TypeName System.Management.Automation.PSCredential `
        -ArgumentList ($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))

    return $credential
} # New-LabCredential

<#
    .SYNOPSIS
        Ensures the WS-Man is configured on this system.

    .DESCRIPTION
        If WS-Man is not enabled on this system it will be enabled.
        This is required to communicate with the managed Lab Virtual Machines.

    .EXAMPLE
        Enable-LabWSMan
        Enables WS-Man on this machine.

    .OUTPUTS
        None
#>
function Enable-LabWSMan
{
    [CmdLetBinding()]
    param (
        [Parameter()]
        [Switch] $Force
    )

    if (-not (Get-PSPRovider -PSProvider WSMan -ErrorAction SilentlyContinue))
    {
        Write-LabMessage -Message ($LocalizedData.EnablingWSManMessage)

        try
        {
            Start-Service -Name WinRm -ErrorAction Stop
        }
        catch
        {
            $null = Enable-PSRemoting `
                @PSBoundParameters `
                -SkipNetworkProfileCheck `
                -ErrorAction Stop
        }

        # Check WS-Man was enabled
        if (-not (Get-PSProvider -PSProvider WSMan -ErrorAction SilentlyContinue))
        {
            $exceptionParameters = @{
                errorId       = 'WSManNotEnabledError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.WSManNotEnabledError)
            }
            New-LabException @exceptionParameters
        } # if
    } # if
} # Enable-LabWSMan

<#
.SYNOPSIS
    Ensures the Hyper-V features are installed onto the system.
.DESCRIPTION
    If the Hyper-V features are not installed onto this system they will be installed.
.EXAMPLE
    Install-LabHyperV
    Installs the appropriate Hyper-V features if they are not currently installed.
.OUTPUTS
    None
#>
function Install-LabHyperV
{
    [CmdLetBinding()]
    param ()

    # Install Hyper-V Components
    if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1)
    {
        # Desktop OS
        [Array] $Feature = Get-WindowsOptionalFeature -Online -FeatureName '*Hyper-V*' `
            | Where-Object -Property State -Eq 'Disabled'
        if ($Feature.Count -gt 0 )
        {
            Write-LabMessage -Message ($LocalizedData.InstallingHyperVComponentsMesage `
                    -f 'Desktop')
            $Feature.Foreach( {
                    Enable-WindowsOptionalFeature -Online -FeatureName $_.FeatureName
                } )
        }
    }
    Else
    {
        # Server OS
        [Array] $Feature = Get-WindowsFeature -Name Hyper-V `
            | Where-Object -Property Installed -EQ $false
        if ($Feature.Count -gt 0 )
        {
            Write-LabMessage -Message ($LocalizedData.InstallingHyperVComponentsMesage `
                    -f 'Desktop')
            $Feature.Foreach( {
                    Install-WindowsFeature -IncludeAllSubFeature -IncludeManagementTools -Name $_.Name
                } )
        }
    }
} # Install-LabHyperV

<#
.SYNOPSIS
    Validates the provided configuration XML against the Schema.
.DESCRIPTION
    This function will ensure that the provided Configration XML
    is compatible with the LabBuilderConfig.xsd Schema file.
.PARAMETER ConfigPath
    Contains the path to the Configuration XML file
.EXAMPLE
    Assert-ValidConfigurationXMLSchema -ConfigPath c:\mylab\config.xml
    Validates the XML configuration and downloads any resources required by it.
.OUTPUTS
    None. If the XML is invalid an exception will be thrown.
#>
function Assert-ValidConfigurationXMLSchema
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ConfigPath
    )

    # Define these variables so they are accesible inside the event handler.
    $Script:XMLErrorCount = 0
    $Script:XMLFirstError = ''
    $Script:XMLPath = $ConfigPath
    $Script:ConfigurationXMLValidationMessage = $LocalizedData.ConfigurationXMLValidationMessage

    # Perform the XSD Validation
    $readerSettings = New-Object -TypeName System.Xml.XmlReaderSettings
    $readerSettings.ValidationType = [System.Xml.ValidationType]::Schema
    $null = $readerSettings.Schemas.Add("labbuilderconfig", $Script:ConfigurationXMLSchema)
    $readerSettings.ValidationFlags = [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessInlineSchema -bor [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessSchemaLocation
    $readerSettings.add_ValidationEventHandler(
        {
            # Triggered each time an error is found in the XML file
            if ([System.String]::IsNullOrWhitespace($Script:XMLFirstError))
            {
                $Script:XMLFirstError = $_.Message
            } # if
            Write-LabMessage -Message ($Script:ConfigurationXMLValidationMessage `
                    -f $Script:XMLPath, $_.Message)
            $Script:XMLErrorCount++
        })

    $reader = [System.Xml.XmlReader]::Create([System.String] $ConfigPath, $readerSettings)

    try
    {
        while ($reader.Read())
        {
        } # while
    } # try
    catch
    {
        # XML is NOT valid
        $exceptionParameters = @{
            errorId       = 'ConfigurationXMLValidationError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.ConfigurationXMLValidationError `
                    -f $ConfigPath, $_.Exception.Message)
        }
        New-LabException @exceptionParameters
    } # catch
    finally
    {
        $null = $reader.Close()
    } # finally

    # Verify the results of the XSD validation
    if ($script:XMLErrorCount -gt 0)
    {
        # XML is NOT valid
        $exceptionParameters = @{
            errorId       = 'ConfigurationXMLValidationError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.ConfigurationXMLValidationError -f $ConfigPath, $Script:XMLFirstError)
        }
        New-LabException @exceptionParameters
    } # if
} # Assert-ValidConfigurationXMLSchema

<#
.SYNOPSIS
    Increases the MAC Address.
.PARAMETER MACAddress
    Contains the MAC Address to increase.
.PARAMETER Step
    Contains the number of steps to increase the MAC address by.
.EXAMPLE
    Get-NextMacAddress -MacAddress '00155D0106ED' -Step 2
    Returns the MAC Address '00155D0106EF'
.OUTPUTS
    The increased MAC Address.
#>
function Get-NextMacAddress
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $MacAddress,

        [Byte] $Step = 1
    )
    Return [System.String]::Format("{0:X}", [Convert]::ToUInt64($MACAddress, 16) + $Step).PadLeft(12, '0')
} # Get-NextMacAddress

<#
    .SYNOPSIS
        Increases the IP Address.

    .PARAMETER IpAddress
        Contains the IP Address to increase.

    .PARAMETER Step
        Contains the number of steps to increase the IP address by.

    .EXAMPLE
        Get-NextIpAddress -IpAddress '192.168.123.44' -Step 2
        Returns the IP Address '192.168.123.44'

    .EXAMPLE
        Get-NextIpAddress -IpAddress 'fe80::15b4:b934:5d23:1a2f' -Step 2
        Returns the IP Address 'fe80::15b4:b934:5d23:1a31'

    .OUTPUTS
        The increased IP Address.
#>
function Get-NextIpAddress
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $IpAddress,

        [Parameter()]
        [System.Byte] $Step = 1
    )

    # Check the IP Address is valid
    $ip = Assert-ValidIpAddress -IpAddress $IpAddress

    # This code will increase the next IP address by the step amount.
    # It uses the IP Address byte array to do this.
    $bytes = $ip.GetAddressBytes()
    $position = $bytes.Length - 1

    while ($Step -gt 0)
    {
        if ($bytes[$position] + $Step -gt 255)
        {
            $bytes[$position] = $bytes[$position] + $Step - 256
            $Step = $Step - $bytes[$position]
            $position--
        }
        else
        {
            $bytes[$position] = $bytes[$position] + $Step
            $Step = 0
        } # if
    } # while

    return [System.Net.IPAddress]::new($bytes).IPAddressToString
} # Get-NextIpAddress

<#
    .SYNOPSIS
        Validates the IP Address.

    .PARAMETER IpAddress
        Contains the IP Address to validate.

    .EXAMPLE
        Assert-ValidIpAddress -IpAddress '192.168.123.44'
        Does not throw an exception and returns '192.168.123.44'.

    .EXAMPLE
        Assert-ValidIpAddress -IpAddress '192.168.123.4432'
        Throws an exception.

    .OUTPUTS
        The IP address if valid.
#>
function Assert-ValidIpAddress
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $IpAddress
    )

    $ip = [System.Net.IPAddress]::Any
    if (-not [System.Net.IPAddress]::TryParse($IpAddress, [ref] $ip))
    {
        $exceptionParameters = @{
            errorId       = 'IPAddressError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.IPAddressError -f $IpAddress)
        }
        New-LabException @exceptionParameters
    }
    return $ip
} # Assert-ValidIpAddress

<#
    .SYNOPSIS
        Ensures the Package Providers required by LabBuilder are installed.

    .DESCRIPTION
        This function will check that both the NuGet and the PowerShellGet package
        providers are installed.
        If either of them are missing the function will attempt to install them.

    .EXAMPLE
        Install-LabPackageProvider
        Ensures the required Package Providers for LabBuilder are installed.

    .OUTPUTS
        None
#>
function Install-LabPackageProvider
{
    [CmdLetBinding(SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]
    param
    (
        [Parameter()]
        [Switch] $Force
    )

    $requiredPackageProviders = @('PowerShellGet', 'NuGet')
    $currentPackageProviders = Get-PackageProvider `
        -ListAvailable `
        -ErrorAction Stop

    foreach ($requiredPackageProvider in $requiredPackageProviders)
    {
        $packageProvider = $currentPackageProviders |
            Where-Object { $_.Name -eq $requiredPackageProvider }
        if (-not $packageProvider)
        {
            # The Package provider is not installed so install it
            if ($Force -or $PSCmdlet.ShouldProcess( 'LocalHost', `
                    ($LocalizedData.ShouldInstallPackageProvider `
                            -f $packageProvider )))
            {
                Write-LabMessage -Message ($LocalizedData.InstallPackageProviderMessage `
                        -f $requiredPackageProvider)

                $null = Install-PackageProvider `
                    -Name $requiredPackageProvider `
                    -ForceBootstrap `
                    -Force `
                    -ErrorAction Stop
            }
            else
            {
                # Can't continue if the package provider is not installed.
                $exceptionParameters = @{
                    errorId       = 'PackageProviderNotInstalledError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.PackageProviderNotInstalledError `
                            -f $requiredPackageProvider)
                }
                New-LabException @exceptionParameters
            } # if
        } # if
    } # foreach
} # Install-LabPackageProvider


<#
    .SYNOPSIS
        Ensures the Package Sources required by LabBuilder are registered.

    .DESCRIPTION
        This function will check that both the NuGet.org and the PSGallery package
        sources are registered.
        If either of them are missing the function will attempt to register them.

    .EXAMPLE
        Register-LabPackageSource
        Ensures the required Package Sources for LabBuilder are required.

    .OUTPUTS
        None
#>
function Register-LabPackageSource
{
    [CmdLetBinding(SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]
    param
    (
        [Parameter()]
        [Switch] $Force
    )

    $requiredPackageSources = @(
        @{
            Name         = 'nuget.org'
            ProviderName = 'NuGet'
            Location     = 'https://www.nuget.org/api/v2/'
        },
        @{
            Name         = 'PSGallery'
            ProviderName = 'PowerShellGet'
            Location     = 'https://www.powershellgallery.com/api/v2/'
        }
    )

    $currentPackageSources = Get-PackageSource -ErrorAction Stop

    foreach ($requiredPackageSource in $requiredPackageSources)
    {
        $packageSource = $currentPackageSources |
            Where-Object -FilterScript {
            $_.Name -eq $requiredPackageSource.Name
        }

        if ($packageSource)
        {
            if (-not $packageSource.IsTrusted)
            {
                if ($Force -or $PSCmdlet.ShouldProcess( 'Localhost', `
                        ($LocalizedData.ShouldTrustPackageSource `
                                -f $requiredPackageSource.Name, $requiredPackageSource.Location )))
                {
                    # The Package source is not trusted so trust it
                    Write-LabMessage -Message ($LocalizedData.RegisterPackageSourceMessage `
                            -f $requiredPackageSource.Name, $requiredPackageSource.Location)

                    $null = Set-PackageSource `
                        -Name $requiredPackageSource.Name `
                        -Trusted `
                        -Force `
                        -ErrorAction Stop
                }
                else
                {
                    # Can't continue if the package source is not trusted.
                    $exceptionParameters = @{
                        errorId       = 'PackageSourceNotTrustedError'
                        errorCategory = 'InvalidArgument'
                        errorMessage  = $($LocalizedData.PackageSourceNotTrustedError `
                                -f $requiredPackageSource.Name)
                    }
                    New-LabException @exceptionParameters
                } # if
            } # if
        }
        else
        {
            # The Package source is not registered so register it
            if ($Force -or $PSCmdlet.ShouldProcess( 'Localhost', `
                    ($LocalizedData.ShouldRegisterPackageSource `
                            -f $requiredPackageSource.Name, $requiredPackageSource.Location )))
            {
                Write-LabMessage -Message ($LocalizedData.RegisterPackageSourceMessage `
                        -f $requiredPackageSource.Name, $requiredPackageSource.Location)

                $null = Register-PackageSource `
                    -Name $requiredPackageSource.Name `
                    -Location $requiredPackageSource.Location `
                    -ProviderName $requiredPackageSource.ProviderName `
                    -Trusted `
                    -Force `
                    -ErrorAction Stop
            }
            else
            {
                # Can't continue if the package source is not registered.
                $exceptionParameters = @{
                    errorId       = 'PackageSourceNotRegisteredError'
                    errorCategory = 'InvalidArgument'
                    errorMessage  = $($LocalizedData.PackageSourceNotRegisteredError `
                            -f $requiredPackageSource.Name)
                }
                New-LabException @exceptionParameters
            } # if
        } # if
    } # foreach
} # Register-LabPackageSource

<#
    .SYNOPSIS
        Writes a Message of the specified Type.

    .DESCRIPTION
        This cmdlet will write a message along with the time to the specified output stream.

    .PARAMETER Type
        This can be one of the following:
        Error - Writes to the Error Stream.
        Warning - Writes to the Warning Stream.
        Verbose - Writes to the Verbose Stream (default)
        Debug - Writes to the Debug Stream.
        Information - Writes to the Information Stream.
        Output - Writes to the Output Stream (so should be used for a terminating message)

    .PARAMETER Message
        The Message to output.

    .PARAMETER ForegroundColor
        The foreground color of the message if being writen to the output stream.

    .EXAMPLE
        Write-LabMessage -Type Verbose -Message 'Downloading file'
        New-LabException @exceptionParameters
        Outputs the message 'Downloading file' to the Verbose stream.

    .OUTPUTS
        None
#>
function Write-LabMessage
{
    [CmdLetBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Error', 'Warning', 'Verbose', 'Debug', 'Info', 'Alert')]
        [System.String] $Type = 'Verbose',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Message,

        [Parameter()]
        [System.String] $ForegroundColor = 'Yellow'
    )

    $time = Get-Date -UFormat %T

    switch ($Type)
    {
        'Error'
        {
            Write-Error -Message $Message
            break
        }

        'Warning'
        {
            Write-Warning -Message ('[{0}]: {1}' -f $time, $Message)
            break
        }

        'Verbose'
        {
            Write-Verbose -Message ('[{0}]: {1}' -f $time, $Message)
            break
        }

        'Debug'
        {
            Write-Debug -Message ('[{0}]: {1}' -f $time, $Message)
            break
        }

        'Info'
        {
            Write-Information -MessageData ('INFO: [{0}]: {1}' -f $time, $Message)
            break
        }

        'Alert'
        {
            Write-Host `
                -ForegroundColor $ForegroundColor `
                -Object $Message
            break
        }
    } # switch
} # Write-LabMessage
