function Uninstall-Lab
{
    [CmdLetBinding(DefaultParameterSetName="Lab",
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]
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
        [Switch] $RemoveSwitch,

        [Parameter(
            Position=5)]
        [Switch] $RemoveVMTemplate,

        [Parameter(
            Position=6)]
        [Switch] $RemoveVMFolder,

        [Parameter(
            Position=7)]
        [Switch] $RemoveVMTemplateVHD,

        [Parameter(
            Position=8)]
        [Switch] $RemoveLabFolder
    ) # Param

    begin
    {
        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('RemoveSwitch')
        $null = $PSBoundParameters.Remove('RemoveVMTemplate')
        $null = $PSBoundParameters.Remove('RemoveVMFolder')
        $null = $PSBoundParameters.Remove('RemoveVMTemplateVHD')
        $null = $PSBoundParameters.Remove('RemoveLabFolder')

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters
        } # if
    } # begin

    process
    {
        if ($PSCmdlet.ShouldProcess( 'LocalHost', `
            ($LocalizedData.ShouldUninstallLab `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
        {
            # Remove the VMs
            $VMSplat = @{}
            if ($RemoveVMFolder)
            {
                $VMSplat += @{ RemoveVMFolder = $true }
            } # if
            $null = Remove-LabVM `
                -Lab $Lab `
                @VMSplat

            # Remove the VM Templates
            if ($RemoveVMTemplate)
            {
                if ($PSCmdlet.ShouldProcess( 'LocalHost', `
                    ($LocalizedData.ShouldRemoveVMTemplate `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabVMTemplate `
                        -Lab $Lab
                } # if
            } # if

            # Remove the VM Switches
            if ($RemoveSwitch)
            {
                if ($PSCmdlet.ShouldProcess( 'LocalHost', `
                    ($LocalizedData.ShouldRemoveSwitch `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabSwitch `
                        -Lab $Lab
                } # if
            } # if

            # Remove the VM Template VHDs
            if ($RemoveVMTemplateVHD)
            {
                if ($PSCmdlet.ShouldProcess( 'LocalHost', `
                    ($LocalizedData.ShouldRemoveVMTemplateVHD `
                    -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                {
                    $null = Remove-LabVMTemplateVHD `
                        -Lab $Lab
                } # if
            } # if

            # Remove the Lab Folder
            if ($RemoveLabFolder)
            {
                if (Test-Path -Path $Lab.labbuilderconfig.settings.labpath)
                {
                    if ($PSCmdlet.ShouldProcess( 'LocalHost', `
                        ($LocalizedData.ShouldRemoveLabFolder `
                        -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )))
                    {
                        Remove-Item `
                            -Path $Lab.labbuilderconfig.settings.labpath `
                            -Recurse `
                            -Force
                    } # if
                } # if
            } # if

            # Remove the LabBuilder Management Network switch
            [System.String] $ManagementSwitchName = Get-LabManagementSwitchName `
                -Lab $Lab
            if ((Get-VMSwitch | Where-Object -Property Name -eq $ManagementSwitchName).Count -ne 0)
            {
                $null = Remove-VMSwitch `
                    -Name $ManagementSwitchName

                Write-LabMessage -Message $($LocalizedData.RemovingLabManagementSwitchMessage `
                    -f $ManagementSwitchName)
            }

            Write-LabMessage -Message $($LocalizedData.LabUninstallCompleteMessage `
                -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath )
        } # if
    } # process

    end
    {
    } # end
} # Uninstall-Lab
