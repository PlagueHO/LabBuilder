<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FAILOVERCLUSTER_DHCP
.Desription
    Builds a Network failover clustering node for use as a DHCP Server.
    It also optionally starts the iSCSI Initiator and connects to any specified iSCSI Targets.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    ISCSIServerName = 'SA-FS1'
    ServerTargetName = 'sa-foc-target'
    TargetPortalAddress = '192.168.129.24'
    InitiatorPortalAddress = '192.168.129.28'
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
###################################################################################################>

Configuration MEMBER_FAILOVERCLUSTER_FS
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName xDHCPServer -ModuleVersion 2.0.0.0

    Node $AllNodes.NodeName {
        # Assemble the Admin Credentials
        if ($Node.DomainAdminPassword)
        {
            $DomainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature FailoverClusteringInstall
        {
            Ensure = 'Present'
            Name   = 'Failover-Clustering'
        }

        WindowsFeature FailoverClusteringPSInstall
        {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-PowerShell'
            DependsOn = '[WindowsFeature]FailoverClusteringInstall'
        }

        WindowsFeature DHCPInstall
        {
            Ensure    = 'Present'
            Name      = 'DHCP'
            DependsOn = '[WindowsFeature]FailoverClusteringPSInstall'
        }

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        # Join this Server to the Domain so that it can be an Enterprise CA.
        Computer JoinDomain
        {
            Name       = $Node.NodeName
            DomainName = $Node.DomainName
            Credential = $DomainAdminCredential
            DependsOn  = '[WaitForAll]DC'
        }

        if ($Node.ServerTargetName)
        {
            # Ensure the iSCSI Initiator service is running
            Service iSCSIService
            {
                Name        = 'MSiSCSI'
                StartupType = 'Automatic'
                State       = 'Running'
            }

            # Wait for the iSCSI Server Target to become available
            WaitForAny WaitForiSCSIServerTarget
            {
                ResourceName     = '[ISCSIServerTarget]ClusterServerTarget'
                NodeName         = $Node.ServerName
                RetryIntervalSec = 30
                RetryCount       = 30
                DependsOn        = '[Service]iSCSIService'
            }

            # Connect the Initiator
            ISCSIInitiator iSCSIInitiator
            {
                Ensure                 = 'Present'
                NodeAddress            = "iqn.1991-05.com.microsoft:$($Node.ServerTargetName)"
                TargetPortalAddress    = $Node.TargetPortalAddress
                InitiatorPortalAddress = $Node.InitiatorPortalAddress
                IsPersistent           = $true
                DependsOn              = '[WaitForAny]WaitForiSCSIServerTarget'
            } # End of ISCSITarget Resource

            # Enable iSCSI FireWall rules so that the Initiator can be added to iSNS
            Firewall iSCSIFirewallIn
            {
                Name    = 'MsiScsi-In-TCP'
                Ensure  = 'Present'
                Enabled = 'True'
            }
            Firewall iSCSIFirewallOut
            {
                Name    = 'MsiScsi-Out-TCP'
                Ensure  = 'Present'
                Enabled = 'True'
            }
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
