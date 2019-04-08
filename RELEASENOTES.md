# Release Notes

## What is New in LabBuilder Ureleased

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
