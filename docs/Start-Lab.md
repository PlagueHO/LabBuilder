---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Start-Lab

## SYNOPSIS

Starts an existing Lab.

## SYNTAX

### Lab (Default)

```powershell
Start-Lab [-Lab] <Object> [[-StartupTimeout] <Int32>] [<CommonParameters>]
```

### File

```powershell
Start-Lab [-ConfigPath] <String> [[-LabPath] <String>] [[-StartupTimeout] <Int32>] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will start all the Hyper-V virtual machines definied in a Lab
configuration.

It will use the Bootorder attribute (if defined) for any VMs to determine
the order they should be booted in.
If a Bootorder is not specified for a
machine, it will be booted after all machines with a defined boot order.

The lower the Bootorder value for a machine the earlier it will be started
in the start process.

Machines will be booted in series, with each machine starting once the
previous machine has completed startup and has a management IP address.

If a Virtual Machine in the Lab is already running, it will be ignored
and the next machine in series will be started.

If more than one Virtual Machine shares the same Bootorder value, then
these machines will be booted in parallel, with the boot process only
continuing onto the next Bootorder when all these machines are booted.

If a Virtual Machine specified in the configuration is not found an
exception will be thrown.

If a Virtual Machine takes longer than the StartupTimeout then an exception
will be thown but the Start process will continue.

If a Bootorder of 0 is specifed then the Virtual Machine will not be booted at
all.
This is useful for things like Root CA VMs that only need to started when
the Lab is created.

## EXAMPLES

### EXAMPLE 1

```powershell
Start-Lab -ConfigPath c:\mylab\config.xml
```

Start the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE 2

```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Start-Lab
```

Start the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

## PARAMETERS

### -ConfigPath

The path to the LabBuilder configuration XML file.

```yaml
Type: String
Parameter Sets: File
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LabPath

The optional path to install the Lab to - overrides the LabPath setting in the
configuration file.

```yaml
Type: String
Parameter Sets: File
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Lab

The Lab object returned by Get-Lab of the lab to start.

```yaml
Type: Object
Parameter Sets: Lab
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -StartupTimeout

The maximum number of seconds that the process will wait for a VM to startup.
Defaults to 90 seconds.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: $script:StartupTimeout
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### None

## NOTES

## RELATED LINKS
