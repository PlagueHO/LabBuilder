<#
.SYNOPSIS
   Throws a custom exception.
.DESCRIPTION
   This cmdlet throw a terminating or non-terminating exception. 
.EXAMPLE
    $ExceptionParameters = @{
        errorId = 'ConnectionFailure'
        errorCategory = 'ConnectionError'
        errorMessage = 'Could not connect'
    }
    ThrowException @ExceptionParameters
    Throw a ConnectionError exception with the message 'Could not connect'.
.PARAMETER errorId
   The Id of the exception.
.PARAMETER errorCategory
   The category of the exception. It must be a valid [System.Management.Automation.ErrorCategory]
   value.
.PARAMETER errorMessage
   The exception message.
.PARAMETER terminate
   THis switch will cause the exception to terminate the cmdlet.
.OUTPUTS
   None
#>

function ThrowException
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [String] $errorId,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorCategory] $errorCategory,

        [Parameter(Mandatory)]
        [String] $errorMessage,
        
        [Switch]
        $terminate
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
} # ThrowException


<#
.SYNOPSIS
   Download the a file to a folder and optionally unzip it.
   
   If the file is a zip file the file will be downloaded to a temporary
   working folder and then unzipped to the destination, otherwise it
   will be downloaded straight to the destination folder.
#>
function DownloadAndUnzipFile()
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]	
        [String] $URL,
        
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $DestinationPath
    )
        
    $FileName = $URL.Substring($URL.LastIndexOf('/') + 1)

    if (-not (Test-Path -Path $DestinationPath))
    {
        $ExceptionParameters = @{
            errorId = 'DownloadFolderDoesNotExistError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.DownloadFolderDoesNotExistError `
            -f $DestinationPath,$Filename)
        }
        ThrowException @ExceptionParameters            
    }

    $Extension = [System.IO.Path]::GetExtension($Filename)
    if ($Extension -eq '.zip')
    {
        # Download to a temp folder and unzip
        $DownloadPath = Join-Path -Path $Script:WorkingFolder -ChildPath $FileName
    }
    else
    {
        # Download to a temp folder and unzip
        $DownloadPath = Join-Path -Path $DestinationPath -ChildPath $FileName
    }

    Write-Verbose -Message ($LocalizedData.DownloadingFileMessage `
        -f $Filename,$URL,$DownloadPath)

    Try
    {
        Invoke-WebRequest `
            -Uri $URL `
            -OutFile $DownloadPath `
            -ErrorAction Stop
    }
    Catch
    {
        $ExceptionParameters = @{
            errorId = 'FileDownloadError'
            errorCategory = 'InvalidOperation'
            errorMessage = $($LocalizedData.FileDownloadError `
                -f $Filename,$URL,$_.Exception.Message)
        }
        ThrowException @ExceptionParameters
    } # Try
    
    if ($Extension -eq '.zip')
    {        
        Write-Verbose -Message ($LocalizedData.ExtractingFileMessage `
            -f $Filename,$DownloadPath)

        # Extract this to the destination folder
        Try
        {
            Expand-Archive `
                -Path $DownloadPath `
                -DestinationPath $DestinationPath `
                -Force `
                -ErrorAction Stop
        }
        Catch
        {
            $ExceptionParameters = @{
                errorId = 'FileExtractError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.FileExtractError `
                -f $Filename,$_.Exception.Message)
            }
            ThrowException @ExceptionParameters
        }
        finally
        {
            # Remove the downloaded zip file
            Remove-Item -Path $DownloadPath
        } # Try
    }
} # DownloadAndUnzipFile


<#
.SYNOPSIS
    Generates a credential object from a username and password.
#>
function CreateCredential()
{
    [CmdletBinding()]
    [OutputType([PSCredential])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]	
        [String] $Username,
        
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]	
        [String] $Password
    )
    [PSCredential] $Credential = New-Object `
        -TypeName System.Management.Automation.PSCredential `
        -ArgumentList ($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))
    return $Credential
} # CreateCredential


<#
.SYNOPSIS
    Downloads a resource module.
.DESCRIPTION
    It will download a specific resource module, either from PowerShell Gallery
    or from a URL if the module does not already exist.
.PARAMETER Name
    Contains the Name of the module to download.
.PARAMETER URL
    If this parameter is specified, the resource module will be downloaded from a URL rather than via PowerShell Gallery.
    This is a the URL to use to download a zip file containing this resource module.
.PARAMETER Folder
    If this resource module is downloaded using a URL, this is the folder in the zip file that contains the resource and will need to be renamed to the name of the resource.
.PARAMETER RequiredVersion
    This is the required version of the Resource Module that is required.
    If this version is not installed the a new version will be downloaded.
.PARAMETER MinimumVersion
    This is the minimum version of the Resource Module that is required.
    If at least this version is not installed then a new version will be downloaded.
.EXAMPLE
    DownloadResourceModule `
        -Name xNetworking `
        -RequiredVersion 2.7.0.0
    Downloads the Resource Module xNetowrking version 2.7.0.0
.OUTPUTS
    None.
#>
function DownloadResourceModule {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [Parameter(
            position=2)]
        [String] $URL,

        [Parameter(
            position=3)]
        [String] $Folder,
        
        [Parameter(
            position=4)]
        [String] $RequiredVersion,

        [Parameter(
            position=5)]
        [String] $MinimumVersion
    )

    $InstalledModules = @(Get-Module -ListAvailable)

    # Determine a query that will be used to decide if the module is already installed
    if ($RequiredVersion) {
        [ScriptBlock] $Query = `
            { ($_.Name -eq $Name) -and ($_.Version -eq $RequiredVersion) }
        $VersionMessage = $RequiredVersion
    }
    elseif ($MinimumVersion)
    {
        [ScriptBlock] $Query = `
            { ($_.Name -eq $Name) -and ($_.Version -ge $MinimumVersion) }
        $VersionMessage = "min ${MinimumVersion}"
    }
    else
    {
        [ScriptBlock] $Query = `
            $Query = { $_.Name -eq $Name }
        $VersionMessage = 'any version'
    }

    # Is the module installed?
    if ($InstalledModules.Where($Query).Count -eq 0)
    {
        Write-Verbose -Message ($LocalizedData.ModuleNotInstalledMessage `
            -f $Name,$VersionMessage)

        # If a URL was specified, download this module via HTTP
        if ($URL)
        {
            # The module is not installed - so download it
            # This is usually for downloading modules directly from github
            $FileName = $URL.Substring($URL.LastIndexOf('/') + 1)

            Write-Verbose -Message ($LocalizedData.DownloadingLabResourceWebMessage `
                -f $Name,$VersionMessage,$URL)

            [String] $ModulesFolder = "$($ENV:ProgramFiles)\WindowsPowerShell\Modules\"

            DownloadAndUnzipFile `
                -URL $URL `
                -DestinationPath $ModulesFolder `
                -ErrorAction Stop

            if ($Folder)
            {
                # This zip file contains a folder that is not the name of the module so it must be
                # renamed. This is usually the case with source downloaded directly from GitHub
                $ModulePath = Join-Path -Path $ModulesFolder -ChildPath $Name
                if (Test-Path -Path $ModulePath)
                {
                    Remove-Item -Path $ModulePath -Recurse -Force
                }
                Rename-Item `
                    -Path (Join-Path -Path $ModulesFolder -ChildPath $Folder) `
                    -NewName $Name `
                    -Force
            } # If

            Write-Verbose -Message ($LocalizedData.InstalledLabResourceWebMessage `
                -f $Name,$VersionMessage,$ModulePath)
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
            $Splat = [PSObject] @{ Name = $Name }
            if ($RequiredVersion)
            {
                # Is a specific module version required?
                $Splat += [PSObject] @{ RequiredVersion = $RequiredVersion }
            }
            elseif ($MinimumVersion)
            {
                # Is a specific module version minimum version?
                $Splat += [PSObject] @{ MinimumVersion = $MinimumVersion }
            }
            try
            {
                Install-Module @Splat -Force -ErrorAction Stop
            }
            catch
            {
                $ExceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f $Name,$VersionMessage,$_.Exception.Message)
                }
                ThrowException @ExceptionParameters
            }
        } # If
    } # If
} # DownloadResourceModule


<#
.SYNOPSIS
   Ensures the Hyper-V features are installed onto the system.
.DESCRIPTION
   If the Hyper-V features are not installed onto this system they will be installed.
.EXAMPLE
   InstallHyperV
   Installs the appropriate Hyper-V features if they are not currently installed.
.OUTPUTS
   None
#>
function InstallHyperV {
    [CmdLetBinding()]
    Param ()

    # Install Hyper-V Components
    if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1)
    {
        # Desktop OS
        [Array] $Feature = Get-WindowsOptionalFeature -Online -FeatureName '*Hyper-V*' `
            | Where-Object -Property State -Eq 'Disabled'
        if ($Feature.Count -gt 0 )
        {
            Write-Verbose -Message ($LocalizedData.InstallingHyperVComponentsMesage `
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
            Write-Verbose -Message ($LocalizedData.InstallingHyperVComponentsMesage `
                -f 'Desktop')
            $Feature.Foreach( {
                Install-WindowsFeature -IncludeAllSubFeature -IncludeManagementTools -Name $_.Name
            } )
        }
    }
} # InstallHyperV


<#
.SYNOPSIS
   Validates the provided configuration XML against the Schema.
.DESCRIPTION
   This function will ensure that the provided Configration XML
   is compatible with the LabBuilderConfig.xsd Schema file.
.PARAMETER ConfigPath
   Contains the path to the Configuration XML file
.EXAMPLE
   ValidateConfigurationXMLSchema -ConfigPath c:\mylab\config.xml
   Validates the XML configuration and downloads any resources required by it.   
.OUTPUTS
   None. If the XML is invalid an exception will be thrown.
#>
function ValidateConfigurationXMLSchema {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $ConfigPath
    )

    # Define these variables so they are accesible inside the event handler.
    [int] $Script:XMLErrorCount = 0
    [string] $Script:XMLFirstError = ''
    [String] $Script:XMLPath = $ConfigPath 
    [string] $Script:ConfigurationXMLValidationMessage = $LocalizedData.ConfigurationXMLValidationMessage

    # Perform the XSD Validation
    $readerSettings = New-Object -TypeName System.Xml.XmlReaderSettings
    $readerSettings.ValidationType = [System.Xml.ValidationType]::Schema
    $null = $readerSettings.Schemas.Add("labbuilderconfig", $Script:ConfigurationXMLSchema)
    $readerSettings.ValidationFlags = [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessInlineSchema -bor [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessSchemaLocation
    $readerSettings.add_ValidationEventHandler(
    {
        # Triggered each time an error is found in the XML file
        if ([String]::IsNullOrWhitespace($Script:XMLFirstError))
        {    
            $Script:XMLFirstError = $_.Message
        } # if
        Write-Verbose -Message ($Script:ConfigurationXMLValidationMessage `
            -f $Script:XMLPath,$_.Message)
        $Script:XMLErrorCount++
    });
    $reader = [System.Xml.XmlReader]::Create([string] $ConfigPath, $readerSettings)
    try
    {
        while ($reader.Read())
        {
        } # while
    } # try
    catch
    {
        # XML is NOT valid
        $ExceptionParameters = @{
            errorId = 'ConfigurationXMLValidationError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationXMLValidationError `
                -f $ConfigPath,$_.Exception.Message)
        }
        ThrowException @ExceptionParameters
    } # catch
    finally
    {
        $null = $reader.Close()
    } # finally
    
    # Verify the results of the XSD validation
    if($script:XMLErrorCount -gt 0)
    {
        # XML is NOT valid
        $ExceptionParameters = @{
            errorId = 'ConfigurationXMLValidationError'
            errorCategory = 'InvalidArgument'
            errorMessage = $($LocalizedData.ConfigurationXMLValidationError `
                -f $ConfigPath,$Script:XMLFirstError)
        }
        ThrowException @ExceptionParameters
    } # if
} # ValidateConfigurationXMLSchema