---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Stop-Lab

## SYNOPSIS

Stop an existing Lab.

## SYNTAX

### Lab (Default)

```powershell
Stop-Lab [-Lab] <Object> [<CommonParameters>]
```

### File

```powershell
Stop-Lab [-ConfigPath] <String> [[-LabPath] <String>] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will stop all the Hyper-V virtual machines definied in a Lab
configuration.

It will use the Bootorder attribute (if defined) for any VMs to determine
the order they should be shutdown in.
If a Bootorder is not specified for a
machine, it will be shutdown before all machines with a defined boot order.

The higher the Bootorder value for a machine the earlier it will be shutdown
in the stop process.

The Virtual Machines will be shutdown in REVERSE Bootorder.

Machines will be shutdown in series, with each machine shutting down once the
previous machine has completed shutdown.

If a Virtual Machine in the Lab is already shutdown, it will be ignored
and the next machine in series will be shutdown.

If more than one Virtual Machine shares the same Bootorder value, then
these machines will be shutdown in parallel, with the shutdown process only
continuing onto the next Bootorder when all these machines are shutdown.

If a Virtual Machine specified in the configuration is not found an
exception will be thrown.

If a Virtual Machine takes longer than the ShutdownTimeout then an exception
will be thown but the Stop process will continue.

## EXAMPLES

### EXAMPLE 1

```powershell
Stop-Lab -ConfigPath c:\mylab\config.xml
```

Stop the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE 2

```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Stop-Lab
```

Stop the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### None

## NOTES

## RELATED LINKS
