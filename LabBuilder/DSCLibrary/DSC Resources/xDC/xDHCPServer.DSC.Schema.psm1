 Configuration DHCP
{
    Param
    (
        # Domain Admin Password
        [Parameter(Mandatory=$True)]
        [String]
        $DomainAdminPassword,
        
        # Local Admin Password
        [Parameter(Mandatory=$True)]
        [string]
        $LocalAdminPassword,
        
        # Domain Name
        [Parameter(Mandatory=$True)]
        [String]
        $DomainName,
        
        # Scope Options to add 
        [Parameter(AttributeValues)]
        [hashtable]
        $ScopeOptions,
        
        # Scopes to create
        [Parameter(AttributeValues)]
        [hashtable]
        $Scopes,
        
        # Scope Reservations
        [Parameter(AttributeValues)]
        [hashtable]
        $Reservations
        
        
    )
    
    
    
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName xDHCPServer

        # Assemble the Local Admin Credentials
        If ($LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force))
        }
        If ($DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$DomainName\Administrator", (ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature DHCPInstall 
        { 
            Ensure = "Present" 
            Name = "DHCP" 
        }


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
            DependsOn = '[WindowsFeature]DHCPInstall'
        }
        [Int]$Count=0
        Foreach ($Scope in $Scopes) {
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
            }
        }
        [Int]$Count=0
        Foreach ($Reservation in $Reservations) {
            $Count++
            xDhcpServerReservation "Reservation$Count"
            {
                Ensure = 'Present'
                ScopeID = $Reservation.ScopeId
                ClientMACAddress = $Reservation.ClientMACAddress
                IPAddress = $Reservation.IPAddress
                Name = $Reservation.Name
                AddressFamily = $Reservation.AddressFamily
            }
        }
        [Int]$Count=0
        Foreach ($ScopeOption in $ScopeOptions) {
            $Count++
            xDhcpServerOption "ScopeOption$Count"
            {
                Ensure = 'Present'
                ScopeID = $ScopeOption.ScopeId
                DnsDomain = $DomainName
                DnsServerIPAddress = $ScopeOption.DNServerIPAddress
                Router = $ScopeOption.Router
                AddressFamily = $ScopeOption.AddressFamily
            }
        }
}
