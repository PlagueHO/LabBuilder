Configuration SECONDARYDC
{
	Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
	Import-DscResource -ModuleName xActiveDirectory 
	Node $AllNodes.NodeName {
		# Assemble the Local Admin Credentials
		If ($Node.LocalAdminPassword) {
			[PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
		}
		If ($Node.DomainAdminPassword) {
			[PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
		}

		WindowsFeature DNSInstall 
        { 
            Ensure = "Present" 
            Name = "DNS" 
        } 

		WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services" 
			DependsOn = "[WindowsFeature]DNSInstall" 
        } 

        xWaitForADDomain DscForestWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $DomainAdminCredential 
            RetryCount = 20 
            RetryIntervalSec = 30 
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
        
		xADDomainController SecondaryDC
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $DomainAdminCredential
            SafemodeAdministratorPassword = $DomainAdminCredential 
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }	
	}
}
