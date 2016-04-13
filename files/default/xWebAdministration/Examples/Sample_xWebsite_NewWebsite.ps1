configuration Sample_xWebsite_NewWebsite
{
    # This configuration expects that $ConfigurationData will have one or more
    # nodes with three keys:

    # SourceUrl - which is the zip file with the BakeryWebsite demo site
    # DestinationPath - which is where the IIS site files will be saved
    # WebSiteName - Name of the website to host the BakeryWebsite

    # Import the module that defines custom resources
    Import-DscResource -Module xWebAdministration, PSDesiredStateConfiguration

    Node $AllNodes.NodeName
    {
        $MandatoryNodeData = 'SourceUrl', 'DestinationPath', 'WebSiteName'
        if ($MandatoryNodeData.where({-not $Node.ContainsKey($_)}))
        {
            throw 'Nodes in $ConfigurationData must contain SourceUrl, DestinationPath, and WebSiteName properties.'
        }

        # Install the IIS role
        WindowsFeature IIS
        {
            Ensure          = 'Present'
            Name            = 'Web-Server'
        }

        # Install the ASP .NET 4.5 role
        WindowsFeature AspNet45
        {
            Ensure          = 'Present'
            Name            = 'Web-Asp-Net45'
            DependsOn       = '[WindowsFeature]IIS'
        }

        # Stop the default website
        xWebsite DefaultSite
        {
            Ensure          = 'Present'
            Name            = 'Default Web Site'
            State           = 'Stopped'
            PhysicalPath    = 'C:\inetpub\wwwroot'
            DependsOn       = '[WindowsFeature]AspNet45'
        }

        # Grab a zip file of the demo
        script DownloadSample
        {
           GetScript = "@{}"
           SetScript = "irm $($Node.SourceUrl) -outfile c:\bakery.zip"
           TestScript = "test-path c:\bakery.zip"
        }

        # Extract the zipfile of demo files.
        Archive DemoFiles
        {
            Destination = 'c:\demo'
            Path = 'c:\bakery.zip'
            DependsOn = '[Script]DownloadSample'
        }

        # Setup the directory to host the website content.
        File SiteDirectory
        {
            DestinationPath = (Split-Path $Node.DestinationPath)
            Type = 'Directory'
        }

        # Copy the website content from the demo download.
        File WebContent
        {
            DestinationPath = $Node.DestinationPath
            SourcePath = 'c:\demo\Demo_WindowServer2012R2-Preview\PreReq\BakeryWebsite\'
            Recurse = $true
            Force = $true
            MatchSource = $true
            DependsOn = @('[Archive]DemoFiles', '[File]SiteDirectory')
        }

        # Create the new Website
        xWebsite NewWebsite
        {
            Ensure          = 'Present'
            Name            = $Node.WebSiteName
            State           = 'Started'
            PhysicalPath    = $Node.DestinationPath -replace '/', '\'
            DependsOn       = @('[WindowsFeature]AspNet45', '[File]WebContent')
        }
    }
}
