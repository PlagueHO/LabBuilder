LabBuilder
==========

## Summary
This module will build a multiple machine Hyper-V Lab environment from an XML configuration file and other installation scripts.

## Introduction
While studying for some of my Microsoft certifications I had a need to quickly and easily spin up various Hyper-V Lab environments so that I could experiment with and learn the technologies involved.

Originally I performed this process manually, creating Hyper-V VM's and environments to suit. But as the complexity of the Lab environment increased (e.g. take multi-tier PKIs) manually building these Labs became unmanageable. Also, if I wanted to repeat a particular process mutliple times I would have to either snapshot multiple VMs or manually back them all up. This quickly became unsupportable as snapshots slows VMs down and constant backups of large Hyper-V environments was slow and also limited by space. This gave me a basic set of requirements for this module.

So as a solution to these problems I decided that I wanted a declarative approach to automating the process of building a Lab environment.

This had the following advantages:
+ Building a new Lab with multiple VMs was automated.
+ Creation of the actual Lab VMs could be done without supervision.
+ Once a basic Lab was created more complex Lab environments could be created by cloning the original XML configuration and tailoring it.
+ Configuration files could be distributed easily.
+ Because the post setup configuration of the Lab VM machines was performed via DSC this gave me an opportunity to work with DSC to a greater depth.

## Usage Summary
The use of this module is fairly simple from a process standpoint - the bulk of the work for a Lab goes into the creation of the XML that defines the Lab environment - as well as any DSC config scripts that are used by the Lab.

A Lab consists of the following items:
1. A configuration XML file that defines the Virtual Machines, Switches, the DSC config files and anything else related to how the Lab is set up.
2. One or more VHDs containing Syspreped Windows images used by the Lab. Usually just a VHD of a Syspreped Windows Server 2012 R2 (or other) OS is fine. But you may use multiple template VHDs for different OS's or configurations (e.g. I have one for Windows Server 2012 R2 full install and one for Windows Server 2012 R2 Core install).
3. Any DSC configuration files that will be used to configure the Lab VMs after the OS initial start up has completed. I have provided many basic and more complex ones with this project.

Once these files are available the process of setting up the Lab is simple. Just run the following commands in an Administrative PowerShell window:
```powershell
Import-Module LabBuilder
Install-Lab -Path 'c:\Lab01\Config.xml'
```

## Version Info
```
0.2   2015-12-01   Daniel Scott-Raynsford       Code cleanup and refactoring.
0.1   2015-08-31   Daniel Scott-Raynsford       Initial Release.
```

## Functions

## Example Usage

## Links
**GitHub Repository:** https://github.com/PlagueHO/LabBuilder/
**Blog:** https://dscottraynsford.wordpress.com/
