### Unreleased
* DSCLibrary\MEMBER_FAILOVERCLUSTER_FS.DSC.ps1: Added ServerName property to contain name of ISCSI Server.
* samples\Sample_WS2012R2_DomainClustering.xml: Added ServerName property to all Failover Cluster servers DSC properties.
* docs\labbuilderconfig-schema.md: Converted to UTF-8 to eliminate issues with Git.
* support\Convert-XSDToMD.ps1: Added code to convert transformed output to UTF-8.
* Start-Lab: Improved readability if timeout detect code.
* Stop-Lab: Improved readability if timeout detect code.
            Ensure all VMs are stopped in a Bootphase, even if timeout occurs.
* StartDSCDebug.ps1: Added a WaitForDebugger parameter to StartDSCDebug.ps1 that will cause LCM to start with debugging mode enabled.

### 0.7.2.0
* DSCLibrary\MEMBER_FAILOVERCLUSTER_FS.DSC.ps1: Changed to install most File Server features on cluster nodes.
* DSCLibrary\MEMBER_FAILOVERCLUSTER_DHCP.DSC.ps1: Created resource for Failover Cluster DHCP Server nodes.
* Readme.md: Additional Documentation added.

### 0.7.1.0
* GetDSCNetworkingConfig: Fix DSC error occuring when a blank DNS Server address or Default Gateway address is set on an Adapter.
* InitializeVhd: Prevent unnecessary results of disk partitioning and volume creation to console.
* UpdateVMDataDisks: Fix to incorrectly reported Data VHD type change error.
* DSCLibrary\MEMBER_BRANCHCACHE_HOST.DSC.ps1: Created resource for BranchCache Hosted Servers.
* DSCLibrary\MEMBER_FILESERVER_*.DSC.ps1: Added BranchCache for File Servers feature.
* Readme.md: Added 'Lab Installation Process in Detail' section.

### 0.7.0.0
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
* Initialize-LabVMTemplateVHD: Converted to use LabVMTemplateVHD objects.
                               Check added to ensure Drive Letter is assigned to mounted ISO.
* Remove-LabVMTemplateVHD: Converted to use LabVMTemplateVHD objects.
* Readme.md: Windows Management Framework 5.0 (WMF 5.0) section added.
* DSCLibrary\DC_FORESTDOMAIN.DSC.ps1: Changed name to DC_FORESTCHILDDOMAIN.DSC.ps1 to better indicate purpose.
* Get-LabVMTemplate: Converted to output array of LabVMTemplate objects.
* Initialize-LabVMTemplate: Converted to use LabVMTemplate objects.
* Remove-LabVMTemplate: Converted to use LabVMTemplate objects.
* Get-LabVM: Converted to output array of LabVM objects.
* Initialize-LabVM: Converted to use LabVM objects.
* Remove-LabVM: Converted to use LabVM objects.
* Lib\dsc.ps1: All functions converted to use LabVM objects.
* Lib\vm.ps1: All functions converted to use LabVM objects.
* Lib\vhd.ps1: All functions converted to use LabVM objects.
* InitializeVhd: Fix error when attempting to create a new VHD/VHDx with a formatted volume.

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
