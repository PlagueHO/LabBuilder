function Stop-Lab
{
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [System.String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters
        } # if
    } # begin

    process
    {
        # Get the VMs
        $VMs = Get-LabVM `
            -Lab $Lab

        # Get the bootorders by highest first and ignoring 0
        $BootOrders = @( ($VMs |
            Where-Object -FilterScript { ($_.Bootorder -gt 0) } ).Bootorder )
        $BootPhases = @( ($Bootorders |
            Sort-Object -Unique -Descending) )

        # Step through each of these "Bootphases" waiting for them to complete
        foreach ($BootPhase in $BootPhases)
        {
            # Process this "Bootphase"
            Write-LabMessage -Message $($LocalizedData.StoppingBootPhaseVMsMessage `
                -f $BootPhase)

            # Get all VMs in this "Bootphase"
            $BootVMs = @( $VMs |
                Where-Object -FilterScript { ($_.BootOrder -eq $BootPhase) } )

            [DateTime] $StartPhase = Get-Date
            [boolean] $PhaseComplete = $false
            [boolean] $PhaseAllStopped = $true
            [System.Int32] $VMCount = $BootVMs.Count
            [System.Int32] $VMNumber = 0

            # Loop through all the VMs in this "Bootphase" repeatedly
            while (-not $PhaseComplete)
            {
                # Get the VM to boot/check
                $VM = $BootVMs[$VMNumber]
                $VMName = $VM.Name

                # Get the actual Hyper-V VM object
                $VMObject = Get-VM `
                    -Name $VMName `
                    -ErrorAction SilentlyContinue
                if (-not $VMObject)
                {
                    # if the VM does not exist then throw a non-terminating exception
                    $exceptionParameters = @{
                        errorId = 'VMDoesNotExistError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDoesNotExistError `
                            -f $VMName)

                    }
                    New-LabException @exceptionParameters
                } # if

                # Shutodwn the VM if it is off
                if ($VMObject.State -eq 'Running')
                {
                    Write-LabMessage -Message $($LocalizedData.StoppingVMMessage `
                        -f $VMName)
                    $null = Stop-VM `
                        -VM $VMObject `
                        -Force `
                        -ErrorAction Continue
                } # if

                # Determine if the VM has stopped.
                if ((Get-VM -VMName $VMName).State -ne 'Off')
                {
                    # It has not stopped
                    $PhaseAllStopped = $false
                } # if
                $VMNumber++
                if ($VMNumber -eq $VMCount)
                {
                    # We have stepped through all VMs in this Phase so check
                    # if all have stopped, otherwise reset the loop.
                    if ($PhaseAllStopped)
                    {
                        # if we have gone through all VMs in this "Bootphase"
                        # and they're all marked as stopped then we can mark
                        # this phase as complete and allow moving on to the next one
                        Write-LabMessage -Message $($LocalizedData.AllBootPhaseVMsStoppedMessage `
                            -f $BootPhase)
                        $PhaseComplete = $true
                    }
                    else
                    {
                        $PhaseAllStopped = $true
                    } # if
                    # Reset the VM Loop
                    $VMNumber = 0
                } # if
            } # while
        } # foreach

        Write-LabMessage -Message $($LocalizedData.LabStopCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)
    } # process

    end
    {
    } # end
} # Stop-Lab
