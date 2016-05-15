<#
.SYNOPSIS
    Gets an Array of LabVM objects from a Lab.
.DESCRIPTION
    Takes the provided Lab and returns the list of VM objects that will be created in this lab.
    This list is usually passed to Initialize-LabVM.
.PARAMETER Lab
    Contains the Lab Builder Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM names.

    Only VMs matching names in this list will be returned in the array.
.PARAMETER VMTemplates
    Contains the array of LabVMTemplate objects returned by Get-LabVMTemplate from this Lab.

    If not provided it will attempt to pull the list from the Lab.
.PARAMETER Switches
    Contains the array of LabVMSwitch objects returned by Get-LabSwitch from this Lab.

    If not provided it will attempt to pull the list from the Lab.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplates = Get-LabVMTemplate -Lab $Lab
    $Switches = Get-LabSwitch -Lab $Lab
    $VMs = Get-LabVM `
        -Lab $Lab `
        -VMTemplates $VMTemplates `
        -Switches $Switches
    Loads a Lab and pulls the array of VMs from it.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVM -Lab $Lab
    Loads a Lab and pulls the array of VMs from it.
.OUTPUTS
    Returns an array of LabVM objects.
#>
function Get-LabVM {
    [OutputType([LabVM[]])]
    [CmdLetBinding()]
    param (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,
        
        [Parameter(
            Position=3)]
        [LabVMTemplate[]] $VMTemplates,

        [Parameter(
            Position=4)]
        [LabSwitch[]] $Switches
    )

    # if VMTeplates array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMTemplates'))
    {
        [LabVMTemplate[]] $VMTemplates = Get-LabVMTemplate `
            -Lab $Lab
    }

    # if Switches array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('Switches'))
    {
        [LabSwitch[]] $Switches = Get-LabSwitch `
            -Lab $Lab
    }

    [LabVM[]] $LabVMs = @()
    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    [String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
    [String] $LabId = $Lab.labbuilderconfig.settings.labid 
    $VMs = $Lab.labbuilderconfig.vms.vm

    foreach ($VM in $VMs)
    {
        if ($VM.Name -eq 'VM')
        {
            $ExceptionParameters = @{
                errorId = 'VMNameError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.VMNameError)
            }
            ThrowException @ExceptionParameters
        } # if

        # Get the Instance Count attribute
        $InstanceCount = $VM.InstanceCount
        if (-not $InstanceCount)
        {
            $InstanceCount = 1
        }

        foreach ($Instance in 1..$InstanceCount)
        {
            # If InstanceCount is 1 then don't append a number to the VM name
            if ($InstanceCount -eq 1)
            {
                $VMName = $VM.Name
                $ComputerName = $VM.ComputerName
                $IncNetIds = 0
            }
            else
            {
                $VMName = "$($VM.Name) $Instance"
                $ComputerName = "$($VM.ComputerName)$Instance"
                # This value is used to increment IP and MAC addresses
                $IncNetIds = $Instance - 1
            } # if

            if ($Name -and ($VMName -notin $Name))
            {
                # A names list was passed but this VM wasn't included
                continue
            } # if

            # if a LabId is set for the lab, prepend it to the VM name.
            if ($LabId)
            {
                $VMName = "$LabId $VMName"
            }

            if (-not $VM.Template) 
            {
                $ExceptionParameters = @{
                    errorId = 'VMTemplateNameEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                        -f $VMName)
                }
                ThrowException @ExceptionParameters
            } # if

            # Find the template that this VM uses and get the VHD Path
            [String] $ParentVHDPath = ''
            [Boolean] $Found = $false
            foreach ($VMTemplate in $VMTemplates) {
                if ($VMTemplate.Name -eq $VM.Template) {
                    $ParentVHDPath = $VMTemplate.ParentVHD
                    $Found = $true
                    Break
                } # if
            } # foreach

            if (-not $Found) 
            {
                $ExceptionParameters = @{
                    errorId = 'VMTemplateNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                        -f $VMName,$VM.template)
                }
                ThrowException @ExceptionParameters
            } # if

            # Assemble the Network adapters that this VM will use
            [LabVMAdapter[]] $VMAdapters = @()
            [Int] $AdapterCount = 0
            foreach ($VMAdapter in $VM.Adapters.Adapter)
            {
                $AdapterCount++
                $AdapterName = $VMAdapter.Name 
                $AdapterSwitchName = $VMAdapter.SwitchName
                if ($AdapterName -eq 'adapter')
                {
                    $ExceptionParameters = @{
                        errorId = 'VMAdapterNameError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMAdapterNameError `
                            -f $VMName)
                    }
                    ThrowException @ExceptionParameters
                }
                
                if (-not $AdapterSwitchName)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMAdapterSwitchNameError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                            -f $VMName,$AdapterName)
                    }
                    ThrowException @ExceptionParameters
                }

                # if a LabId is set for the lab, prepend it to the adapter name
                # name and switch name.
                if ($LabId)
                {
                    $AdapterName = "$LabId $AdapterName"
                    $AdapterSwitchName = "$LabId $AdapterSwitchName"
                }

                # Check the switch is in the switch list
                [Boolean] $Found = $False
                foreach ($Switch in $Switches)
                {
                    # Match the switch name to the Adapter Switch Name or
                    # the LabId and Adapter Switch Name
                    if ($Switch.Name -eq $AdapterSwitchName) `
                    {
                        # The switch is found in the switch list - record the VLAN (if there is one)
                        $Found = $True
                        $SwitchVLan = $Switch.Vlan
                        Break
                    } # if
                    elseif ($Switch.Name -eq $VMAdapter.SwitchName)
                    {
                        # The switch is found in the switch list - record the VLAN (if there is one)
                        $Found = $True
                        $SwitchVLan = $Switch.Vlan
                        if ($Switch.Type -eq [LabSwitchType]::External)
                        {
                            $AdapterName = $VMAdapter.Name
                            $AdapterSwitchName = $VMAdapter.SwitchName
                        } # if
                        Break
                    }
                } # foreach
                if (-not $Found)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMAdapterSwitchNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMAdapterSwitchNotFoundError `
                            -f $VMName,$AdapterName,$AdapterSwitchName)
                    }
                    ThrowException @ExceptionParameters
                } # if

                # Figure out the VLan - If defined in the VM use it, otherwise use the one defined in the Switch, otherwise keep blank.
                [String] $VLan = $VMAdapter.VLan
                if (-not $VLan)
                {
                    $VLan = $SwitchVLan
                } # if

                [Boolean] $MACAddressSpoofing = ($VMAdapter.macaddressspoofing -eq 'On')

                # Have we got any IPv4 settings?
                Remove-Variable -Name IPv4 -ErrorAction SilentlyContinue
                if ($VMAdapter.IPv4)
                {
                    if ($VMAdapter.IPv4.Address)
                    {
                        $IPv4 = [LabVMAdapterIPv4]::New(`
                            (IncreaseIpAddress `
                                -IpAddress $VMAdapter.IPv4.Address`
                                -Step $IncNetIds)`
                            ,$VMAdapter.IPv4.SubnetMask)
                    } # if
                    $IPv4.defaultgateway = $VMAdapter.IPv4.DefaultGateway
                    $IPv4.dnsserver = $VMAdapter.IPv4.DNSServer
                } # if

                # Have we got any IPv6 settings?
                Remove-Variable -Name IPv6 -ErrorAction SilentlyContinue
                if ($VMAdapter.IPv6)
                {
                    if ($VMAdapter.IPv6.Address)
                    {
                        $IPv6 = [LabVMAdapterIPv6]::New(`
                            (IncreaseIpAddress `
                                -IpAddress $VMAdapter.IPv6.Address`
                                -Step $IncNetIds)`
                            ,$VMAdapter.IPv6.SubnetMask)
                    } # if
                    $IPv6.defaultgateway = $VMAdapter.IPv6.DefaultGateway
                    $IPv6.dnsserver = $VMAdapter.IPv6.DNSServer
                } # if

                $NewVMAdapter = [LabVMAdapter]::New($AdapterName)
                $NewVMAdapter.SwitchName = $AdapterSwitchName
                if($VMAdapter.macaddress)
                {
                    $NewVMAdapter.MACAddress = IncreaseMacAddress `
                        -MacAddress $VMAdapter.macaddress `
                        -Step $IncNetIds
                } # if
                $NewVMAdapter.MACAddressSpoofing = $MACAddressSpoofing
                $NewVMAdapter.VLan = $VLan
                $NewVMAdapter.IPv4 = $IPv4
                $NewVMAdapter.IPv6 = $IPv6
                $VMAdapters += @( $NewVMAdapter )
            } # foreach

            # Assemble the Data Disks this VM will use
            [LabDataVHD[]] $DataVhds = @()
            [Int] $DataVhdCount = 0
            foreach ($VMDataVhd in $VM.DataVhds.DataVhd)
            {
                $DataVhdCount++

                # Load all the VHD properties and check they are valid
                [String] $Vhd = $VMDataVhd.Vhd
                if (-not $VMDataVhd.Vhd)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskVHDEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                            -f $VMName)
                    }
                    ThrowException @ExceptionParameters
                } # if

                # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                # if it doesn't contain a root (e.g. c:\)
                if (-not [System.IO.Path]::IsPathRooted($Vhd))
                {
                    $Vhd = Join-Path `
                        -Path $LabPath `
                        -ChildPath "$($VMName)\Virtual Hard Disks\$Vhd"
                } # if

                # Does the VHD already exist?
                $Exists = Test-Path `
                    -Path $Vhd

                # Create the new Data VHD object
                $NewDataVHD = [LabDataVHD]::New($Vhd)

                # Get the Parent VHD and check it exists if passed
                if ($VMDataVhd.ParentVHD)
                {
                    $NewDataVHD.ParentVhd = $VMDataVhd.ParentVHD
                    # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                    # if it doesn't contain a root (e.g. c:\)
                    if (-not [System.IO.Path]::IsPathRooted($NewDataVHD.ParentVhd))
                    {
                        $NewDataVHD.ParentVhd = Join-Path `
                            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $NewDataVHD.ParentVhd
                    }
                    if (-not (Test-Path -Path $NewDataVHD.ParentVhd))
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskParentVHDNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                                -f $VMName,$NewDataVHD.ParentVhd)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                } # if

                # Get the Source VHD and check it exists if passed
                if ($VMDataVhd.SourceVHD)
                {
                    $NewDataVHD.SourceVhd = $VMDataVhd.SourceVHD
                    # Adjust the path to be relative to the Virtual Hard Disks folder of the VM
                    # if it doesn't contain a root (e.g. c:\)
                    if (-not [System.IO.Path]::IsPathRooted($NewDataVHD.SourceVhd))
                    {
                        $NewDataVHD.SourceVhd = Join-Path `
                            -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                            -ChildPath $NewDataVHD.SourceVhd
                    } # if
                    if (-not (Test-Path -Path $NewDataVHD.SourceVhd))
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskSourceVHDNotFoundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                                -f $VMName,$NewDataVHD.SourceVhd)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                } # if

                # Get the disk size if provided
                if ($VMDataVhd.Size)
                {
                    $NewDataVHD.Size = (Invoke-Expression $VMDataVhd.Size)
                } # if

                # Get the Shared flag
                $NewDataVHD.Shared = ($VMDataVhd.Shared -eq 'Y')

                # Get the Support Persistent Reservations
                $NewDataVHD.SupportPR = ($VMDataVhd.SupportPR -eq 'Y')
                if ($NewDataVHD.SupportPR -and -not $NewDataVHD.Shared)
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskSupportPRError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskSupportPRError `
                            -f $VMName,$VHD)
                    }
                    ThrowException @ExceptionParameters
                } # if

                # Validate the data disk type specified
                if ($VMDataVhd.Type)
                {
                    switch ($VMDataVhd.Type)
                    {
                        'fixed'
                        {
                            break;
                        }
                        'dynamic'
                        {
                            break;
                        }
                        'differencing'
                        {
                            if (-not $NewDataVHD.ParentVhd)
                            {
                                $ExceptionParameters = @{
                                    errorId = 'VMDataDiskParentVHDMissingError'
                                    errorCategory = 'InvalidArgument'
                                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                                        -f $VMName)
                                }
                                ThrowException @ExceptionParameters
                            } # if
                            if ($NewDataVHD.Shared)
                            {
                                $ExceptionParameters = @{
                                    errorId = 'VMDataDiskSharedDifferencingError'
                                    errorCategory = 'InvalidArgument'
                                    errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                                        -f $VMName,$VHD)
                                }
                                ThrowException @ExceptionParameters
                            } # if
                        }
                        Default
                        {
                            $ExceptionParameters = @{
                                errorId = 'VMDataDiskUnknownTypeError'
                                errorCategory = 'InvalidArgument'
                                errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                                    -f $VMName,$VHD,$VMDataVhd.Type)
                            }
                            ThrowException @ExceptionParameters
                        }
                    } # switch
                    $NewDataVHD.VHDType = [LabVHDType]::$($VMDataVhd.Type)
                } # if

                # Get Partition Style for the new disk.
                if ($VMDataVhd.PartitionStyle)
                {
                    $PartitionStyle = [LabPartitionStyle]::$($VMDataVhd.PartitionStyle)
                    if (-not $PartitionStyle)
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskPartitionStyleError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskPartitionStyleError `
                                -f $VMName,$VHD,$VMDataVhd.PartitionStyle)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                    $NewDataVHD.PartitionStyle = $PartitionStyle
                } # if

                # Get file system for the new disk.
                if ($VMDataVhd.FileSystem)
                {
                    $FileSystem = [LabFileSystem]::$($VMDataVhd.FileSystem)
                    if (-not $FileSystem)
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskFileSystemError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskFileSystemError `
                                -f $VMName,$VHD,$VMDataVhd.FileSystem)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                    $NewDataVHD.FileSystem = $FileSystem
                } # if

                # Has a file system label been provided?
                if ($VMDataVhd.FileSystemLabel)
                {
                    $NewDataVHD.FileSystemLabel = $VMDataVhd.FileSystemLabel
                } # if

                # if the Partition Style, File System or File System Label has been
                # provided then ensure Partition Style and File System are set.
                if ($NewDataVHD.PartitionStyle `
                    -or $NewDataVHD.FileSystem `
                    -or $NewDataVHD.FileSystemLabel)
                {
                    if (-not $NewDataVHD.PartitionStyle)
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskPartitionStyleMissingError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskPartitionStyleMissingError `
                                -f $VMName,$VHD)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                    if (-not $NewDataVHD.FileSystem)
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskFileSystemMissingError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskFileSystemMissingError `
                                -f $VMName,$VHD)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                } # if

                # Get the Folder to copy and check it exists if passed
                if ($VMDataVhd.CopyFolders)
                {
                    foreach ($CopyFolder in ($VMDataVhd.CopyFolders -Split ','))
                    {
                        # Adjust the path to be relative to the configuration folder 
                        # if it doesn't contain a root (e.g. c:\)
                        if (-not [System.IO.Path]::IsPathRooted($CopyFolder))
                        {
                            $CopyFolder = Join-Path `
                                -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                                -ChildPath $CopyFolder
                        } # if
                        if (-not (Test-Path -Path $CopyFolder -Type Container))
                        {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskCopyFolderMissingError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskCopyFolderMissingError `
                                -f $VMName,$VHD,$CopyFolder)
                            }
                        ThrowException @ExceptionParameters 
                        }
                    } # foreach
                    $NewDataVHD.CopyFolders = $VMDataVhd.CopyFolders
                } # if

                # Should the Source VHD be moved rather than copied
                if ($VMDataVhd.MoveSourceVHD)
                {
                    $NewDataVHD.MoveSourceVHD = ($VMDataVhd.MoveSourceVHD -eq 'Y')
                    if (-not $NewDataVHD.SourceVHD)
                    {
                        $ExceptionParameters = @{
                            errorId = 'VMDataDiskSourceVHDIfMoveError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                                -f $VMName,$VHD)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                } # if

                # if the data disk file doesn't exist then some basic parameters MUST be provided
                if (-not $Exists `
                    -and ( ( ( -not $NewDataVHD.VhdType ) -or ( $NewDataVHD.Size -eq 0) ) `
                    -and -not $NewDataVHD.SourceVhd ) )
                {
                    $ExceptionParameters = @{
                        errorId = 'VMDataDiskCantBeCreatedError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                            -f $VMName,$VHD)
                    }
                    ThrowException @ExceptionParameters
                } # if

                $DataVHDs += @( $NewDataVHD )
            } # foreach

            # Assemble the DVD Drives this VM will use
            [LabDVDDrive[]] $DVDDrives = @()
            [Int] $DVDDriveCount = 0
            foreach ($VMDVDDrive in $VM.DVDDrives.DVDDrive)
            {
                $DVDDriveCount++

                # Create the new DVD Drive object
                $NewDVDDrive = [LabDVDDRive]::New()

                # Load all the DVD Drive properties and check they are valid
                if ($VMDVDDrive.ISO)
                {
                    # Look the ISO up in the ISO Resources
                    # Pull the list of Resource ISOs available if not already pulled from Lab.
                    if (-not $ResourceISOs)
                    {
                        $ResourceISOs = Get-LabResourceISO `
                            -Lab $Lab
                    } # if

                    # Lookup the Resource ISO record
                    $ResourceISO = $ResourceISOs | Where-Object -Property Name -eq $VMDVDDrive.ISO
                    if (-not $ResourceISO)
                    {
                        # The ISO Resource was not found
                        $ExceptionParameters = @{
                            errorId = 'VMDVDDriveISOResourceNotFOundError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.VMDVDDriveISOResourceNotFOundError `
                                -f $VMName,$VMDVDDrive.ISO)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                    # The ISO resource was found so populate the ISO details
                    $NewDVDDrive.ISO = $VMDVDDrive.ISO
                    $NewDVDDrive.Path = $ResourceISO.Path
                } # if

                $DVDDrives += @( $NewDVDDrive )
            } # foreach

            # Does the VM have an Unattend file specified?
            [String] $UnattendFile = ''
            if ($VM.UnattendFile)
            {
                if ([System.IO.Path]::IsPathRooted($VM.UnattendFile))
                {
                    $UnattendFile = $VM.UnattendFile
                }
                else
                {
                    $UnattendFile = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $VM.UnattendFile
                } # if
                if (-not (Test-Path $UnattendFile)) 
                {
                    $ExceptionParameters = @{
                        errorId = 'UnattendFileMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.UnattendFileMissingError `
                            -f $VMName,$UnattendFile)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if
            
            # Does the VM specify a Setup Complete Script?
            [String] $SetupComplete = ''
            if ($VM.SetupComplete) 
            {
                if ([System.IO.Path]::IsPathRooted($VM.SetupComplete))
                {
                    $SetupComplete = $VM.SetupComplete
                }
                else
                {
                    $SetupComplete = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.fullconfigpath `
                        -ChildPath $VM.SetupComplete
                } # if
                if ([System.IO.Path]::GetExtension($SetupComplete).ToLower() -notin '.ps1','.cmd' )
                {
                    $ExceptionParameters = @{
                        errorId = 'SetupCompleteFileBadTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                            -f $VMName,$SetupComplete)
                    }
                    ThrowException @ExceptionParameters
                } # if
                if (-not (Test-Path $SetupComplete))
                {
                    $ExceptionParameters = @{
                        errorId = 'SetupCompleteFileMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                            -f $VMName,$SetupComplete)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if

            # Create the Lab DSC object
            $LabDSC = [LabDSC]::New($VM.DSC.ConfigName)

            # Load the DSC Config File setting and check it
            [String] $LabDSC.ConfigFile = ''
            if ($VM.DSC.ConfigFile) 
            {
                if (-not [System.IO.Path]::IsPathRooted($VM.DSC.ConfigFile))
                {
                    $LabDSC.ConfigFile = Join-Path `
                        -Path $Lab.labbuilderconfig.settings.dsclibrarypathfull `
                        -ChildPath $VM.DSC.ConfigFile
                }
                else
                {
                    $LabDSC.ConfigFile = $VM.DSC.ConfigFile
                } # if

                if ([System.IO.Path]::GetExtension($LabDSC.ConfigFile).ToLower() -ne '.ps1' )
                {
                    $ExceptionParameters = @{
                        errorId = 'DSCConfigFileBadTypeError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                            -f $VMName,$LabDSC.ConfigFile)
                    }
                    ThrowException @ExceptionParameters
                } # if

                if (-not (Test-Path $LabDSC.ConfigFile))
                {
                    $ExceptionParameters = @{
                        errorId = 'DSCConfigFileMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                            -f $VMName,$LabDSC.ConfigFile)
                    }
                    ThrowException @ExceptionParameters
                } # if
                if (-not $VM.DSC.ConfigName)
                {
                    $ExceptionParameters = @{
                        errorId = 'DSCConfigNameIsEmptyError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                            -f $VMName)
                    }
                    ThrowException @ExceptionParameters
                } # if
            } # if

            # Load the DSC Parameters
            [String] $LabDSC.Parameters = ''
            if ($VM.DSC.Parameters)
            {
                # Correct any LFs into CRLFs to ensure the new line format is the same when
                # pulled from the XML.
                $LabDSC.Parameters = ($VM.DSC.Parameters -replace "`r`n","`n") -replace "`n","`r`n"
            } # if

            # Load the DSC Parameters
            [Boolean] $LabDSC.Logging = ($VM.DSC.Logging -eq 'Y')

            # Get the Memory Startup Bytes (from the template or VM)
            [Int64] $MemoryStartupBytes = 1GB
            if ($VM.memorystartupbytes)
            {
                $MemoryStartupBytes = (Invoke-Expression $VM.memorystartupbytes)
            }
            elseif ($VMTemplate.memorystartupbytes)
            {
                $MemoryStartupBytes = $VMTemplate.memorystartupbytes
            } # if

            # Get the Dynamic Memory Enabled flag
            [Boolean] $DynamicMemoryEnabled = $True
            if ($VM.DynamicMemoryEnabled)
            {
                $DynamicMemoryEnabled = ($VM.DynamicMemoryEnabled -eq 'Y')
            }
            elseif ($VMTemplate.DynamicMemoryEnabled)
            {
                $DynamicMemoryEnabled = $VMTemplate.DynamicMemoryEnabled
            } # if
            
            # Get the Memory Startup Bytes (from the template or VM)
            [Int] $ProcessorCount = 1
            if ($VM.processorcount)
            {
                $ProcessorCount = (Invoke-Expression $VM.processorcount)
            }
            elseif ($VMTemplate.processorcount)
            {
                $ProcessorCount = $VMTemplate.processorcount
            } # if

            # Get the Expose Virtualization Extensions flag
            if ($VM.ExposeVirtualizationExtensions)
            {
                $ExposeVirtualizationExtensions = ($VM.ExposeVirtualizationExtensions -eq 'Y')
            }
            elseif ($VMTemplate.ExposeVirtualizationExtensions)
            {
                $ExposeVirtualizationExtensions = $VMTemplate.ExposeVirtualizationExtensions
            } # if

            # If VM requires ExposeVirtualizationExtensions but
            # it is not supported on Host then throw an exception.
            if ($ExposeVirtualizationExtensions -and ($Script:CurrentBuild -lt 10565))
            {
                $ExceptionParameters = @{
                    errorId = 'VMVirtualizationExtError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMVirtualizationExtError `
                        -f $VMName)
                }
                ThrowException @ExceptionParameters
            } # if

            [Boolean] $UseDifferencingDisk = $True
            if ($VM.UseDifferencingDisk -eq 'N')
            {
                $UseDifferencingDisk = $False
            } # if

            # Get the Integration Services flags
            if ($null -ne $VM.IntegrationServices)
            {
                $IntegrationServices = $VM.IntegrationServices
            } 
            elseif ($null -ne $VMTemplate.IntegrationServices)
            {
                $IntegrationServices = $VMTemplate.IntegrationServices
            } # if

            # Get the Administrator password (from the template or VM)
            [String] $AdministratorPassword = ''
            if ($VM.administratorpassword) 
            {
                $AdministratorPassword = $VM.administratorpassword
            }
            elseif ($VMTemplate.administratorpassword)
            {
                $AdministratorPassword = $VMTemplate.administratorpassword
            } # if

            # Get the Product Key (from the template or VM)
            [String] $ProductKey = ''
            if ($VM.productkey) 
            {
                $ProductKey = $VM.productkey
            }
            elseif ($VMTemplate.productkey)
            {
                $ProductKey = $VMTemplate.productkey
            } # if

            # Get the Timezone (from the template or VM)
            [String] $Timezone = 'Pacific Standard Time'
            if ($VM.timezone) 
            {
                $Timezone = $VM.timezone
            }
            elseif ($VMTemplate.timezone) 
            {
                $Timezone = $VMTemplate.timezone
            } # if

            # Get the OS Type
            $OSType = [LabOStype]::Server
            if ($VM.OSType)
            {
                $OSType = $VM.OSType
            }
            elseif ($VMTemplate.OSType)
            {
                $OSType = $VMTemplate.OSType
            } # if

            # Get the Bootorder
            [Byte] $Bootorder = [Byte]::MaxValue
            if ($VM.bootorder)
            {
                $Bootorder = $VM.bootorder
            } # if

            # Get the Packages
            [String] $Packages = $null
            if ($VM.packages)
            {
                $Packages = $VM.packages
            }
            elseif ($VMTemplate.packages)
            {
                $Packages = $VMTemplate.packages
            } # if

            # Get the Certificate Source
            $CertificateSource = [LabCertificateSource]::Guest
            if ($OSType -eq [LabOSType]::Nano)
            {
                # Nano Server can't generate certificates so must always be set to Host
                $CertificateSource = [LabCertificateSource]::Host
            }
            elseif ($VM.CertificateSource)
            {
                $CertificateSource = $VM.CertificateSource
            } # if

            $LabVM = [LabVM]::New($VMName,$ComputerName)
            $LabVM.Template = $VM.Template
            $LabVM.ParentVHD = $ParentVHDPath
            $LabVM.UseDifferencingDisk = $UseDifferencingDisk
            $LabVM.MemoryStartupBytes = $MemoryStartupBytes
            $LabVM.DynamicMemoryEnabled = $DynamicMemoryEnabled
            $LabVM.ProcessorCount = $ProcessorCount
            $LabVM.ExposeVirtualizationExtensions = $ExposeVirtualizationExtensions
            $LabVM.IntegrationServices = $IntegrationServices
            $LabVM.AdministratorPassword = $AdministratorPassword
            $LabVM.ProductKey = $ProductKey
            $LabVM.TimeZone =$Timezone
            $LabVM.UnattendFile = $UnattendFile
            $LabVM.SetupComplete = $SetupComplete
            $LabVM.OSType = $OSType
            $LabVM.CertificateSource = $CertificateSource
            $LabVM.Bootorder = $Bootorder
            $LabVM.Packages = $Packages
            $LabVM.Adapters = $VMAdapters
            $LabVM.DataVHDs = $DataVHDs
            $LabVM.DVDDrives = $DVDDrives
            $LabVM.DSC = $LabDSC
            $LabVM.VMRootPath = Join-Path `
                -Path $LabPath `
                -ChildPath $VMName
            $LabVM.LabBuilderFilesPath = Join-Path `
                -Path $LabPath `
                -ChildPath "$VMName\LabBuilder Files"
            $LabVMs += @( $LabVM )
        } # foreach
    } # foreach

    Return $LabVMs
} # Get-LabVM


<#
.SYNOPSIS
    Initializes the Virtual Machines used by a Lab from a provided array.
.DESCRIPTION
    Takes an array of LabVM objects that were configured in the Lab.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM names.

    Only VMs matching names in this list will be initialized.
.PARAMETER VMs
    An array of LabVM objects pulled from a Lab object.

    If not provided it will attempt to pull the list from the Lab object.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMs = Get-LabVs -Lab $Lab
    Initialize-LabVM `
        -Lab $Lab `
        -VMs $VMs
    Initializes the Virtual Machines in the configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Initialize-LabVMs -Lab $Lab
    Initializes the Virtual Machines in the configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Initialize-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,
        
        [Parameter(
            Position=3)]
        [LabVM[]] $VMs
    )
    
    # if VMs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMs'))
    {
        [LabVM[]] $VMs = Get-LabVM `
            @PSBoundParameters
    } # if
    
    # if there are not VMs just return
    if (-not $VMs)
    {
        return
    } # if
    
    $CurrentVMs = Get-VM

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # Figure out the name of the LabBuilder control switch
    $ManagementSwitchName = GetManagementSwitchName `
        -Lab $Lab
    if ($Lab.labbuilderconfig.switches.ManagementVlan)
    {
        [Int32] $ManagementVlan = $Lab.labbuilderconfig.switches.ManagementVlan
    }
    else
    {
        [Int32] $ManagementVlan = $Script:DefaultManagementVLan
    } # if

    foreach ($VM in $VMs)
    {
        if ($Name -and ($VM.Name -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if
        
        # Get the root path of the VM
        [String] $VMRootPath = $VM.VMRootPath

        # Get the Virtual Machine Path
        [String] $VMPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Machines'
            
        # Get the Virtual Hard Disk Path
        [String] $VHDPath = Join-Path `
            -Path $VMRootPath `
            -ChildPath 'Virtual Hard Disks'

        # Get Path to LabBuilder files
        [String] $VMLabBuilderFiles = $VM.LabBuilderFilesPath

        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -eq 0)
        {
            WriteMessage -Message $($LocalizedData.CreatingVMMessage `
                -f $VM.Name)

            # Make sure the appropriate folders exist
            InitializeVMPaths `
                -VMPath $VMRootPath

            # Create the boot disk
            $VMBootDiskPath = "$VHDPath\$($VM.Name) Boot Disk.vhdx"
            if (-not (Test-Path -Path $VMBootDiskPath))
            {
                if ($VM.UseDifferencingDisk)
                {
                    WriteMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Differencing Boot')

                    $Null = New-VHD `
                        -Differencing `
                        -Path $VMBootDiskPath `
                        -ParentPath $VM.ParentVHD
                }
                else
                {
                    WriteMessage -Message $($LocalizedData.CreatingVMDiskMessage `
                        -f $VM.Name,$VMBootDiskPath,'Boot')

                    $Null = Copy-Item `
                        -Path $VM.ParentVHD `
                        -Destination $VMBootDiskPath
                }
                
                # Create all the required initialization files for this VM
                CreateVMInitializationFiles `
                    -Lab $Lab `
                    -VM $VM

                # Because this is a new boot disk apply any required initialization
                InitializeBootVHD `
                    -Lab $Lab `
                    -VM $VM `
                    -VMBootDiskPath $VMBootDiskPath
            }
            else
            {
                WriteMessage -Message $($LocalizedData.VMDiskAlreadyExistsMessage `
                    -f $VM.Name,$VMBootDiskPath,'Boot')
            } # if

            $null = New-VM `
                -Name $VM.Name `
                -MemoryStartupBytes $VM.MemoryStartupBytes `
                -Generation 2 `
                -Path $LabPath `
                -VHDPath $VMBootDiskPath
            # Remove the default network adapter created with the VM because we don't need it
            Remove-VMNetworkAdapter `
                -VMName $VM.Name `
                -Name 'Network Adapter'
        }

        # Set the processor count if different to default and if specified in config file
        if ($VM.ProcessorCount)
        {
            if ($VM.ProcessorCount -ne (Get-VM -Name $VM.Name).ProcessorCount)
            {
                Set-VM `
                    -Name $VM.Name `
                    -ProcessorCount $VM.ProcessorCount
            } # if
        } # if
        
        # Enable/Disable Dynamic Memory
        if ($VM.DynamicMemoryEnabled -ne (Get-VMMemory -VMName $VM.Name).DynamicMemoryEnabled)
        {
            Set-VMMemory `
                -VMName $VM.Name `
                -DynamicMemoryEnabled:$($VM.DynamicMemoryEnabled)
        } # if

        # Is ExposeVirtualizationExtensions supported?
        if ($Script:CurrentBuild -lt 10565)
        {
            # No, it is not supported - is it required by VM?
            if ($VM.ExposeVirtualizationExtensions)
            {
                # ExposeVirtualizationExtensions is required for this VM
                $ExceptionParameters = @{
                    errorId = 'VMVirtualizationExtError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMVirtualizationExtError `
                        -f $VM.Name)
                }
                ThrowException @ExceptionParameters
            } # if
        }
        else
        {
            # Yes, it is - is the setting different?
            if ($VM.ExposeVirtualizationExtensions `
                -ne (Get-VMProcessor -VMName $VM.Name).ExposeVirtualizationExtensions)
            {
                # Try and update it
                Set-VMProcessor `
                    -VMName $VM.Name `
                    -ExposeVirtualizationExtensions:$VM.ExposeVirtualizationExtensions `
                    -ErrorAction Stop
            } # if
        } # if

        # Enable/Disable the Integration Services
        UpdateVMIntegrationServices `
            -VM $VM

        # Update the data disks for the VM
        UpdateVMDataDisks `
            -Lab $Lab `
            -VM $VM

        # Update the DVD Drives for the VM
        UpdateVMDVDDrives `
            -Lab $Lab `
            -VM $VM

        # Create/Update the Management Network Adapter
        if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $ManagementSwitchName).Count -eq 0)
        {
            WriteMessage -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                -f $VM.Name,$ManagementSwitchName,'Management')

            Add-VMNetworkAdapter `
                -VMName $VM.Name `
                -SwitchName $ManagementSwitchName `
                -Name $ManagementSwitchName
        }
        $VMNetworkAdapter = Get-VMNetworkAdapter `
            -VMName $VM.Name `
            -Name $ManagementSwitchName
        $null = $VMNetworkAdapter |
            Set-VMNetworkAdapterVlan `
                -Access `
                -VlanId $ManagementVlan

        WriteMessage -Message $($LocalizedData.SettingVMNetworkAdapterVlanMessage `
            -f $VM.Name,$ManagementSwitchName,'Management',$ManagementVlan)

        # Create any network adapters
        foreach ($VMAdapter in $VM.Adapters)
        {
            if ((Get-VMNetworkAdapter -VMName $VM.Name | Where-Object -Property Name -EQ $VMAdapter.Name).Count -eq 0)
            {
                WriteMessage -Message $($LocalizedData.AddingVMNetworkAdapterMessage `
                    -f $VM.Name,$VMAdapter.SwitchName,$VMAdapter.Name)

                Add-VMNetworkAdapter `
                    -VMName $VM.Name `
                    -SwitchName $VMAdapter.SwitchName `
                    -Name $VMAdapter.Name
            } # if

            $VMNetworkAdapter = Get-VMNetworkAdapter `
                -VMName $VM.Name `
                -Name $VMAdapter.Name
            if ($VMAdapter.VLan)
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapterVlan `
                        -Access `
                        -VlanId $VMAdapter.VLan

                WriteMessage -Message $($LocalizedData.SettingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'',$VMAdapter.VLan)
            }
            else
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapterVlan `
                        -Untagged

                WriteMessage -Message $($LocalizedData.ClearingVMNetworkAdapterVlanMessage `
                    -f $VM.Name,$VMAdapter.Name,'')
            } # if

            if ([String]::IsNullOrWhitespace($VMAdapter.MACAddress))
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -DynamicMacAddress
            }
            else
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -StaticMacAddress $VMAdapter.MACAddress
            } # if

            # Enable Device Naming
            if ((Get-Command -Name Set-VMNetworkAdapter).Parameters.ContainsKey('DeviceNaming'))
            {
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -DeviceNaming On
            } # if
            if ($VMAdapter.MACAddressSpoofing -ne $VMNetworkAdapter.MACAddressSpoofing)
            {
                $MACAddressSpoofing = if ($VMAdapter.MACAddressSpoofing) {'On'} else {'Off'}
                $null = $VMNetworkAdapter |
                    Set-VMNetworkAdapter `
                        -MacAddressSpoofing $MACAddressSpoofing
            } # if
        } # foreach

        Install-LabVM `
            -Lab $Lab `
            -VM $VM
    } # foreach
} # Initialize-LabVM


<#
.SYNOPSIS
    Removes all Lab Virtual Machines.
.DESCRIPTION
    This cmdlet is used to remove any Virtual Machines that were created as part of this
    Lab.

    It can also optionally delete the folder and all files created as part of this Lab
    Virutal Machine.
.PARAMETER Lab
    Contains the Lab object that was loaded by the Get-Lab object.
.PARAMETER Name
    An optional array of VM names.

    Only VMs matching names in this list will be removed.
.PARAMETER VMs
    The array of LabVM objects pulled from the Lab using Get-LabVM.

    If not provided it will attempt to pull the list from the Lab object.
.PARAMETER RemoveVMFolder
    Causes the folder created to contain the Virtual Machine in this lab to be deleted.
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    $VMTemplates = Get-LabVMTemplate -Lab $Lab
    $VMs = Get-LabVs -Lab $Lab -VMTemplates $VMTemplates
    Remove-LabVM -Lab $Lab -VMs $VMs
    Removes any Virtual Machines configured in the Lab c:\mylab\config.xml
.EXAMPLE
    $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
    Remove-LabVM -Lab $Lab
    Removes any Virtual Machines configured in the Lab c:\mylab\config.xml
.OUTPUTS
    None.
#>
function Remove-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [String[]] $Name,
        
        [Parameter(
            Position=3)]
        [LabVM[]] $VMs,

        [Parameter(
            Position=4)]
        [Switch] $RemoveVMFolder
    )
    
    # if VMs array not passed, pull it from config.
    if (-not $PSBoundParameters.ContainsKey('VMs'))
    {
        $null = $PSBoundParameters.Remove('RemoveVMFolder')
        [LabVM[]] $VMs = Get-LabVM `
            @PSBoundParameters
    } # if

    $CurrentVMs = Get-VM

    # Get the LabPath
    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath
    
    foreach ($VM in $VMs)
    {
        if ($Name -and ($VM.Name -notin $Name))
        {
            # A names list was passed but this VM wasn't included
            continue
        } # if

        if (($CurrentVMs | Where-Object -Property Name -eq $VM.Name).Count -ne 0)
        {
            # if the VM is running we need to shut it down.
            if ((Get-VM -Name $VM.Name).State -eq 'Running')
            {
                WriteMessage -Message $($LocalizedData.StoppingVMMessage `
                    -f $VM.Name)

                Stop-VM `
                    -Name $VM.Name
                # Wait for it to completely shut down and report that it is off.
                WaitVMOff `
                    -VM $VM
            }

            WriteMessage -Message $($LocalizedData.RemovingVMMessage `
                -f $VM.Name)
           
            # Now delete the actual VM
            Get-VM `
                -Name $VM.Name | Remove-VM -Force -Confirm:$False

            WriteMessage -Message $($LocalizedData.RemovedVMMessage `
                -f $VM.Name)
        }
        else
        {
            WriteMessage -Message $($LocalizedData.VMNotFoundMessage `
                -f $VM.Name)
        }
    }
    # Should we remove the VM Folder?
    if ($RemoveVMFolder)
    {
        if (Test-Path -Path $VM.VMRootPath)
        {
            WriteMessage -Message $($LocalizedData.DeletingVMFolderMessage `
                -f $VM.Name)

            Remove-Item `
                -Path $VM.VMRootPath `
                -Recurse `
                -Force
        }
    }
} # Remove-LabVM



<#
.SYNOPSIS
   Starts a Lab VM and ensures it has been Initialized.
.DESCRIPTION
   This cmdlet is used to start up a Lab VM for the first time.
   
   It will start the VM if it is off.
   
   If the VM is a Server OS or Nano Server then it will also perform an initial setup:
    - It will ensure that initial setup has been completed and a self-signed certificate has
      been created by the VM and downloaded to the LabBuilder folder.   

    - It will also ensure DSC is configured for the VM.
.PARAMETER VM
   The LabVM Object referring to the VM to start to.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
   $Session = Install-LabVM -VM $VMs[0]
   Start up the first VM in the Lab c:\mylab\config.xml and initialize it.
.OUTPUTS
   None.
#>
function Install-LabVM {
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=2)]
        [ValidateNotNullOrEmpty()]
        [LabVM] $VM
    )

    [String] $LabPath = $Lab.labbuilderconfig.settings.labpath

    # The VM is now ready to be started
    if ((Get-VM -Name $VM.Name).State -eq 'Off')
    {
        WriteMessage -Message $($LocalizedData.StartingVMMessage `
            -f $VM.Name)

        Start-VM -VMName $VM.Name
    } # if

    # We only perform this section of VM Initialization (DSC, Cert, etc) with Server OS
    if ($VM.OSType -in ([LabOStype]::Server,[LabOStype]::Nano))
    {
        # Has this VM been initialized before (do we have a cert for it)
        if (-not (Test-Path "$LabPath\$($VM.Name)\LabBuilder Files\$Script:DSCEncryptionCert"))
        {
            # No, so check it is initialized and download the cert if required
            if (WaitVMInitializationComplete -VM $VM -ErrorAction Continue)
            {
                WriteMessage -Message $($LocalizedData.CertificateDownloadStartedMessage `
                    -f $VM.Name)

                if ($VM.CertificateSource -eq [LabCertificateSource]::Guest)
                {
                    if (GetSelfSignedCertificate -Lab $Lab -VM $VM)
                    {
                        WriteMessage -Message $($LocalizedData.CertificateDownloadCompleteMessage `
                            -f $VM.Name)
                    }
                    else
                    {
                        $ExceptionParameters = @{
                            errorId = 'CertificateDownloadError'
                            errorCategory = 'InvalidArgument'
                            errorMessage = $($LocalizedData.CertificateDownloadError `
                                -f $VM.name)
                        }
                        ThrowException @ExceptionParameters
                    } # if
                } # if
            }
            else
            {
                $ExceptionParameters = @{
                    errorId = 'InitializationDidNotCompleteError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.InitializationDidNotCompleteError `
                        -f $VM.name)
                }
                ThrowException @ExceptionParameters
            } # if
        } # if

        # Create any DSC Files for the VM
        InitializeDSC `
            -Lab $Lab `
            -VM $VM

        # Attempt to start DSC on the VM
        StartDSC `
            -Lab $Lab `
            -VM $VM
    } # if
} # Install-LabVM



<#
.SYNOPSIS
   Connects to a running Lab VM.
.DESCRIPTION
   This cmdlet will connect to a running VM using PSRemoting. A PSSession object will be returned
   if the connection was successful.
   
   If the connection fails, it will be retried until the ConnectTimeout is reached. If the
   ConnectTimeout is reached and a connection has not been established then a ConnectionError 
   exception will be thrown.
   
   The IP Address to this VM will be added to the WSMan TrustedHosts list if it isn't already
   added or if it isn't set to '*'.
.PARAMETER VM
   The LabVM Object referring to the VM to connect to.
.PARAMETER ConnectTimeout
   The number of seconds the connection will attempt to be established for.

   Defaults to 300 seconds.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
   $Session = Connect-LabVM -VM $VMs[0]
   Connect to the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
   The PSSession object of the remote connect or null if the connection failed.
#>
function Connect-LabVM
{
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [LabVM] $VM,
        
        [Parameter(
            Position=2)]
        [Int] $ConnectTimeout = 300
    )

    [DateTime] $StartTime = Get-Date
    [System.Management.Automation.Runspaces.PSSession] $Session = $null
    [PSCredential] $AdminCredential = CreateCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword
    [Boolean] $FatalException = $False
    
    while (($null -eq $Session) `
        -and (((Get-Date) - $StartTime).TotalSeconds) -lt $ConnectTimeout `
        -and -not $FatalException)
    {
        try
        {
            # Get the Management IP Address of the VM
            # We repeat this because the IP Address will only be assiged 
            # once the VM is fully booted.
            $IPAddress = GetVMManagementIPAddress `
                -Lab $Lab `
                -VM $VM

            # Add the IP Address to trusted hosts if not already in it
            # This could be avoided if able to use SSL or if PS Direct is used.
            # Also, don't add if TrustedHosts is already *
            $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
            if (($TrustedHosts -notlike "*$IPAddress*") -and ($TrustedHosts -ne '*'))
            {
                if ([String]::IsNullOrWhitespace($TrustedHosts))
                {
                    $TrustedHosts = $IPAddress
                }
                else
                {
                    $TrustedHosts = "$TrustedHosts,$IPAddress"
                }
                Set-Item `
                    -Path WSMAN::localhost\Client\TrustedHosts `
                    -Value $TrustedHosts `
                    -Force
                WriteMessage -Message $($LocalizedData.AddingIPAddressToTrustedHostsMessage `
                    -f $VM.Name,$IPAddress)
            }
        
            WriteMessage -Message $($LocalizedData.ConnectingVMMessage `
                -f $VM.Name,$IPAddress)

            $Session = New-PSSession `
                -Name 'LabBuilder' `
                -ComputerName $IPAddress `
                -Credential $AdminCredential `
                -ErrorAction Stop
        }
        catch
        {
            if (-not $IPAddress)
            {
                WriteMessage -Message $($LocalizedData.WaitingForIPAddressAssignedMessage `
                    -f $VM.Name,$Script:RetryConnectSeconds)                                
            }
            else
            {
                WriteMessage -Message $($LocalizedData.ConnectingVMFailedMessage `
                    -f $VM.Name,$Script:RetryConnectSeconds,$_.Exception.Message)
            }
            Start-Sleep -Seconds $Script:RetryConnectSeconds
        } # Try
    } # While

    # if a fatal exception occured or the connection just couldn't be established
    # then throw an exception so it can be caught by the calling code.
    if ($FatalException -or ($null -eq $Session))
    {
        # The connection failed so throw an error
        $ExceptionParameters = @{
            errorId = 'RemotingConnectionError'
            errorCategory = 'ConnectionError'
            errorMessage = $($LocalizedData.RemotingConnectionError `
                -f $VM.Name)
        }
        ThrowException @ExceptionParameters
    }
    Return $Session
} # Connect-LabVM


<#
.SYNOPSIS
   Disconnects from a running Lab VM.
.DESCRIPTION
   This cmdlet will disconnect a session from a running VM using PSRemoting.
   
   The IP Address to this VM will be removed from the WSMan TrustedHosts list 
   if it exists in it.
.PARAMETER VM
   The LabVM Object referring to the VM to disconnect from.
.EXAMPLE
   $Lab = Get-Lab -ConfigPath c:\mylab\config.xml
   $VMs = Get-LabVM -Lab $Lab
   Disconnect-LabVM -VM $VMs[0]
   Disconnect from the first VM in the Lab c:\mylab\config.xml.
.OUTPUTS
   None
#>
function Disconnect-LabVM
{
    [CmdLetBinding()]
    param
    (
        [Parameter(
            Position=1,
            Mandatory=$true)]
        [LabVM] $VM
    )

    [PSCredential] $AdminCredential = CreateCredential `
        -Username '.\Administrator' `
        -Password $VM.AdministratorPassword

    # Get the Management IP Address of the VM
    $IPAddress = GetVMManagementIPAddress `
        -Lab $Lab `
        -VM $VM

    try
    {
        # Look for the session
        $Session = Get-PSSession `
            -Name 'LabBuilder' `
            -ComputerName $IPAddress `
            -Credential $AdminCredential `
            -ErrorAction Stop

        if (-not $Session)
        {
            # No session found to this machine so nothing to do.
            WriteMessage -Message $($LocalizedData.VMSessionDoesNotExistMessage `
                -f $VM.Name)
        }
        else
        {
            if ($Session.State -eq 'Opened')
            {
                # Disconnect the session
                $null = $Session | Disconnect-PSSession
                WriteMessage -Message $($LocalizedData.DisconnectingVMMessage `
                    -f $VM.Name,$IPAddress)
            }
            # Remove the session
            $null = $Session | Remove-PSSession -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Throw $_
    }
    finally
    {
        # Remove the entry from TrustedHosts
        $TrustedHosts = (Get-Item -Path WSMAN::localhost\Client\TrustedHosts).Value
        if (($TrustedHosts -like "*$IPAddress*") -and ($TrustedHosts -ne '*'))
        {
            $IPAddresses = @($TrustedHosts -split ',')
            $TrustedHosts = ($IPAddresses | Where-Object { $_ -ne $IPAddress }) -join ','
            Set-Item `
                -Path WSMAN::localhost\Client\TrustedHosts `
                -Value $TrustedHosts `
                -Force
            WriteMessage -Message $($LocalizedData.RemovingIPAddressFromTrustedHostsMessage `
                -f $VM.Name,$IPAddress)
        }
    } # try
} # Disconnect-LabVM
