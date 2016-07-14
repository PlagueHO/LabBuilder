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
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xDNSServer
    Import-DscResource -ModuleName xDHCPServer
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }

        WindowsFeature DHCPInstall 
        {
            Ensure = "Present" 
            Name = "DHCP" 
        }

        WindowsFeature DNSInstall 
        {
            Ensure = "Present" 
            Name = "DNS" 
        }

        # Add the DHCP Scope, Reservation and Options from
        # the node configuration
        [Int]$Count=0
        Foreach ($Scope in $Node.Scopes) {
            $Count++
            xDhcpServerScope "Scope$Count"
            {
                Ensure = 'Present'
                IPStartRange = $Scope.Start
                IPEndRange = $Scope.End
                Name = $Scope.Name
                SubnetMask = $Scope.SubnetMask
                State = 'Active'
                LeaseDuration = '00:08:00'
                AddressFamily = $Scope.AddressFamily
                DependsOn = '[WindowsFeature]DHCPInstall'
            }
        }
        [Int]$Count=0
        Foreach ($Reservation in $Node.Reservations) {
            $Count++
            xDhcpServerReservation "Reservation$Count"
            {
                Ensure = 'Present'
                ScopeID = $Reservation.ScopeId
                ClientMACAddress = $Reservation.ClientMACAddress
                IPAddress = $Reservation.IPAddress
                Name = $Reservation.Name
                AddressFamily = $Reservation.AddressFamily
                DependsOn = '[WindowsFeature]DHCPInstall'
            }
        }
        [Int]$Count=0
        Foreach ($ScopeOption in $Node.ScopeOptions) {
            $Count++
            xDhcpServerOption "ScopeOption$Count"
            {
                Ensure = 'Present'
                ScopeID = $ScopeOption.ScopeId
                DnsDomain = $Node.DomainName
                DnsServerIPAddress = $ScopeOption.DNServerIPAddress
                Router = $ScopeOption.Router
                AddressFamily = $ScopeOption.AddressFamily
                DependsOn = '[WindowsFeature]DHCPInstall'
            }
        }
        
        # DNS Server Settings
        if ($Node.Forwarders)
        {
            xDnsServerForwarder DNSForwarders
            {
                IsSingleInstance = 'Yes'
                IPAddresses      = $Node.Forwarders
                Credential       = $DomainAdminCredential 
                DependsOn        = '[xComputer]JoinDomain'
            }
        }

        [Int]$Count=0
        Foreach ($ADZone in $Node.ADZones) {
            $Count++
            xDnsServerADZone "ADZone$Count"
            {
                Ensure           = 'Present'
                Name             = $ADZone.Name
                DynamicUpdate    = $ADZone.DynamicUpdate
                ReplicationScope = $ADZone.ReplicationScope
                Credential       = $DomainAdminCredential 
                DependsOn        = '[xComputer]JoinDomain'
            }
        }

        [Int]$Count=0
        Foreach ($PrimaryZone in $Node.PrimaryZones) {
            $Count++
            xDnsServerSecondaryZone "PrimaryZone$Count"
            {
                Ensure        = 'Present'
                Name          = $PrimaryZone.Name
                ZoneFile      = $PrimaryZone.ZoneFile
                DynamicUpdate = $PrimaryZone.DynamicUpdate
                Credential    = $DomainAdminCredential 
                DependsOn     = '[xComputer]JoinDomain'
            }
        }
    }
}
