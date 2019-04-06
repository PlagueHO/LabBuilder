---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Initialize-LabVMTemplateVHD

## SYNOPSIS

Scans through an array of LabVMTemplateVHD objects and creates them from the ISO if missing.

## SYNTAX

```powershell
Initialize-LabVMTemplateVHD [-Lab] <Object> [[-Name] <String[]>] [[-VMTemplateVHDs] <LabVMTemplateVHD[]>]
 [<CommonParameters>]
```

## DESCRIPTION

This function will take an array of LabVMTemplateVHD objects from a Lab or it will
extract the arrays itself if it is not provided and ensure that each VHD file is available.

If the VHD file is not available then it will attempt to create it from the ISO.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$VMTemplateVHDs = Get-LabVMTemplateVHD -Lab $Lab
Initialize-LabVMTemplateVHD -Lab $Lab -VMTemplateVHDs $VMTemplateVHDs
Loads a Lab and pulls the array of VM Template VHDs from it and then
ensures all the VHDs are available.

### EXAMPLE 2

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

Initialize-LabVMTemplateVHD -Lab $Lab
Loads a Lab and then ensures VM Template VHDs all the VHDs are available.

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

Only VM Template VHDs matching names in this list will be initialized.

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

The array of LabVMTemplateVHD objects pulled from the Lab using Get-LabVMTemplateVHD

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

### None

## NOTES

## RELATED LINKS
