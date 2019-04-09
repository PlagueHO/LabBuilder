---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Initialize-LabVM

## SYNOPSIS

Initializes the Virtual Machines used by a Lab from a provided array.

## SYNTAX

```powershell
Initialize-LabVM [-Lab] <Object> [[-Name] <String[]>] [[-VMs] <LabVM[]>] [<CommonParameters>]
```

## DESCRIPTION

Takes an array of LabVM objects that were configured in the Lab.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$VMs = Get-LabVs -Lab $Lab
Initialize-LabVM \`
    -Lab $Lab \`
    -VMs $VMs
Initializes the Virtual Machines in the configured in the Lab c:\mylab\config.xml

### EXAMPLE 2

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

Initialize-LabVMs -Lab $Lab
Initializes the Virtual Machines in the configured in the Lab c:\mylab\config.xml

## PARAMETERS

### -Lab

Contains the Lab object that was loaded by the Get-Lab object.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name

An optional array of VM names.

Only VMs matching names in this list will be initialized.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -VMs

An array of LabVM objects pulled from a Lab object.

If not provided it will attempt to pull the list from the Lab object.

```yaml
Type: LabVM[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
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
