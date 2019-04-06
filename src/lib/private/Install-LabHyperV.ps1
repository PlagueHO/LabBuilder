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
}
