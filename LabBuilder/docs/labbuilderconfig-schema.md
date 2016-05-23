
# LabBuilder Configuration XML File Format
> labbuilderconfig xmlns="labbuilderconfig"
  
### 1.0a - NAME Required Attribute
> name="xs:string"


This required attribute should be used to set a descriptive name for this Lab configuration.
          
``` name="WS2012R2-DOMAIN-CLUSTER" ```

### 2.0a - VERSION Required Attribute
> version="xs:decimal"


This required attribute should be used to set a version number for this Lab configuration in the format #.#.
It should be updated each time the Lab configuration is changed.
          
``` version="2.1" ```

### 1.0e - DESCRIPTION Optional Element

> description="xs:string"


This optional element should contain a brief description of this Lab.
            
``` <description>This Lab builds two Domain Controllers and two DHCP Servers.</description> ```

### 2.0e - SETTINGS Required Element

This required element contains settings attributes controlling general settings of this Lab.
            
``` <settings /> ```

### 2.1a - LABID Optional Attribute
> labid="xs:string"


This optional attribute contains a Lab Identifier for the Lab.
This identifier will be pre-pended to the names of any Virtual Machines, Switches and Network Adapter names created for this Lab.
                
``` labid="WS2012R2-CLUSTER-TEST" ```

### 2.2a - DOMAINNAME Optional Attribute
> domainname="xs:string"


This optional attribute contains the Domain Name identifier used by Virtual Machines created in this Lab. It may be used by DSC to configure the Virtual Machines in the Lab.
                
``` domainname="CONTOSO.COM" ```

### 2.3a - EMAIL Optional Attribute
> email="xs:string"


This optional attribute contains an E-mail address of the Administrator of this Lab. It may be used by DSC to configure the Virtual Machines in the Lab.
                
``` email="dev@contoso.com" ```

### 2.4a - LABPATH Optional Attribute
> labpath="xs:string"


This optional attribute contains the full path to the folder that this Lab should be created in. It can be overridden when the Lab is installed.
The folder will be created when the Lab is installed if it doesn't already exist.
The Virtual Machines, Virtual Hard Disk drives and other Lab related files will be created in this folder.
                
``` labpath="f:\Labs\WS2012R2-CLUSTER-TEST-01" ```

### 2.5a - VHDPARENTPATH Optional Attribute
> vhdparentpath="xs:string"


This optional attribute contains the path to the folder that will contain the Parent VHD files used by the Virtual Machines in this Lab.
If this folder is not rooted, it will be assumed to be a subfolder of the 'labpath'.
The Parent VHD files are used as Parent VHD's to any Lab VM boot disks or cloned to each Virtual Machine folder depending on the 'usedifferencingdisk' setting for each Lab VM.

- Default Value: ParentVHDs
                
``` vhdparentpath="f:\Labs\WS2012R2-CLUSTER-TEST-01\ParentVHDs" ```

### 2.6a - DSCLIBRARYPATH Optional Attribute
> dsclibrarypath="xs:string"


This optional attribute contains the path to the folder that will contain the DSC Library files used by the Virtual Machines in this Lab.
If this folder is not rooted, it will be assumed to be a subfolder of the 'labpath'.
If this setting is not set it will default to 'dsclibrary' and will therefore be a subfolder of the 'labpath'.
Usually the content of this folder will either be provided with the Lab or created by copying the DSCLibrary folder provided with the LabBuilder module.

Each Virtual Machine that is set to be configured by DSC requires a DSC configuration file that must be found in this folder.

- Default Value: DSCLibrary
                
``` dsclibrarypath="C:\DSC\MyLibrary" ```

### 2.7a - RESOURCEPATH Optional Attribute
> resourcepath="xs:string"


This optional attribute contains the path to the folder that will contain any Resource files required by this Lab.
This includes the MSU packages that may need to be installed into the TemplateVHD or VM BootVHD files by specifing the MSU package names in the Packages attribute of the VMTemplateVHD, TemplateVHD or VM elements.
If this folder is not rooted, it will be assumed to be a subfolder of the 'labpath'.

- Default Value: Resource
                
``` resourcepath="f:\SharedResources\" ```

### 2.8a - MODULEPATH Optional Attribute
> modulepath="xs:string"


This optional attribute can be used to add a path to the PowerShell Module Search path.
It can be used to specify an alternate path for DSC Resource Modules for the use in this Lab.
If specified, LabBuilder will search for DSC Resource Modules in this path before searching all other default PowerShell Module Paths.
If this folder is not rooted, it will be assumed to be a subfolder of the 'labpath'.
                
``` modulepath="f:\SharedModules\" ```

### 2.9a - DISMPATH Optional Attribute
> dismpath="xs:string"


This optional attribute contains the path to the copy of DISM.EXE that should be used to convert any Windows Install Media ISOs to VHD files.
This is usually only required if the Lab Host is running Windows Server 2012 R2 or earlier or Windows 8.1 or earlier and the Windows Install Media ISO being converted is Windows Server 2016.
The latest version of DISM can be found in the Windows ADK here https://msdn.microsoft.com/en-us/library/hh825494.aspx.
Once the ADK is installed this setting can be configured to tell LabBuilder where to find the appropriate version (x86 or amd64) of DISM.
You should not include the DISM.EXE application name in the path.
                
``` resourcepath="C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\" ```

### 2.10a - REQUIREDWINDOWSBUILD Optional Attribute
> requiredwindowsbuild="xs:integer"


This optional attribute contains the minimum build required on the Lab host to install or use this Lab.
If the Lab Host does not meet this build number an error will be thrown when loading the Lab configuration.
This ensures that all features required to install a Lab are available on the Lab Host before installation will proceed.
If this attribute is not set then the Lab Configuration will be able to installed on any Windows build version Lab Host.
                
``` requiredwindowsbuild="14295" ```

### 3.0e - RESOURCES Optional Element

This optional element can contain one or more resources that will be required for this Lab to be installed.
These resources may be downloaded from the Internet automatically depending on the resource type.

There can be different types of Resources that can be contained in the Resources element.

Currently the Resource types that are supported are:
 - Module: A PowerShell (DSC) Module that is downloaded via URL or using PowerShell Get. This can be a DSC or non-DSC PowerShell module.
 - MSU: A Microsoft Update package that will be downloaded to the lab Resources folder and can be installed into the Boot VHD when it is created from an ISO, when it is copied to the Parent VHD folder or when the VM is prepared for first boot.
            
``` <resources>...</resources> ```

### 3.1a - ISOPATH Optional Attribute
> isopath="xs:string"


This optional attribute can be used to set the path to the folder that LabBuilder will look for the Resource ISO files.
If not set this will default to the ResourcePath specified in the Lab configuration file.
If a ResourcePath is not set then this will be the Resource folder within the Lab folder.
This can be a relative or full path.
If a relative path is set, it will be relative to the full path of the Lab Resource folder.
                
``` isopath="d:\LabShared\ISOs" ```

### 3.1e - MODULE Optional Element

A PowerShell (DSC) Module that will be downloaded and installed to the Lab Host when this Lab is installed.

Note: This is not required for any PowerShell DSC Modules that are referenced in a DSC configuration used by a Virtual Machine if the version required is available in the PowerShell Gallery and is just the latest version.
This is usually only required if the Lab requires the use of development resources or versions that are either not available on PowerShell Gallery or a specific version is requred.
                  
``` <module /> ```

### 3.1.1a - NAME Required Attribute
> name="xs:string"


The Name of the PowerShell (DSC) Module that this Lab requires.
If a URL attribute is not specified, the PowerShell Gallery will be searched for a module with this name and downloaded.
                      
``` name="xNetworking" ```

### 3.1.2a - URL Optional Attribute
> url="xs:string"


An optional URL that will be used to download the PowerShell (DSC) Module from. Setting this attribute prevent LabBuilder from using PowerShell Get to download the Module if it is missing.
This is commonly used to download PowerShell (DSC) Modules directly from GitHub or other repositories.
                      
``` url="https://github.com/PowerShell/xNetworking/archive/dev.zip" ```

### 3.1.3a - FOLDER Optional Attribute
> folder="xs:string"


This optional attribute only needs to be set if the zip file downloaded by the URL in the URL attribute contains a folder that the PowerShell (DSC) Module is in.
This is usually used when the URL specifies a GitHub repository branch, which will cause the downloaded zip file to contain a folder named 'name-branch' (e.g. xNetworking-dev).
                      
``` folder="xNetworking-dev" ```

### 3.1.4a - MINIMUMVERSION Optional Attribute
> minimumversion="xs:string"


This optional attribute contains the minimum PowerShell module version that is required by this Lab.
If a version of the Module is not found that is at least this version then a newer version will be downloaded using PowerShell Get.
This attribute should only be used if URL is not set.
                      
``` minimumversion="2.0.0.0" ```

### 3.1.5a - REQUIREDVERSION Optional Attribute
> requiredversion="xs:string"


This optional attribute contains the specific PowerShell module version that is required by this Lab.
If a version of the Module is not found that is exactly this version then this version will be downloaded using PowerShell Get.
This attribute should only be used if URL is not set.
                      
``` requiredversion="2.1.0.0" ```

### 3.2e - MSU Optional Element

An Microsoft Update (MSU) package file to be installed into a Boot VM.
                  
``` <msu /> ```

### 3.2.1a - NAME Required Attribute
> name="xs:string"


A descriptive name for this MSU that will be used to identify this package.
Any Lab build process that installs MSU packages will need to refer to this name, not the file name of the package.
                      
``` name="WMF5.0-WS2012R2-W81" ```

### 3.2.2a - URL Required Attribute
> url="xs:string"


The URL to download this MSU file from.
If this file already exists in the Resources folder for this Lab when the Lab is installed, it will not be downloaded again.

Note: If the Lab contains Windows Server 2012 R2, Windows Server 2012 or Windows Server 2008 R2 machines, the WMF 5.0 MSU packages MUST be installed on these machines before first boot or they will not be able to be configured.

To download these packages:
 - Windows Server 2012 R2 - https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win8.1AndW2K12R2-KB3134758-x64.msu
 - Windows Server 2012 - https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/W2K12-KB3134759-x64.msu
 - Windows Server 2008 R2 - https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win7AndW2K8R2-KB3134760-x64.msu'
                      
``` url="https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win8.1AndW2K12R2-KB3134758-x64.msu" ```

### 3.2.3a - PATH Optional Attribute
> path="xs:string"


This optional attribute can be used to set an optional path this package will be stored and/or downloaded to.
                      
``` path="f:\LabBuilder\sharedpackages\" ```

### 3.3e - ISO Optional Element

An ISO file that can be mounted into one or more Lab Virtual Machines.
                  
``` <iso /> ```

### 3.3.1a - NAME Required Attribute
> name="xs:string"


A descriptive name for this ISO that will be used to identify this disk.
Any Lab build process that mounts ISO files will need to refer to this name, not the file name of the ISO.
                      
``` name="SQL2012_FULL_ENU" ```

### 3.3.2a - URL Optional Attribute
> url="xs:string"


The optional URL to download this ISO file from.
If this file already exists in the Resources folder for this Lab when the Lab is installed, it will not be downloaded again.
This attribute should not be used if the path attribute is also set.
                      
``` url="https://download.microsoft.com/download/4/C/7/4C7D40B9-BCF8-4F8A-9E76-06E9B92FE5AE/ENU/SQLFULL_ENU.iso" ```

### 3.3.3a - PATH Required Attribute
> path="xs:string"


This required attribute is used to set the filename (and optionally path) of the source ISO.
The ISO will be used from that location and not copied into the Resources folder of the Lab.
If this path does not contain a root it will be appended onto the _ISOFiles_ attribute on the _Resources_ node or the path set in the _ResourcePath_ attribute on the _Settings_ node.
If the ISO file does not exist but a URL is provided that contains a filename with an extension of ISO or ZIP it will be downloaded to this location and optionally unzipped.
If the ISO file does not exist but a URL is provided that does not contain an ISO or ZIP filename the user will be requested to manually download the file from the URL and Lab installation will terminate.
                      
``` path="f:\isos\SQLFULL_ENU.iso" ```

### 4.0e - SWITCHES Optional Element

This optional element contains a collection of zero or more Switch nodes representing the Hyper-V Virtual Switches that are required for this Lab.
Any missing switches in this list will be created on the Lab Host when this Lab is installed.

Note: A Private Management Virtual Switch will always be created for each installed Lab for LabBuilder to install and configure the Virtual Machines in a Lab. This Management Virtual Switch will not appear in this list but will always be created.
            
``` <switches>...</switches> ```

### 4.1a - MANAGEMENTVLAN Optional Attribute
> managementvlan="xs:unsignedByte"


This optional attribute is used to change the VLAN ID used by the Private Hyper-V Management Switch created to manage this Lab.
If not set the default VLAN ID value of 99 will be used.
All Virtual Network Adapters automatically created and attached to the Management Switch for this Lab will be set to use this VLAN ID.
                
``` managementvlan="55" ```

### 4.1e - SWITCH Optional Element

This optional element represents a Hyper-V Virtual Switch that is required for this Lab.
A Lab may contain one or more Internal, Private, External or NAT Virtual Switches.
                  
``` <switch>...</switch> ```

### 4.1.1a - NAME Required Attribute
> name="xs:string"


This required attribute is used to configure the Name of the Hyper-V Virtual Switch to be created for this Lab.

Note: If this Lab configuration has got a LabId setting defined, it will be pre-pended to this value when the Switch is created if the Switch type is a Private, Internal or NAT.
                      
``` name="Domain Cluster" ```

### 4.1.2a - TYPE Required Attribute
> type="xs:string"


This required attribute is used to set the Type of Hyper-V Virtual Switch to create.
It can be set to:
 - Internal
 - Private
 - External
 - NAT (only available on Windows 10 and Windows Server 2016 build 14295 and above)
                      
``` type="Internal" ```

### 4.1.3a - VLAN Optional Attribute
> vlan="xs:unsignedByte"


This optional attribute is used to configure the VLAN ID of all Virtual Network Adapters that will connect to this Virtual Switch.
                      
``` vlan="43" ```

### 4.1.4a - BINDINGADAPTERNAME Optional Attribute
> bindingadaptername="xs:string"


This optional attribute is used to configure which physical network adapter an External switch will be bound to.
This attribute should only be set if the switch type is External.
If the bindingadaptermac attribute is set then this attribute should not be set.
                      
``` bindingadaptername="Ethernet 1" ```

### 4.1.5a - BINDINGADAPTERMAC Optional Attribute
> bindingadaptermac="xs:string"


This optional attribute is used to configure which physical network adapter an External switch will be bound to.
This attribute should only be set if the switch type is External.
If the bindingadaptername attribute is set then this attribute should not be set.
                      
``` bindingadaptermac="C86000A1A895" ```

### 4.1.6a - NATSUBNET Optional Attribute
> natsubnet="xs:string"


This optional attribute is used to configure the subnet that will be assigned to this NAT switch.
It must contain an IP address (192.168.10.0) followed by a slash (/) then the subnet prefix length (e.g. 24).
This attribute should only be set if the switch type is NAT.
If this attribute is set the natgatewayaddress attribute must also be set.
                      
``` natsubnet="192.168.10.0/24" ```

### 4.1.7a - NATGATEWAYADDRESS Optional Attribute
> natgatewayaddress="xs:string"


This optional attribute is used to configure the IP address that will be used as a gateway address on this NAT switch.
This IP Address must be within the defined NAT subnet set in the natsubnet attribute.
This attribute should only be set if the switch type is NAT.
If this attribute is set the natsubnet attribute must also be set.
                      
``` natgatewayaddress="192.168.10.1" ```

### 4.1.1e - ADAPTERS Optional Element

This optional element contains a collection of zero or more Adapter nodes representing Hyper-V Virtual Network Adapters that are used by the Host Operating System to connect to this Hyper-V Virtual Switch.
This should element should only be added for External or Private switches.
                        
``` <adapters>...</adapters> ```

### 4.1.1.1e - ADAPTER Optional Element

This optional element represents a Hyper-V Virtual Network Adapter that will be used as a Management Adapter for the Host Operating system to connect to this Virtual Switch.
These Management Adapters are usually used to allow access to the Internet by the Virtual Machines in a Lab.
                              
``` <switch>...</switch> ```

### 4.1.1.1.1a - NAME Required Attribute
> name="xs:string"


This required attribute is used to set the Name of the Management Virtual Adapter connected to this Hyper-V Virtual Switch.

Note: If this Lab configuration has got a LabId setting defined, it will be pre-pended to this value when the Switch is created if the Switch type is a Private, Internal or NAT.
                                  
``` name="Cluster Network" ```

### 4.1.1.1.2a - MACADDRESS Required Attribute
> macaddress="xs:string"


This required attribute is used to set the MAC Address of the Management Virtual Adapter connected to this Hyper-V Virtual Switch.
                                  
``` macaddress="00155D010703" ```

### 4.1.1.1.3a - VLAN Optional Attribute
> vlan="xs:unsignedByte"


This optional attribute is used to set a VLAN ID of the Management Virtual Adapter connected to this Hyper-V Virtual Switch.
                                  
``` vlan="10" ```

### 5.0e - TEMPLATEVHDS Optional Element

This optional element contains a collection of zero or more TemplateVHD nodes representing the Template Virtual Hard Disk files that are required by the Templates and/or Virtual Machines in this Lab.
These Template VHD files will be created from Windows Install Media ISO files if they can't be found in the specified VHDPath folder during the Lab Install process.
            
``` <templatevhds>...</templatevhds> ```

### 5.1a - ISOPATH Optional Attribute
> isopath="xs:string"


This optional attribute can be used to set the path to the folder that LabBuilder will look for the Windows Install Media ISO files for any missing Template VHD files.
If not set this will default to the same path as the Lab configuration file.
This can be a relative or full path.
If a relative path is set, it will be relative to the full path of the Lab configuration file.
                
``` isopath="d:\LabShared\ISOs" ```

### 5.2a - VHDPATH Optional Attribute
> vhdpath="xs:string"


This optional attribute can be used to set the path to the folder that LabBuilder will create or look for any Template VHD files in.
If not set this will default to the same path as the Lab configuration file.
This can be a relative or full path.
If a relative path is set, it will be relative to the full path of the Lab configuration file.
                
``` isopath="d:\LabShared\VHDs" ```

### 5.3a - PREFIX Optional Attribute
> prefix="xs:string"


This optional attribute can be used to pre-pend a string to the VHD Template file that is created.
                
``` prefix="Templates " ```

### 5.1e - TEMPLATEVHD Optional Element

This optional element represents a Template VHD (Virtual Hard Disk) that will be created and used by a Virtual Machine Template to create boot disks for Virtual Machines.
If the VHD/VHDx file for this Template VHD can not be found it will be created using the specified Windows Install Media ISO file.
If the Windows Media ISO file can not be found the Lab Install will not be able to proceed.

Note: It is common for more than one Lab to use the same Template VHD files, therefore it is common to set the VHDPath and ISOPath attributes of this element to be a folder that can be accessed by multiple Labs.
                  
``` <templatevhd>...</templatevhd> ```

### 5.1.1a - NAME Required Attribute
> name="xs:string"


This required attribute will be the name of this Template VHD.
It will be used by Template elements to refer to this Template VHD.
                      
``` name="Windows Server 2012 R2 Datacenter Full" ```

### 5.1.2a - ISO Required Attribute
> iso="xs:string"


This required attribute should contain the relative or full path to the Windows Install Media ISO file required to build this Template VHD.
If this filename is not a rooted path it will be appended to the path found in the ISOFiles attribute.
                      
``` iso="9600.16384.130821-1623_x64fre_Server_EN-US_IRM_SSS_DV5.iso" ```

### 5.1.3a - URL Optional Attribute
> url="xs:string"


This optional attribute can be set to a URL that will be reported to a user if the ISO file required to build this Template VHD is not found.

Note: This URL will not be automatically downloaded, a user will need to open this URL in a browser.
                      
``` url="https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2012-r2" ```

### 5.1.4a - VHD Required Attribute
> vhd="xs:string"


This required attribute should contain the relative or full path to the VHD file that this Template VHD will use and/or create.
If this filename is not a rooted path it will be appended to the path found in the VHDFiles attribute.
                      
``` vhd="Windows Server 2012 R2 Datacenter Full.vhdx" ```

### 5.1.5a - EDITION Optional Attribute
> edition="xs:string"


This optional attribute will be the Edition that is installed from the Windows Install Media ISO if the Template VHD needs to be created.
If this is not provided and the VHD file needs to be created from the Windows Install Media ISO then the first edition in this Install Media will be created.
                      
``` edition="Windows Server 2012 R2 SERVERDATACENTER" ```

### 5.1.6a - OSTYPE Required Attribute
> ostype="xs:string"


This required attribute sets defines the type of Operating System that this Template VHD contains.
It is used by LabBuilder to determine how to configure Virtual Machines based on this template VHD.
It is also used to determine if Nano Server packages should be applied.

 - Default Value: Server.
 - Valid Values: Server | Client | Nano
                      
``` ostype="Server" ```

### 5.1.7a - FEATURES Optional Attribute
> features="xs:string"


This optional attribute can contain a comma delimited list of Windows Server Features that should be installed into this Virtual Machine Template VHD.
Normally, additional Windows Server Features are installed via DSC Library Configurations, so this attribute should not normally be used.
                      
``` features="Web-Application-Proxy,Routing" ```

### 5.1.8a - VHDFORMAT Optional Attribute
> vhdformat="xs:string"


This optional attribute controls the type of VHD format to create if the VHD does not already exist.

 - Default Value: VHDX
 - Valid Values: VHDX | VHD
                      
``` vhdformat="VHDx" ```

### 5.1.9a - VHDTYPE Optional Attribute
> vhdtype="xs:string"


This optional attribute controls the type of VHD file to create if the VHD does not already exist.

 - Default Value: Dynamic
 - Valid Values: Fixed | Dynamic
                      
``` vhdtype="Fixed" ```

### 5.1.10a - GENERATION Optional Attribute
> generation="xs:unsignedByte"


This optional attribute controls the Virtual Machine generation of VHD file to create if the VHD does not already exist.

 - Default Value: 2
 - Valid Values: 1 | 2
                      
``` generation="1" ```

### 5.1.11a - VHDSIZE Required Attribute
> vhdsize="xs:string"


This optional attribute controls the size of Boot VHD file to create if the VHD does not already exist.

Valid Values: PowerShell numeric values (e.g. 2GB, 1TB, 300MB, 160000000).
                      
``` size="25GB" ```

### 5.1.12a - PACKAGES Optional Attribute
> packages="xs:string"


This optional attribute can contain a comma delimited list of packages that should be installed into this Virtual Machine Template VHD.

If the Template VHD is a Nano Server then the packages can be .cab files, which will install the Nano Server package from the ISO or a Resource MSU file.

If the Template VHD is not a Nano Server then the packages must be Resource MSU files.

Valid Values:
 - Resource MSU names that are can be found in the ResourceMSU list.

Valid Values for Nano Server:
 - Filename including the .cab extension of a valid Nano Server package found on the Windows Install Media ISO.
 - Resource MSU names that are can be found in the ResourceMSU list.
                      
``` packages="Microsoft-NanoServer-DNS-Package.cab,SomePackage.msu" ```

### 6.0e - TEMPLATES Optional Element

This optional element contains a collection of zero or more Template nodes representing the Virtual Machine Templates used to build the Virtual Machines in this Lab.
The Virtual Machine Templates in this list may refer to a TemplateVHD or define a direct path to a Source VHD file.
If a TemplateVHD is specified, this TemplateVHD must be found in the TemplateVHDs collection.
Every Virtual Machine defined in this Lab must refer to a Template in this collection.
            
``` <templates>...</templates> ```

### 6.1a - FROMVM Optional Attribute
> fromvm="xs:string"


This optional attribute enables the list of Template Virtual Machines to be pulled from the Virtual Machines defined in Hyper-V.
The list of Hyper-V Virtual Machines to use as templates can be specified using a wild card value. E.g. 'Template *'
If specified, when the Lab is installed the list of available Virtual Machine Templates will be pulled from Hyper-V by matching the names against the FromVM attribute.
After the list of Hyper-V Virtual Machines to use a templates is pulled in, any Templates defined in this container will be merged into this list.
                
``` fromvm="Template *" ```

### 6.1e - TEMPLATE Optional Element

This optional element represents a Virtual Machine Template that will be created when this Lab is installed.
                  
``` <template>...</template> ```

### 6.1.1a - NAME Required Attribute
> name="xs:string"


This required attribute contains the name of this Virtual Machine Template.
Virtual Machines will refer to this value if they are going to use this Virtual Machine Template.
                      
``` name="Windows Server 2012 R2 Datacenter CORE" ```

### 6.1.2a - VHD Optional Attribute
> vhd="xs:string"


This optional attribute contains the file name of the VHD Boot file that will be used for any Virtual Machines using this Template.
If this attribute is not set it will default to the filename specified in the SourceVHD attribute or the filename of the Template VHD linked to by the TemplateVHD attribute.
                      
``` vhd="Windows Server 2012 R2 Datacenter CORE.vhdx" ```

### 6.1.3a - SOURCEVHD Optional Attribute
> sourcevhd="xs:string"


This optional attribute contains the relative or full path to the VHD file that will be cloned for use as the Boot VHD for any Virtual Machines using this template.

Note: This attribute should not be set if the TemplateVHD attribute is set.
                      
``` sourcevhd="VhdFiles\Windows Server 2012 R2 Datacenter Full.vhdx" ```

### 6.1.4a - MEMORYSTARTUPBYTES Optional Attribute
> memorystartupbytes="xs:string"


This optional attribute contains the amount of startup memory to assign to Virtual Machines based on this Template.

 - Default Value: 1GB.
 - Valid Values: PowerShell numeric values (e.g. 2GB, 1TB, 300MB, 160000000).
                      
``` memorystartupbytes="8GB" ```

### 6.1.5a - DYNAMICMEMORYENABLED Optional Attribute
> dynamicmemoryenabled="xs:string"


This optional attribute contains a flag to enable or disable Dynamic Memory for Virtual Machines based on this Template.
Note: Disabling this value is usually only used when Nested Virtualization is required.

 - Default Value: Y.
 - Valid Values: Y | N
                      
``` dynamicmemoryenabled="N" ```

### 6.1.6a - PROCESSORCOUNT Optional Attribute
> processorcount="xs:unsignedByte"


This optional attribute determines the number of virtual processors assigned to Virtual Machines based on this Template.

 - Default Value: 1.
 - Valid Values: 1-n.
                      
``` processorcount="2" ```

### 6.1.7a - ADMINISTRATORPASSWORD Optional Attribute
> administratorpassword="xs:string"


This optional attribute specifies the local Administrator password to assign when Virtual Machines based on this Template are installed.
If this is not defined for the Template it should be defined in the Virtual Machine definition.
                      
``` administratorpassword="MyP@ssw0rd!1" ```

### 6.1.8a - PRODUCTKEY Optional Attribute
> productkey="xs:string"


This optional attribute specifies the Windows product key to set on any Virtual Machines based on this Template.
                      
``` productkey="AAAAA-AAAAA-AAAAA-AAAAA-AAAAA" ```

### 6.1.9a - TIMEZONE Optional Attribute
> timezone="xs:string"


This optional attribute sets the timezone assigned to Virtual Machines based on this Template.

 - Default Value: PST.
                      
``` timezone="CST" ```

### 6.1.10a - OSTYPE Required Attribute
> ostype="xs:string"


This required attribute sets defines the type of Operating System that this Template contains.
It is used by LabBuilder to determine how to configure Virtual Machines based on this template.

 - Default Value: Server.
 - Valid Values: Server | Client | Nano
                      
``` ostype="Server" ```

### 6.1.11a - INTEGRATIONSERVICES Optional Attribute
> integrationservices="xs:string"


This optional attribute controls which Integration Services are enabled on any Virtual Machines created using this Template.
It should contain a comma delimited list of Integration Service names that should be enabled.
If this attribute is defined but left empty, all Integration Services will be disabled.
If this attribute is not defined all Integration Services will be enabled.

 - Default Value: Guest Service Interface,Heartbeat,Key-Value Pair Exchange,Shutdown,Time Synchronization,VSS
 - Valid Values: Guest Service Interface | Heartbeat | Key-Value Pair Exchange | Shutdown | Time Synchronization | VSS
                      
``` ostype="Server" ```

### 6.1.12a - TEMPLATEVHD Optional Attribute
> templatevhd="xs:string"


This optional attribute defines a Template VHD that this Virtual Machine Template will use to determine the Boot VHD file.
If a TemplateVHD with a name matching the value of this attribute can not be found then an error will occur when this Lab is installed.
If this attribute is defined, the SourceVHD attribute should not be defined.
                      
``` templatevhd="Windows Server 2012 R2 Datacenter Core" ```

### 6.1.13a - EXPOSEVIRTUALIZATIONEXTENSIONS Optional Attribute
> exposevirtualizationextensions="xs:string"


This optional attribute controls whether or not Virtualization Extensions are exposed for Virtual Machines based on this Template.
This attribute should only be enabled if the Host system this Lab is to be installed on is able to support Nested Virtualization.
Currently this is only supported on Windows 10 built 10586 or above and Windows Server 2016 TP4 or above.

 - Default Value: N.
 - Valid Values: Y | N
                      
``` exposevirtualizationextensions="Y" ```

### 6.1.14a - PACKAGES Optional Attribute
> packages="xs:string"


This optional attribute can contain a comma delimited list of packages that should be installed onto any Virtual Machines using this Template.

If the Template is a Nano Server then the packages can be .cab files, which will install the Nano Server package from the ISO or a Resource MSU file.

If the Template is not a Nano Server then the packages must be Resource MSU files.

Valid Values:
 - Resource MSU names that are can be found in the ResourceMSU list.

Valid Values for Nano Server:
 - Filename including the .cab extension of a valid Nano Server package found on the Windows Install Media ISO.
 - Resource MSU names that are can be found in the ResourceMSU list.
                       
``` packages="Microsoft-NanoServer-DNS-Package.cab,SomePackage.msu" ```

### 7.0e - VMS Optional Element

This optional element contains a collection of zero or more VM nodes, each representing a Virtual Machine that will be created when this Lab is installed.
Each Virtual Machine will refer back to a Template that is found in the Templates collection.
If the Template used by this Virtual Machine can not be found, an error will occur when this Lab is installed.
            
``` <vms>...</vms> ```

### 7.1e - VM Optional Element

This optional element represents a Virtual Machine that will be created when this Lab is installed.

All Lab configurations should include at least one Virtual Machine, although an error will not be thrown if no Virtual Machines are defined in a Lab.
                  
``` <vm>...</vm> ```

### 7.1.1a - NAME Required Attribute
> name="xs:string"


This required attribute contains the name of the Lab Virtual Machine.
This is the name that will appear in the Hyper-V manager for this Virtual Machine when this Lab is installed.

Note: If this Lab configuration has got a LabId setting defined, it will be pre-pended to this value when the Virtual Machines is created.
                      
``` name="SA-DC1" ```

### 7.1.2a - TEMPLATE Required Attribute
> template="xs:string"


This required attribute is used to specify the template from the templates collection that will be used to create this Virtual Machine from.
The Template must match the name of one of the Templates in the Template collection, otherwise an error will occur when the Lab is installed.

Note: many of the attributes defined in for the Virtual Machine may also be defined in the Template.
If they are defined in the template but not in the Virtual Machine then the template setting will be used.
If the setting is defined in the Virtual Machine and also in the Template, the Virtual Machine value will be used.
                      
``` template="Windows Server 2012 R2 Datacenter Core" ```

### 7.1.3a - COMPUTERNAME Required Attribute
> computername="xs:string"


This required attribute contains the Computer Name of the Virtual Machine.
This is the name that will be set on the Virtual Machine once it has been first booted.
                      
``` computername="SA-DC1" ```

### 7.1.4a - MEMORYSTARTUPBYTES Optional Attribute
> memorystartupbytes="xs:string"


This optional attribute contains the amount of startup memory to assign to Virtual Machine.
If this attribute is not defined, but it is defined in the Template then the template value will be used, otherwise the default value will be used.

 - Default Value: 1GB.
 - Valid Values: PowerShell numeric values (e.g. 2GB, 1TB, 300MB, 160000000).
                      
``` memorystartupbytes="8GB" ```

### 7.1.5a - DYNAMICMEMORYENABLED Optional Attribute
> dynamicmemoryenabled="xs:string"


This optional attribute contains a flag to enable or disable Dynamic Memory for Virtual Machine.
If this attribute is not defined, but it is defined in the Template then the template value will be used, otherwise the default value will be used.
Note: Disabling this value is usually only used when Nested Virtualization is required.

 - Default Value: Y.
 - Valid Values: Y | N
                      
``` dynamicmemoryenabled="N" ```

### 7.1.6a - EXPOSEVIRTUALIZATIONEXTENSIONS Optional Attribute
> exposevirtualizationextensions="xs:string"


This optional attribute controls whether or not Virtualization Extensions are exposed for Virtual Machine.
If this attribute is not defined, but it is defined in the Template then the template value will be used, otherwise the default value will be used.
This attribute should only be enabled if the Host system this Lab is to be installed on is able to support Nested Virtualziation.
Currently this is only supported on Windows 10 built 10586 or above and Windows Server 2016 TP4 or above.

 - Default Value: N.
 - Valid Values: Y | N
                      
``` exposevirtualizationextensions="Y" ```

### 7.1.7a - USEDIFFERENCINGDISK Optional Attribute
> usedifferencingdisk="xs:string"


This optional attribute controls whether or not the Boot VHD created for this Virtual Machine will be a Differencing disk or a copy of the Template VHD.
Using a Differencing Disk for the Boot VHD will conserve disk space.

 - Default Value: Y.
 - Valid Values: Y | N
                      
``` usedifferencingdisk="Y" ```

### 7.1.8a - ADMINISTRATORPASSWORD Optional Attribute
> administratorpassword="xs:string"


This optional attribute specifies the local Administrator password to assign when this Virtual Machine is installed.
If this attribute is not defined, but it is defined in the Template then the template value will be used, otherwise the default value will be used.
                      
``` administratorpassword="MyP@ssw0rd!1" ```

### 7.1.9a - PRODUCTKEY Optional Attribute
> productkey="xs:string"


This optional attribute specifies the Windows product key to set on this Virtual Machine.
If this attribute is not defined, but it is defined in the Template then the template value will be used, otherwise the default value will be used.
                      
``` productkey="AAAAA-AAAAA-AAAAA-AAAAA-AAAAA" ```

### 7.1.10a - TIMEZONE Optional Attribute
> timezone="xs:string"


This optional attribute sets the timezone assigned to this Virtual Machine.
If this attribute is not defined, but it is defined in the Template then the template value will be used, otherwise the default value will be used.

 - Default Value: PST.
                      
``` timezone="CST" ```

### 7.1.11a - UNATTENDFILE Optional Attribute
> unattendfile="xs:string"


This optional attribute allows a specific unattend XML file to be used instead of the default XML file.
If a relative path is used for this attribute then it will be appended onto the path of this the Lab config file, otherwise the full rooted path to the file will be used.
                      
``` unattendfile="Unattend\SpecialUnattend.xml" ```

### 7.1.12a - SETUPCOMPLETE Optional Attribute
> setupcomplete="xs:string"


This optional attribute allows a specific Setup Complete script file to be used instead of the default Setup Complete script.
If a relative path is used for this attribute then it will be appended onto the path of this the Lab config file, otherwise the full rooted path to the file will be used.
                      
``` setupcomplete="Scripts\SetupScompleteDebug.cmd" ```

### 7.1.13a - INTEGRATIONSERVICES Optional Attribute
> integrationservices="xs:string"


This optional attribute controls which Integration Services are enabled on this Virtual Machine.
It should contain a comma delimited list of Integration Service names that should be enabled.
If this attribute is defined but left empty, all Integration Services will be disabled.
If this attribute is not defined all Integration Services will be enabled.
If this attribute is not defined, but it is defined in the Template then the template value will be used, otherwise the default value will be used.

 - Default Value: Guest Service Interface,Heartbeat,Key-Value Pair Exchange,Shutdown,Time Synchronization,VSS
 - Valid Values: Guest Service Interface | Heartbeat | Key-Value Pair Exchange | Shutdown | Time Synchronization | VSS
                      
``` integrationservices="Guest Service Interface,Heartbeat" ```

### 7.1.14a - PACKAGES Optional Attribute
> packages="xs:string"


This optional attribute can contain a comma delimited list of packages that should be installed onto this Virtual Machine.
If this attribute is not defined, but it is defined in the Template then the template value will be used, otherwise the default value will be used.

If the Virtual Machine is a Nano Server then the packages can be .cab files, which will install the Nano Server package from the ISO or a Resource MSU file.

If the Virtual Machine is not a Nano Server then the packages must be Resource MSU files.

Valid Values:
 - Resource MSU names that are can be found in the ResourceMSU list.

Valid Values for Nano Server:
 - Filename including the .cab extension of a valid Nano Server package found on the Windows Install Media ISO.
 - Resource MSU names that are can be found in the ResourceMSU list.
                      
``` packages="Microsoft-NanoServer-DNS-Package.cab,SomePackage.msu" ```

### 7.1.15a - BOOTORDER Optional Attribute
> bootorder="xs:unsignedByte"


This optional attribute controls the boot and shutdown order of the Virtual Machine when Start-Lab or Stop-Lab is called repsectively.
Multiple Lab Virtual Machines in the same Lab can share the same boot order.
Any Lab Virtual Machines without a boot order will be started last or shutdown first.
                      
``` bootorder="4" ```

### 7.1.16a - CERTIFICATESOURCE Optional Attribute
> certificatesource="xs:string"


This optional attribute controls where the Certificates for the Lab Virtual Machine is generated from.
This attribute should not need to be changed in most Lab Virtual Machines.
The attribute is ignored for Nano Servers because certificate generation can not be performed by Nano Servers (currently).

 - Default Value: Guest (or Host for Nano Servers).
 - Valid Values: Guest | Host
                      
``` certificatesource="Host" ```

### 7.1.17a - INSTANCECOUNT Optional Attribute
> instancecount="xs:unsignedByte"


This optional attribute causes more than one copy of the Virtual Machine to be generated.
If set to a value more than one, it will cause this Virtual Machine to be replicated this number of times, with the machine number appended onto the end of the Virtual Machine and folder.
Any IP addresses and MAC addresses statically assigned to the network adapters in this machine will also be adjusted by increasing by one each time.

**Care should be taken to ensure that IP addresses and MAC addresses do not overlap or stretch outside of subnet boundaries.**
**It is strongly recommended that the adapter MAC addresses on Lab VMs that have an instance count of more than one is not set, but allowed to be managed by the Hyper-V Host.**
**DHCP address assignment is also recommneded on all adapters connected to Lab VMs with an instance count of more than one.**
**If DHCP address assignement is not used then extreme care must be taken to ensure that all adapters are assigned to different subnets and will not overlap any other Lab Virtual Machine IP address assignments.**

 - Default Value: 1
 - Valid Values: 1 - 255
                      
``` instancecount="5" ```

### 7.1.1e - DATAVHDS Optional Element

This optional element contains a collection of zero or more DataVHD nodes, each representing a Data Virtual Hard Drive that will be created and attached to this Virtual Machine when this Lab is installed.
                        
``` <datavhds>...</datavhds> ```

### 7.1.1.1e - DATAVHD Optional Element

This optional element represents a Data Virtual Hard Drive that will be created and attached to the Virtual Machine when the Lab is installed.
                              
``` <datavhd>...</datavhd> ```

### 7.1.1.1.1a - VHD Required Attribute
> vhd="xs:string"


This required attribute is used to specify the path and filename of the Virtual Machine Data VHD to create and attach to the Virtual Machine.
If a relative path or just a filename is provided to the VHD file then it will be set as relative to the 'Virtual Hard Disks' folder in the Virtual Machine folder.
If this VHD does not exist then it may be created using the additional attributes provided.
                                  
``` vhd="DataDisks/DataDisk1.vhdx" ```

### 7.1.1.1.2a - SOURCEVHD Optional Attribute
> sourcevhd="xs:string"


This optional attribute controls the file path to the VHD file that will be cloned to create the new Data VHD if it does not exist.
This attribute is only used when the Data VHD does not exist and need to be created.
This attribute should not be defined if the Size or Type attributes are defined.
If the MoveSourceVHD attribute is set to 'Y' then this file will be moved to Data VHD location instead of being copied.
                                  
``` vhd="DataDisks/DataDisk1.vhdx" ```

### 7.1.1.1.3a - COPYFOLDERS Optional Attribute
> copyfolders="xs:string"


This optional attribute allows specified folders to be copied onto a new Data VHD when it is first created.
This attribute is only used when the Data VHD does not exist and need to be created.
When a new DataVHD is created the folders specified in this attribute are copied recursively to the first formatted partition on the new Data VHD.
This attribute should only be set if both the partitionstyle and filesystem attributes are defined, or if the new Data VHD is cloned from a VHD that contains a formatted volume.
                                  
``` copyfolders="f:\data\tools" ```

### 7.1.1.1.4a - TYPE Optional Attribute
> type="xs:string"


This optional attribute controls the type of Data VHD file to create if the VHD does not already exist.
This attribute is only used when the Data VHD does not exist and need to be created.
This attribute should not be defined if the SourceVHD attribute is defined.
If the value of this attribute is Differencing then the ParentVHD attribute must also be set.

 - Valid Values: Fixed | Dynamic | Differencing
                                  
``` type="Dynamic" ```

### 7.1.1.1.5a - SIZE Optional Attribute
> size="xs:string"


This optional attribute controls the size of Data VHD file to create if the VHD does not already exist.
If the VHD already exists and this value is larger than the current size of the VHD, then it will be expanded, otherwise an error will occur.
This attribute should not be defined if the SourceVHD attribute is defined.

 - Valid Values: PowerShell numeric values (e.g. 2GB, 1TB, 300MB, 160000000).
                                  
``` size="100GB" ```

### 7.1.1.1.6a - SUPPORTPR Optional Attribute
> supportpr="xs:string"


This optional attribute enables support persistent reservation on this Data VHD.
This attribute is only used when the Data VHD does not exist and need to be created.
This attribute is only used when the Data VHD has the Shared attribute set to 'Y'.

 - Valid Values: Y | N
                                  
``` supportpr="Y" ```

### 7.1.1.1.7a - PARTITIONSTYLE Optional Attribute
> partitionstyle="xs:string"


This optional attribute causes a newly created Data VHD to be partitioned and formatted so that files and folders can be copied to it.
This attribute is only used when the Data VHD does not exist and need to be created.
Normally, this attribute would be set if the CopyFolders attribute was also set, enabling the folders to be copied onto the Data VHD before the Virtual Machine has been provisioned.
If this is not defined for then the Data VHD will need to be partitioned and allocated within the host operating system via DSC or some other mechanism.
If this attribute is defined then the FileSystem attribute must also be defined.

 - Valid Values: MBR | GPT
                                  
``` partitionstyle="GPT" ```

### 7.1.1.1.8a - FILESYSTEM Optional Attribute
> filesystem="xs:string"


This optional attribute causes a newly created Data VHD to be partitioned and formatted so that files and folders can be copied to it.
This attribute is only used when the Data VHD does not exist and need to be created.
Normally, this attribute would be set if the CopyFolders attribute was also set, enabling the folders to be copied onto the Data VHD before the Virtual Machine has been provisioned.
If this is not defined for then the Data VHD will need to be partitioned and allocated within the host operating system via DSC or some other mechanism.
If this attribute is defined then the PartitionStyle attribute must also be defined.

 - Valid Values: FAT32 | EXFAT | NTFS | REFS
Note: REFS can only be used if the host is Windows Server 2012 or above. However, REFS can still be formatted within the guest operating system even if the Host is Windows 10.
                                  
``` filesystem="NTFS" ```

### 7.1.1.1.9a - FILESYSTEMLABEL Optional Attribute
> filesystemlabel="xs:string"


This optional attribute causes a newly created Data VHD to be set with a label if it has been partitioned and formatted.
This attribute is only used when the Data VHD does not exist and need to be created.
Normally, this attribute would be set if the CopyFolders attribute was also set, enabling the folders to be copied onto the Data VHD before the Virtual Machine has been provisioned.
If this attribute is defined then both the PartitionStyle and FileSystem attributes must also be defined.
                                  
``` filesystemlabel="ToolsDisk" ```

### 7.1.1.1.10a - PARENTVHD Optional Attribute
> parentvhd="xs:string"


This optional attribute specifies the Parent VHD to use for a Differencing VHD.
It should be a full path or a path relative to the Virtual Hard Disk folder in the Virtual Machine.
This attribute is only used when the Data VHD does not exist and need to be created.
If this attribute is defined then the Type attribute must be set to Differencing.
                                  
``` parentvhd="..\..\ToolsDiskParent.vhdx" ```

### 7.1.1.1.11a - MOVESOURCEVHD Optional Attribute
> movesourcevhd="xs:string"


This optional attribute causes the Source VHD that is used to create the new Data VHD to be moved instead of copied.
This attribute should only be set to 'Y' if this SourceVHD attribute is defined.

 - Valid Values: Y | N
                                  
``` movesourcevhd="Y" ```

### 7.1.1.1.12a - SHARED Optional Attribute
> shared="xs:string"


This optional attribute enables the Data VHD to be attached as a Shared VHD to the Virtual Machine.
This attribute should only be set to 'Y' if this DataVHD is being stored on a Cluster Shared Volume and the share supports SMB 3.02.

 - Valid Values: Y | N
                                  
``` shared="Y" ```

### 7.1.2e - DVDDRIVES Optional Element

This optional element contains a collection of zero or more DVDDrive nodes, each representing a Virtual DVD Drive that will be created and attached to this Virtual Machine when this Lab is installed.
                        
``` <dvddrives>...</dvedrives> ```

### 7.1.2.1e - DVDDRIVE Optional Element

This optional element represents a Virtual DVD Drive that will be created and attached to the Virtual Machine when the Lab is installed.
                              
``` <dvddrive>...</dvddrive> ```

### 7.1.2.1.1a - ISO Optional Attribute
> iso="xs:string"


This optional attribute is used to specify the name of the ISO Resource to mount to this Virtual DVD Drive.
                                  
``` iso="" ```

### 7.1.3e - ADAPTERS Optional Element

This optional element contains a collection of zero or more Adapter nodes, each representing a Virtual Network Adapter that will be created, attached to the Virtual Machine and connected to a Virtual Switch when this Lab is installed.
                        
``` <adapters>...</adapters> ```

### 7.1.3.1e - ADAPTER Optional Element

This optional element represents a Virtual Network Adapter that will be created, attached to the Virtual Machine and connected to a Virtual Switch when the Lab is installed.
                              
``` <adapter>...</adapter> ```

### 7.1.3.1.1a - NAME Required Attribute
> name="xs:string"


This required attribute controls the name of this Virtual Network Adapter within the Host Operating System and the Guest Operating System of this Virtual Machine.
The Virtual Network Adapter name within the Host will be changed immediately, but the Adapter name within the Guest Operating System will only be configured when the Guest is first installed.

Changing the Name of the Adapter after the Guest Operating System has been installed is not possible, by changing this Name value.

Note: If this Lab configuration has got a LabId setting defined, it will be pre-pended to this value when the Virtual Machine is created.
                                  
``` name="Cluster Comms" ```

### 7.1.3.1.2a - SWITCHNAME Required Attribute
> switchname="xs:string"


This required attribute controls the which Virtual Switch this Virtual Network Adapter should connect to.

Note: If this Lab configuration has got a LabId setting defined, it will be pre-pended to this value when the Virtual Machine is created as long as the switch being connected to is an Internal, Private or NAT switch.
                                  
``` switchname="Cluster" ```

### 7.1.3.1.3a - MACADDRESS Optional Attribute
> macaddress="xs:string"


This optional attribute is used to set a static MAC Address on the Virtual Network Adapter.
Care should be taken to ensure that this MAC Address is unique on the Virtual Switch that is being connected to.
                                  
``` macaddress="00155D010801" ```

### 7.1.3.1.4a - VLAN Optional Attribute
> vlan="xs:unsignedByte"


This optional attribute is used to configure a VLAN ID on the Virtual Network Adapter.
If this attribute is set it will override any VLAN ID that is set on the Virtual Switch that this Virtual Network Adapter connects to.
If this attribute is not set but the VLAN ID is set on the Virtual Switch that this Virtual Network Adapter connects to is set, then the Virtual Network Adapter VLAN ID will be set to the Virtual Switch VLAN ID.
                                  
``` vlan="80" ```

### 7.1.3.1.5a - MACADDRESSSPOOFING Optional Attribute
> macaddressspoofing="xs:string"


This optional attribute enables MAC Address spoofing by the Guest Operating System.
This is usually required when Network Virtualization is being implemented.

 - Default Value: N.
 - Valid Values: Y | N
                                  
``` macaddressspoofing="Y" ```

### 7.1.4e - DSC Optional Element

This optional element contains the settings related to configuring Desired State Configuration on the Lab Virtual Machine.
                        
``` <dsc>...</dsc> ```

### 7.1.4.1a - CONFIGNAME Required Attribute
> configname="xs:string"


This required attribute contains the configuration name that is set in the DSC Library Configuration file that is used to configure this Virtual Machine.
                            
``` configname="DC_FORESTPRIMARY" ```

### 7.1.4.2a - CONFIGFILE Required Attribute
> configfile="xs:string"


This required attribute contains the filename for the DSC Library Configuration file to use to configure this Virtual Machine.
If a relative path is used for this attribute then it will be appended onto the DSCLibrary path specified in the Lab settings, otherwise the full rooted path to the file will be used.
                            
``` configfile="DC_FORESTPRIMARY.DSC.ps1" ```

### 7.1.4.3a - LOGGING Optional Attribute
> logging="xs:string"


This optional attribute enables DSC Logging on the Virtual Machine in the DSC Event Logs.

 - Default Value: N.
 - Valid Values: Y | N
                            
``` logging="Y" ```

### 7.1.4.1e - PARAMETERS Optional Element

> parameters="xs:string"


This optional element contains any parameters that should be passed to the DSC Library Configuration script being used to configure this Virtual Machine.
These parameters get loaded into the ConfigData object and can be then used by the DSC Library Configuration script.
The parameters that are available to be set depends on the DSC Library Configuration script that is assigned to this Virtual Machine.
Review the documentation within the DSC Library Configuration script to see what parameters are available.
                              
``` <parameters>...</parameters> ```
