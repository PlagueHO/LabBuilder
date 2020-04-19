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
        $vms = Get-LabVM `
            -Lab $Lab

        # Get the bootorders by highest first and ignoring 0
        $bootOrders = @( ($vms |
            Where-Object -FilterScript { ($_.Bootorder -gt 0) } ).Bootorder )
        $bootPhases = @( ($bootOrders | Sort-Object -Unique -Descending) )

        # Step through each of these "Bootphases" waiting for them to complete
        foreach ($bootPhase in $bootPhases)
        {
            # Process this "Bootphase"
            Write-LabMessage -Message $($LocalizedData.StoppingBootPhaseVMsMessage `
                -f $bootPhase)

            # Get all VMs in this "Bootphase"
            $bootVMs = @( $vms |
                Where-Object -FilterScript { ($_.BootOrder -eq $bootPhase) } )

            $phaseComplete = $false
            $phaseAllStopped = $true
            $vmCount = $bootVMs.Count
            $vmNumber = 0

            # Loop through all the VMs in this "Bootphase" repeatedly
            while (-not $phaseComplete)
            {
                # Get the VM to boot/check
                $VM = $bootVMs[$vmNumber]
                $vmName = $VM.Name

                # Get the actual Hyper-V VM object
                $vmObject = Get-VM `
                    -Name $vmName `
                    -ErrorAction SilentlyContinue

                if (-not $vmObject)
                {
                    # if the VM does not exist then throw a non-terminating exception
                    $exceptionParameters = @{
                        errorId = 'VMDoesNotExistError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDoesNotExistError `
                            -f $vmName)

                    }
                    New-LabException @exceptionParameters
                } # if

                # Shutodwn the VM if it is off
                if ($vmObject.State -eq 'Running')
                {
                    Write-LabMessage -Message $($LocalizedData.StoppingVMMessage `
                        -f $VMName)
                    $null = Stop-VM `
                        -VM $vmObject `
                        -Force `
                        -ErrorAction Continue
                } # if

                # Determine if the VM has stopped.
                if ($vmObject -and (Get-VM -VMName $vmName).State -ne 'Off')
                {
                    # It has not stopped
                    $phaseAllStopped = $false
                } # if

                $vmNumber++

                if ($vmNumber -eq $vmCount)
                {
                    <#
                        We have stepped through all VMs in this Phase so check
                        if all have stopped, otherwise reset the loop.
                    #>
                    if ($phaseAllStopped)
                    {
                        <#
                            if we have gone through all VMs in this "Bootphase"
                            and they're all marked as stopped then we can mark
                            this phase as complete and allow moving on to the next one
                        #>
                        Write-LabMessage -Message $($LocalizedData.AllBootPhaseVMsStoppedMessage `
                            -f $bootPhase)
                        $phaseComplete = $true
                    }
                    else
                    {
                        $phaseAllStopped = $true
                    } # if

                    # Reset the VM Loop
                    $vmNumber = 0
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
