---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# New-Lab

## SYNOPSIS

Creates a new Lab Builder Configuration file and Lab folder.

## SYNTAX

```powershell
New-Lab [-ConfigPath] <String> [-LabPath] <String> [-Name] <String> [[-Version] <String>] [[-Id] <String>]
 [[-Description] <String>] [[-DomainName] <String>] [[-Email] <String>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION

This function will take a path to a new Lab folder and a path or filename
for a new Lab Configuration file and creates them using the standard XML
template.

It will also copy the DSCLibrary folder as well as the create an empty
ISOFiles and VHDFiles folder in the Lab folder.

After running this function the VMs, VMTemplates, Switches and VMTemplateVHDs
in the new Lab Configuration file would normally be customized to for the new
Lab.

## EXAMPLES

### EXAMPLE 1

```powershell
$MyLab = New-Lab `
```

-ConfigPath c:\MyLab\LabConfig1.xml \`
    -LabPath c:\MyLab \`
    -LabName 'MyLab' \`
    -LabVersion '1.2'
Creates a new Lab Configration file LabConfig1.xml and also a Lab folder
c:\MyLab and populates it with default DSCLibrary file and supporting folders.

## PARAMETERS

### -ConfigPath

This is the path to the Lab Builder configuration file to create.
If it is
not rooted the configuration file is created in the LabPath folder.

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

This is a required path of the new Lab to create.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name

This is a required name of the Lab that gets added to the new Lab Configration
file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version

This is a required version of the Lab that gets added to the new Lab Configration
file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 1.0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Id

This is the optional Lab Id that gets set in the new Lab Configuration
file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description

This is the optional Lab description that gets set in the new Lab Configuration
file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DomainName

This is the optional Lab domain name that gets set in the new Lab Configuration
file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Email

This is the optional Lab email address that gets set in the new Lab Configuration
file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: None
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

### The Lab object representing the new Lab Configuration that was created

## NOTES

## RELATED LINKS
