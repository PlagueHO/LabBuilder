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
        [System.String] $labPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $lab,

        [Parameter(
            Position=4)]
        [System.Int32] $StartupTimeout = $script:StartupTimeout
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('StartupTimeout')

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $lab = Get-Lab @PSBoundParameters
        } # if
    } # begin

    process
    {
        # Get the VMs
        $vms = Get-LabVM `
            -Lab $lab

        # Get the bootorders by lowest first and ignoring 0 and call
        $bootOrders = @( ($vms |
            Where-Object -FilterScript { ($_.Bootorder -gt 0) } ).Bootorder )
        $bootPhases = @( ($bootOrders | Sort-Object -Unique) )

        # Step through each of these "Bootphases" waiting for them to complete
        foreach ($bootPhase in $bootPhases)
        {
            # Process this "Bootphase"
            Write-LabMessage -Message $($LocalizedData.StartingBootPhaseVMsMessage `
                -f $bootPhase)

            # Get all VMs in this "Bootphase"
            $bootVMs = @( $vms | Where-Object -FilterScript { ($_.BootOrder -eq $bootPhase) } )

            $startPhase = Get-Date
            $phaseComplete = $false
            $phaseAllBooted = $true
            $vmCount = $bootVMs.Count
            $vmNumber = 0

            <#
                Loop through all the VMs in this "Bootphase" repeatedly
                until timeout occurs or PhaseComplete is marked as complete
            #>
            while (-not $phaseComplete `
                -and ((Get-Date) -lt $startPhase.AddSeconds($StartupTimeout)))
            {
                # Get the VM to boot/check
                $vm = $bootVMs[$vmNumber]
                $vmName = $vm.Name

                # Get the actual Hyper-V VM object
                $vmObject = Get-VM `
                    -Name $vmName `
                    -ErrorAction SilentlyContinue

                if ($vmObject)
                {
                    # Start the VM if it is off
                    if ($vmObject.State -eq 'Off')
                    {
                        Write-LabMessage -Message $($LocalizedData.StartingVMMessage -f $vmName)
                        Start-VM -VM $vmObject
                    } # if

                    <#
                        Use the allocation of a Management IP Address as an indicator
                        the machine has booted
                    #>
                    $managementIP = Get-LabVMManagementIPAddress `
                        -Lab $lab `
                        -VM $vm `
                        -ErrorAction SilentlyContinue

                    if (-not ($managementIP))
                    {
                        # It has not booted
                        $phaseAllBooted = $false
                    } # if
                }
                else
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

                $vmNumber++

                if ($vmNumber -eq $vmCount)
                {
                    <#
                        We have stepped through all VMs in this Phase so check
                        if all have booted, otherwise reset the loop.
                    #>
                    if ($phaseAllBooted)
                    {
                        <#
                            If we have gone through all VMs in this "Bootphase"
                            and they're all marked as booted then we can mark
                            this phase as complete and allow moving on to the next one
                        #>
                        Write-LabMessage -Message $($LocalizedData.AllBootPhaseVMsStartedMessage -f $bootPhase)
                        $phaseComplete = $true
                    }
                    else
                    {
                        $phaseAllBooted = $true
                    } # if

                    # Reset the VM Loop
                    $vmNumber = 0
                } # if
            } # while

            # Did we timeout?
            if (-not ($phaseComplete))
            {
                # Yes, throw an exception
                $exceptionParameters = @{
                    errorId = 'BootPhaseVMsTimeoutError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.BootPhaseStartVMsTimeoutError `
                        -f $bootPhase)

                }
                New-LabException @exceptionParameters
            } # if
        } # foreach

        Write-LabMessage -Message $($LocalizedData.LabStartCompleteMessage `
            -f $lab.labbuilderconfig.name,$lab.labbuilderconfig.settings.fullconfigpath)
    } # process

    end
    {
    } # end
} # Start-Lab
