function Disconnect-LabVM
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [LabVM] $VM
    )

    [PSCredential] $AdminCredential = New-LabCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword

    # Get the Management IP Address of the VM
    $IPAddress = Get-LabVMManagementIPAddress `
        -Lab $Lab `
        -VM $VM

    try
    {
        # Look for the session
        $Session = Get-PSSession `
            -Name 'LabBuilder' `
            -ComputerName $IPAddress `
            -Credential $AdminCredential `
            -ErrorAction Stop

        if (-not $Session)
        {
            # No session found to this machine so nothing to do.
            Write-LabMessage -Message $($LocalizedData.VMSessionDoesNotExistMessage `
                -f $VM.Name)
        }
        else
        {
            if ($Session.State -eq 'Opened')
            {
                # Disconnect the session
                $null = $Session | Disconnect-PSSession
                Write-LabMessage -Message $($LocalizedData.DisconnectingVMMessage `
                    -f $VM.Name,$IPAddress)
            }
            # Remove the session
            $null = $Session | Remove-PSSession -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Throw $_
    }
    finally
    {
        # Remove the entry from TrustedHosts
        $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
        if (($TrustedHosts -like "*$IPAddress*") -and ($TrustedHosts -ne '*'))
        {
            $IPAddresses = @($TrustedHosts -split ',')
            $TrustedHosts = ($IPAddresses | Where-Object { $_ -ne $IPAddress }) -join ','
            Set-Item `
                -Path WSMAN::localhost\Client\TrustedHosts `
                -Value $TrustedHosts `
                -Force
            Write-LabMessage -Message $($LocalizedData.RemovingIPAddressFromTrustedHostsMessage `
                -f $VM.Name,$IPAddress)
        }
    } # try
} # Disconnect-LabVM
