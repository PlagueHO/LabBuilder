<#
    .SYNOPSIS
        Creates the folder structure that will contain a Lab Virtual Machine.

    .DESCRIPTION
        Creates a standard Hyper-V Virtual Machine folder structure as well as additional folders
        for containing configuration files for DSC.

    .PARAMETER vmpath
        The path to the folder where the Virtual Machine files are stored.

    .EXAMPLE
        Initialize-LabVMPath -VMPath 'c:\VMs\Lab\Virtual Machine 1'
        The command will create the Virtual Machine structure for a Lab VM in the folder:
        'c:\VMs\Lab\Virtual Machine 1'

    .OUTPUTS
        None.
#>
function Initialize-LabVMPath
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $VMPath
    )

    if (-not (Test-Path -Path $VMPath))
    {
        $null = New-Item `
            -Path $VMPath `
            -ItemType Directory
    } # if

    if (-not (Test-Path -Path "$VMPath\Virtual Machines"))
    {
        $null = New-Item `
            -Path "$VMPath\Virtual Machines" `
            -ItemType Directory
    } # if

    if (-not (Test-Path -Path "$VMPath\Virtual Hard Disks"))
    {
        $null = New-Item `
        -Path "$VMPath\Virtual Hard Disks" `
        -ItemType Directory
    } # if

    if (-not (Test-Path -Path "$VMPath\LabBuilder Files"))
    {
        $null = New-Item `
            -Path "$VMPath\LabBuilder Files" `
            -ItemType Directory
    } # if

    if (-not (Test-Path -Path "$VMPath\LabBuilder Files\DSC Modules"))
    {
        $null = New-Item `
            -Path "$VMPath\LabBuilder Files\DSC Modules" `
            -ItemType Directory
    } # if
}
