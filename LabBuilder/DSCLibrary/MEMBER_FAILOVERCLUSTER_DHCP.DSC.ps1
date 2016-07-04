<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_FAILOVERCLUSTER_DHCP
.Desription
    Builds a Network failover clustering node for use as a DHCP Server.
    It also optionally starts the iSCSI Initiator and connects to any specified iSCSI Targets.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $True
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
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName xDHCPServer
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature FailoverClusteringInstall
        {
            Ensure = "Present" 
            Name = "Failover-Clustering" 
        }

        WindowsFeature FailoverClusteringPSInstall
        {
            Ensure = "Present" 
            Name = "RSAT-Clustering-PowerShell" 
            DependsOn = "[WindowsFeature]FailoverClusteringInstall" 
        }

        WindowsFeature DHCPInstall 
        {
            Ensure = "Present" 
            Name = "DHCP" 
            DependsOn = "[WindowsFeature]FailoverClusteringPSInstall"
        }

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
        ResourceName      = '[xADDomain]PrimaryDC'
        NodeName          = $Node.DCname
        RetryIntervalSec  = 15
        RetryCount        = 60
        }
        
        # Join this Server to the Domain so that it can be an Enterprise CA.
        xComputer JoinDomain 
        { 
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential 
            DependsOn = "[WaitForAll]DC" 
        }

        if ($Node.ServerTargetName)
        {
            # Ensure the iSCSI Initiator service is running
            Service iSCSIService 
            { 
                Name = 'MSiSCSI'
                StartupType = 'Automatic'
                State = 'Running'
            }

            # Wait for the iSCSI Server Target to become available
            WaitForAny WaitForiSCSIServerTarget
            {
                ResourceName = "[ciSCSIServerTarget]ClusterServerTarget"
                NodeName = $Node.ServerName
                RetryIntervalSec = 30
                RetryCount = 30
                DependsOn = "[Service]iSCSIService"
            }

            # Connect the Initiator
            ciSCSIInitiator iSCSIInitiator
            {
                Ensure = 'Present'
                NodeAddress = "iqn.1991-05.com.microsoft:$($Node.ServerTargetName)"
                TargetPortalAddress = $Node.TargetPortalAddress
                InitiatorPortalAddress = $Node.InitiatorPortalAddress
                IsPersistent = $true 
                DependsOn = "[WaitForAny]WaitForiSCSIServerTarget" 
            } # End of ciSCSITarget Resource

            # Enable iSCSI FireWall rules so that the Initiator can be added to iSNS
            xFirewall iSCSIFirewallIn
            {
                Name = "MsiScsi-In-TCP"
                Ensure = 'Present'
                Enabled = 'True'
            }
            xFirewall iSCSIFirewallOut
            {
                Name = "MsiScsi-Out-TCP"
                Ensure = 'Present'
                Enabled = 'True'
            }
        }

        # DHCP Server Settings
        Script DHCPAuthorize
        {
            PSDSCRunAsCredential = $DomainAdminCredential
            SetScript = {
                Add-DHCPServerInDC
            }
            GetScript = {
                Return @{
                    'Authorized' = (@(Get-DHCPServerInDC | Where-Object { $_.IPAddress -In (Get-NetIPAddress).IPAddress }).Count -gt 0);
                }
            }
            TestScript = { 
                Return (-not (@(Get-DHCPServerInDC | Where-Object { $_.IPAddress -In (Get-NetIPAddress).IPAddress }).Count -eq 0))
            }
            DependsOn = '[xComputer]JoinDomain'
        }
        [Int]$Count=0
        Foreach ($Scope in $Node.Scopes) {
            $Count++
            xDhcpServerScope "Scope$Count"
            {
                Ensure        = 'Present'
                IPStartRange  = $Scope.Start
                IPEndRange    = $Scope.End
                Name          = $Scope.Name
                SubnetMask    = $Scope.SubnetMask
                State         = 'Active'
                LeaseDuration = '00:08:00'
                AddressFamily = $Scope.AddressFamily
            }
        }
        [Int]$Count=0
        Foreach ($Reservation in $Node.Reservations) {
            $Count++
            xDhcpServerReservation "Reservation$Count"
            {
                Ensure           = 'Present'
                ScopeID          = $Reservation.ScopeId
                ClientMACAddress = $Reservation.ClientMACAddress
                IPAddress        = $Reservation.IPAddress
                Name             = $Reservation.Name
                AddressFamily    = $Reservation.AddressFamily
            }
        }
        [Int]$Count=0
        Foreach ($ScopeOption in $Node.ScopeOptions) {
            $Count++
            xDhcpServerOption "ScopeOption$Count"
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
