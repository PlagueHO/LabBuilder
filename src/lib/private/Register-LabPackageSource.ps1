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
        [Switch]
        $Force
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
}
