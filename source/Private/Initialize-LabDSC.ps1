<#
    .SYNOPSIS
        This function prepares all files require to configure a VM using Desired State
        Configuration (DSC).

    .DESCRIPTION
        Calling this function will cause the LabBuilder folder to be populated/updated
        with all files required to configure a Virtual Machine with DSC.
        This includes:
            1. Required DSC Resouce Modules.
            2. DSC Credential Encryption certificate.
            3. DSC Configuration files.
            4. DSC MOF Files for general config and for LCM config.
            5. Start up scripts.

    .PARAMETER Lab
        Contains the Lab object that was produced by the Get-Lab cmdlet.

    .PARAMETER VM
        A LabVM object pulled from the Lab Configuration file using Get-LabVM

    .EXAMPLE
        $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
        $VMs = Get-LabVM -Lab $Lab
        Initialize-LabDSC -Lab $Lab -VM $VMs[0]
        Prepares all files required to start up Desired State Configuration for the
        first VM in the Lab c:\mylab\config.xml for DSC start up.

    .OUTPUTS
        None.
#>
function Initialize-LabDSC
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Lab,

        [Parameter(Mandatory = $true)]
        [LabVM]
        $VM
    )

    # Are there any DSC Settings to manage?
    Update-LabDSC -Lab $Lab -VM $VM

    # Generate the DSC Start up Script file
    Set-LabDSC -Lab $Lab -VM $VM
}
