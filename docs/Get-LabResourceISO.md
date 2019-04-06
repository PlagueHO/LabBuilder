---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Get-LabResourceISO

## SYNOPSIS

Gets an array of ISO Resources from a Lab.

## SYNTAX

```powershell
Get-LabResourceISO [-Lab] <Object> [[-Name] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

Takes a provided Lab and returns the list of ISO resources required for this Lab.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$ResourceISO = Get-LabResourceISO $Lab
Loads a Lab and pulls the array of ISO Resources from it.

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

An optional array of ISO names.

Only ISO Resources matching names in this list will be pulled into the returned in the array.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### Returns an array of LabISOResource objects

## NOTES

## RELATED LINKS
