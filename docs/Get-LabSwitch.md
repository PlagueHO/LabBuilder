---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Get-LabSwitch

## SYNOPSIS

Gets an array of switches from a Lab.

## SYNTAX

```powershell
Get-LabSwitch [-Lab] <Object> [[-Name] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

Takes a provided Lab and returns the array of LabSwitch objects required for this Lab.
This list is usually passed to Initialize-LabSwitch to configure the switches required for this lab.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$Switches = Get-LabSwitch -Lab $Lab
Loads a Lab and pulls the array of switches from it.

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

An optional array of Switch names.

Only Switches matching names in this list will be pulled into the returned in the array.

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

### Returns an array of LabSwitch objects

## NOTES

## RELATED LINKS
