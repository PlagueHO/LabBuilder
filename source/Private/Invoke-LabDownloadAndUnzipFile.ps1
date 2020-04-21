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
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $URL,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DestinationPath
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
        $downloadPath = Join-Path -Path $script:WorkingFolder -ChildPath $fileName
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
}
