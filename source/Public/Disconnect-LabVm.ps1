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

    $adminCredential = New-LabCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword

    # Get the Management IP Address of the VM
    $ipAddress = Get-LabVMManagementIPAddress `
        -Lab $Lab `
        -VM $VM

    try
    {
        # Look for the session
        $session = Get-PSSession `
            -Name 'LabBuilder' `
            -ComputerName $ipAddress `
            -Credential $adminCredential `
            -ErrorAction Stop

        if (-not $session)
        {
            # No session found to this machine so nothing to do.
            Write-LabMessage -Message $($LocalizedData.VMSessionDoesNotExistMessage `
                -f $VM.Name)
        }
        else
        {
            if ($session.State -eq 'Opened')
            {
                # Disconnect the session
                $null = $session | Disconnect-PSSession
                Write-LabMessage -Message $($LocalizedData.DisconnectingVMMessage `
                    -f $VM.Name,$IPAddress)
            }
            # Remove the session
            $null = $session | Remove-PSSession -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Throw $_
    }
    finally
    {
        # Remove the entry from TrustedHosts
        $trustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value

        if (($trustedHosts -like "*$ipAddress*") -and ($trustedHosts -ne '*'))
        {
            $ipAddresses = @($trustedHosts -split ',')
            $trustedHosts = ($ipAddresses | Where-Object -FilterScript {
                $_ -ne $ipAddress
            }) -join ','

            Set-Item `
                -Path WSMAN::localhost\Client\TrustedHosts `
                -Value $trustedHosts `
                -Force
            Write-LabMessage -Message $($LocalizedData.RemovingIPAddressFromTrustedHostsMessage `
                -f $VM.Name,$ipAddress)
        }
    } # try
} # Disconnect-LabVM
