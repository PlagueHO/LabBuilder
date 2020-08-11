<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    STANDALONE_INTERNET
.Desription
    Builds a Standalone DHCP, DNS and IIS Server to simulate the Internet.
    See http://blog.superuser.com/2011/05/16/windows-7-network-awareness/
    for details on how Windows computers detect Internet connectivity.
.Parameters:
###################################################################################################>

Configuration STANDALONE_INTERNET
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xDNSServer -ModuleVersion 1.16.0.0
    Import-DscResource -ModuleName xDHCPServer -ModuleVersion 2.0.0.0
    Import-DscResource -ModuleName xWebAdministration

    Node $AllNodes.NodeName {
        WindowsFeature WebServerInstall
        {
            Ensure = 'Present'
            Name   = 'Web-WebServer'
        }

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

        # Create the default ncsi.txt.
        File CAPolicy
        {
            Ensure          = 'Present'
            DestinationPath = 'c:\inetpub\wwwroot\ncsi.txt'
            Contents        = 'Microsoft NCSI'
            Type            = 'File'
            DependsOn       = '[WindowsFeature]WebServerInstall'
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
    }
}
