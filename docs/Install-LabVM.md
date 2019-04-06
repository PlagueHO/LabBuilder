---
external help file: LabBuilder-help.xml
Module Name: LabBuilder
online version:
schema: 2.0.0
---

# Install-LabVM

## SYNOPSIS

Starts a Lab VM and ensures it has been Initialized.

## SYNTAX

```powershell
Install-LabVM [-Lab] <Object> [[-VM] <LabVM>] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet is used to start up a Lab VM for the first time.

It will start the VM if it is off.

If the VM is a Server OS or Nano Server then it will also perform an initial setup:

 - It will ensure that initial setup has been completed and a self-signed certificate has
   been created by the VM and downloaded to the LabBuilder folder.

 - It will also ensure DSC is configured for the VM.

## EXAMPLES

### EXAMPLE 1

```powershell
$Lab = Get-Lab -ConfigPath c:\mylab\config.xml
```

$VMs = Get-LabVM -Lab $Lab
$Session = Install-LabVM -VM $VMs\[0\]
Start up the first VM in the Lab c:\mylab\config.xml and initialize it.

## PARAMETERS

### -Lab

{{Fill Lab Description}}

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

### -VM

The LabVM Object referring to the VM to start to.

```yaml
Type: LabVM
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
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
