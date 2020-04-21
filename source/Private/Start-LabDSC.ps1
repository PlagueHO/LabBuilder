<#
    .SYNOPSIS
        Uploads prepared Modules and MOF files to a VM and starts up Desired State
        Configuration (DSC) on it.

    .DESCRIPTION
        This function will perform the following tasks:
            1. Connect to the VM via remoting.
            2. Upload the DSC and LCM MOF files to the c:\windows\setup\scripts folder of the VM.
            3. Upload DSC Start up scripts to the c:\windows\setup\scripts folder of the VM.
            4. Upload all required modules to the c:\program files\WindowsPowerShell\Modules\ folder
                of the VM.
            5. Invoke the StartDSC.ps1 script on the VM to start DSC processing.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM.

    .PARAMETER Timeout
        The maximum amount of time that this function can take to perform DSC start-up.
        If the timeout is reached before the process is complete an error will be thrown.
        The timeout defaults to 300 seconds.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Start-LabDSC -Lab $Lab -VM $VMs[0]
        Starts up Desired State Configuration for the first VM in the Lab c:\mylab\config.xml.

    .OUTPUTS
        None.
#>
function Start-LabDSC
{
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM,

        [Parameter()]
        [System.Int32]
        $Timeout = 300
    )

    $startTime = Get-Date
    $session = $null
    $complete = $false
    $configCopyComplete = $false
    $moduleCopyComplete = $false

    # Get Path to LabBuilder files
    $vmLabBuilderFiles = $VM.LabBuilderFilesPath

    While ((-not $complete) `
            -and (((Get-Date) - $startTime).TotalSeconds) -lt $TimeOut)
    {
        # Connect to the VM
        $session = Connect-LabVM `
            -VM $VM `
            -ErrorAction Continue

        # Failed to connnect to the VM
        if (-not $session)
        {
            $exceptionParameters = @{
                errorId       = 'DSCInitializationError'
                errorCategory = 'OperationTimeout'
                errorMessage  = $($LocalizedData.DSCInitializationError `
                        -f $VM.Name)
            }
            New-LabException @exceptionParameters

            return
        }

        if (($session) `
                -and ($session.State -eq 'Opened') `
                -and (-not $configCopyComplete))
        {
            $copyParameters = @{
                Destination = 'c:\Windows\Setup\Scripts'
                ToSession   = $session
                Force       = $true
                ErrorAction = 'Stop'
            }

            # Connection has been made OK, upload the DSC files
            While ((-not $configCopyComplete) `
                    -and (((Get-Date) - $startTime).TotalSeconds) -lt $TimeOut)
            {
                Try
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMMessage `
                            -f $VM.Name, 'DSC')

                    $null = Copy-Item `
                        @copyParameters `
                        -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath "$($VM.ComputerName).mof")

                    if (Test-Path `
                            -Path "$vmLabBuilderFiles\$($VM.ComputerName).meta.mof")
                    {
                        $null = Copy-Item `
                            @copyParameters `
                            -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath "$($VM.ComputerName).meta.mof")
                    } # If

                    $null = Copy-Item `
                        @copyParameters `
                        -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath 'StartDSC.ps1')

                    $null = Copy-Item `
                        @copyParameters `
                        -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath 'StartDSCDebug.ps1')

                    $configCopyComplete = $true
                }
                catch
                {
                    Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMFailedMessage `
                            -f $VM.Name, 'DSC', $script:RetryConnectSeconds)

                    Start-Sleep -Seconds $script:RetryConnectSeconds
                } # try
            } # while
        } # if

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $configCopyComplete) `
                -and (((Get-Date) - $startTime).TotalSeconds) -ge $TimeOut)
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $exceptionParameters = @{
                errorId       = 'DSCInitializationError'
                errorCategory = 'OperationTimeout'
                errorMessage  = $($LocalizedData.DSCInitializationError `
                        -f $VM.Name)
            }
            New-LabException @exceptionParameters
        } # if

        # Upload any required modules to the VM
        if (($session) `
                -and ($session.State -eq 'Opened') `
                -and (-not $moduleCopyComplete))
        {
            $dscContent = Get-Content `
                -Path $($VM.DSC.ConfigFile) `
                -Raw
            [LabDSCModule[]] $dscModules = Get-LabModulesInDSCConfig -DSCConfigContent $dscContent

            # Add the NetworkingDsc DSC Resource because it is always used
            $module = [LabDSCModule]::New('NetworkingDsc')
            $dscModules += @( $module )

            foreach ($dscModule in $dscModules)
            {
                $moduleName = $dscModule.ModuleName

                # Upload all but PSDesiredStateConfiguration because it
                # should always exist on client node.
                if ($moduleName -ne 'PSDesiredStateConfiguration')
                {
                    try
                    {
                        Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMMessage `
                                -f $VM.Name, "DSC Module $moduleName")

                        $null = Copy-Item `
                            -Path (Join-Path -Path $vmLabBuilderFiles -ChildPath "DSC Modules\$moduleName\") `
                            -Destination "$($env:ProgramFiles)\WindowsPowerShell\Modules\" `
                            -ToSession $session `
                            -Force `
                            -Recurse `
                            -ErrorAction Stop
                    }
                    catch
                    {
                        Write-LabMessage -Message $($LocalizedData.CopyingFilesToVMFailedMessage `
                                -f $VM.Name, "DSC Module $moduleName", $script:RetryConnectSeconds)

                        Start-Sleep -Seconds $script:RetryConnectSeconds
                    } # try
                } # if
            } # foreach

            $moduleCopyComplete = $true
        } # if

        # If the copy didn't complete and we're out of time throw an exception
        if ((-not $moduleCopyComplete) `
                -and (((Get-Date) - $startTime).TotalSeconds) -ge $TimeOut)
        {
            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $exceptionParameters = @{
                errorId       = 'DSCInitializationError'
                errorCategory = 'OperationTimeout'
                errorMessage  = $($LocalizedData.DSCInitializationError `
                        -f $VM.Name)
            }
            New-LabException @exceptionParameters
        } # if

        # Finally, Start DSC up!
        if (($session) `
                -and ($session.State -eq 'Opened') `
                -and ($configCopyComplete) `
                -and ($moduleCopyComplete))
        {
            Write-LabMessage -Message $($LocalizedData.StartingDSCMessage `
                    -f $VM.Name)

            Invoke-Command -Session $session {
                c:\windows\setup\scripts\StartDSC.ps1
            }

            # Disconnect from the VM
            Disconnect-LabVM `
                -VM $VM `
                -ErrorAction Continue

            $complete = $true
        } # if
    } # while
}
