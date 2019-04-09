---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Remove-LabVM

## SYNOPSIS

Removes all Lab Virtual Machines.

## SYNTAX

```powershell
Remove-LabVM [-Lab] <Object> [[-Name] <String[]>] [[-VMs] <LabVM[]>] [-RemoveVMFolder] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet is used to remove any Virtual Machines that were created as part of this
Lab.

It can also optionally delete the folder and all files created as part of this Lab
Virutal Machine.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$VMTemplates = Get-LabVMTemplate -Lab $Lab
$VMs = Get-LabVs -Lab $Lab -VMTemplates $VMTemplates
Remove-LabVM -Lab $Lab -VMs $VMs
Removes any Virtual Machines configured in the Lab c:\mylab\config.xml

### EXAMPLE 2

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

Remove-LabVM -Lab $Lab
Removes any Virtual Machines configured in the Lab c:\mylab\config.xml

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

Only VMs matching names in this list will be removed.

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

The array of LabVM objects pulled from the Lab using Get-LabVM.

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

### -RemoveVMFolder

Causes the folder created to contain the Virtual Machine in this lab to be deleted.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: False
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
