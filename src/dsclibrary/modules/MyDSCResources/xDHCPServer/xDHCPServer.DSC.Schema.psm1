Configuration DHCP
{
    Param
    (
        # Domain Admin Password
        [Parameter(Mandatory = $true)]
        [System.String]
        $DomainAdminPassword,

        # Local Admin Password
        [Parameter(Mandatory = $true)]
        [System.String]
        $LocalAdminPassword,

        # Domain Name
        [Parameter(Mandatory = $true)]
        [System.String]
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

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xDHCPServer -ModuleVersion 2.0.0.0

    # Assemble the Local Admin Credentials
    if ($LocalAdminPassword)
    {
        [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force))
    }
    if ($DomainAdminPassword)
    {
        [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$DomainName\Administrator", (ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force))
    }

    WindowsFeature DHCPInstall
    {
        Ensure = "Present"
        Name   = "DHCP"
    }

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
        DependsOn            = '[WindowsFeature]DHCPInstall'
    }

    $count = 0
    foreach ($Scope in $Scopes)
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
    foreach ($Reservation in $Reservations)
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
    foreach ($ScopeOption in $ScopeOptions)
    {
        $count++
        xDhcpServerOption "ScopeOption$count"
        {
            Ensure             = 'Present'
            ScopeID            = $ScopeOption.ScopeId
            DnsDomain          = $DomainName
            DnsServerIPAddress = $ScopeOption.DNServerIPAddress
            Router             = $ScopeOption.Router
            AddressFamily      = $ScopeOption.AddressFamily
        }
    }
}
