Get-Lab
-------
### SYNOPSIS
Loads a Lab Builder Configuration file and returns a Lab object

### DESCRIPTION
Takes the path to a valid LabBuilder Configiration XML file and loads it.

It will perform simple validation on the XML file and throw an exception
if any of the validation tests fail.

At load time it will also add temporary configuration attributes to the in
memory configuration that are used by other LabBuilder functions. So loading
XML Configurartion without using this function is not advised.

### PARAMETER ConfigPath
This is the path to the Lab Builder configuration file to load.

### PARAMETER LabPath
This is an optional path that is used to Override the LabPath in the config file passed.

### EXAMPLE
$MyLab = Get-Lab -ConfigPath c:\MyLab\LabConfig1.xml
Loads the LabConfig1.xml configuration and returns Lab object.

### OUTPUTS
The Lab object representing the Lab Configuration that was loaded.


New-Lab
-------
### SYNOPSIS
Creates a new Lab Builder Configuration file and Lab folder.

### DESCRIPTION
This function will take a path to a new Lab folder and a path or filename 
for a new Lab Configuration file and creates them using the standard XML
template.

It will also copy the DSCLibrary folder as well as the create an empty
ISOFiles and VHDFiles folder in the Lab folder.

After running this function the VMs, VMTemplates, Switches and VMTemplateVHDs
in the new Lab Configuration file would normally be customized to for the new
Lab.

### PARAMETER ConfigPath
This is the path to the Lab Builder configuration file to create. If it is
not rooted the configuration file is created in the LabPath folder.

### PARAMETER LabPath
This is a required path of the new Lab to create.

### PARAMETER Name
This is a required name of the Lab that gets added to the new Lab Configration file.

### PARAMETER Version
This is a required version of the Lab that gets added to the new Lab Configration file.

### PARAMETER Id
This is the optional Lab Id that gets set in the new Lab Configuration file.

### PARAMETER Description
This is the optional Lab description that gets set in the new Lab Configuration file.

### PARAMETER DomainName
This is the optional Lab domain name that gets set in the new Lab Configuration file.

### PARAMETER Email
This is the optional Lab email address that gets set in the new Lab Configuration file.

### EXAMPLE
```powershell
$MyLab = New-Lab `
    -ConfigPath c:\MyLab\LabConfig1.xml `
    -LabPath c:\MyLab `
    -LabName 'MyLab' `
    -LabVersion '1.2'
```
Creates a new Lab Configration file LabConfig1.xml and also a Lab folder
c:\MyLab and populates it with default DSCLibrary file and supporting folders.

### OUTPUTS
The Lab object representing the new Lab Configuration that was created.


Install-Lab
-----------
### SYNOPSIS
Installs or Update a Lab.

### DESCRIPTION
This cmdlet will install an entire Hyper-V lab environment defined by the
LabBuilder configuration file provided.

If components of the Lab already exist, they will be updated if they differ
from the settings in the Configuration file.

The Hyper-V component can also be optionally installed if it is not.

### PARAMETER ConfigPath
The path to the LabBuilder configuration XML file.

### PARAMETER LabPath
The optional path to install the Lab to - overrides the LabPath setting in the
configuration file.

### PARAMETER Lab
The Lab object returned by Get-Lab of the lab to install.    

### PARAMETER CheckEnvironment
Whether or not to check if Hyper-V is installed and install it if missing.

### EXAMPLE
```powershell
Install-Lab -ConfigPath c:\mylab\config.xml
```
Install the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE
```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Install-Lab
```
Install the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### OUTPUTS
None


Update-Lab
----------
### SYNOPSIS
Update a Lab.

### DESCRIPTION
This cmdlet will update the existing Hyper-V lab environment defined by the
LabBuilder configuration file provided.

If components of the Lab are missing they will be added.

If components of the Lab already exist, they will be updated if they differ
from the settings in the Configuration file.

### PARAMETER ConfigPath
The path to the LabBuilder configuration XML file.

### PARAMETER LabPath
The optional path to update the Lab in - overrides the LabPath setting in the
configuration file.

### PARAMETER Lab
The Lab object returned by Get-Lab of the lab to update.    

### EXAMPLE
```powershell
Update-Lab -ConfigPath c:\mylab\config.xml
```
Update the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE
```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Update-Lab
```
Update the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### OUTPUTS
None


Uninstall-Lab
-------------
### SYNOPSIS
Uninstall the components of an existing Lab.

### DESCRIPTION
This function will attempt to remove the components of the lab specified
in the provided LabBuilder configuration file.

It will always remove any Lab Virtual Machines, but can also optionally
remove:
Switches
VM Templates
VM Template VHDs

### PARAMETER ConfigPath
The path to the LabBuilder configuration XML file.

### PARAMETER LabPath
The optional path to uninstall the Lab from - overrides the LabPath setting in the
configuration file.

### PARAMETER Lab
The Lab object returned by Get-Lab of the lab to uninstall. 

### PARAMETER RemoveSwitch
Causes the switches defined by this to be removed.

### PARAMETER RemoveVMTemplate
Causes the VM Templates created by this to be be removed. 

### PARAMETER RemoveVMFolder
Causes the VM folder created to contain the files for any the
VMs in this Lab to be removed.

### PARAMETER RemoveVMTemplateVHD
Causes the VM Template VHDs that are used in this lab to be
deleted.

### PARAMETER RemoveLabFolder
Causes the entire folder containing this Lab to be deleted.

### EXAMPLE
```powershell
Uninstall-Lab `
    -Path c:\mylab\config.xml `
    -RemoveSwitch`
    -RemoveVMTemplate `
    -RemoveVMFolder `
    -RemoveVMTemplateVHD `
    -RemoveLabFolder
```
Completely uninstall all components in the lab defined in the
c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE
```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Uninstall-Lab `
    -RemoveSwitch`
    -RemoveVMTemplate `
    -RemoveVMFolder `
    -RemoveVMTemplateVHD `
    -RemoveLabFolder
```
Completely uninstall all components in the lab defined in the
c:\mylab\config.xml LabBuilder configuration file.

### OUTPUTS
None


Start-Lab
---------
### SYNOPSIS
Starts an existing Lab.

### DESCRIPTION
This cmdlet will start all the Hyper-V virtual machines definied in a Lab
configuration.

It will use the Bootorder attribute (if defined) for any VMs to determine
the order they should be booted in. If a Bootorder is not specified for a
machine, it will be booted after all machines with a defined boot order.

The lower the Bootorder value for a machine the earlier it will be started
in the start process.

Machines will be booted in series, with each machine starting once the
previous machine has completed startup and has a management IP address.

If a Virtual Machine in the Lab is already running, it will be ignored
and the next machine in series will be started.

If more than one Virtual Machine shares the same Bootorder value, then
these machines will be booted in parallel, with the boot process only
continuing onto the next Bootorder when all these machines are booted.

If a Virtual Machine specified in the configuration is not found an
exception will be thrown.

If a Virtual Machine takes longer than the StartupTimeout then an exception
will be thown but the Start process will continue.

If a Bootorder of 0 is specifed then the Virtual Machine will not be booted at
all. This is useful for things like Root CA VMs that only need to started when
the Lab is created.

### PARAMETER ConfigPath
The path to the LabBuilder configuration XML file.

### PARAMETER LabPath
The optional path to install the Lab to - overrides the LabPath setting in the
configuration file.

### PARAMETER Lab
The Lab object returned by Get-Lab of the lab to start.     

### PARAMETER StartupTimeout
The maximum number of seconds that the process will wait for a VM to startup.
Defaults to 90 seconds.

### EXAMPLE
```powershell
Start-Lab -ConfigPath c:\mylab\config.xml
```
Start the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE
```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Start-Lab
```
Start the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### OUTPUTS
None
    

Stop-Lab
--------
### SYNOPSIS
Stop an existing Lab.

### DESCRIPTION
This cmdlet will stop all the Hyper-V virtual machines definied in a Lab
configuration.

It will use the Bootorder attribute (if defined) for any VMs to determine
the order they should be shutdown in. If a Bootorder is not specified for a
machine, it will be shutdown before all machines with a defined boot order.

The higher the Bootorder value for a machine the earlier it will be shutdown
in the stop process.

The Virtual Machines will be shutdown in REVERSE Bootorder.

Machines will be shutdown in series, with each machine shutting down once the
previous machine has completed shutdown.

If a Virtual Machine in the Lab is already shutdown, it will be ignored
and the next machine in series will be shutdown.

If more than one Virtual Machine shares the same Bootorder value, then
these machines will be shutdown in parallel, with the shutdown process only
continuing onto the next Bootorder when all these machines are shutdown.

If a Virtual Machine specified in the configuration is not found an
exception will be thrown.

If a Virtual Machine takes longer than the ShutdownTimeout then an exception
will be thown but the Stop process will continue.

### PARAMETER ConfigPath
The path to the LabBuilder configuration XML file.

### PARAMETER LabPath
The optional path to install the Lab to - overrides the LabPath setting in the
configuration file.

### PARAMETER Lab
The Lab object returned by Get-Lab of the lab to start.     

### PARAMETER ShutdownTimeout
The maximum number of seconds that the process will wait for a VM to shutdown.
Defaults to 30 seconds.

### EXAMPLE
```powershell
Stop-Lab -ConfigPath c:\mylab\config.xml
```
Stop the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### EXAMPLE
```powershell
Get-Lab -ConfigPath c:\mylab\config.xml | Stop-Lab
```
Stop the lab defined in the c:\mylab\config.xml LabBuilder configuration file.

### OUTPUTS
None
