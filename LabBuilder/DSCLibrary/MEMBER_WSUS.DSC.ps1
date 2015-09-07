<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_WSUS
.Desription
	Builds a Server that is joined to a domain and then installs WSUS components.
	Requires cMicrosoftUpdate resource from https://github.com/fabiendibot/cMicrosoftUpdate
.Parameters:          
	DomainName = "LABBUILDER.COM"
	DomainAdminPassword = "P@ssword!1"
#########################################################################################################################################>

Configuration MEMBER_WSUS
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
	Import-DscResource -ModuleName xActiveDirectory
	Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName cMicrosoftUpdate
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

		WindowsFeature UpdateServicesWIDDBInstall 
        { 
            Ensure = "Present" 
            Name = "UpdateServices-WidDB" 
			DependsOn = "[xComputer]JoinDomain" 
        } 

		WindowsFeature UpdateServicesServicesInstall 
        { 
            Ensure = "Present" 
            Name = "UpdateServices-Services" 
			DependsOn = "[WindowsFeature]UpdateServicesWIDDBInstall" 
        } 

	}
}
