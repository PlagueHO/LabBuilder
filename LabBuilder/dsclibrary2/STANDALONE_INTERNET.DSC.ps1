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
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xDNSServer
    Import-DscResource -ModuleName xDHCPServer
    Import-DscResource -ModuleName xWebAdministration
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }

        WindowsFeature WebServerInstall 
        {
            Ensure = "Present" 
            Name = "Web-WebServer" 
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

        # Create the default ncsi.txt.
        File CAPolicy
        {
            Ensure = 'Present'
            DestinationPath = 'c:\inetpub\wwwroot\ncsi.txt'
            Contents = "Microsoft NCSI"
            Type = 'File'
            DependsOn = '[WindowsFeature]WebServerInstall'
        }

        # Add the special DNS A records that Windows OS's use
        # to identify if the internet is available.
        # Can't be done yet because Resources are too limited.

        # Manually create the DHCP Groups

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
