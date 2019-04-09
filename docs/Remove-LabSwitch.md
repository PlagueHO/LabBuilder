---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Remove-LabSwitch

## SYNOPSIS

Removes all Hyper-V Virtual Switches provided.

## SYNTAX

```powershell
Remove-LabSwitch [-Lab] <Object> [[-Name] <String[]>] [[-Switches] <LabSwitch[]>]
[-RemoveExternal] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet is used to remove any Hyper-V Virtual Switches that were created by
the Initialize-LabSwitch cmdlet.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$Switches = Get-LabSwitch -Lab $Lab
Remove-LabSwitch -Lab $Lab -Switches $Switches
Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml

### EXAMPLE 2

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

Remove-LabSwitch -Lab $Lab
Removes any Hyper-V switches in the configured in the Lab c:\mylab\config.xml

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

An optional array of Switch names.

Only Switches matching names in this list will be removed.

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

If not provided it will attempt to pull the array from the Lab object.

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

### -RemoveExternal

By default, external switches will not be removed. Using this switch
will allow External switches to be deleted by the function.

```yaml
Type: Switch
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
