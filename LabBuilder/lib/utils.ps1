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
   Returns True if running as Administrator
#>
function IsAdmin()
{
    # Get the ID and security principal of the current user account
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
  
    # Get the security principal for the Administrator role
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
  
    # Check to see if we are currently running "as Administrator"
    Return ($myWindowsPrincipal.IsInRole($adminRole))
} # IsAdmin

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
   Downloads any resources required by the configuration.
.DESCRIPTION
   It will ensure any required modules and files are downloaded.
.PARAMETER Lab
   Contains the Lab object that was produced by the Get-Lab cmdlet.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   DownloadResources -Lab $Lab
   Loads a Lab Builder configuration and downloads any resources required by it.   
.OUTPUTS
   None.
#>
function DownloadModule {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [String] $URL,

        [String] $Folder,
        
        [String] $RequiredVersion,

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
            $null = Get-PackageProvider -name nuget -ForceBootStrap -Force

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
} # DownloadModule


<#
.SYNOPSIS
   Downloads any resources required by the configuration.
.DESCRIPTION
   It will ensure any required modules and files are downloaded.
.PARAMETER Lab
   Contains the Lab object that was produced by the Get-Lab cmdlet.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   DownloadResources -Lab $Lab
   Loads a Lab Builder configuration and downloads any resources required by it.   
.OUTPUTS
   None.
#>
function DownloadResources {
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $Lab
    )
        
    # Downloading Lab Resources
    Write-Verbose -Message $($LocalizedData.DownloadingLabResourcesMessage)

    # Bootstrap Nuget # This needs to be a test, not a force 
    # $null = Get-PackageProvider -Name NuGet -ForceBootstrap -Force
    
    # Make sure PSGallery is trusted
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted    
    
    # Download any other resources required by this lab
    if ($Lab.labbuilderconfig.resources) 
    {
        foreach ($Module in $Lab.labbuilderconfig.resources.module)
        {
            if (-not $Module.Name)
            {
                $ExceptionParameters = @{
                    errorId = 'ResourceModuleNameEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ResourceModuleNameEmptyError)
                }
                ThrowException @ExceptionParameters
            } # If
            $Splat = [PSObject] @{ Name = $Module.Name }
            if ($Module.URL)
            {
                $Splat += [PSObject] @{ URL = $Module.URL }
            }
            if ($Module.Folder)
            {
                $Splat += [PSObject] @{ Folder = $Module.Folder }
            }
            if ($Module.RequiredVersion)
            {
                $Splat += [PSObject] @{ RequiredVersion = $Module.RequiredVersion }
            }
            if ($Module.MiniumVersion)
            {
                $Splat += [PSObject] @{ MiniumVersion = $Module.MiniumVersion }
            }
            DownloadModule @Splat
        } # Foreach
    } # If
} # DownloadResources


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