<#########################################################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
	MEMBER_DEFAULT
.Desription
	Builds a Server that is joined to a domain.
.Parameters:          
	DomainName = "LABBUILDER.COM"
	DomainAdminPassword = "P@ssword!1"
#########################################################################################################################################>

Configuration MEMBER_FILESERVER
{
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration' -ModuleVersion 1.1
	Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.4.0.0 # Current as of 8 Feb 2016
    Import-DscResource -ModuleName xNetworking -ModuleVersion 2.7.0.0  #Current as of 13-Feb-2016
	Node $AllNodes.NodeName {
		# Assemble the Local Admin Credentials
		If ($Node.LocalAdminPassword) {
			[PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
		}
		If ($Node.DomainAdminPassword) {
			[PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
		}

        WaitForAll DC
        {
        ResourceName      = '[xADDomain]PrimaryDC'
        NodeName          = $Node.DCname
        RetryIntervalSec  = 15
        RetryCount        = 60
        }


		xComputer JoinDomain 
		{ 
			Name          = $Node.NodeName
			DomainName    = $Node.DomainName
			Credential    = $DomainAdminCredential 
			DependsOn = "[WaitForAll]DC" 
		}
	}
}
