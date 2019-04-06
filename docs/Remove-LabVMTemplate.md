---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Remove-LabVMTemplate

## SYNOPSIS

Removes all Lab Virtual Machine Template VHDs.

## SYNTAX

```powershell
Remove-LabVMTemplate [-Lab] <Object> [[-Name] <String[]>] [[-VMTemplates] <LabVMTemplate[]>]
 [<CommonParameters>]
```

## DESCRIPTION

This cmdlet is used to remove any Virtual Machine Template VHDs that were copied when
creating this Lab.

This function should never be run unless the Lab has no Differencing Disks using these
Template VHDs or the Lab is being completely removed.
Removing these Template VHDs if
Lab Virtual Machines are using these templates as differencing disk parents will cause
the Lab Virtual Hard Drives to become corrupt.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$VMTemplates = Get-LabVMTemplate -Lab $Lab
Remove-LabVMTemplate -Lab $Lab -VMTemplates $VMTemplates
Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml

### EXAMPLE 2

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

Remove-LabVMTemplate -Lab $Lab
Removes any Virtual Machine template VHDs configured in the Lab c:\mylab\config.xml

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

Only VM Templates matching names in this list will be removed.

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

### -VMTemplates

The array of LabVMTemplate objects pulled from the Lab using Get-LabVMTemplate.

If not provided it will attempt to pull the list from the Lab.

```yaml
Type: LabVMTemplate[]
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
