<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_WAC
.Desription
    Builds a Server that is joined to a domain and then installs Windows Admin Center.
.Parameters:
    DomainName = 'LABBUILDER.COM'
    DomainAdminPassword = 'P@ssword!1'
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    WacSslCertThumbprint = '' # Thumbprint of the SSL Certificate to use the WAC site. If not specified will generate one.
    Port = 6516 # The port number to install the WAC site on. If not specified will default to 6516
###################################################################################################>

Configuration MEMBER_WAC
{
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 7.1.0.0
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.1.0

    Node $AllNodes.NodeName {
        # Assemble the Domain Admin Credential
        if ($Node.DomainAdminPassword)
        {
            $domainAdminCredential = New-Object `
                -TypeName System.Management.Automation.PSCredential `
                -ArgumentList ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        $wacInstallArguments = '/qn /l*v c:\windows\temp\windowsadmincenter.msiinstall.log'

        if ($null -ne $Node.Port) {
            $wacInstallArguments = '{0} SME_PORT={1}' -f $wacInstallArguments, $Node.Port
        }

        if ([System.String]::IsNullOrEmpty($Node.WacSslCertThumbprint))
        {
            $wacInstallArguments = '{0} SSL_CERTIFICATE_OPTION=generate' -f $wacInstallArguments
        }
        else
        {
            $wacInstallArguments = '{0} SME_THUMBPRINT={1}' -f $wacInstallArguments, $Node.WacSslCertThumbprint
        }

        # Wait for the Domain to be available so we can join it.
        WaitForAll DC
        {
            ResourceName     = '[ADDomain]PrimaryDC'
            NodeName         = $Node.DCname
            RetryIntervalSec = 15
            RetryCount       = 60
        }

        # Join this Server to the Domain
        Computer JoinDomain
        {
            Name       = $Node.NodeName
            DomainName = $Node.DomainName
            Credential = $domainAdminCredential
            DependsOn  = '[WaitForAll]DC'
        }

        xMsiPackage InstallWindowsAdminCenter
        {
            ProductId = '{4FAE3A2E-4369-490E-97F3-0B3BFF183AB9}'
            Path      = 'https://download.microsoft.com/download/1/0/5/1059800B-F375-451C-B37E-758FFC7C8C8B/WindowsAdminCenter1809.5.msi'
            Arguments = $wacInstallArguments
            Ensure    = 'Present'
        }
    }
}
