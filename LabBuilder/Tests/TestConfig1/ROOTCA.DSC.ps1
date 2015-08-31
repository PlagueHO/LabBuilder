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
		xADCSCertificationAuthority ADCS
        {
            Ensure = 'Present'
            Credential = $LocalAdminCredential
            CAType = 'StandaloneRootCA'
			CACommonName = $Node.CACommonName
			CADistinguishedNameSuffix = $Node.CADistinguishedNameSuffix
			ValidityPeriod = 'Years'
			ValidityPeriodUnits = 20
            DependsOn = '[WindowsFeature]ADCSCA'
        }
	}
}
