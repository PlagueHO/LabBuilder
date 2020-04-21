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
            -Name NetworkingDsc `
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
        [System.String]
        $Name,

        [Parameter(
            position = 2)]
        [System.String]
        $URL,

        [Parameter(
            position = 3)]
        [System.String]
        $Folder,

        [Parameter(
            position = 4)]
        [System.String]
        $RequiredVersion,

        [Parameter(
            position = 5)]
        [System.String]
        $MinimumVersion
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
}
