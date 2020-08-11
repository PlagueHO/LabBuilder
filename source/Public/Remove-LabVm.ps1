function Remove-LabVM
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Name,

        [Parameter(
            Position=3)]
        [LabVM[]] $VMs,

        [Parameter(
            Position=4)]
        [Switch] $RemoveVMFolder
    )

    # if VMs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMs'))
    {
        $null = $PSBoundParameters.Remove('RemoveVMFolder')
        [LabVM[]] $VMs = Get-LabVM `
            @PSBoundParameters
    } # if

    $CurrentVMs = Get-VM

    # Get the LabPath
    [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    foreach ($VM in $VMs)
    {
        if ($Name -and ($VM.Name -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if

        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -ne 0)
        {
            # if the VM is running we need to shut it down.
            if ((Get-VM -Name $VM.Name).State -eq 'Running')
            {
                Write-LabMessage -Message $($LocalizedData.StoppingVMMessage `
                    -f $VM.Name)

                Stop-VM `
                    -Name $VM.Name
                # Wait for it to completely shut down and report that it is off.
                Wait-LabVMOff `
                    -VM $VM
            }

            Write-LabMessage -Message $($LocalizedData.RemovingVMMessage `
                -f $VM.Name)

            # Now delete the actual VM
            Get-VM `
                -Name $VM.Name | Remove-VM -Force -Confirm:$false

            Write-LabMessage -Message $($LocalizedData.RemovedVMMessage `
                -f $VM.Name)
        }
        else
        {
            Write-LabMessage -Message $($LocalizedData.VMNotFoundMessage `
                -f $VM.Name)
        }
    }
    # Should we remove the VM Folder?
    if ($RemoveVMFolder)
    {
        if (Test-Path -Path $VM.VMRootPath)
        {
            Write-LabMessage -Message $($LocalizedData.DeletingVMFolderMessage `
                -f $VM.Name)

            Remove-Item `
                -Path $VM.VMRootPath `
                -Recurse `
                -Force
        }
    }
} # Remove-LabVM
