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
    PSDscAllowDomainUser = $True
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
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xWebAdministration
    Node $AllNodes.NodeName {
        # Assemble the Local Admin Credentials
        If ($Node.LocalAdminPassword) {
            [PSCredential]$LocalAdminCredential = New-Object System.Management.Automation.PSCredential ("Administrator", (ConvertTo-SecureString $Node.LocalAdminPassword -AsPlainText -Force))
        }
        If ($Node.DomainAdminPassword) {
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

        xComputer JoinDomain 
        { 
            Name          = $Node.NodeName
            DomainName    = $Node.DomainName
            Credential    = $DomainAdminCredential 
            DependsOn     = "[WaitForAll]DC" 
        }

        # Create the Web App Pools
        [Int]$Count=0
        Foreach ($WebAppPool in $Node.WebAppPools) {
            $Count++
            xWebAppPool "WebAppPool$Count"
            {
                Ensure        = $WebAppPool.Ensure
                Name          = $WebAppPool.Name
                State         = $WebAppPool.State
            }
        }

        # Create the Web Sites
        [Int]$Count=0
        Foreach ($WebSite in $Node.WebSites) {
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
        [Int]$Count=0
        Foreach ($WebApplication in $Node.WebApplications) {
            $Count++

            # Create an empty folder or copy content from Source Path
            if ($WebApplication.SourcePath)
            {
                File "WebApplicationContent$Count"
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
                File "WebApplicationContent$Count"
                {
                    Ensure          = "Present"
                    Type            = "Directory"
                    DestinationPath = $WebApplication.PhysicalPath
                }
            } # if

            xWebApplication "WebApplication$Count"
            {
                Ensure             = $WebApplication.Ensure
                WebSite            = $WebApplication.WebSite
                Name               = $WebApplication.Name
                WebAppPool         = $WebApplication.WebAppPool
                PhysicalPath       = $WebApplication.PhysicalPath
                DependsOn          = "[File]WebApplicationContent$Count"
            }
        }

        # Create the Web Virtual Directories
        [Int]$Count=0
        Foreach ($WebVirtualDirectory in $Node.WebVirtualDirectories) {
            $Count++

            # Create an empty folder or copy content from Source Path
            if ($WebVirtualDirectory.SourcePath)
            {
                File "WebVirtualDirectoryContent$Count"
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
                File "WebVirtualDirectoryContent$Count"
                {
                    Ensure          = "Present"
                    Type            = "Directory"
                    DestinationPath = $WebVirtualDirectory.PhysicalPath
                }
            } # if

            xWebVirtualDirectory "WebVirtualDirectory$Count"
            {
                Ensure             = $WebVirtualDirectory.Ensure
                WebSite            = $WebVirtualDirectory.WebSite
                WebApplication     = $WebVirtualDirectory.WebApplication
                PhysicalPath       = $WebVirtualDirectory.PhysicalPath
                Name               = $WebVirtualDirectory.Name
                DependsOn          = "[File]WebVirtualDirectoryContent$Count"
            }
        }
    }
}
