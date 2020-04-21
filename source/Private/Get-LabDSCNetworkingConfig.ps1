<#
    .SYNOPSIS
        Assemble the content of the Networking DSC config file.

    .DESCRIPTION
        This function creates the content that will be written to the Networking DSC Config file
        from the networking details stored in the VM object.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        $NetworkingDsc = Get-LabDSCNetworkingConfig -Lab $Lab -VM $VMs[0]
        Return the Networking DSC for the first VM in the Lab c:\mylab\config.xml for DSC configuration.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .OUTPUTS
        A string containing the DSC Networking config.
#>
function Get-LabDSCNetworkingConfig
{
    [CmdLetBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM
    )

    $NetworkingDscVersion = (`
            Get-Module -Name NetworkingDsc -ListAvailable `
            | Sort-Object version -Descending `
            | Select-Object -First 1 `
    ).Version.ToString()

    $dscNetworkingConfig = @"
Configuration Networking {
    Import-DscResource -ModuleName NetworkingDsc -ModuleVersion $NetworkingDscVersion

"@
    $adapterCount = 0

    foreach ($Adapter in $VM.Adapters)
    {
        $adapterCount++

        if ($adapter.IPv4)
        {
            if (-not [System.String]::IsNullOrWhitespace($adapter.IPv4.Address))
            {
                $dscNetworkingConfig += @"
    IPAddress IPv4_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv4'
        IPAddress      = '$($adapter.IPv4.Address.Replace(',',"','"))/$($adapter.IPv4.SubnetMask)'
    }

"@
                if (-not [System.String]::IsNullOrWhitespace($adapter.IPv4.DefaultGateway))
                {
                    $dscNetworkingConfig += @"
    DefaultGatewayAddress IPv4G_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv4'
        Address        = '$($adapter.IPv4.DefaultGateway)'
    }

"@
                }
                else
                {
                    $dscNetworkingConfig += @"
    DefaultGatewayAddress IPv4G_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv4'
    }

"@
                } # if
            }
            else
            {
                $dscNetworkingConfig += @"
    NetIPInterface IPv4DHCP_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv4'
        Dhcp           = 'Enabled'
    }

"@

            } # if

            if (-not [System.String]::IsNullOrWhitespace($adapter.IPv4.DNSServer))
            {
                $dscNetworkingConfig += @"
    DnsServerAddress IPv4D_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv4'
        Address        = '$($adapter.IPv4.DNSServer.Replace(',',"','"))'
    }

"@
            } # if
        } # if

        if ($adapter.IPv6)
        {
            if (-not [System.String]::IsNullOrWhitespace($adapter.IPv6.Address))
            {
                $dscNetworkingConfig += @"
    IPAddress IPv6_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv6'
        IPAddress      = '$($adapter.IPv6.Address.Replace(',',"','"))/$($adapter.IPv6.SubnetMask)'
    }

"@
                if (-not [System.String]::IsNullOrWhitespace($adapter.IPv6.DefaultGateway))
                {
                    $dscNetworkingConfig += @"
    DefaultGatewayAddress IPv6G_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv6'
        Address        = '$($adapter.IPv6.DefaultGateway)'
    }

"@
                }
                else
                {
                    $dscNetworkingConfig += @"
    DefaultGatewayAddress IPv6G_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv6'
    }

"@
                } # if
            }
            else
            {
                $dscNetworkingConfig += @"
    NetIPInterface IPv6DHCP_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv6'
        Dhcp           = 'Enabled'
    }

"@

            } # if

            if (-not [System.String]::IsNullOrWhitespace($adapter.IPv6.DNSServer))
            {
                $dscNetworkingConfig += @"
    DnsServerAddress IPv6D_$adapterCount {
        InterfaceAlias = '$($adapter.Name)'
        AddressFamily  = 'IPv6'
        Address        = '$($adapter.IPv6.DNSServer.Replace(',',"','"))'
    }

"@
            } # if
        } # if
    } # endfor

    $dscNetworkingConfig += @"
}
"@

    return $dscNetworkingConfig
} # Get-LabDSCNetworkingConfig

[DSCLocalConfigurationManager()]
Configuration ConfigLCM {
    param (
        [System.String] $ComputerName,
        [System.String] $Thumbprint
    )
    Node $ComputerName {
        Settings
        {
            RefreshMode                    = 'Push'
            ConfigurationMode              = 'ApplyAndAutoCorrect'
            CertificateId                  = $Thumbprint
            ConfigurationModeFrequencyMins = 15
            RefreshFrequencyMins           = 30
            RebootNodeIfNeeded             = $true
            ActionAfterReboot              = 'ContinueConfiguration'
        }
    }
}
