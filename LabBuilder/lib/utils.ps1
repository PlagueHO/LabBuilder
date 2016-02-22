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
        New-LabException @ExceptionParameters            
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
        New-LabException @ExceptionParameters
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
            New-LabException @ExceptionParameters
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
