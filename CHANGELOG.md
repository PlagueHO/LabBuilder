# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
