---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Initialize-LabSwitch

## SYNOPSIS

Creates Hyper-V Virtual Switches from a provided array of LabSwitch objects.

## SYNTAX

```powershell
Initialize-LabSwitch [-Lab] <Object> [[-Name] <String[]>] [[-Switches] <LabSwitch[]>] [<CommonParameters>]
```

## DESCRIPTION

Takes an array of LabSwitch objectsthat were pulled from a Lab object by calling
Get-LabSwitch and ensures that they Hyper-V Virtual Switches on the system
are configured to match.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$Switches = Get-LabSwitch -Lab $Lab
Initialize-LabSwitch -Lab $Lab -Switches $Switches
Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml

### EXAMPLE 2

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

Initialize-LabSwitch -Lab $Lab
Initializes the Hyper-V switches in the configured in the Lab c:\mylab\config.xml

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

An optional array of Switch names.

Only Switches matching names in this list will be initialized.

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

### -Switches

The array of LabSwitch objects pulled from the Lab using Get-LabSwitch.

If not provided it will attempt to pull the array from the Lab object provided.

```yaml
Type: LabSwitch[]
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
