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
 1. Make a folder where all your Lab files will go (e.g. VMs, VHDs, ISOs, scripts) - e.g. c:\MyLab
 2. Copy your the Lab Configuration XML file into that folder (try one of the sample configurations in the **Samples** folder).
 3. Edit the Lab Configuration XML file and customize the Settings to suit (specifically the LabPath setting). 
 4. Make a folder in your Lab folder for your Windows ISO files called **isofiles** - e.g. c:\MyLab\ISOFiles
 5. Copy any ISO files into this folder that your lab will use.
 6. Make a folder in your Lab folder for your VHD boot templates (converted from the ISO files) **vhdfiles** - e.g. c:\MyLab\VHDFiles
 7. Run the following commands in an Administrative PowerShell window:
```powershell
Import-Module LabBuilder
Install-Lab -Path 'c:\MyLab\Configuration.xml'
```

This will create a new Lab using the c:\MyLab\Configuration.xml file.


ISO Files
---------
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


Configuration XML
-----------------



Versions
--------
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
