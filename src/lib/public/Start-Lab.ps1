function Start-Lab
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
        $Lab,

        [Parameter(
            Position=4)]
        [System.Int32] $StartupTimeout = $Script:StartupTimeout
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('StartupTimeout')

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

        # Get the bootorders by lowest first and ignoring 0 and call
        $BootOrders = @( ($VMs |
            Where-Object -FilterScript { ($_.Bootorder -gt 0) } ).Bootorder )
        $BootPhases = @( ($Bootorders |
            Sort-Object -Unique) )

        # Step through each of these "Bootphases" waiting for them to complete
        foreach ($BootPhase in $BootPhases)
        {
            # Process this "Bootphase"
            Write-LabMessage -Message $($LocalizedData.StartingBootPhaseVMsMessage `
                -f $BootPhase)

            # Get all VMs in this "Bootphase"
            $BootVMs = @( $VMs |
                Where-Object -FilterScript { ($_.BootOrder -eq $BootPhase) } )

            [DateTime] $StartPhase = Get-Date
            [boolean] $PhaseComplete = $false
            [boolean] $PhaseAllBooted = $true
            [System.Int32] $VMCount = $BootVMs.Count
            [System.Int32] $VMNumber = 0

            # Loop through all the VMs in this "Bootphase" repeatedly
            # until timeout occurs or PhaseComplete is marked as complete
            while (-not $PhaseComplete `
                -and ((Get-Date) -lt $StartPhase.AddSeconds($StartupTimeout)))
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

                # Start the VM if it is off
                if ($VMObject.State -eq 'Off')
                {
                    Write-LabMessage -Message $($LocalizedData.StartingVMMessage `
                        -f $VMName)
                    Start-VM `
                        -VM $VMObject
                } # if

                # Use the allocation of a Management IP Address as an indicator
                # the machine has booted
                $ManagementIP = Get-LabVMManagementIPAddress `
                    -Lab $Lab `
                    -VM $VM `
                    -ErrorAction SilentlyContinue
                if (-not ($ManagementIP))
                {
                    # It has not booted
                    $PhaseAllBooted = $false
                } # if
                $VMNumber++
                if ($VMNumber -eq $VMCount)
                {
                    # We have stepped through all VMs in this Phase so check
                    # if all have booted, otherwise reset the loop.
                    if ($PhaseAllBooted)
                    {
                        # if we have gone through all VMs in this "Bootphase"
                        # and they're all marked as booted then we can mark
                        # this phase as complete and allow moving on to the next one
                        Write-LabMessage -Message $($LocalizedData.AllBootPhaseVMsStartedMessage `
                            -f $BootPhase)
                        $PhaseComplete = $true
                    }
                    else
                    {
                        $PhaseAllBooted = $true
                    } # if
                    # Reset the VM Loop
                    $VMNumber = 0
                } # if
            } # while

            # Did we timeout?
            if (-not ($PhaseComplete))
            {
                # Yes, throw an exception
                $exceptionParameters = @{
                    errorId = 'BootPhaseVMsTimeoutError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.BootPhaseStartVMsTimeoutError `
                        -f $BootPhase)

                }
                New-LabException @exceptionParameters
            } # if
        } # foreach

        Write-LabMessage -Message $($LocalizedData.LabStartCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.fullconfigpath)
    } # process

    end
    {
    } # end
} # Start-Lab
