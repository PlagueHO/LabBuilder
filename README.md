LabBuilder
==========

[![Join the chat at https://gitter.im/PlagueHO/LabBuilder](https://badges.gitter.im/PlagueHO/LabBuilder.svg)](https://gitter.im/PlagueHO/LabBuilder?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Build status](https://ci.appveyor.com/api/projects/status/rcg7xmm97qhg2bjr/branch/master?svg=true)](https://ci.appveyor.com/project/PlagueHO/labbuilder/branch/master)


Summary
=======
This module will build a multiple machine Hyper-V Lab environment from an XML configuration file and other optional installation scripts.


Introduction
============
While studying for some of my Microsoft certifications I had a need to quickly and easily spin up various Hyper-V Lab environments so that I could experiment with and learn the technologies involved.

Originally I performed this process manually, creating Hyper-V VM's and environments to suit. But as the complexity of the Lab environment increased (e.g. take multi-tier PKIs) manually building these Labs became unmanageable. Also, if I wanted to repeat a particular process multiple times I would have to either snapshot multiple VMs or manually back them all up. This quickly became unsupportable as snapshots slows VMs down and constant backups of large Hyper-V environments was slow and also limited by space. This gave me a basic set of requirements for this module.

So as a solution to these problems I decided that I wanted a declarative approach to automating the process of building a Lab environment.

This had the following advantages:
+ Building a new Lab with multiple VMs was automated.
+ Creation of the actual Lab VMs could be done without supervision.
+ Once a basic Lab was created more complex Lab environments could be created by cloning the original XML configuration and tailoring it.
+ Configuration files could be distributed easily.
+ Because the post setup configuration of the Lab VM machines was performed via DSC this gave me an opportunity to work with DSC to a greater depth.
+ The configuration files could be created by people without knowledge of PowerShell or DSC.
+ UI based applications could be easily created to generate the configuration XML.


Goals
=====
The general goals of this module are:
+ **One-Click Create**: Enable "one-click" creation of a Hyper-V Lab environment.
+ **Easy Configuration**: Enable non-developers to easily define Lab environments.
+ **Multiple Labs**: Support multiple Lab environments on the same Hyper-V host.
+ **Stretched Labs**: Allow a Lab environment to span or be installed on a remote Hyper-V host.
+ **Lab Isolation**: Ensure that multiple Lab environments are completely isolated from each other.
+ **Minimal Disk Usage**: Minimize Lab footprint by utilizing differencing disks where possible.
+ **Configuration Flexibility**: Allow GUI based tools to be easily created to create Lab configurations.
+ **Extensible**: Enable new Lab VM machine types to be configured by supplying different DSC library resources.


Basic Usage Guide
=================
The use of this module is fairly simple from a process standpoint with the bulk of the work creating a Lab going into the creation of the configuration XML that defines it. But if there is a Lab configuration already available that fits your needs then there is almost nothing to do.

A Lab consists of the following items:
- A configuration XML file that defines the Virtual Machines, Switches, the DSC config files and anything else related to how the Lab is set up.
- Copies of the Windows Operating System Images used in the Lab which are: 
   - Either VHDs containing Syspreped Windows images.
   - Or Windows Installation media ISO files (these will be automatically converted to VHDs for you during Lab creation).
- Any DSC configuration files that are used to configure the Lab VMs after the OS initial start up has completed.

There are a library of DSC configuration files for various machine types already defined and available for you to use in the **DSCLibrary** folder.

Once these files are available the process of setting up the Lab is simple.
 1. Make a folder where all your Lab files will go (e.g. VMs, VHDs, ISOs, scripts) - e.g. c:\MyLab
 2. Copy your the Lab Configuration XML file into that folder (try one of the sample configurations in the **Samples** folder).
 3. Edit the Lab Configuration XML file and customize the Settings to suit (specifically the LabPath setting). 
 4. Make a folder in your Lab folder for your Windows ISO files called **isofiles** - e.g. c:\MyLab\ISOFiles
 5. Copy any ISO files into this folder that your lab will use.
 6. Make a folder in your Lab folder for your VHD boot templates (converted from the ISO files) **vhdfiles** - e.g. c:\MyLab\VHDFiles
 7. Run the following commands in an Administrative PowerShell window:
```powershell
Import-Module LabBuilder
Install-Lab -ConfigPath 'c:\MyLab\Configuration.xml'
```

This will create a new Lab using the c:\MyLab\Configuration.xml file.


ISO Files
=========
During the Install process of a Lab, if the template VHD files to use as boot disks for your VMs, LabBuilder will attempt to convert the required ISO files into VHD boot disks for you.
This will only occur if the ISO files required to build a specific VHD file are found in the ISO folder specified by the Lab.

By default LabBuilder will look in the **isofiles** subfolder of your Lab folder for any ISO files it needs.
You can change the folder that a Lab looks in for the ISO files by changing/setting the _isopath_ attribute of the _<templatevhds>_ node in the configuration
If it can't find an ISO file it needs, you will be notified of an official download location for trial or preview editions of the ISO files (as long as the LabBuilder configuration you're using contains the download URLs).

Some common ISO download locations:  
 - Windows Server 2012 R2: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2012-r2
 - Windows 10 Enterprise: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise
 - Windows Server 2016 TP4: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview

Multiple VHD templates may use the same ISO file in a Lab.
For example, if multiple editions of an Operating system are used in the same lab.

Once an ISO has been converted to an VHD, it will be stored in the VHDFiles folder in your lab folder.
However, if you are using multiple Labs on the same machine you might want to share these VHD files between mutlpile Lab projects to save having to build and store copies for each Lab.
In that case, you can set the _vhdpath_ attribute of the _<templatevhds>_ node in the configuration to a different relative or absolute path.

The conversion process for a single ISO to VHD can take 10-20 minutes depending on your machine.
For this reason multiple Labs can be configured to use the same path to store these VHDs by changing the _vhdpath_ attribute of the _<templatevhds>_ node in the configuration. 


Requirements
============
To use this Module you will require on your Lab Host:
 1. Operating Systems supported:
    - Windows Server 2012
    - Windows Server 2012 R2
    - Windows Server 2016 TP4
    - Windows 8.0
    - Windows 8.1
    - Windows 10
 2. Hyper-V available (which requires intel-VT CPU support).
 3. To use labs that contain Nested Hyper-V hosts only Windows 10 built 10586 or later and Windows Server 2016 TP3 or later are supported.
 4. Copies of the Windows installation media for any Operating Systems that will be used in your Labs.
    * Note: Many Lab configuration files can contain a URL where the relevant trial media can be downloaded from.


Configuration XML
=================
Documentation for the LabBuilder Configuration XML can be found in the file [schema/labbuilderconfig-schema.md](LabBuilder/schema/labbuilderconfig-schema.md).

Cmdlets
=======

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


Versions
========
### Unreleased
* Initialize-LabSwitch: External switch correctly sets Adapter Name.
* IsAdmin: Function removed because was not useful.
* dsclibrary\DC_FORESTDOMAIN.DSC: New DSC Library config for creating child domains in an existing forest.
* Samples\Sample_WS2012R2_MultiForest.xml: Added child domains.
* Get-LabSwitch: Converted to output array of LabSwitch objects.
* Initialize-LabSwitch: Converted to use LabSwitch objects.
                        Fixed bug setting VLAN Id on External and Internal Switch Adapters.
* Remove-LabSwitch: Converted to use LabSwitch objects.
* Tests\Test_Sample_*.ps1: Test-StartLabVM function fixed.
* DSCLibrary\MEMBER_*.DSC.ps1: Updated parameter examples to include DCName parameter.
* DSCLibrary\DC_*.DSC.ps1: Added DNS Zone and forwarder options (setting forwarder requires xDNSServer 1.6.0.0).
* DSCLibrary\MEMBER_DNS.DSC.ps1: Created resource for member DNS servers.
* Get-LabVMTemplateVHD: Converted to output array of LabVMTemplateVHD objects.

### 0.6.0.0
* New-Lab: Function added for creating a new Lab configuration file and basic folder structure.
* Get-Lab: Redundant checks for XML valid removed because convered by XSD schema validation.
* Added Lib\Type.ps1 containing customg LabBuilder Classes and Enumerations.
* Added functions for converting XSD schema to MD.
* Fix to Nano Server Package caching bug.
* DSC Library Domain Join process improved.
* DSC\ConfigFile attribute supports rooted paths.
* VM\UnattendFile attribute supports rooted paths.
* VM\SetupComplete attribute supports rooted paths.
* DSC\ConfigFile Lab setting supports rooted paths.
* VM\UseDifferencingBootDisk default changed to 'Y'.
* GetModulesInDSCConfig: Returns Array of objects containing ModuleName and ModuleVersion.
                         Now returns PSDesiredStateConfiguration module if listed -expected that calling function will ignore if required.
                         Added function to set the Module versions in a DSC Config.
* CreateDSCMOFFiles: Updated to set Module versions in DSC Config files.
* DSC Library: Module Version numbers removed from all DSC Library Configrations. 
* Test Sample file code updated to remove switches when lab uninstalled.
* Uninstall-Lab: Management Switch automatically removed when Lab uninstalled.
* Configuration Schema: Added Resources\MSU element.
                        Added Settings\Resource attribute.
                        Removed VM\Install element support, superceeded by Packages attribute.
* Get-LabResourceModule: Function added.
* Initialize-LabResourceModule: Function added.
* Get-LabResourceMSU: Function added.
* Initialize-LabResourceMSU: Function added.
* Install-Lab: Fix CheckEnvironment bug.
               Added calls to Initialize-LabResourceModule and Initialize-LabResourceMSU.
* DownloadResources: Utility function removed, superceeded by Initialize-LabResourceModule and Initialize-LabResourceMSU functions
* Get-LabVM: Removed Install\MSU support.
* InitializeBootVM: Removed Install\MSU support.
                    Added support for installing Packages from Resources\MSU element.
* Initialize-LabVMTemplateVHD: MSU Resources specified in Packages attribute are added to Template VHD when converted.
* Initialize-LabVMTemplate: MSU Resources specified in Packages attribute are added to Template  when copied.
 
### 0.5.0.0
* BREKAING: Renamed Config parameter to Lab parameter to indicate the object is actually an object that also stores Lab state information.
* Remove-LabVM: Removed parameter 'RemoveVHDs'. Added parameter RemoveVMFolder which causes the VM folder and all contents to be deleted.
* Uninstall-Lab: Renamed "Remove" parameters to be singular names rather than plural.
* Uninstall-Lab: Added parameter 'RemoveLabFolder' which will cause the entire Lab folder to be deleted.
* Uninstall-Lab: Added ShouldProcess support to ask user to confirm actions.
* Update-Lab: Added function which just calls Install-Lab.
* Start-LabVM: Renamed function to Install-LabVM so that it is not confused with Start-VM.
* *-LabSwitch: Added Name array parameter to allow filtering of switches to work with.
* *-LabVMTemplateVHD: Added Name array parameter to allow filtering of VM Template VHDs to work with.
* *-LabVMTemplate: Added Name array parameter to allow filtering of VM Templates to work with.
* *-LabVM: Added Name array parameter to allow filtering of VMs to work with.
* Samples: Updated sample code with additional examples.
* Help completed for all exported cmdlets.
* Get-LabVM: XML now validated against labbuilderconfig-schema.xsd in Schemas folder when loaded -unless SkipXMLValidation switch is passed.
* All sample and test configuration XML files validated against labbuilderconfig-schema.xsd in schemas folder when unit tests run.
* All sample and test configuration XML files updated with namespace -> xmlns="labbuilderconfig".
 
### 0.4.2.0
* Add bootorder VM attribute for controlling stop-lab/start-lab order.
* Added Start-Lab and Stop-Lab cmdlets.
* *-Lab cmdlet documentation added to Readme.md

### 0.4.1.0
* VHDParentPath setting made optional. Defaults to "Virtual Machine Hard Disks" under config.
* Initialize-LabConfiguration function will create labpath and vhdparentpath folders if not exist.
* Removed Test-LabConfiguration function and tests moved to Get-LabConfiguration.
* Added Disconnect-LabVM function to disconnect from a connect Lab VM.
* Fixed bug setting TrustedHosts when connecting to Lab VM.
* Added code to revert TrustedHosts when disconnecting from Lab VM. 
* All non-exported supporting functions moved into separate support libraries.
* Add support for LabId setting that gets prepended to Lab resources.
* Added LabBuilderConfig schema in schema folder.
* Added LabPath parameter to Install-Lab, Uninstall-Lab and Get-LabConfiguration.
* Fix exception in Disconnect-LabVM.
* Fixed Unit tests to retain current folder location.
* Added PS ScriptAnalyzer Error tests to unit tests.
* Display PS ScriptAnalyzer Warnings when unit tests run.
* Remove-LabVMTemplateVHD function added and will be called from Uninstall-Lab.

### 0.4.0.0
* Some secondary non-exported functions moved into separate support libraries.
* Initialize-LabVMTemplate caches NanoServerPackages from VHD template folder to Lab folder.
* Fix exception connecting to VM when TrustedHosts is set to '*'.
* Fix path Lab VM files are created. 
* Support for creating Certificates for Nano Servers on the host added.
 
### 0.3.3.0
* Changed Get-LabSwitch Unit tests to use PesterTestConfig.OK.xml.
* Added support for configuring Nano Server packages for each VM.
* Removed MAC Address minimum/maximum value settings from configuration.
* Fix bug with Wait-LabInitVM failing to copy InitialSetupComplete.txt file.
* Added VMRootPath and LabBuilderFilesPath properties Get-LabVM array containing path where VM and LabBuilder files should be stored respectively.
* Added TemplateVHD in templates/template config node for specifying the template VHD. 

### 0.3.2.0
* Added Initialize-VHD function.
* Added support for formatting Data VHDs.
* Added support for copying multiple folders to DataVHDs.
* Updated Download-ResourceModule to use DownloadAndUnzipFile function.
* Changed name of Settings\VMPath attribute to LabPath. 

### 0.3.1.0
* Disable 'Access Denied' test when connecting to new VM because this error is reported by VM that is still booting up.
* Correct Verbose message shown when Integration Services enabled.
* Added Verbose message to indicate creation of VM Initialization files.
* Correct Verbose message not appearing when mounting VM boot disk image file.
* Moved DSC Config message into Localization data.
* Disabled automatic module push to PSGallery till version 1.0.0.0 or greater.

### 0.3.0.0
* Fix to Module detection regex.
* Updated AppVeyor.yml to push more artifacts.
* Fix issue preventing timeout from triggering.
* Improved handling of Remoting connection by moving into a new function Connect-LabVM
* IP Address of VMs automatically added to WS-Man Trusted Hosts to enable HTTP remoting connection.
* Prevent error if Panther folder doesn't exist in VHD image when creating a new VM.
* Add support for multiple data disks for each VM.
* Add support for creating new data disks by cloning exising VHDs.
* Support for Fixed, Differencing and Shared data disks.
* JSON Object comparison unit tests fixed.
* AppVeyor build status badge added.
* Add support for VM Integration Services flag.
* Initialize-Lab* arrays made optional and will be pulled from config if not passed.
* Configuration parameter changed to Config to reduce size/typing.
* Support for creating VHD boot disks from ISO via TemplateVHD nodes in XML.

### 0.2.0.0
* Code cleanup and refactoring.

### 0.1.0.0
* Initial Release.


Links
-----
- [GitHub Repository](https://github.com/PlagueHO/LabBuilder/)
- [Blog](https://dscottraynsford.wordpress.com/)
