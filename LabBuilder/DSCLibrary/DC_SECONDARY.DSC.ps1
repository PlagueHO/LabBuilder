<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	DC_SECONDARY
.Desription
	Builds a Domain Controller and adds it to the existing domain provided in the Parameter DomainName.
.Parameters:          
	DomainName = "BMDLAB.COM"
	DomainAdminPassword = "P@ssword!1"
#########################################################################################################################################>

Configuration DC_SECONDARY
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
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

        xWaitForADDomain DscDomainWait
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
            SafemodeAdministratorPassword = $LocalAdminCredential 
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }	
	}
}
