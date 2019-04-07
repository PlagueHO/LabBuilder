<#
    .SYNOPSIS
        Updates the VM DVD Drives to match the VM Configuration.

    .DESCRIPTION
        This cmdlet will take the VM configuration provided and ensure that the DVD Drives are
        attached to the VM and with the specified ISO.

        The function will use the array of items in the DVDDrives property of the VM to create and
        attach any DVD Drives that are missing.

        If an ISO File is specified in the DVD Drive then it will be mounted to the DVD Drive.

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Update-LabVMDvdDrive -Lab $Lab -VM VM[0]
        This will update the DVD Drives for the first VM in the configuration file c:\mylab\config.xml.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .OUTPUTS
        None.
#>
function Update-LabVMDvdDrive
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Mandatory,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Mandatory,
            Position=1)]
        [ValidateNotNullOrEmpty()]
        [LabVM]
        $VM
    )

    # If there are no DVD Drives just return
    if (-not $VM.DVDDrives)
    {
        return
    }

    [System.Int32] $DVDDriveCount = 0
    foreach ($DVDDrive in @($VM.DVDDrives))
    {
        # Get a list of DVD Drives attached to the VM
        $VMDVDDrives = @(Get-VMDVDDrive `
            -VMName $VM.Name)

        # The DVD Drive will now exist so ensure it is attached
        if ($VMDVDDrives[$DVDDriveCount])
        {
            # The DVD Drive is already attached then make sure the correct ISO
            if ($VMDVDDrives[$DVDDriveCount].Path -ne $DVDDrive.Path)
            {
                if ($DVDDrive.Path)
                {
                    Write-LabMessage -Message $($LocalizedData.MountingVMDVDDriveISOMessage `
                        -f $VM.Name,$DVDDrive.Path)
                }
                else
                {
                    Write-LabMessage -Message $($LocalizedData.DismountingVMDVDDriveISOMessage `
                        -f $VM.Name,$VMDVDDrives[$DVDDriveCount].Path)
                } # if
                Set-VMDVDDrive `
                    -VMName $VM.Name `
                    -ControllerNumber $VMDVDDrives[$DVDDriveCount].ControllerNumber `
                    -ControllerLocation $VMDVDDrives[$DVDDriveCount].ControllerLocation `
                    -Path $DVDDrive.Path
            } # if
        }
        else
        {
            # The DVD Drive does not exist
            Write-LabMessage -Message $($LocalizedData.AddingVMDVDDriveMessage `
                -f $VM.Name)

            $NewDVDDriveParams = @{
                VMName = $VM.Name
                ErrorAction = 'Stop'
            }

            if ($DVDDrive.Path)
            {
                Write-LabMessage -Message $($LocalizedData.MountingVMDVDDriveISOMessage `
                    -f $VM.Name,$DVDDrive.Path)

                $NewDVDDriveParams += @{
                    Path = $DVDDrive.Path
                }
            } # if
            $null = Add-VMDVDDrive @NewDVDDriveParams
        } # if
        $DVDDriveCount++
    } # foreach
}
