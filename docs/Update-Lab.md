---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Update-Lab

## SYNOPSIS

Update a Lab.

## SYNTAX

### Lab (Default)

```powershell
Update-Lab [-Lab] <Object> [<CommonParameters>]
```

### File

```powershell
Update-Lab [-ConfigPath] <String> [[-LabPath] <String>] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will update the existing Hyper-V lab environment defined by the
LabBuilder configuration file provided.

If components of the Lab are missing they will be added.

If components of the Lab already exist, they will be updated if they differ
from the settings in the Configuration file.

## EXAMPLES

### EXAMPLE 1

```powershell
Update-Lab -ConfigPath c:\mylab\config.xml
```

Update the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE 2

```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Update-Lab
```

Update the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

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

The optional path to update the Lab in - overrides the LabPath setting in the
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

The Lab object returned by Get-Lab of the lab to update.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### None

## NOTES

## RELATED LINKS
