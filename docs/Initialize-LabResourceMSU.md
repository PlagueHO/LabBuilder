---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Initialize-LabResourceMSU

## SYNOPSIS

Downloads the Resource MSU packages from a provided array.

## SYNTAX

```powershell
Initialize-LabResourceMSU [-Lab] <Object> [[-Name] <String[]>] [[-ResourceMSUs] <LabResourceMSU[]>]
 [<CommonParameters>]
```

## DESCRIPTION

Takes an array of LabResourceMSU objects and ensures the MSU packages are available in the
Lab Resources folder.
If they are not they will be downloaded.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$ResourceMSUs = Get-LabResourceMSU -Lab $Lab
Initialize-LabResourceMSU -Lab $Lab -ResourceMSUs $ResourceMSUs
Initializes the Resource MSUs in the configured in the Lab c:\mylab\config.xml

### EXAMPLE 2

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

Initialize-LabResourceMSU -Lab $Lab
Initializes the Resource MSUs in the configured in the Lab c:\mylab\config.xml

## PARAMETERS

### -Lab

Contains Lab object that was loaded by the Get-Lab object.

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

An optional array of MSU packages names.

Only MSU packages matching names in this list will be pulled into the returned in the array.

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

### -ResourceMSUs

The array of ResourceMSU objects pulled from the Lab using Get-LabResourceModule.

If not provided it will attempt to pull the list from the Lab.

```yaml
Type: LabResourceMSU[]
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
