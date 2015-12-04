<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_NPS
.Desription
	Builds a Server that is joined to a domain and then contains NPS/Radius components.
.Requires
	Windows Server 2012 R2 Full (Server core not supported).
.Parameters:          
	DomainName = "LABBUILDER.COM"
	DomainAdminPassword = "P@ssword!1"
#########################################################################################################################################>

Configuration MEMBER_NPS
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration' -ModuleVersion 1.1
	Import-DscResource -ModuleName xActiveDirectory
	Import-DscResource -ModuleName xComputerManagement
	Node $AllNodes.NodeName {
		# Assemble the Local Admin Credentials
		If ($Node.LocalAdminPassword) {
			[PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
		}
		If ($Node.DomainAdminPassword) {
			[PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
		}

		WindowsFeature NPASPolicyServerInstall 
        { 
            Ensure = "Present" 
            Name = "NPAS-Policy-Server" 
        } 

		WindowsFeature NPASHealthInstall 
        { 
            Ensure = "Present" 
            Name = "NPAS-Health" 
			DependsOn = "[WindowsFeature]NPASPolicyServerInstall" 
        } 

		WindowsFeature RSATNPAS
        { 
            Ensure = "Present" 
            Name = "RSAT-NPAS" 
			DependsOn = "[WindowsFeature]NPASPolicyServerInstall" 
        } 

		WindowsFeature RSATADPowerShell
        { 
            Ensure = "Present" 
            Name = "RSAT-AD-PowerShell" 
			DependsOn = "[WindowsFeature]NPASHealthInstall" 
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
	}
}
