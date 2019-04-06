function Install-Lab
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
        [Switch] $CheckEnvironment,

        [Parameter(
            Position=5)]
        [Switch] $Force,

        [Parameter(
            Position=6)]
        [Switch] $OffLine

    ) # Param

    begin
    {
        # Create a splat array containing force if it is set
        $ForceSplat = @{}

        if ($PSBoundParameters.ContainsKey('Force'))
        {
            $ForceSplat = @{ Force = $true }
        } # if

        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('CheckEnvironment')
        $null = $PSBoundParameters.Remove('Force')

        if ($CheckEnvironment)
        {
            # Check Hyper-V
            Install-LabHyperV `
                -ErrorAction Stop
        } # if

        # Ensure WS-Man is enabled
        Enable-LabWSMan `
            @ForceSplat `
            -ErrorAction Stop

        if (!($PSBoundParameters.ContainsKey('OffLine')))
        {
        # Install Package Providers
        Install-LabPackageProvider `
            @ForceSplat `
            -ErrorAction Stop

        # Register Package Sources
        Register-LabPackageSource `
            @ForceSplat `
            -ErrorAction Stop
        }

        $null = $PSBoundParameters.Remove('Offline')

        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            $Lab = Get-Lab `
                @PSBoundParameters `
                -ErrorAction Stop
        } # if
    } # begin

    process
    {
        # Initialize the core Lab components
        # Check Lab Folder structure
        Write-LabMessage -Message $($LocalizedData.InitializingLabFoldersMesage)

        # Check folders are defined
        [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath

        if (-not (Test-Path -Path $LabPath))
        {
            Write-LabMessage -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'LabPath',$LabPath)

            $null = New-Item `
                -Path $LabPath `
                -Type Directory
        }

        [System.String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull

        if (-not (Test-Path -Path $VHDParentPath))
        {
            Write-LabMessage -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'VHDParentPath',$VHDParentPath)

            $null = New-Item `
                -Path $VHDParentPath `
                -Type Directory
        }

        [System.String] $ResourcePath = $Lab.labbuilderconfig.settings.resourcepathfull

        if (-not (Test-Path -Path $ResourcePath))
        {
            Write-LabMessage -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'ResourcePath',$ResourcePath)

            $null = New-Item `
                -Path $ResourcePath `
                -Type Directory
        }

        # Initialize the Lab Management Switch
        Initialize-LabManagementSwitch `
            -Lab $Lab `
            -ErrorAction Stop

        # Download any Resource Modules required by this Lab
        $ResourceModules = Get-LabResourceModule `
            -Lab $Lab
        Initialize-LabResourceModule `
            -Lab $Lab `
            -ResourceModules $ResourceModules `
            -ErrorAction Stop

        # Download any Resource MSUs required by this Lab
        $ResourceMSUs = Get-LabResourceMSU `
            -Lab $Lab
        Initialize-LabResourceMSU `
            -Lab $Lab `
            -ResourceMSUs $ResourceMSUs `
            -ErrorAction Stop

        # Initialize the Switches
        $Switches = Get-LabSwitch `
            -Lab $Lab
        Initialize-LabSwitch `
            -Lab $Lab `
            -Switches $Switches `
            -ErrorAction Stop

        # Initialize the VM Template VHDs
        $VMTemplateVHDs = Get-LabVMTemplateVHD `
            -Lab $Lab
        Initialize-LabVMTemplateVHD `
            -Lab $Lab `
            -VMTemplateVHDs $VMTemplateVHDs `
            -ErrorAction Stop

        # Initialize the VM Templates
        $VMTemplates = Get-LabVMTemplate `
            -Lab $Lab
        Initialize-LabVMTemplate `
            -Lab $Lab `
            -VMTemplates $VMTemplates `
            -ErrorAction Stop

        # Initialize the VMs
        $VMs = Get-LabVM `
            -Lab $Lab `
            -VMTemplates $VMTemplates `
            -Switches $Switches
        Initialize-LabVM `
            -Lab $Lab `
            -VMs $VMs `
            -ErrorAction Stop

        Write-LabMessage -Message $($LocalizedData.LabInstallCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath)
    } # process

    end
    {
    } # end
} # Install-Lab
