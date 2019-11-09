# Release Notes

## What is New in LabBuilder 1.0.5.104

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

## What is New in LabBuilder 1.0.4.83

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

## What is New in LabBuilder 1.0.3.69

July 21, 2019

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

## What is New in LabBuilder 1.0.2.58

May 5, 2019

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

## What is New in LabBuilder 1.0.1.40

April 8, 2019

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

## What is New in LabBuilder 1.0.0.6

December 8, 2018

- Samples\Sample_WS2016_DCandDHCPandCA.xml: Added to easily create a Windows
  Server 2016 domain with a enterprise root CA.
- Correct certificate authority DSC Resources with ADCSCertificationAuthority
  to be IsSingleInstance.
- Convert xNetworking to NetworkingDsc.
- Converted repository structure and build pipeline to more modern standards.
- Enabled Azure DevOps build pipeline.
- Convert module to require WMF 5.1 and all the samples to install WMF 5.1.
- DSCLibrary\MEMBER_MEMBER_DHCP*.ps1: Fixed to support xDHCPServer 2.0.0.0.

## Feedback

Please send your feedback to [http://github.com/PlagueHO/LabBuilder/issues](http://github.com/PlagueHO/LabBuilder/issues).
