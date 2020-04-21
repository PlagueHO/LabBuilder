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
        [Switch]
        $Force
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
}
