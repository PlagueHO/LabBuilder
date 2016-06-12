Push-Location
Set-Location -Path "$PSScriptRoot\..\LabBuilder\"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
if (-not (Get-Module -Name Pester -ListAvailable -ErrorAction SilentlyContinue))
{
    Install-Module Pester -Force
}
Install-WindowsFeature -Name Hyper-V-PowerShell
$testResultsFile = "$PSScriptRoot\..\LabBuilder\TestsResults.xml"
Invoke-Pester `
    -ExcludeTag Incomplete `
    -OutputFormat NUnitXml `
    -OutputFile $testResultsFile `
    -PassThru `
Pop-Location
