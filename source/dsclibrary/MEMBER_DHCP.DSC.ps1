<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_DHCP
.Desription
    Builds a Server that is joined to a domain and then made into a DHCP Server.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    InstallRSATTools = $true
    Scopes = @(
        @{
            Name = 'Site A Primary'
            ScopeID = '192.168.128.0'
            Start = '192.168.128.50'
            End = '192.168.128.254'
            SubnetMask = '255.255.255.0'
            AddressFamily = 'IPv4'
        }
    )
    Reservations = @(
        @{
            Name = 'SA-DC1'
            ScopeID = '192.168.128.0'
            ClientMACAddress = '000000000000'
            IPAddress = '192.168.128.10'
            AddressFamily = 'IPv4'
        },
        @{
            Name = 'SA-DC2'
            ScopeID = '192.168.128.0'
            ClientMACAddress = '000000000001'
            IPAddress = '192.168.128.11'
            AddressFamily = 'IPv4'
        },
        @{
            Name = 'SA-DHCP1'
            ScopeID = '192.168.128.0'
            ClientMACAddress = '000000000002'
            IPAddress = '192.168.128.16'
            AddressFamily = 'IPv4'
        },
        @{
            Name = 'SA-EDGE1'
            ScopeID = '192.168.128.0'
            ClientMACAddress = '000000000005'
            IPAddress = '192.168.128.19'
            AddressFamily = 'IPv4'
        }
    )
    ScopeOptions = @(
        @{
            ScopeID = '192.168.128.0'
            DNServerIPAddress = @('192.168.128.10','192.168.128.11')
            Router = '192.168.128.19'
            AddressFamily = 'IPv4'
        }
    )
###################################################################################################>

Configuration MEMBER_DHCP
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName xDHCPServer -ModuleVersion 2.0.0.0

    Node $AllNodes.NodeName {
        # Assemble the Admin Credentials
        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature DHCPInstall
        {
            Ensure = 'Present'
            Name   = 'DHCP'
        }

        if ($InstallRSATTools)
        {
            WindowsFeature RSAT-ManagementTools
            {
                Ensure    = 'Present'
                Name      = 'RSAT-DHCP', 'RSAT-DNS-Server'
                DependsOn = '[WindowsFeature]DHCPInstall'
            }
        }

        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        Computer JoinDomain
        {
            Name       = $Node.NodeName
            DomainName = $Node.DomainName
            Credential = $DomainAdminCredential
            DependsOn  = '[WaitForAll]DC'
        }

        # DHCP Server Settings
        Script DHCPAuthorize
        {
            PSDSCRunAsCredential = $DomainAdminCredential
            SetScript            = {
                Add-DHCPServerInDC
            }
            GetScript            = {
                Return @{
                    'Authorized' = (@(Get-DHCPServerInDC | Where-Object { $_.IPAddress -In (Get-NetIPAddress).IPAddress }).Count -gt 0);
                }
            }
            TestScript           = {
                Return (-not (@(Get-DHCPServerInDC | Where-Object { $_.IPAddress -In (Get-NetIPAddress).IPAddress }).Count -eq 0))
            }
            DependsOn            = '[Computer]JoinDomain'
        }

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
            }
        }
    }
}
