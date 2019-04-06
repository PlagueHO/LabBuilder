---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Initialize-LabResourceModule

## SYNOPSIS

Downloads the Resource Modules from a provided array.

## SYNTAX

```powershell
Initialize-LabResourceModule [-Lab] <Object> [[-Name] <String[]>] [[-ResourceModules] <LabResourceModule[]>]
 [<CommonParameters>]
```

## DESCRIPTION

Takes an array of LabResourceModule objects ane ensures the Resource Modules are available in
the PowerShell Modules folder.
If they are not they will be downloaded.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$ResourceModules = Get-LabResourceModule -Lab $Lab
Initialize-LabResourceModule -Lab $Lab -ResourceModules $ResourceModules
Initializes the Resource Modules in the configured in the Lab c:\mylab\config.xml

### EXAMPLE 2

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

Initialize-LabResourceModule -Lab $Lab
Initializes the Resource Modules in the configured in the Lab c:\mylab\config.xml

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

An optional array of Module names.

Only Module Resources matching names in this list will be pulled into the returned in the array.

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

### -ResourceModules

The array of Resource Modules pulled from the Lab using Get-LabResourceModule.

If not provided it will attempt to pull the list from the Lab.

```yaml
Type: LabResourceModule[]
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
