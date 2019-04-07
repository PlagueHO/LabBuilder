function Connect-LabVM
{
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [LabVM] $VM,

        [Parameter(
            Position=2)]
        [System.Int32] $ConnectTimeout = 300
    )

    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [PSCredential] $AdminCredential = New-LabCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword
    [Boolean] $FatalException = $false

    while (($null -eq $Session) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $ConnectTimeout `
        -and -not $FatalException)
    {
        try
        {
            # Get the Management IP Address of the VM
            # We repeat this because the IP Address will only be assiged
            # once the VM is fully booted.
            $IPAddress = Get-LabVMManagementIPAddress `
                -Lab $Lab `
                -VM $VM

            # Add the IP Address to trusted hosts if not already in it
            # This could be avoided if able to use SSL or if PS Direct is used.
            # Also, don't add if TrustedHosts is already *
            $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
            if (($TrustedHosts -notlike "*$IPAddress*") -and ($TrustedHosts -ne '*'))
            {
                if ([System.String]::IsNullOrWhitespace($TrustedHosts))
                {
                    $TrustedHosts = $IPAddress
                }
                else
                {
                    $TrustedHosts = "$TrustedHosts,$IPAddress"
                }
                Set-Item `
                    -Path WSMAN::localhost\Client\TrustedHosts `
                    -Value $TrustedHosts `
                    -Force
                Write-LabMessage -Message $($LocalizedData.AddingIPAddressToTrustedHostsMessage `
                    -f $VM.Name,$IPAddress)
            }

            Write-LabMessage -Message $($LocalizedData.ConnectingVMMessage `
                -f $VM.Name,$IPAddress)

            $Session = New-PSSession `
                -Name 'LabBuilder' `
                -ComputerName $IPAddress `
                -Credential $AdminCredential `
                -ErrorAction Stop
        }
        catch
        {
            if (-not $IPAddress)
            {
                Write-LabMessage -Message $($LocalizedData.WaitingForIPAddressAssignedMessage `
                    -f $VM.Name,$Script:RetryConnectSeconds)
            }
            else
            {
                Write-LabMessage -Message $($LocalizedData.ConnectingVMFailedMessage `
                    -f $VM.Name,$Script:RetryConnectSeconds,$_.Exception.Message)
            }
            Start-Sleep -Seconds $Script:RetryConnectSeconds
        } # Try
    } # While

    # if a fatal exception occured or the connection just couldn't be established
    # then throw an exception so it can be caught by the calling code.
    if ($FatalException -or ($null -eq $Session))
    {
        # The connection failed so throw an error
        $exceptionParameters = @{
            errorId = 'RemotingConnectionError'
            errorCategory = 'ConnectionError'
            errorMessage = $($LocalizedData.RemotingConnectionError `
                -f $VM.Name)
        }
        New-LabException @exceptionParameters
    }
    Return $Session
} # Connect-LabVM
