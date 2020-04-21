<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    STANDALONE_DHCPDNS
.Desription
    Builds a Standalone DHCP and DNS Server.
.Parameters:
    Scopes = @(
        @{ Name = 'Site A Primary';
            Start = '192.168.128.50';
            End = '192.168.128.254';
            SubnetMask = '255.255.255.0';
            AddressFamily = 'IPv4'
        }
    )
    Reservations = @(
        @{ Name = 'SA-DC1';
            ScopeID = '192.168.128.0';
            ClientMACAddress = '000000000000';
            IPAddress = '192.168.128.10';
            AddressFamily = 'IPv4'
        },
        @{ Name = 'SA-DC2';
            ScopeID = '192.168.128.0';
            ClientMACAddress = '000000000001';
            IPAddress = '192.168.128.11';
            AddressFamily = 'IPv4'
        },
        @{ Name = 'SA-DHCP1';
            ScopeID = '192.168.128.0';
            ClientMACAddress = '000000000002';
            IPAddress = '192.168.128.16';
            AddressFamily = 'IPv4'
        },
        @{ Name = 'SA-EDGE1';
            ScopeID = '192.168.128.0';
            ClientMACAddress = '000000000005';
            IPAddress = '192.168.128.19';
            AddressFamily = 'IPv4'
        }
    )
    ScopeOptions = @(
        @{ ScopeID = '192.168.128.0';
            DNServerIPAddress = @('192.168.128.10','192.168.128.11');
            Router = '192.168.128.19';
            AddressFamily = 'IPv4'
        }
    )
    Forwarders = @('8.8.8.8','8.8.4.4')
    ADZones = @(
        @{ Name = 'ALPHA.LOCAL';
           DynamicUpdate = 'Secure';
           ReplicationScope = 'Forest';
        }
    )
    PrimaryZones = @(
        @{ Name = 'BRAVO.LOCAL';
           ZoneFile = 'bravo.local.dns';
           DynamicUpdate = 'None';
        }
    )
###################################################################################################>

Configuration STANDALONE_DHCPDNS
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xDNSServer -ModuleVersion 1.16.0.0
    Import-DscResource -ModuleName xDHCPServer -ModuleVersion 2.0.0.0

    Node $AllNodes.NodeName {
        WindowsFeature DHCPInstall
        {
            Ensure = 'Present'
            Name   = 'DHCP'
        }

        WindowsFeature DNSInstall
        {
            Ensure = 'Present'
            Name   = 'DNS'
        }

        <#
            Add the DHCP Scope, Reservation and Options from
            the node configuration
        #>
        $count = 0
        foreach ($Scope in $Node.Scopes)
        {
            $count++
            xDhcpServerScope "Scope$count"
            {
                Ensure        = 'Present'
                ScopeId       = $Scope.Name
                IPStartRange  = $Scope.Start
                IPEndRange    = $Scope.End
                Name          = $Scope.Name
                SubnetMask    = $Scope.SubnetMask
                State         = 'Active'
                LeaseDuration = '00:08:00'
                AddressFamily = $Scope.AddressFamily
                DependsOn     = '[WindowsFeature]DHCPInstall'
            }
        }

        $count = 0
        foreach ($Reservation in $Node.Reservations)
        {
            $count++
            xDhcpServerReservation "Reservation$count"
            {
                Ensure           = 'Present'
                ScopeID          = $Reservation.ScopeId
                ClientMACAddress = $Reservation.ClientMACAddress
                IPAddress        = $Reservation.IPAddress
                Name             = $Reservation.Name
                AddressFamily    = $Reservation.AddressFamily
                DependsOn        = '[WindowsFeature]DHCPInstall'
            }
        }

        $count = 0
        foreach ($ScopeOption in $Node.ScopeOptions)
        {
            $count++
            xDhcpServerOption "ScopeOption$count"
            {
                Ensure             = 'Present'
                ScopeID            = $ScopeOption.ScopeId
                DnsDomain          = $Node.DomainName
                DnsServerIPAddress = $ScopeOption.DNServerIPAddress
                Router             = $ScopeOption.Router
                AddressFamily      = $ScopeOption.AddressFamily
                DependsOn          = '[WindowsFeature]DHCPInstall'
            }
        }

        # DNS Server Settings
        if ($Node.Forwarders)
        {
            xDnsServerForwarder DNSForwarders
            {
                IsSingleInstance = 'Yes'
                IPAddresses      = $Node.Forwarders
                DependsOn        = '[Computer]JoinDomain'
            }
        }

        $count = 0
        foreach ($ADZone in $Node.ADZones)
        {
            $count++
            xDnsServerADZone "ADZone$count"
            {
                Ensure           = 'Present'
                Name             = $ADZone.Name
                DynamicUpdate    = $ADZone.DynamicUpdate
                ReplicationScope = $ADZone.ReplicationScope
                Credential       = $DomainAdminCredential
                DependsOn        = '[Computer]JoinDomain'
            }
        }

        $count = 0
        foreach ($PrimaryZone in $Node.PrimaryZones)
        {
            $count++
            xDnsServerPrimaryZone "PrimaryZone$count"
            {
                Ensure        = 'Present'
                Name          = $PrimaryZone.Name
                ZoneFile      = $PrimaryZone.ZoneFile
                DynamicUpdate = $PrimaryZone.DynamicUpdate
                DependsOn     = '[Computer]JoinDomain'
            }
        }
    }
}
