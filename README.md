LabBuilder
==========

[![Join the chat at https://gitter.im/PlagueHO/LabBuilder](https://badges.gitter.im/PlagueHO/LabBuilder.svg)](https://gitter.im/PlagueHO/LabBuilder?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build status](https://ci.appveyor.com/api/projects/status/rcg7xmm97qhg2bjr/branch/master?svg=true)](https://ci.appveyor.com/project/PlagueHO/labbuilder/branch/master)
[![Stories in Ready](https://badge.waffle.io/PlagueHO/LabBuilder.svg?label=ready&title=Ready)](http://waffle.io/PlagueHO/LabBuilder) 

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


Requirements
============
To use this Module you will require on your Lab Host:
 1. Operating Systems supported:
    - Windows Server 2012
    - Windows Server 2012 R2
    - Windows Server 2016 TP5
    - Windows 8.0
    - Windows 8.1
    - Windows 10
 2. **Windows Management Framewok 5.0 (WMF5.0)** installed.

    _WMF 5.0 is installed on Windows 10 and Windows Server 2016 out of the box, but for Windows Server 2012/R2 and Windows 8/8.1 it will need to be installed separately._
    _WMF 5.0 can be downloaded from [here](https://www.microsoft.com/en-us/download/details.aspx?id=50395)._
    
 3. **Hyper-V** available (which requires intel-VT CPU support).
 4. To use labs that contain Nested Hyper-V hosts only Windows 10 built 10586 or later and Windows Server 2016 TP3 or later are supported.
 5. Copies of the **Windows installation media** for any Operating Systems that will be used in your Labs.
    * Note: Most Lab configuration files can contain a URL where the relevant trial media can be downloaded from, but you can use any Windows Install Media source you choose (including custom built ISOs).
 6. An **internet connection** to download the WMF 5.0 MSU and any other optional MSU packages required by the Lab.
    * Note: This only needs to be done during the Install-Lab phase and can be disabled after this phase is complete.
 7. **WS-Man** enabled to allow communication with the Lab Virtual Machines.
    * Note: if WS-Man is not enabled, the Install-Lab cmdlet will attempt to install it with confirmation being required from the user.
    Confirmation can be suppressed using the -force option.

Contributing
============
If you wish to contribute to this project, please read the [Contributing.md](/.github/CONTRIBUTING.md) document first. We would be very grateful of any contributions.


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

## Installing the LabBuilder Module

The easiest way to download and install the LabBuilder module is using PowerShell Get to download it from the [PowerShell Gallery](https://www.powershellgallery.com/packages/LabBuilder/):
```powershell
Install-Module -Name LabBuilder
```

PowerShell Get is built into Windows Management Framework 5.0, which is a requirement of this project, so it should already be installed onto your host.
If it is not installed, download it from [here](https://www.microsoft.com/en-us/download/details.aspx?id=50395).

## Installing a Lab

Once the Lab files are available the process of installing the Lab is simple.
 1. Make a folder where all your Lab files will go (e.g. VMs, VHDs, ISOs, scripts) - e.g. c:\MyLab
 2. Copy the Lab Configuration XML file into that folder (try one of the sample configurations in the **Samples** folder).
 3. Edit the Lab Configuration XML file and customize the Settings to suit (specifically the LabPath setting). 
 4. Make a folder in your Lab folder for your Windows ISO files called **isofiles** - e.g. c:\MyLab\ISOFiles
 5. Copy any ISO files into this folder that your lab will use.
 6. Make a folder in your Lab folder for your VHD boot templates (converted from the ISO files) **vhdfiles** - e.g. c:\MyLab\VHDFiles
 7. Run the following command in an Administrative PowerShell window:
```powershell
Install-Lab -ConfigPath 'c:\MyLab\Configuration.xml'
```

This will create a new Lab using the c:\MyLab\Configuration.xml file.

If you want more verbose output of what is happening during the Lab Install process, use the -verbose parameter:
```powershell
Install-Lab -ConfigPath 'c:\MyLab\Configuration.xml' -Verbose
```

## Stopping a Lab

Once the Lab has been installed, it can be stopped using this PowerShell command:

```powershell
Get-Lab -ConfigPath 'c:\MyLab\Configuration.xml' | Stop-Lab
```

This will shutdown any running Virutal Machines in the Lab in **Reverse Boot Order**, starting with Virtual Machines that have no boot order defined.
LabBuilder will wait for all machines with the same Boot Order to be shut down before beginning shut down of VMs in the next lowest Boot Order.
Any Lab Virtual Machine that has already been stopped will be ignored.

_Note: Boot Order is an optional attribute defined in the Lab Configuration that controls the order Lab Virtual Machines should be booted in._

You can of course just shut down the Virtual Machines in a Lab yourself via Hyper-V (or some other mechanism), but using Stop-Lab ensures the Virtual Machines are shutdown in a specific order defined in the Lab (e.g. Domain Controllers shut down last).


## Starting a Lab

Once the Lab has been installed and then stopped, it can be started back up using this PowerShell command:

```powershell
Get-Lab -ConfigPath 'c:\MyLab\Configuration.xml' | Start-Lab
```

This will start up any stopped Virutal Machines in the Lab in **Boot Order**, with Virtual Machines that have no boot order defined being started last.
LabBuilder will wait for all machines with the same Boot Order to be started up fully before beginning start up of VMs in the next highest Boot Order.

_Note: Boot Order is an optional attribute defined in the Lab Configuration that controls the order Lab Virtual Machines should be booted in._

You can of course just start up the Virtual Machines in a Lab yourself via Hyper-V (or some other mechanism), but using Start-Lab ensures the Virtual Machines are started up in a specific order defined in the Lab (e.g. Domain Controllers started up first).


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
 - Windows Server 2016 TP5: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview

**Important**: If you are converting Windows Server 2016 ISO files or adding packages to VHDs please see the [Windows Server 2016](#Windows Server 2016) section.

Multiple VHD templates may use the same ISO file in a Lab.
For example, if multiple editions of an Operating system are used in the same lab.

Once an ISO has been converted to an VHD, it will be stored in the VHDFiles folder in your lab folder.
However, if you are using multiple Labs on the same machine you might want to share these VHD files between mutlpile Lab projects to save having to build and store copies for each Lab.
In that case, you can set the _vhdpath_ attribute of the _<templatevhds>_ node in the configuration to a different relative or absolute path.

The conversion process for a single ISO to VHD can take 10-20 minutes depending on your machine.
For this reason multiple Labs can be configured to use the same path to store these VHDs by changing the _vhdpath_ attribute of the _<templatevhds>_ node in the configuration. 

Windows Server 2016
===================

If you are converting a Windows Server 2016 image and your Lab Host is running either:
 - Windows Server 2012 R2 or older
 - Windows 8.1 or older

**Important:** Only Windows Server 2016 Technical Preview 5 and above are supported with LabBilder.
 
You will need to install an updated version of the DISM before you will be able to add any packages to a Windows Server 2016 ISO.
This includes building Nano Server Images.

You can get the latest version of the DISM by downloading and installing the [Windows ADK](http://go.microsoft.com/fwlink/?LinkId=293394).
After installing the Windows ADK, you can force LabBuilder to use this version by configuring the "dismpath" attribute in the "settings" element of your LabBuilder configuration file:
```xml
<labbuilderconfig xmlns="labbuilderconfig"
                  name="PesterTestConfig"
                  version="1.0">
  <description>My Lab</description>

  <settings labid="TestLab"
            domainname="CONTOSO.COM"
            labpath="C:\Lab"
            dismpath="C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM" />
```

Lab Installation Process in Detail
==================================
When a new Lab is installed onto a Lab Host from a configuration file, LabBuilder performs the following tasks (in order):
 1. **Load Config**: The Lab configuration file is Loaded and validated.

   _If the Lab Configuration file is invalid it will be rejected and the Lab will not be installed._

 2. **Create Lab Folder**: A folder on the Lab Host is created to store the Lab files (VM Templates, VMs, Resources etc.).

  _The user specifies the location of this folder in the Lab Configuration file or by passing the LabPath parameter to the Install-Lab cmdlet._

 3. **Download Modules**: All Module Resources listed in the Lab Configuration are downloaded to the PowerShell Modules folder if they don't already exist.
 4. **Download MSUs**: All MSU Resources listed in the Lab Configuration are downloaded to the Resources folder in the Lab folder if they don't already exist. 
 5. **Create Lab Switches**: Each Virtual Switch specified in the Lab Configuration is created or updated in Hyper-V.
 6. **Create Management Switch**: A Management Internal Virtual Switch is created in Hyper-V for this Lab.

   _Each Lab has it's own Management Internal Virtual Switch which will be named "Lab Management" with the Lab ID prepended to it._
   _It will be assigned a VLAN Id of 99, which can be overridden in the Lab Configuration file._
   _The Lab Management switch is for the Lab Host to communicate with the Lab Guest Virtual Machines so must not be removed._

 7. **Create Template VHDs**: Any Template VHD files that don't exist but should are created from the appropriate ISO files.

    _A Lab Configuration file may not list any Template VHD files, or it may list them but not specify source ISO files to create the VHD files from._
    _Instead the Templates may directly link to a VHD file or an existing Hyper-V Virtual Machine._ 

 8. **Create VHD Templates Folder**: A folder within the Lab folder will be created to store the Virtual Hard Disk Template files.

    _This folder is usually called 'Virtual Hard Disk Templates'._
    _This folder will be used to store Template VHD files or Differencing Disk Parent VHD files for use as a Boot Disk for Lab Virtual Machines._
    _A VHD file in this folder can be used as a Template or a Differencing Disk Parent or both._

 9. **Copy VHD Templates**: Get the list of Templates in the Lab Configuration and copy the VHD specified to the Lab Virtual Hard Disk Templates folder.

   _Any packages listed in the Template will be applied to the Template at this point._
   _A Template VHD file will only be copied into this folder if it does not already exist._
   _The Template VHD file will also be optimized in this folder and then marked as Read Only to ensure it is not changed (as it may be used as a Differencing Disk Parent)._

 10. **Create Virtual Machines**: Create the Lab Virtual Machines, one at a time, for each one performing the following steps:
     
     1. **Create Hyper-V VM**: Create the Virtual Machine and attach any Network Adapters listed in the Lab Configuration with it.
     2. **Create Boot VHD**: Copy (if not using a Differencing Boot VHD) the Boot VHD from the Virtual Hard Disk Templates folder and attach it to the VM.
     3. **Add Packages**: Add any listed packages to the VM.
     4. **Create Data VHDs**: Copy/Create and attach any Data VHDs listed in the Lab Configuration with the VM.
     5. **Create Config Files**: Create any VM configuration files required for first boot of the VM (e.g. Unattend.xml, SetupComplete.cmd) and copy them into the Boot VHD.  
     6. **Boot VM**: Boot the VM for the first time and wait for Initial Setup of the VM to complete.
     7. **Create Certificate**: A Self-Signed certificate will be created by the VM and made available on the VM Boot VHD.
     8. **Download Certificate**: The Self-Signed certificate will be downloaded by the Lab Host and used to encrypt the credentials in the DSC MOF file that will be created.
     9. **Create DSC Configuration**: The DSC Configuration file will be assembled from the speficied DSC Configuration and the required networking information.
     10. **Compile DSC Configuration**: The DSC Configuration file will be compiled and a MOF file produced.
     11. **Upload DSC Files**: This DSC MOF file, DSC LCM (Meta) MOF File and any DSC Resource Modules required will be uploaded into the VM.
     12. **Start DSC**: DSC configuration will be started on the VM.

         _Note: The LCM is configured to re-apply DSC every 15 minutes, so changing any settings managed by DSC on the server will be reverted within 15 minutes of them being changed._

The entire process above is automated.
As long as you a valid Lab Configuration file and any required Windows Installation Media ISO files then the Lab will be installed for you.
Depending on the size of the Lab you are building and whether or not the ISO files need to be converted to VHD files, this could take from 5 minutes to many hours.
For example, an Lab containing eight Windows Server 2012 R2 Virtual Machines configured as an AD Domain containing various services installed on a Host with four CPU cores, 32 GB RAM and an SSD will take about 45 minutes to install.


Windows Management Framework 5.0 (WMF 5.0)
==========================================
All Lab Guest Virtual Machines must have WMF 5.0 installed onto them before they are first booted in a Lab environment. This is to ensure the Self-Signed certificate can be generated and returned to the host for DSC MOF encryption.

If WMF 5.0 is not installed before the Lab VM Guest first boot then DSC configuration will not proceed, and the Lab Guest VM will boot with a clean OS, but none of the specific features installed or configured (e.g. DC's not promoted).

WMF 5.0 is only required to be installed onto Windows 7, 8 and 8.1 or Windows Server 2008 R2, Windows Server 2012 and Windows Server 2012 R2. Windows 10 and Windows Server 2016 already include WMF 5.0 so it doesn't need to be installed.

_Most Labs_ are configured to install WMF 5.0 **completely automatically** so you don't need to install worry about it.

Note: It is possible to change a Lab Configuration file to prevent automatic installation of the WMF 5.0 MSU package onto Guest Lab VM's, but this is not recommended unless there is a good reason for doing so.

LabBuilder supports automatically installing any MSU package that can be downloaded from the internet onto the Lab Guest VMs during installation of the Lab.
These MSU packages can be installed during any of the following phases of Lab installation:
 - Convert Windows Install Media ISO to Template VHD.
 - Copy Template VHD to ParentVHD folder in Lab.
 - Create new VM Boot VHD from ParentVHD folder in Lab.
 
 By default, Lab configuration files are configured to ensure WMF 5.0 is installed at each of the above phases.
 
 The WMF 5.0 MSU package is controlled by adding a new MSU element to the &lt;Resources&gt; element in a Lab Configuration.
 E.g.
```xml
     <msu name="WMF5.0-WS2012R2-W81"
         url="https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win8.1AndW2K12R2-KB3134758-x64.msu" />
```

This defines the name of the MSU package and the Download location.
The package can then be added to the &lt;Template&gt;, &lt;TemplateVHD&gt; or &lt;VM&gt; element in the **Packages** attribute.
E.g.
```xml
<templatevhd name="Windows Server 2012 R2 Datacenter Full"
                iso="9600.16384.130821-1623_x64fre_Server_EN-US_IRM_SSS_DV5.iso"
                url="https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2012-r2"
                vhd="Windows Server 2012 R2 Datacenter Full.vhdx" 
                edition="Windows Server 2012 R2 SERVERDATACENTER" 
                ostype="Server"
                packages="WMF5.0-WS2012R2-W81"
                vhdformat="vhdx" 
                vhdtype="dynamic" 
                generation="2" 
                vhdsize="40GB" />
```

Other MSU packages can also be installed in the same way.
Multiple MSU Packages can be installed to the same VHD by comma delimiting the Packages attribute.


Configuration XML
=================
Documentation for the LabBuilder Configuration XML can be found in the file [docs/labbuilderconfig-schema.md](LabBuilder/docs/labbuilderconfig-schema.md).


Cmdlets
=======
Complete documentation for the LabBuilder Lab Cmdlets can be found in the file [docs/cmdlets-lab.md](LabBuilder/docs/cmdlets-lab.md).

A list of Cmdlets in the LabBuilder module can be found by running the following PowerShell commands:
```PowerShell
Import-Module LabBuilder
Get-Command -Module LabBuilder
```

Help on individual Cmdlets can be found in the built-in Cmdlet help:
```PowerShell
Get-Help -Name Install-Lab
```


Change List
===========
For a list of changes to versions, see the [docs/changelist.md](LabBuilder/docs/changelist.md) file.


Project Management Dashboard
============================
[![Throughput Graph](https://graphs.waffle.io/PlagueHO/LabBuilder/throughput.svg)](https://waffle.io/PlagueHO/LabBuilder/metrics/throughput)


Links
=====
- [GitHub Repository](https://github.com/PlagueHO/LabBuilder/)
- [Blog](https://dscottraynsford.wordpress.com/)
