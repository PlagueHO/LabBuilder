<###################################################################################################
DSC Template Configuration File For use by LabBuilder
.Title
    MEMBER_WEBSERVER
.Desription
    Builds a Server that is joined to a domain and then made into an IIS Web Application Server.
.Parameters:
    DomainName = "LABBUILDER.COM"
    DomainAdminPassword = "P@ssword!1"
    DCName = 'SA-DC1'
    PSDscAllowDomainUser = $true
    WebAppPools = @(
        @{ Name            = 'MyAppPool';
           State           = 'Started';
           Ensure          = 'Present';
        }
    )
    WebSites = @(
        @{ Name            = 'MySite1';
           Ensure          = 'Present';
           State           = 'Started';
           SourcePath      = '\\fileserver\MySite1';
           PhysicalPath    = 'c:\MySite1';
           BindingInfo     = @(
               MSFT_xWebBindingInformation
               {
                   Protocol              = "HTTPS"
                   Port                  = 8443
                   CertificateThumbprint = "71AD93562316F21F74606F1096B85D66289ED60F"
                   CertificateStoreName  = "WebHosting"
               },
               MSFT_xWebBindingInformation
               {
                   Protocol              = "HTTPS"
                   Port                  = 8444
                   CertificateThumbprint = "DEDDD963B28095837F558FE14DA1FDEFB7FA9DA7"
                   CertificateStoreName  = "MY"
               }
           )
           ApplicationPool = 'MyAppPool';
       }
    )
    WebApplications = @(
        @{ WebSite         = 'MySite1';
           Name            = 'MyWebApp';
           WebAppPool      = 'MyAppPool';
           PhysicalPath    = 'c:\MyApp1';
           SourcePath      = '\\fileserver\MyApp1';
           Ensure          = 'Present';
        }
    )
    WebVirtualDirectories = @(
        @{ WebSite         = 'MySite1'
           WebApplication  = 'MyWebApp';
           PhysicalPath    = 'c:\Images';
           SourcePath      = '\\fileserver\MySite1\Images;
           Name            = 'Images';
           Ensure          = 'Present';
        }
    )
###################################################################################################>

Configuration MEMBER_WEBSERVER
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName xWebAdministration

    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        if ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        if ($Node.DomainAdminPassword) {
            [PSCredential]$DomainAdminCredential = New-Object System.Management.Automation.PSCredential ("$($Node.DomainName)\Administrator", (ConvertTo-SecureString $Node.DomainAdminPassword -AsPlainText -Force))
        }

        WindowsFeature IISInstall
        {
            Ensure          = "Present"
            Name            = "Web-Server"
        }

        WindowsFeature AspNet45Install
        {
            Ensure          = "Present"
            Name            = "Web-Asp-Net45"
        }

        WindowsFeature WebMgmtServiceInstall
        {
            Ensure          = "Present"
            Name            = "Web-Mgmt-Service"
        }

        WaitForAll DC
        {
            ResourceName      = '[xADDomain]PrimaryDC'
            NodeName          = $Node.DCname
            RetryIntervalSec  = 15
            RetryCount        = 60
        }

        Computer JoinDomain
        {
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential
            DependsOn     = "[WaitForAll]DC"
        }

        # Create the Web App Pools
        [System.Int32]$Count=0
        foreach ($WebAppPool in $Node.WebAppPools) {
            $Count++
            xWebAppPool "WebAppPool$Count"
            {
                Ensure        = $WebAppPool.Ensure
                Name          = $WebAppPool.Name
                State         = $WebAppPool.State
            }
        }

        # Create the Web Sites
        [System.Int32]$Count=0
        foreach ($WebSite in $Node.WebSites) {
            $Count++

            # Create an empty folder or copy content from Source Path
            if ($WebSite.SourcePath)
            {
                File "WebSiteContent$Count"
                {
                    Ensure          = "Present"
                    SourcePath      = $WebSite.SourcePath
                    DestinationPath = $WebSite.PhysicalPath
                    Recurse         = $true
                    Type            = "Directory"
                }
            }
            else
            {
                File "WebSiteContent$Count"
                {
                    Ensure          = "Present"
                    Type            = "Directory"
                    DestinationPath = $WebSite.PhysicalPath
                }
            } # if

            xWebsite "WebSite$Count"
            {
                Ensure          = $WebSite.Ensure
                Name            = $WebSite.Name
                State           = $WebSite.State
                PhysicalPath    = $WebSite.PhysicalPath
                BindingInfo     = $WebSite.BindingInfo
                ApplicationPool = $WebSite.ApplicationPool
                DependsOn       = "[File]WebSiteContent$Count"
            }
        }

        # Create the Web Applications
        $count=0
        foreach ($WebApplication in $Node.WebApplications) {
            $count++

            # Create an empty folder or copy content from Source Path
            if ($WebApplication.SourcePath)
            {
                File "WebApplicationContent$count"
                {
                    Ensure          = "Present"
                    SourcePath      = $WebApplication.SourcePath
                    DestinationPath = $WebApplication.PhysicalPath
                    Recurse         = $true
                    Type            = "Directory"
                }
            }
            else
            {
                File "WebApplicationContent$count"
                {
                    Ensure          = "Present"
                    Type            = "Directory"
                    DestinationPath = $WebApplication.PhysicalPath
                }
            } # if

            xWebApplication "WebApplication$count"
            {
                Ensure             = $WebApplication.Ensure
                WebSite            = $WebApplication.WebSite
                Name               = $WebApplication.Name
                WebAppPool         = $WebApplication.WebAppPool
                PhysicalPath       = $WebApplication.PhysicalPath
                DependsOn          = "[File]WebApplicationContent$count"
            }
        }

        # Create the Web Virtual Directories
        $count=0
        foreach ($WebVirtualDirectory in $Node.WebVirtualDirectories) {
            $count++

            # Create an empty folder or copy content from Source Path
            if ($WebVirtualDirectory.SourcePath)
            {
                File "WebVirtualDirectoryContent$count"
                {
                    Ensure          = "Present"
                    SourcePath      = $WebVirtualDirectory.SourcePath
                    DestinationPath = $WebVirtualDirectory.PhysicalPath
                    Recurse         = $true
                    Type            = "Directory"
                }
            }
            else
            {
                File "WebVirtualDirectoryContent$count"
                {
                    Ensure          = "Present"
                    Type            = "Directory"
                    DestinationPath = $WebVirtualDirectory.PhysicalPath
                }
            } # if

            xWebVirtualDirectory "WebVirtualDirectory$count"
            {
                Ensure             = $WebVirtualDirectory.Ensure
                WebSite            = $WebVirtualDirectory.WebSite
                WebApplication     = $WebVirtualDirectory.WebApplication
                PhysicalPath       = $WebVirtualDirectory.PhysicalPath
                Name               = $WebVirtualDirectory.Name
                DependsOn          = "[File]WebVirtualDirectoryContent$count"
            }
        }
    }
}
