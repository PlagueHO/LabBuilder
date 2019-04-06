---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Install-Lab

## SYNOPSIS

Installs or Update a Lab.

## SYNTAX

### Lab (Default)

```powershell
Install-Lab [-Lab] <Object> [-CheckEnvironment] [-Force] [-OffLine] [<CommonParameters>]
```

### File

```powershell
Install-Lab [-ConfigPath] <String> [[-LabPath] <String>] [-CheckEnvironment] [-Force] [-OffLine]
 [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will install an entire Hyper-V lab environment defined by the
LabBuilder configuration file provided.

If components of the Lab already exist, they will be updated if they differ
from the settings in the Configuration file.

The Hyper-V component can also be optionally installed if it is not.

## EXAMPLES

### EXAMPLE 1

```powershell
Install-Lab -ConfigPath c:\mylab\config.xml
```

Install the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE 2

```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Install-Lab
```

Install the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

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

The optional path to install the Lab to - overrides the LabPath setting in the
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

The Lab object returned by Get-Lab of the lab to install.

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

### -CheckEnvironment

Whether or not to check if Hyper-V is installed and install it if missing.

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

### -Force

This will force the Lab to be installed, automatically suppressing any confirmations.

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

### -OffLine

{{Fill OffLine Description}}

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### None

## NOTES

## RELATED LINKS
