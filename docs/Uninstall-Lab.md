---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Uninstall-Lab

## SYNOPSIS

Uninstall the components of an existing Lab.

## SYNTAX

### Lab (Default)

```powershell
Uninstall-Lab [-Lab] <Object> [-RemoveSwitch] [-RemoveVMTemplate] [-RemoveVMFolder] [-RemoveVMTemplateVHD]
 [-RemoveLabFolder] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### File

```powershell
Uninstall-Lab [-ConfigPath] <String> [[-LabPath] <String>] [-RemoveSwitch] [-RemoveVMTemplate]
 [-RemoveVMFolder] [-RemoveVMTemplateVHD] [-RemoveLabFolder] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

This function will attempt to remove the components of the lab specified
in the provided LabBuilder configuration file.

It will always remove any Lab Virtual Machines, but can also optionally
remove:
Switches
VM Templates
VM Template VHDs

## EXAMPLES

### EXAMPLE 1

```powershell
Uninstall-Lab `
```

-ConfigPath c:\mylab\config.xml \`
    -RemoveSwitch\`
    -RemoveVMTemplate \`
    -RemoveVMFolder \`
    -RemoveVMTemplateVHD \`
    -RemoveLabFolder
Completely uninstall all components in the lab defined in the
c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE 2

```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Uninstall-Lab `
```

-RemoveSwitch\`
    -RemoveVMTemplate \`
    -RemoveVMFolder \`
    -RemoveVMTemplateVHD \`
    -RemoveLabFolder
Completely uninstall all components in the lab defined in the
c:\mylab\config.xml LabBuilder configuration file.

## PARAMETERS

### -ConfigPath

The path to the LabBuilder configuration XML file.

```yaml
Type: String
Parameter Sets: File
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LabPath

The optional path to uninstall the Lab from - overrides the LabPath setting in the
configuration file.

```yaml
Type: String
Parameter Sets: File
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Lab

The Lab object returned by Get-Lab of the lab to uninstall.

```yaml
Type: Object
Parameter Sets: Lab
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -RemoveSwitch

Causes the switches defined by this to be removed.

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

### -RemoveVMTemplate

Causes the VM Templates created by this to be be removed.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveVMFolder

Causes the VM folder created to contain the files for any the
VMs in this Lab to be removed.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveVMTemplateVHD

Causes the VM Template VHDs that are used in this lab to be
deleted.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveLabFolder

Causes the entire folder containing this Lab to be deleted.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf

Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
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
