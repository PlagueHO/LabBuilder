---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Get-LabVMTemplateVHD

## SYNOPSIS

Gets an Array of TemplateVHDs for a Lab.

## SYNTAX

```powershell
Get-LabVMTemplateVHD [-Lab] <Object> [[-Name] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

Takes a provided Lab and returns the list of Template Disks that will be used to
create the Virtual Machines in this lab.
This list is usually passed to
Initialize-LabVMTemplateVHD.

It will validate the paths to the ISO folder as well as to the ISO files themselves.

If any ISO files references can't be found an exception will be thrown.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
Loads a Lab and pulls the array of TemplateVHDs from it.

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

An optional array of VM Template VHD names.

Only VM Template VHDs matching names in this list will be returned in the array.

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

### Returns an array of LabVMTemplateVHD objects

It will return Null if the TemplateVHDs node does not exist or contains no TemplateVHD nodes

## NOTES

## RELATED LINKS
