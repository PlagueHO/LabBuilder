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
				Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value "Set Fires"

				If ($Node.DSConifgDN) {
					& "certutil.exe -setreg CA\DSConfigDN `"$($Node.DSConfigDN)`""
				}
				If ($Node.CRLPublicationURLs) {
					& "certutil.exe -setreg CA\CRLPublicationURLs `"$($Node.CRLPublicationURLs)`""
				}
				If ($Node.CACertPublicationURLs) {
					& "certutil.exe -setreg CA\CACertPublicationURLs `"$($Node.CACertPublicationURLs)`""
				}
				Restart-Service -Name CertSvc
				Add-Content -Path 'c:\windows\setup\scripts\certutil.log' -Value "Certificate Service Restarted ..."
			}
			GetScript = {
				Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value "Get Fires"
				Return @{
					'DSConfigDN' = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN');
					'CRLPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs');
					'CACertPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs')
				}
			}
			TestScript = { 
				Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value "Test Fires"
				Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value ($Node.DSConfigDN)
				Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN'))
				If (($Node.DSConfigDN) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN') -ne $Node.DSConfigDN)) {
					Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value "DSConfigDN NE"
					Return $False
				}
				Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs'))
				Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value ($Node.CRLPublicationURLs)
				If (($Node.CRLPublicationURLs) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs') -ne $Node.CRLPublicationURLs)) {
					Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value "CRLPublicationURLs NE"
					Return $False
				}
				Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs'))
				Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value ($Node.CACertPublicationURLs)
				If (($Node.CACertPublicationURLs) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs') -ne $Node.CACertPublicationURLs)) {
					Add-Content -Path "c:\windows\setup\scripts\TestScript.log" -Value "CACertPublicationURLs NE"
					Return $False
				}
				Return $True
			}
			DependsOn = '[xADCSCertificationAuthority]ADCS'
		}
	}
}
