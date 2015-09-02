Configuration ROOTCA
{
	Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
	Import-DscResource -ModuleName xAdcsDeployment
	Node $AllNodes.NodeName {
		# Assemble the Local Admin Credentials
		If ($Node.LocalAdminPassword) {
			[PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
		}

		WindowsFeature ADCSCA {
			Name = 'ADCS-Cert-Authority'
			Ensure = 'Present'
			}
		
		WindowsFeature ADCSRSAT {
			Name = 'RSAT-ADCS'
			Ensure = 'Present'
			}

		File CAPolicy
		{
			DestinationPath = 'C:\Windows\CAPolicy'
			Contents = "[Version]`r`nSignature= `"$Windows NT$`"`r`n[Certsrv_Server]`r`nRenewalKeyLength=4096`r`nRenewalValidityPeriod=Years`r`nRenewalValidityPeriodUnits=20`r`n[CRLDistributionPoint]`r`n[AuthorityInformationAccess]`r`n"
			Ensure = 'Present'
			DependsOn = '[WindowsFeature]ADCSCA'
			Type = 'File'
		}
		
		xADCSCertificationAuthority ADCS
        {
            Ensure = 'Present'
            Credential = $LocalAdminCredential
            CAType = 'StandaloneRootCA'
			CACommonName = $Node.CACommonName
			CADistinguishedNameSuffix = $Node.CADistinguishedNameSuffix
			ValidityPeriod = 'Years'
			ValidityPeriodUnits = 20
            DependsOn = '[File]CAPolicy'
        }
	}
}
