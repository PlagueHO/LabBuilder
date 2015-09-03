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
			Contents = "[Version]`r`n Signature= `"$Windows NT$`"`r`n[Certsrv_Server]`r`n RenewalKeyLength=4096`r`n RenewalValidityPeriod=Years`r`n RenewalValidityPeriodUnits=20`r`n CRLDeltaPeriod=Days`r`n CRLDeltaPeriodUnits=0`r`n[CRLDistributionPoint]`r`n[AuthorityInformationAccess]`r`n"
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
		Script ADCSAdvConfig
		{
			SetScript = {
				[String]$DN = ''
				$Node.DomainName.Split('.') | % { $DN = "DC=$($_),$DN" }
				$DN = $DN.SubString(0,$DN.Length-1)
				& "certutil.exe -setreg CA\DSConfigDN `"CN=Configuration,$DN`" "
				If ($Node.CRLPublicationURLs) {
					& "certutil.exe -setreg CA\CRLPublicationURLs `"$($Node.CRLPublicationURLs)`" "
				}
				If ($Node.CACertPublicationURLs) {
					& "certutil.exe -setreg CA\CACertPublicationURLs `"$($Node.CACertPublicationURLs)`" "
				}
				Restart-Service -Name CertSvc
			}
			GetScript = {
				Return @{
					'DSConfigDN' = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN');
					'CRLPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs');
					'CACertPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs')
				}
			}
			TestScript = { 
				[String]$DN = ''
				$Node.DomainName.Split('.') | % { $DN = "DC=$($_),$DN" }
				$DN = $DN.SubString(0,$DN.Length-1)
				If ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN') -ne $DN) {
					Return $False
				}
				If ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs') -ne $Node.CRLPublicationURLs) {
					Return $False
				}
				If ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs') -ne $Node.CACertPublicationURLs) {
					Return $False
				}
				Return $True
			}
			DependsOn = '[xADCSCertificationAuthority]ADCS'
		}
	}
}
