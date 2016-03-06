<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    STANDALONE_DHCPDNS
.Desription
    Builds a Standalone DHCP and DNS Server.
.Parameters:    
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
    }
}
