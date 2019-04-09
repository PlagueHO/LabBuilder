---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Get-Lab

## SYNOPSIS

Loads a Lab Builder Configuration file and returns a Lab object

## SYNTAX

```powershell
Get-Lab [-ConfigPath] <String> [[-LabPath] <String>] [-SkipXMLValidation] [<CommonParameters>]
```

## DESCRIPTION

Takes the path to a valid LabBuilder Configiration XML file and loads it.

It will perform simple validation on the XML file and throw an exception
if any of the validation tests fail.

At load time it will also add temporary configuration attributes to the in
memory configuration that are used by other LabBuilder functions.
So loading
XML Configurartion without using this function is not advised.

## EXAMPLES

### EXAMPLE 1

```powershell
$MyLab = Get-Lab -ConfigPath c:\MyLab\LabConfig1.xml
```

Loads the LabConfig1.xml configuration and returns Lab object.

## PARAMETERS

### -ConfigPath

This is the path to the Lab Builder configuration file to load.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LabPath

This is an optional path that is used to Override the LabPath in the config
file passed.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipXMLValidation

{{Fill SkipXMLValidation Description}}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### The Lab object representing the Lab Configuration that was loaded.

## NOTES

## RELATED LINKS
