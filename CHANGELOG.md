# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Convert build pipeline to use GitTools Azure DevOps extension tasks
  instead of deprecated GitVersion extension.

## [1.2.0] - 2020-11-14

### Fixed

- Fix build problems preventing help from being compiled and added
  to the module.

### Changed

- Update sample labs for Windows Server 2019 to use latest
  evaluation ISO download URIs and edition names.
- Removed sample `samples\Sample_WS2019_NanoDomain.xml` because it
  is not valid for Windows Server 2019.
- Improve structure of `Invoke-LabSample.ps1` function to remove need
  for `$script` scope variables.
- Fixed sample `samples\Sample_WS2019_AzureADConnect.xml` default gateway
  for SA-AADC VM.
- `dsclibrary\MEMBER_AADC.DSC.ps1`: Created DSC config for deploying an
  Azure AD Connect server.
- `dsclibrary\MEMBER_WAC.DSC.ps1`: Created DSC config for deploying a
  Windows Administration Center server.

### Fixes

- Fixed GitVersion to prevent build failures

## [1.1.0] - 2020-08-30

### Changed

- Renamed `LabBuilder_LocalizedData.psd1` to `LabBuilder.strings.psd1` to
  align to other PowerShell modules.
- Convert all DSC configurations to use ComputerManagementDsc version
  7.1.0.0.
- Clean up code style on all DSC Library files.
- `dsclibrary\DC_FORESTCHILDDOMAIN.DSC.ps1`:
  - Convert to use xDnsServer version 1.16.0.0.
  - Clean up code style.
- `dsclibrary\DC_FORESTPRIMARY.DSC.ps1`:
  - Convert to use xDnsServer version 1.16.0.0.
  - Clean up code style.
- `dsclibrary\DC_FORESTSECONDARY.DSC.ps1`:
  - Convert to use xDnsServer version 1.16.0.0.
  - Clean up code style.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Convert to use xDnsServer version 1.16.0.0.
  - Clean up code style.
  - Correct DHCP scope example - fixes [Issue #343](https://github.com/PlagueHO/LabBuilder/issues/343).
- `dsclibrary\MEMBER_DHCPDNS.DSC.ps1`:
  - Convert to use xDnsServer version 1.16.0.0.
  - Clean up code style.
  - Correct DHCP scope example - fixes [Issue #343](https://github.com/PlagueHO/LabBuilder/issues/343).
- `dsclibrary\MEMBER_DHCPNPAS2016.DSC.ps1`:
  - Convert to use xDnsServer version 1.16.0.0.
  - Clean up code style.
  - Correct DHCP scope example - fixes [Issue #343](https://github.com/PlagueHO/LabBuilder/issues/343).
- `dsclibrary\MEMBER_DNS.DSC.ps1`:
  - Convert to use xDnsServer version 1.16.0.0.
  - Clean up code style.
- `dsclibrary\STNADALONE_DHCPDNS.DSC.ps1`:
  - Convert to use xDnsServer version 1.16.0.0.
  - Clean up code style.
  - Correct DHCP scope example - fixes [Issue #343](https://github.com/PlagueHO/LabBuilder/issues/343).
- `dsclibrary\STNADALONE_INTERNET.DSC.ps1`:
  - Convert to use xDnsServer version 1.16.0.0.
  - Clean up code style.
- Remove AppVeyor CI pipeline and updated to new Continuous Delivery
  pattern using Azure DevOps - fixes [Issue #355](https://github.com/PlagueHO/LabBuilder/issues/355).
- Fix build badges.
- Change Azure DevOps Pipeline definition to include `source/*` - Fixes [Issue #359](https://github.com/PlagueHO/LabBuilder/issues/359).
- Updated pipeline to use `latest` version of `ModuleBuilder` - Fixes [Issue #359](https://github.com/PlagueHO/LabBuilder/issues/359).
- Merge `HISTORIC_CHANGELOG.md` into `CHANGELOG.md` - Fixes [Issue #360](https://github.com/PlagueHO/LabBuilder/issues/360).
- Changed Build.yml to support `ModuleBuilder` version to `1.7.0` by changing
  `CopyDirectories` to `CopyPaths`.
- Changed `azure-pipelines.yml` to run on all builds and PRs.
- Renamed `master` branch to `main` - fixes [Issue #368](https://github.com/PlagueHO/LabBuilder/issues/368).
- Pinned build to Pester v4.10.1 - Fixes [Issue #369](https://github.com/PlagueHO/LabBuilder/issues/369).

## [1.0.5.104] - 2019-11-10

- Samples\Sample_WS2019_AzureADConnect.xml: Added sample for installing Azure AD
  Connect.
- Convert all DSC configurations to use ActiveDirectoryDsc version
  4.1.0.0.
- `dsclibrary\RODC_SECONDARY.DSC.ps1`:
  - Enable RODC creation because it is supported by ActiveDirectoryDsc.
- `dsclibrary\DC_FORESTPRIMARY.DSC.ps1`:
  - Enabled customizing of Domain NetBios name.
- `Get-LabVm.ps1`:
  - Clean up code style.
- `Enable-LabWSMan.ps1`:
  - Improved function so that if WinRM Service is stopped it will be started.
- `Get-Lab.ps1`:
  - Clean up code style.
  - Fix bug reading `configpath` from `settings` node.
  - Changed to use `ConvertTo-LabAbsolutePath.ps1` to simplify code.
  - Changed to automatically use the `DSCLibrary` folder that comes as part of
    the LabBuilder module if the `dsclibrarypath` setting is not specified
    in the lab configuration - fixes [Issue-335](https://github.com/PlagueHO/LabBuilder/issues/335).
- `ConvertTo-LabAbsolutePath.ps1`:
  - Added function to create an absolute path from a relative lab path.
- Removed `dsclibrarypath` setting from all samples as it is no longer required.
- `Get-LabResourceISO.ps1`:
  - Clean up code style.

## [1.0.4.83] - 2019-09-28

- Change `psakefile.ps1` to detect Azure Pipelines correctly.
- Updated `BuildHelpers` support module for CI pipelines to 2.0.10.
- Added PowerShell Gallery badge to `README.md`.
- `Get-LabUnattendFileContent.ps1`:
- Enabled PSRemoting in Unattend.xml (allows DSC to initialize properly on
   newer operating systems).
- Enabled local administrator account for Client operating systems
  (Windows 10).
- Enabled PowerShell script execution for both 32-bit and 64-bit processes.
- `Connect-LabVM.ps1`:
- Test WinRM connectivity prior to initializing DSC.
- `Install-LabVM.ps1`:
  - Check for DSC Configuration section in XML file prior to calling DSC.

## [1.0.3.69] - 2019-07-22

- `dsclibrary\MEMBER_SUBCA.DSC.ps1`:
  - CAServer parameter removed from ADCSWebEnrollment - fixes [Issue-320](https://github.com/PlagueHO/LabBuilder/issues/320).
  - Fix error occuring when `c:\windows\setup\scripts\` folder does not exist when
    setting the advanced CA configuration settings - fixes [Issue-325](https://github.com/PlagueHO/LabBuilder/issues/325).
- `dsclibrary\MEMBER_ROOTCA.DSC.ps1`:
  - CAServer parameter removed from ADCSWebEnrollment - fixes [Issue-320](https://github.com/PlagueHO/LabBuilder/issues/320).
  - Change `DiscreteSignatureAlgorithm` to `AlternateSignatureAlgorithm` and set
    it to 0 - fixes [Issue-322](https://github.com/PlagueHO/LabBuilder/issues/322).
  - Fix error occuring when `c:\windows\setup\scripts\` folder does not exist when
    setting the advanced CA configuration settings - fixes [Issue-325](https://github.com/PlagueHO/LabBuilder/issues/325).
  - Changed CApolicy.inf RenewalKeyLength to 4096, CNGHashAlgorithm to SHA256 and
    LoadDefaultTemplates to 0 - fixes [Issue-324](https://github.com/PlagueHO/LabBuilder/issues/324).
- `dsclibrary\STANDALONE_ROOTCA.DSC.ps1`:
  - Correct SubCA resource name to wait for - fixes [Issue-321](https://github.com/PlagueHO/LabBuilder/issues/321).
  - Change `DiscreteSignatureAlgorithm` to `AlternateSignatureAlgorithm` and set
    it to 0 - fixes [Issue-322](https://github.com/PlagueHO/LabBuilder/issues/322).
  - Fix error occuring when `c:\windows\setup\scripts\` folder does not exist when
    setting the advanced CA configuration settings - fixes [Issue-325](https://github.com/PlagueHO/LabBuilder/issues/325).
- `dsclibrary\STANDALONE_ROOTCA_NOSUBCA.DSC.ps1`:
  - Change `DiscreteSignatureAlgorithm` to `AlternateSignatureAlgorithm` and set
    it to 0 - fixes [Issue-322](https://github.com/PlagueHO/LabBuilder/issues/322).
  - Fix error occuring when `c:\windows\setup\scripts\` folder does not exist when
    setting the advanced CA configuration settings - fixes [Issue-325](https://github.com/PlagueHO/LabBuilder/issues/325).
- Added `.markdownlint.json` file.
- Fix markdown rule violations in `CHANGELOG.MD`.
- `dsclibrary\MEMBER_FAILOVERCLUSTER_DHCP.DSC.ps1`:
  - Fix DHCP scope to work with newer version of xDhcpServerScope DSC resource.
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\STANDALONE_DHCPDNS.DSC.DSC.ps1`:
  - Fix DHCP scope to work with newer version of xDhcpServerScope DSC resource.
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\STANDALONE_INTERNET.DSC.DSC.ps1`:
  - Fix DHCP scope to work with newer version of xDhcpServerScope DSC resource.
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCPDNS.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCPNPAS2016.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_DHCP.DSC.ps1`:
  - Update to require xDhcpServer resource 2.0.0.0.
- `dsclibrary\MEMBER_NPS_DFSTEST.ps1`:
  - Fix to use correct name of the DFSReplicationGroup resource.
- `dsclibrary\MEMBER_WDS.DSC.ps1`:
  - Fix configuration.

## [1.0.2.58] - 2019-05-04

- Reword module description in Manifest.
- Fix bug when connecting to a Lab VM when TrustedHosts is empty - fixes
  [Issue #314](https://github.com/PlagueHO/LabBuilder/issues/314).
- Moved Schema documentation file into docs folder and converted to
  PlatyPS compatible file.
- Cleaned up Schema documentation file to remove most markdown rule
  violations.
- Cleaned up README.MD file to remove most markdown rule
  violations.
- Fix infinite loop bug occuring in `Stop-Lab` when Lab VM does not
  exist - fixes [Issue #316](https://github.com/PlagueHO/LabBuilder/issues/316).
- Fix infinite loop bug occuring in `Start-Lab` when Lab VM does not
  exist.
- DSCLibrary\MEMBER_NANO.DSC.ps1: Rename xOfflineDomainJoin to
  OfflineDomainJoin - fixes [Issue #317](https://github.com/PlagueHO/LabBuilder/issues/317).

## [1.0.1.40] - 2019-04-13

- Update to use NetworkingDsc 7.0.0.0 and converted DhcpClient
  resource to NetIpInterface - fixes [Issue #304](https://github.com/PlagueHO/LabBuilder/issues/304).
- Refactored module manifest generation process to be more reliable
  and robust.
- Convert module name to be a variable in PSake file to make it more
  easily portable between projects.
- Added samples for Windows Server 2019 - fixes [Issue #305](https://github.com/PlagueHO/LabBuilder/issues/305).
- Cleaned up unit test initialization and fixtures.
- Refactored `Install-Lab` to move Management Switch creation into a
  new function `Initialize-LabManagementSwitch` and created unit tests.
- Added more log information to `SetupComplete.cmd` to diagnose issues
  with initial machine boot on Windows Server 2019.
- Fix bug in `Remove-LabSwitch` where adapter
- Correct documentation markdown errors.
- Removed `Timeout 30` from the Initial `SetupComplete.cmd` that runs
  on each VM when first intialized because it fails to execute on
  Windows Server 2019. Replaced with `Start-Sleep` in `SetupComplete.ps1`
  that is called by `SetupComplete.cmd` - fixes [Issue #308](https://github.com/PlagueHO/LabBuilder/issues/308).
- Change `Update-LabDSC` so that module copy process to Lab Files will
  continue even if destination path is too long. This is to allow DSC
  Resource modules that have example filenames that result in a long
  path.
- Update CI module dependencies in `Requirements.psd1` to latest version:
  - PSScriptAnalyzer: 1.18.0
  - PSDeploy: 1.0.1
  - Platyps: 0.14.0
- Split Private Lib functions into individual .ps1 files.
- Refactored Private Lib functions to improve code style standards.

## [1.0.0.7] - 2018-12-08

- Samples\Sample_WS2016_DCandDHCPandCA.xml: Added to easily create a Windows
  Server 2016 domain with a enterprise root CA.
- Correct certificate authority DSC Resources with ADCSCertificationAuthority
  to be IsSingleInstance.
- Convert xNetworking to NetworkingDsc.
- Converted repository structure and build pipeline to more modern standards.
- Convert module to require WMF 5.1 and all the samples to install WMF 5.1.
- DSCLibrary\MEMBER_MEMBER_DHCP*.ps1: Fixed to support xDHCPServer 2.0.0.0.

## [0.8.4.1160] - 2018-05-22

- Clean up markdown errors in README.MD.
- Updated code style to meet current best practices.
- Updated tests to meet Pester v4 guidelines.
- Convert sample labs to use ISCSIDsc resource module.
- Convert sample labs to use FSRMDsc resource module.
- Convert sample labs to use DFSDsc resource module.
- Convert sample labs to use StorageDsc resource module.
- Convert sample labs to use ActiveDirectoryCDDsc resource module.
- Convert sample labs to use SQLServerDsc resource module.
- Fix error that occurs when DSC ConfigurationData is specified
  as a filename instead of a hashtable when compiling the MOF file.
- Removed Visual Studio Solution and Proejct files.
- DSCLibrary\MEMBER_DFSHUB.DSC.ps1: Added to enable Sample_WS2016_DFSHubAndSpoke
  sample.
- DSCLibrary\MEMBER_DFSSPOKE.DSC.ps1: Added to enable Sample_WS2016_DFSHubAndSpoke
  sample.
- Samples\Sample_WS2016_DFSHubAndSpoke.xml: Added to demonstrate Hub and Spoke DFS
  replication gorup.

## [0.8.3.1140] - 2017-07-17

- Enforce xNetworking v5.0.0.0 is installed and used - fixes [Issue #289](https://github.com/PlagueHO/LabBuilder/issues/289).
- DSCLibrary\MEMBER_SQLSERVER2014.DSC.ps1: Updated to support v8.0.0.0 of xSQLServer
- DSCLibrary\MEMBER_SQLSERVER2016.DSC.ps1: Updated to support v8.0.0.0 of xSQLServer

## [0.8.3.1132] - 2017-07-16

- Added .vscode\settings.json to force code styles and enable auto formatting in
  VS Code.
- Changed WaitVMStarted to check VM is running and also handle blank heartbeat
  being returned in Windows 10 15063 (Creators Update) and above.
- Updated LabBuilder to support changes in xNetworking DSC Resource v5.0.0.0
- Updated DSC sample configurations to support xStorage DSC Resource v3.2.0.0

## [0.8.3.1124] - 2017-06-29

- DSCLibrary\MEMBER_DHCPNPAS2016.DSC.ps1:Added DSC Library Configuration for
  DHCP with NPAS on Windows Server 2016 - see [Issue 283](https://github.com/PlagueHO/LabBuilder/issues/283).

## [0.8.3.1116] - 2017-05-20

- Moved Changelist.md file to root and renamed to CHANGELOG.MD.
- Cleaned up markdown errors in README.MD.
- Updated samples to use latest version of Windows Server 2016 Evaulation ISO.
- Added sample Sample_WS2016_DomainFunctions.xml for creating an Azure Functions
  lab.
- Added support for codecoverage analysis using CodeCov.io.

## [0.8.3.1107] - 2016-11-26

- DSCLibrary\MEMBER_CONTAINER_HOST.DSC.ps1: Added DSC Configuration for configuring
  a Docker Container host.
- Added support for inserting ODJ files into a VM for joining Nano Servers to an
  AD domain.
- Fix error occuring when starting DSC on node with no adapters.
- LabDSCModule class: Added [Version] MinimuVersion property, converted ModuleVersion
  property to [Version].
- Corrected format of Changelist.md.
- Change SubnetMask to PrefixLength in xIPAdress DSC Config created by Get-LabDSCNetworkingConfig.
- Added support for specifying minimum module version in Update-LabDSC to enforce
  xNetworking 3.0.0.0 usage.

## [0.8.3.1068] - 2016-01-01

- Added Jenkins build scripts.
- Fix ExposeVirtualizationExtensions when on Windows 10 build 14352 and above.
- DSCLibrary\*_ROOTCA.DSC.ps1: Fix to support 2.0.0.0 of xADCSDeployment resource.
- DSCLibrary\*_SUBCA.DSC.ps1: Fix to support 2.0.0.0 of xADCSDeployment resource.
- Converted AppVeyor.yml to pull Pester from PSGallery instead of Chocolatey.
- Changed AppVeyor.yml to use default image
- Added support for Version of VM - Only works on latest Windows 10 builds post 14352
- Added support for generation of VM so Generation 1 VMs can now be created
- Fixed issue with Shared VHDX that prevented their creation.
- Updated SCHEMA for information on Version and Generation
- Fixed several typos in comment sections
- DSC resources created for working with composite DSC resources - non-functional
  at this time
- Correctly enable PS Remoting using Enable-PSRemoting cmdlet.
- DSCLibrary\MEMEBER_DSCPULLSERVER.DSC.ps1: Added DSC Library resource for
  creating DSC Pull Servers.
- Added additional logging information when copying DSC Resource modules.
- Fix bug when copying DSC Resource modules to LabBuilder Files for VM when DSC
  Modules folder does not exist.
- DSCLibrary\MEMBER_SQLSERVER2016.DSC.ps1: Added DSC Library configuration for
  installing a SQL Server 2016 from an ISO.
- Fix bug using a NIC team as network adapter bound to an external switch.
- Change AppVeyor script to improve and automate deployment process.
- Mock functions added to unit tests so that can run on machines without Hyper-V
  installed.
- Added Windows Server 2016 sample labs.
- Removed old Lab test scripts and replaced with a single Lab test script ```Invoke-LabSample.ps1```.
- Updated all samples to use the filename of the latest Windows Server 2012 R2
  Evaluation ISO.

## [0.8.3.0] - 2016-01-01

- Fix bug where Administrator account is not enabled in Windows client OS.
- Added support for ModulePath attribute on Settings node.

## [0.8.2.0] - 2016-01-01

- Fix bug when creating a new Management adapter for a new Lab and setting a
  static MAC address on it.

## [0.8.1.0] - 2016-01-01

- Converted all Write-Verbose calls to Write-LabMessage function.
- Fix bug when creating a new Management adapter for a new Lab.

## [0.8.0.0] - 2016-01-01

- DSCLibrary\MEMBER_SQLSERVER2014.DSC.ps1: Completed DSC Library configuration
  for installing a SQL Server 2014 from an ISO.
- Samples\Sample_WS2012R2_DomainSQL2014.xml: Added new Sample for building a
  simple domain with a SQL Server.
- Samples\*.xml: DNS Forwarders set to Google for all Samples with Edge nodes.
- Added LabBuilderConfig\Settings attribute requiredwindowsbuild.
- Get-Lab: Added support for preventing a Lab from being used on a host not at
  the requiredwindowsbuild build version.
- Samples\Sample_WS2012R2_DomainClustering.xml: Required build version set to 10586.
- Samples\Sample_WS2012R2_DCandDHCPOnly_NAT.xml: Required build version set to 14295.
- Added LabBuilderConfig\Resources attribute ISOPath.
- DSCLibrary\MEMBER.DSC.ps1: Corrected filename.
- DSCLibrary\MEMBER.DSC.ps1: Fixed Configuration name.
- Added InstallRSATTools parameter DSC configurations to enable installation of
  applicable RSAT Management tools:
  - DC_FORESTCHILDDOMAIN.DSC.ps1
  - DC_FORESTPRIMARY.DSC.ps1
  - DC_SECONDARY.DSC.ps1
  - RODC_SECONDARY.DSC.ps1
  - MEMBER_DNS.DSC.ps1
  - MEMBER_DHCPNPAS.DSC.ps1
  - MEMBER_DHCPDNS.DSC.ps1
  - MEMBER_DHCP.DSC.ps1
  - MEMBER_ROOTCA.DSC.ps1
  - MEMBER_SUBCA.ps1

## [0.7.9.0] - 2016-01-01

- Fixed failure when creating self-signed certificate on localized systems, by
  replacing EKU Names with IDs.
- Fixed support for NAT switches and added Switch attributes NatSubnet and
  NatGatewayAddress.
- Private function UpdateSwitchManagementAdapter added.
- Samples\Sample_WS2012R2_DCandDHCPOnly_NAT.xml: Added sample for testing NAT
  based Lab switches.
- Improved ShouldProcess messages to be easier to read.
- Utils\Install-LabPackageProvider: Added function for ensuring Package Providers
  are installed.
- Utils\Register-LabPackageSource: Added function for ensuring Package surces
  are registered.
- Install-Lab: Added checks to ensure required PackageProviders and PackageSources
  are available.

## [0.7.8.0] - 2016-01-01

- Install-Lab:
  - Force flag added to suppress confirmation messages.
  - Will attempt to install WS-Man if not installed, failure will
    cause install to fail.
- Disconnect-LabVM:
  - Improve handling of adding IPAddress to trusted hosts.
- Get-LabVM:
  - LabID will only be prepended to VM Adapter name for adapters not
    attached to an External switch.

## [0.7.7.0] - 2016-01-01

- Samples\Sample_WS2016TP5_DCandDHCPOnly.xml:
  - Set edition in Nano Server Template VHD.
  - Fixed WS2016 Template VHD edition names.
  - Fixed Template name.

## [0.7.6.0] - 2016-01-01

- Added .vscode\tasks.json file to allow quick conversion of LabBuilder Schema
  to MD.
- Moved existing Libs into Libs\Private folder.
- Updated samples and tests to support Windows Server 2016 TP5.
- Updated Visual Studio Project and Soltion files.
- Fix Nano Server localization package filename support for TP5.

## [0.7.5.0] - 2016-01-01

- Added VM InstanceCount attribute for creating multiple copies a VM in a Lab.
- Added $script:currentBuild variable to allow easier access to OS build version.
- Fix to prevent ExposeVirtualizationExtensions from being applied on Lab Hosts
  that don't support it.
- Samples\Sample_WS2012R2_DCandDHCPandEdge.ps1: Added sample for creating Lab with
  DC, DHCP and Edge servers.
- DSCLibrary\MEMBER_JENKINS.DSC.ps1: Added DSC Library configuration for creating
  a Domain Joined Jenkins CI Server.
- DSCLibrary\STANDALONE_JENKINS.DSC.ps1: Added DSC Library configuration for
  creating a Standalone Jenkins CI Server.
- Install-Lab will now stop if error occurs creating Lab Management switch or adapter.
- Added support for Get-Lab to work with config files with a relative path.
- Improved handling of Initialize-LabSwitches when Multiple External adapters are
  available and/or already in use by external switches.
- Improved Localization support for Integration Services.

## [0.7.4.0] - 2016-01-01

- lib\vm.ps1: WaitWMStarted - name of integrationservice "heartbeat" detected by
  id to be culture neutral
- DSCLibrary\MEMBER_ADFS.DSC.ps1: Enable ADFS Firewall Rules.
- AppVeyor.yml: Module Manifest version number always set to match build version.
- DSCLibrary\MEMBER_IPAM.DSC.ps1:Added DSC Library Configuration for IPAM Server.
- DSCLibrary\MEMBER_FAILOVERCLUSTER_*.DSC.ps1: Added iSCSI Firewall Rules to allow
  iSNS registration.
- DSCLibrary\MEMBER_ADFS.DSC.ps1: Added DSC Library configuration for ADRMS.
- DSCLibrary\MEMBER_SQLSERVER2014.DSC.ps1: Added Incomplete DSC Library configuration
  for SQL Server 2014.
- Support\Convert-WindowsImage.ps1: Updated to March 2016 version so that DISM
  path can be specified.
- labbuilder-schema.xsd: Added Settings\DismPath attribute so that path to DISM
  can be specified.
- Failure to validate Lab configuration XML will terminate any cmdlet immediately.
- Any failure in Install-Lab will cause immediate build termination.
- Support\Convert-WindowsImage.ps1: Fixed incorrect error reported when invalid
  Edition is specified.
- SetModulesInDSCConfig: Ensure each Import-DSCResource ends up on a new line.
- DSCLibrary\MEMBER_NANO.DSC.ps1: Added DSC Library configuration for joining a
  Nano server to n AD Domain.
- labbuilder-schema.xsd: Fixed VM attribute descriptions.
- Added CertificateSource attribute to VM to support controlling where any Lab
  Certificates should be generated from when initializing a Lab VM.
- Generalized Nano Server package support.
- Both ResourceMSU and Nano Server packages can now be installed on Template VHDs
  and Virtual Machines.
- Automatically add Microsoft-NanoServer-DSC-Package.cab to new Nano Server VMs.
- Added BindingAdapterName and BindingAdapterMac attribute to switch element to
  allow control over bound adapter.
- GetCertificatePsFileContent Changed so that PFX certificate imported into Root
  store for non Nano Servers.
- Automatically set xNetworking version in DSC Networking config to that of the
  highest version available on the Lab Host.

## [0.7.3.0] - 2016-01-01

- DSCLibrary\MEMBER_FAILOVERCLUSTER_FS.DSC.ps1: Added ServerName property to
  contain name of ISCSI Server.
- samples\Sample_WS2012R2_DomainClustering.xml: Added ServerName property to all
  Failover Cluster servers DSC properties.
- docs\labbuilderconfig-schema.md: Converted to UTF-8 to eliminate issues with Git.
- support\Convert-XSDToMD.ps1: Added code to convert transformed output to UTF-8.
- Start-Lab: Improved readability if timeout detect code.
- Stop-Lab: Improved readability if timeout detect code.
            Ensure all VMs are stopped in a Bootphase, even if timeout occurs.
- StartDSCDebug.ps1: Added a WaitForDebugger parameter to StartDSCDebug.ps1 that
  will cause LCM to start with debugging mode enabled.
- Lib\Type.ps1: File removed and content moved to header of LabBuilder.psm1 so
  that types were available outside the module context.
- Stop-Lab: Removed Boot Phase timeout because Stop-VM does not return until VM shutdown.
- Added support for ISO resources to be specified in the Lab configuration.
- Added support for DVD Drives in Lab VM configuration.
- DSCLibrary\MEMBER_ADFS.DSC.ps1: Added DSC Library Configuration for ADFS.
- samples\Sample_WS2012R2_MultiForest_ADFS.ps1: Added Sample Lab for creating
  multiple forests for ADFS testing.
- DSCLibrary\MEMBER_REMOTEACCESS_WAP.DSC.ps1: Added DSC Library Configuration for
  Remote Access and Web Application Proxy.
- DSCLibrary\MEMBER_ADFS.DSC.ps1: Install WID.
- DSCLibrary\MEMBER_WEBSERVER.ps1: Created resource for IIS Web Servers.
- samples\Sample_WS2012R2_MultiForest_ADFS.xml: Added Web Application Servers.
- .github\*: Added general documentation on contributing to this project.

## [0.7.2.0] - 2016-01-01

- DSCLibrary\MEMBER_FAILOVERCLUSTER_FS.DSC.ps1: Changed to install most File
  Server features on cluster nodes.
- DSCLibrary\MEMBER_FAILOVERCLUSTER_DHCP.DSC.ps1: Created resource for Failover
  Cluster DHCP Server nodes.
- Readme.md: Additional Documentation added.

## [0.7.1.0] - 2016-01-01

- Get-LabDSCNetworkingConfig: Fix DSC error occuring when a blank DNS Server
  address or Default Gateway address is set on an Adapter.
- InitializeVhd: Prevent unnecessary results of disk partitioning and volume
  creation to console.
- UpdateVMDataDisks: Fix to incorrectly reported Data VHD type change error.
- DSCLibrary\MEMBER_BRANCHCACHE_HOST.DSC.ps1: Created resource for BranchCache
  Hosted Servers.
- DSCLibrary\MEMBER_FILESERVER_*.DSC.ps1: Added BranchCache for File Servers feature.
- Readme.md: Added 'Lab Installation Process in Detail' section.

## [0.7.0.0] - 2016-01-01

- Initialize-LabSwitch: External switch correctly sets Adapter Name.
- IsAdmin: Function removed because was not useful.
- dsclibrary\DC_FORESTDOMAIN.DSC: New DSC Library config for creating child
  domains in an existing forest.
- Samples\Sample_WS2012R2_MultiForest.xml: Added child domains.
- Get-LabSwitch: Converted to output array of LabSwitch objects.
- Initialize-LabSwitch:
  - Converted to use LabSwitch objects.
  - Fixed bug setting VLAN Id on External and Internal Switch Adapters.
- Remove-LabSwitch: Converted to use LabSwitch objects.
- Tests\Test_Sample_*.ps1: Test-StartLabVM function fixed.
- DSCLibrary\MEMBER_*.DSC.ps1: Updated parameter examples to include DCName parameter.
- DSCLibrary\DC_*.DSC.ps1: Added DNS Zone and forwarder options (setting forwarder
  requires xDNSServer 1.6.0.0).
- DSCLibrary\MEMBER_DNS.DSC.ps1: Created resource for member DNS servers.
- Get-LabVMTemplateVHD: Converted to output array of LabVMTemplateVHD objects.
- Initialize-LabVMTemplateVHD:
  - Converted to use LabVMTemplateVHD objects.
  - Check added to ensure Drive Letter is assigned to mounted ISO.
- Remove-LabVMTemplateVHD: Converted to use LabVMTemplateVHD objects.
- Readme.md: Windows Management Framework 5.0 (WMF 5.0) section added.
- DSCLibrary\DC_FORESTDOMAIN.DSC.ps1: Changed name to DC_FORESTCHILDDOMAIN.DSC.ps1
  to better indicate purpose.
- Get-LabVMTemplate: Converted to output array of LabVMTemplate objects.
- Initialize-LabVMTemplate: Converted to use LabVMTemplate objects.
- Remove-LabVMTemplate: Converted to use LabVMTemplate objects.
- Get-LabVM: Converted to output array of LabVM objects.
- Initialize-LabVM: Converted to use LabVM objects.
- Remove-LabVM: Converted to use LabVM objects.
- Lib\dsc.ps1: All functions converted to use LabVM objects.
- Lib\vm.ps1: All functions converted to use LabVM objects.
- Lib\vhd.ps1: All functions converted to use LabVM objects.
- InitializeVhd: Fix error when attempting to create a new VHD/VHDx with a
  formatted volume.

## [0.6.0.0] - 2016-01-01

- New-Lab: Function added for creating a new Lab configuration file and basic
  folder structure.
- Get-Lab: Redundant checks for XML valid removed because convered by XSD schema
  validation.
- Added Lib\Type.ps1 containing customg LabBuilder Classes and Enumerations.
- Added functions for converting XSD schema to MD.
- Fix to Nano Server Package caching bug.
- DSC Library Domain Join process improved.
- DSC\ConfigFile attribute supports rooted paths.
- VM\UnattendFile attribute supports rooted paths.
- VM\SetupComplete attribute supports rooted paths.
- DSC\ConfigFile Lab setting supports rooted paths.
- VM\UseDifferencingBootDisk default changed to 'Y'.
- Get-ModulesInDSCConfig:
  - Returns Array of objects containing ModuleName and ModuleVersion.
  - Now returns PSDesiredStateConfiguration module if listed -expected that
    calling function will ignore if required.
  - Added function to set the Module versions in a DSC Config.
- Update-LabDSC: Updated to set Module versions in DSC Config files.
- DSC Library: Module Version numbers removed from all DSC Library Configrations.
- Test Sample file code updated to remove switches when lab uninstalled.
- Uninstall-Lab: Management Switch automatically removed when Lab uninstalled.
- Configuration Schema:
  - Added Resources\MSU element.
  - Added Settings\Resource attribute.
  - Removed VM\Install element support, superceeded by Packages attribute.
- Get-LabResourceModule: Function added.
- Initialize-LabResourceModule: Function added.
- Get-LabResourceMSU: Function added.
- Initialize-LabResourceMSU: Function added.
- Install-Lab:
  - Fix CheckEnvironment bug.
  - Added calls to Initialize-LabResourceModule and Initialize-LabResourceMSU.
- DownloadResources:
  - Utility function removed, superceeded by Initialize-LabResourceModule and
    Initialize-LabResourceMSU functions.
- Get-LabVM: Removed Install\MSU support.
- InitializeBootVM:
  - Removed Install\MSU support.
  - Added support for installing Packages from Resources\MSU element.
- Initialize-LabVMTemplateVHD:
  - MSU Resources specified in Packages attribute are added to Template VHD when
    converted.
- Initialize-LabVMTemplate:
  - MSU Resources specified in Packages attribute are added to Template  when copied.

## [0.5.0.0] - 2016-01-01

- BREKAING: Renamed Config parameter to Lab parameter to indicate the object is
  actually an object that also stores Lab state information.
- Remove-LabVM: Removed parameter 'RemoveVHDs'. Added parameter RemoveVMFolder
  which causes the VM folder and all contents to be deleted.
- Uninstall-Lab: Renamed "Remove" parameters to be singular names rather than plural.
- Uninstall-Lab: Added parameter 'RemoveLabFolder' which will cause the entire
  Lab folder to be deleted.
- Uninstall-Lab: Added ShouldProcess support to ask user to confirm actions.
- Update-Lab: Added function which just calls Install-Lab.
- Start-LabVM: Renamed function to Install-LabVM so that it is not confused with
  Start-VM.
- *-LabSwitch: Added Name array parameter to allow filtering of switches to work
  with.
- *-LabVMTemplateVHD: Added Name array parameter to allow filtering of VM Template
  VHDs to work with.
- *-LabVMTemplate: Added Name array parameter to allow filtering of VM Templates
  to work with.
- *-LabVM: Added Name array parameter to allow filtering of VMs to work with.
- Samples: Updated sample code with additional examples.
- Help completed for all exported cmdlets.
- Get-LabVM: XML now validated against labbuilderconfig-schema.xsd in Schemas
  folder when loaded -unless SkipXMLValidation switch is passed.
- All sample and test configuration XML files validated against
  labbuilderconfig-schema.xsd in schemas folder when unit tests run.
- All sample and test configuration XML files updated with namespace -> xmlns="labbuilderconfig".

## [0.4.2.0] - 2016-01-01

- Add bootorder VM attribute for controlling stop-lab/start-lab order.
- Added Start-Lab and Stop-Lab cmdlets.
- *-Lab cmdlet documentation added to Readme.md

## [0.4.1.0] - 2016-01-01

- VHDParentPath setting made optional. Defaults to "Virtual Machine Hard Disks"
  under config.
- Initialize-LabConfiguration function will create labpath and vhdparentpath
  folders if not exist.
- Removed Test-LabConfiguration function and tests moved to Get-LabConfiguration.
- Added Disconnect-LabVM function to disconnect from a connect Lab VM.
- Fixed bug setting TrustedHosts when connecting to Lab VM.
- Added code to revert TrustedHosts when disconnecting from Lab VM.
- All non-exported supporting functions moved into separate support libraries.
- Add support for LabId setting that gets prepended to Lab resources.
- Added LabBuilderConfig schema in schema folder.
- Added LabPath parameter to Install-Lab, Uninstall-Lab and Get-LabConfiguration.
- Fix exception in Disconnect-LabVM.
- Fixed Unit tests to retain current folder location.
- Added PS ScriptAnalyzer Error tests to unit tests.
- Display PS ScriptAnalyzer Warnings when unit tests run.
- Remove-LabVMTemplateVHD function added and will be called from Uninstall-Lab.

## [0.4.0.0] - 2016-01-01

- Some secondary non-exported functions moved into separate support libraries.
- Initialize-LabVMTemplate caches NanoServerPackages from VHD template folder to
  Lab folder.
- Fix exception connecting to VM when TrustedHosts is set to '*'.
- Fix path Lab VM files are created.
- Support for creating Certificates for Nano Servers on the host added.

## [0.3.3.0] - 2016-01-01

- Changed Get-LabSwitch Unit tests to use PesterTestConfig.OK.xml.
- Added support for configuring Nano Server packages for each VM.
- Removed MAC Address minimum/maximum value settings from configuration.
- Fix bug with Wait-LabInitVM failing to copy InitialSetupComplete.txt file.
- Added VMRootPath and LabBuilderFilesPath properties Get-LabVM array containing
  path where VM and LabBuilder files should be stored respectively.
- Added TemplateVHD in templates/template config node for specifying the template
  VHD.

## [0.3.2.0] - 2016-01-01

- Added Initialize-VHD function.
- Added support for formatting Data VHDs.
- Added support for copying multiple folders to DataVHDs.
- Updated Download-ResourceModule to use Invoke-LabDownloadAndUnzipFile function.
- Changed name of Settings\VMPath attribute to LabPath.

## [0.3.1.0] - 2016-01-01

- Disable 'Access Denied' test when connecting to new VM because this error is
  reported by VM that is still booting up.
- Correct Verbose message shown when Integration Services enabled.
- Added Verbose message to indicate creation of VM Initialization files.
- Correct Verbose message not appearing when mounting VM boot disk image file.
- Moved DSC Config message into Localization data.
- Disabled automatic module push to PSGallery till version 1.0.0.0 or greater.

## [0.3.0.0] - 2016-01-01

- Fix to Module detection regex.
- Updated AppVeyor.yml to push more artifacts.
- Fix issue preventing timeout from triggering.
- Improved handling of Remoting connection by moving into a new function Connect-LabVM
- IP Address of VMs automatically added to WS-Man Trusted Hosts to enable HTTP
  remoting connection.
- Prevent error if Panther folder doesn't exist in VHD image when creating a new
  VM.
- Add support for multiple data disks for each VM.
- Add support for creating new data disks by cloning exising VHDs.
- Support for Fixed, Differencing and Shared data disks.
- JSON Object comparison unit tests fixed.
- AppVeyor build status badge added.
- Add support for VM Integration Services flag.
- Initialize-Lab- arrays made optional and will be pulled from config if not passed.
- Configuration parameter changed to Config to reduce size/typing.
- Support for creating VHD boot disks from ISO via TemplateVHD nodes in XML.

## [0.2.0.0] - 2016-01-01

- Code cleanup and refactoring.

## [0.1.0.0] - 2016-01-01

- Initial Release.
