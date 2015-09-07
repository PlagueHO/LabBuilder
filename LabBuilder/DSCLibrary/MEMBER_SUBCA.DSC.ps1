<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_SUBCA
.Desription
	Builds a Member Subordinate CA.
.Parameters:    
	CACommonName = "LABBUILDER.COM Issuing CA"
	CADistinguishedNameSuffix = "DC=LABBUILDER,DC=COM"
	DSConfigDN = "CN=Configuration,DC=LABBUILDER,DC=COM"
	CRLPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n2:http://pki.labbuilder.com/CertEnroll/%1_%3%4.crt"
	CACertPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n2:http://pki.labbuilder.com/CertEnroll/%1_%3%4.crt"  
#########################################################################################################################################>

Configuration MEMBER_SUBCA
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
	Import-DscResource -ModuleName xActiveDirectory
	Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xAdcsDeployment
	Node $AllNodes.NodeName {
		# Assemble the Local Admin Credentials
		If ($Node.LocalAdminPassword) {
			[PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
		}
		If ($Node.DomainAdminPassword) {
			[PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
		}

		WindowsFeature RSATADPowerShell
        { 
            Ensure = "Present" 
            Name = "RSAT-AD-PowerShell" 
        } 

        xWaitForADDomain DscDomainWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $DomainAdminCredential 
            RetryCount = 100 
            RetryIntervalSec = 10 
			DependsOn = "[WindowsFeature]RSATADPowerShell" 
        }

		xComputer JoinDomain 
        { 
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential 
			DependsOn = "[xWaitForADDomain]DscDomainWait" 
        } 

		WindowsFeature ADCSCA {
			Name = 'ADCS-Cert-Authority'
			Ensure = 'Present'
			DependsOn = "[xComputer]JoinDomain"
		}
		
		WindowsFeature ADCSRSAT {
			Name = 'RSAT-ADCS'
			Ensure = 'Present'
			DependsOn = "[WindowsFeature]ADCSCA"
		}
	
		xADCSCertificationAuthority ADCS
        {
            Ensure = 'Present'
            Credential = $LocalAdminCredential
            CAType = 'EnterpriseSubordinateCA'
			CACommonName = $Node.CACommonName
			CADistinguishedNameSuffix = $Node.CADistinguishedNameSuffix
			ValidityPeriod = 'Years'
			ValidityPeriodUnits = 20
            DependsOn = '[WindowsFeature]ADCSRSAT'
        }

		Script ADCSAdvConfig
		{
			SetScript = {
				If ($Using:Node.DSConifgDN) {
					& "$($ENV:SystemRoot)\system32\certutil.exe" -setreg CA\DSConfigDN $($Using:Node.DSConfigDN)
				}
				If ($Using:Node.CRLPublicationURLs) {
					& "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CRLPublicationURLs $($Using:Node.CRLPublicationURLs)
				}
				If ($Using:Node.CACertPublicationURLs) {
					& "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CACertPublicationURLs $($Using:Node.CACertPublicationURLs)
				}
				Restart-Service -Name CertSvc
				Add-Content -Path 'c:\windows\setup\scripts\certutil.log' -Value "Certificate Service Restarted ..."
			}
			GetScript = {
				Return @{
					'DSConfigDN' = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN');
					'CRLPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs');
					'CACertPublicationURLs'  = (Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs')
				}
			}
			TestScript = { 
				If (($Using:Node.DSConfigDN) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('DSConfigDN') -ne $Using:Node.DSConfigDN)) {
					Return $False
				}
				If (($Using:Node.CRLPublicationURLs) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CRLPublicationURLs') -ne $Using:Node.CRLPublicationURLs)) {
					Return $False
				}
				If (($Using:Node.CACertPublicationURLs) -and ((Get-ChildItem 'HKLM:\System\CurrentControlSet\Services\CertSvc\Configuration').GetValue('CACertPublicationURLs') -ne $Using:Node.CACertPublicationURLs)) {
					Return $False
				}
				Return $True
			}
			DependsOn = '[xADCSCertificationAuthority]ADCS'
		}
	}
}
