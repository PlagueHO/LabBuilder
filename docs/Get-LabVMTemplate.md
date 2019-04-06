---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Get-LabVMTemplate

## SYNOPSIS

Gets an Array of VM Templates for a Lab.

## SYNTAX

```powershell
Get-LabVMTemplate [-Lab] <Object> [[-Name] <String[]>] [[-VMTemplateVHDs] <LabVMTemplateVHD[]>]
 [<CommonParameters>]
```

## DESCRIPTION

Takes the provided Lab and returns the list of Virtul Machine template machines
that will be used to create the Virtual Machines in this lab.

This list is usually passed to Initialize-LabVMTemplate.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$VMTemplates = Get-LabVMTemplate -Lab $Lab
Loads a Lab and pulls the array of VMTemplates from it.

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

An optional array of VM Template names.

Only VM Templates matching names in this list will be returned in the array.

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

### -VMTemplateVHDs

The array of VMTemplateVHDs pulled from the Lab using Get-LabVMTemplateVHD.

If not provided it will attempt to pull the list from the Lab.

```yaml
Type: LabVMTemplateVHD[]
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

### Returns an array of LabVMTemplate objects

## NOTES

## RELATED LINKS
