---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Get-LabVM

## SYNOPSIS

Gets an Array of LabVM objects from a Lab.

## SYNTAX

```powershell
Get-LabVM [-Lab] <Object> [[-Name] <String[]>] [[-VMTemplates] <LabVMTemplate[]>] [[-Switches] <LabSwitch[]>]
 [<CommonParameters>]
```

## DESCRIPTION

Takes the provided Lab and returns the list of VM objects that will be created in this lab.
This list is usually passed to Initialize-LabVM.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$VMTemplates = Get-LabVMTemplate -Lab $Lab
$Switches = Get-LabSwitch -Lab $Lab
$VMs = Get-LabVM \`
    -Lab $Lab \`
    -VMTemplates $VMTemplates \`
    -Switches $Switches
Loads a Lab and pulls the array of VMs from it.

### EXAMPLE 2

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$VMs = Get-LabVM -Lab $Lab
Loads a Lab and pulls the array of VMs from it.

## PARAMETERS

### -Lab

Contains the Lab Builder Lab object that was loaded by the Get-Lab object.

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

Only VMs matching names in this list will be returned in the array.

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

Contains the array of LabVMTemplate objects returned by Get-LabVMTemplate from this Lab.

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

### -Switches

Contains the array of LabVMSwitch objects returned by Get-LabSwitch from this Lab.

If not provided it will attempt to pull the list from the Lab.

```yaml
Type: LabSwitch[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### Returns an array of LabVM objects

## NOTES

## RELATED LINKS
