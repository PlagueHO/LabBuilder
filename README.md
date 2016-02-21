LabBuilder
==========

[![Join the chat at https://gitter.im/PlagueHO/LabBuilder](https://badges.gitter.im/PlagueHO/LabBuilder.svg)](https://gitter.im/PlagueHO/LabBuilder?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Build status](https://ci.appveyor.com/api/projects/status/rcg7xmm97qhg2bjr/branch/master?svg=true)](https://ci.appveyor.com/project/PlagueHO/labbuilder/branch/master)


Summary
-------
This module will build a multiple machine Hyper-V Lab environment from an XML configuration file and other optional installation scripts.

Introduction
------------
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
-----
The general goals of this project are:
+ Enable "one-click" creation of a Hyper-V Lab environment.
+ Enable non-developers to easily define Lab environments.
+ Support multiple Lab environments on the same Hyper-V host.
+ Allow a Lab environment to span or be installed on a remote Hyper-V host.
+ Ensure that multiple Lab environments are completely isolated from each other.
+ Minimize Lab footprint by utilizing Differencing disks where possible.
+ Allow GUI based tools to be easily created to create Lab configurations.
+ Enable new Lab VM machine types to be configured by supplying different DSC library resources.

Basic Usage Guide
-----------------
The use of this module is fairly simple from a process standpoint with the bulk of the work creating a Lab going into the creation of the configuration XML that defines it. But if there is a Lab configuration already available that fits your needs then there is almost nothing to do.

A Lab consists of the following items:
- A configuration XML file that defines the Virtual Machines, Switches, the DSC config files and anything else related to how the Lab is set up.
- Copies of the Windows Operating System Images used in the Lab which are: 
   - Either VHDs containing Syspreped Windows images.
   - Or Windows Installation media ISO files (these will be automatically converted to VHDs for you during Lab creation).
- Any DSC configuration files that are used to configure the Lab VMs after the OS initial start up has completed.

There are a library of DSC configuration files for various machine types already defined and available for you to use in the **DSCLibrary** folder.

Once these files are available the process of setting up the Lab is simple.
 1. Make a folder where all your Lab files will go - e.g. c:\MyLab
 2. Copy your the Lab Configuration XML file into that folder (try one of the sample configurations in the **Samples** folder).
 3. Edit the Lab Configuration XML file and customize the Settings to suit (specifically the LabPath setting). 
 4. Make a folder in your Lab folder for your Windows ISO files called **isofiles** - e.g. c:\MyLab\ISOFiles
 5. Copy any ISO files into this folder that your lab will use.
 6. Run the following commands in an Administrative PowerShell window:
```powershell
Import-Module LabBuilder
Install-Lab -Path 'c:\MyLab\Configuration.xml'
```

This will create a new Lab using the c:\MyLab\Configuration.xml file.

Requirements
------------
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
  
Versions
--------
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

Functions
---------

Example Usage
-------------

Links
-----
- [GitHub Repository](https://github.com/PlagueHO/LabBuilder/)
- [Blog](https://dscottraynsford.wordpress.com/)
