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


### Windows Management Framework 5.0 (WMF 5.0)
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
    * Note: Most Lab configuration files can contain a URL where the relevant trial media can be downloaded from, but you can use any Windows Install Media source you choose (including custom built ISOs).
 5. An internet connection to download the WMF 5.0 MSU and any other optional MSU packages required by the Lab.
    * Note: This only needs to be done during the Install-Lab phase and can be disabled after this phase is complete.


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


Links
=====
- [GitHub Repository](https://github.com/PlagueHO/LabBuilder/)
- [Blog](https://dscottraynsford.wordpress.com/)
