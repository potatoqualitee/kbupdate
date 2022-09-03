$modulePath = Split-Path -Path $PSScriptRoot -Parent

# Import the shared modules
Import-Module -Name (Join-Path -Path $modulePath `
    -ChildPath (Join-Path -Path 'xPSDesiredStateConfiguration.Common' `
        -ChildPath 'xPSDesiredStateConfiguration.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

New-Variable -Name DscWebServiceDefaultAppPoolName  -Value 'PSWS' -Option ReadOnly -Force -Scope Script

<#
    .SYNOPSIS
        Validate supplied configuration to setup the PSWS Endpoint Function
        checks for the existence of PSWS Schema files, IIS config Also validate
        presence of IIS on the target machine
#>
function Initialize-Endpoint
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $appPool,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $site,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $cfgfile,

        [Parameter()]
        [System.Int32]
        $port,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $app,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $applicationPoolIdentityType,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $svc,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $mof,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $dispatch,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $asax,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentBinaries,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $language,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentMUIFiles,

        [Parameter()]
        [System.String[]]
        $psFiles,

        [Parameter()]
        [System.Boolean]
        $removeSiteFiles = $false,

        [Parameter()]
        [System.String]
        $certificateThumbPrint,

        [Parameter()]
        [System.Boolean]
        $enable32BitAppOnWin64
    )

    if ($certificateThumbPrint -ne 'AllowUnencryptedTraffic')
    {
        Write-Verbose -Message 'Verify that the certificate with the provided thumbprint exists in CERT:\LocalMachine\MY\'

        $certificate = Get-ChildItem -Path CERT:\LocalMachine\MY\ | Where-Object -FilterScript {
            $_.Thumbprint -eq $certificateThumbPrint
        }

        if (!$Certificate)
        {
             throw "ERROR: Certificate with thumbprint $certificateThumbPrint does not exist in CERT:\LocalMachine\MY\"
        }
    }

    Test-IISInstall

    # First remove the site so that the binding count on the application pool is reduced
    Update-Site -siteName $site -siteAction Remove

    Remove-AppPool -appPool $appPool

    # Check for existing binding, there should be no binding with the same port
    $allWebBindingsOnPort = Get-WebBinding | Where-Object -FilterScript {
        $_.BindingInformation -eq "*:$($port):"
    }

    if ($allWebBindingsOnPort.Count -gt 0)
    {
        throw "ERROR: Port $port is already used, please review existing sites and change the port to be used."
    }

    if ($removeSiteFiles)
    {
        if (Test-Path -Path $path)
        {
            Remove-Item -Path $path -Recurse -Force
        }
    }

    Copy-PSWSConfigurationToIISEndpointFolder -path $path `
        -cfgfile $cfgfile `
        -svc $svc `
        -mof $mof `
        -dispatch $dispatch `
        -asax $asax `
        -dependentBinaries $dependentBinaries `
        -language $language `
        -dependentMUIFiles $dependentMUIFiles `
        -psFiles $psFiles

    New-IISWebSite -site $site `
        -path $path `
        -port $port `
        -app $app `
        -apppool $appPool `
        -applicationPoolIdentityType $applicationPoolIdentityType `
        -certificateThumbPrint $certificateThumbPrint `
        -enable32BitAppOnWin64 $enable32BitAppOnWin64
}

<#
    .SYNOPSIS
        Validate if IIS and all required dependencies are installed on the
        target machine
#>
function Test-IISInstall
{
    [CmdletBinding()]
    param ()

    Write-Verbose -Message 'Checking IIS requirements'
    $iisVersion = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\InetStp -ErrorAction silentlycontinue).MajorVersion

    if ($iisVersion -lt 7)
    {
        throw "ERROR: IIS Version detected is $iisVersion , must be running higher than 7.0"
    }

    $wsRegKey = (Get-ItemProperty hklm:\SYSTEM\CurrentControlSet\Services\W3SVC -ErrorAction silentlycontinue).ImagePath
    if ($null -eq $wsRegKey)
    {
        throw 'ERROR: Cannot retrive W3SVC key. IIS Web Services may not be installed'
    }

    if ((Get-Service w3svc).Status -ne 'running')
    {
        throw 'ERROR: service W3SVC is not running'
    }
}

<#
    .SYNOPSIS
        Verify if a given IIS Site exists
#>
function Test-ForIISSite
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [System.String]
        $siteName
    )

    if (Get-Website -Name $siteName)
    {
        return $true
    }

    return $false
}

<#
    .SYNOPSIS
        Perform an action (such as stop, start, delete) for a given IIS Site
#>
function Update-Site
{
    param
    (
        [Parameter(ParameterSetName = 'SiteName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $siteName,

        [Parameter(ParameterSetName = 'Site', Mandatory = $true, Position = 0)]
        [System.Object]
        $site,

        [Parameter(ParameterSetName = 'SiteName', Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = 'Site', Mandatory = $true, Position = 1)]
        [System.String]
        [ValidateSet('Start', 'Stop', 'Remove')]
        $siteAction
    )

    if ('SiteName' -eq  $PSCmdlet.ParameterSetName)
    {
        $site = Get-Website -Name $siteName
    }

    if ($site)
    {
        switch ($siteAction)
        {
            'Start'
            {
                Write-Verbose -Message "Starting IIS Website [$($site.name)]"
                Start-Website -Name $site.name
            }

            'Stop'
            {
                if ('Started' -eq $site.state)
                {
                    Write-Verbose -Message "Stopping WebSite $($site.name)"
                    $website = Stop-Website -Name $site.name -Passthru

                    if ('Started' -eq $website.state)
                    {
                        throw "Unable to stop WebSite $($site.name)"
                    }

                    <#
                      There may be running requests, wait a little
                      I had an issue where the files were still in use
                      when I tried to delete them
                    #>
                    Write-Verbose -Message 'Waiting for IIS to stop website'
                    Start-Sleep -Milliseconds 1000
                }
                else
                {
                    Write-Verbose -Message "IIS Website [$($site.name)] already stopped"
                }
            }

            'Remove'
            {
                Update-Site -site $site -siteAction Stop
                Write-Verbose -Message "Removing IIS Website [$($site.name)]"
                Remove-Website -Name $site.name
            }
        }
    }
    else
    {
        Write-Verbose -Message "IIS Website [$siteName] not found"
    }
}

<#
    .SYNOPSIS
        Returns the list of bound sites and applications for a given IIS Application pool

    .PARAMETER appPool
        The application pool name
#>
function Get-AppPoolBinding
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AppPool
    )

    if (Test-Path -Path "IIS:\AppPools\$AppPool")
    {
        $sites = Get-WebConfigurationProperty `
            -Filter "/system.applicationHost/sites/site/application[@applicationPool=`'$AppPool`'and @path='/']/parent::*" `
            -PSPath 'machine/webroot/apphost' `
            -Name name
        $apps = Get-WebConfigurationProperty `
            -Filter "/system.applicationHost/sites/site/application[@applicationPool=`'$AppPool`'and @path!='/']" `
            -PSPath 'machine/webroot/apphost' `
            -Name path
        $sites, $apps | ForEach-Object {
            $_.Value
        }
    }
}

<#
    .SYNOPSIS
        Delete the given IIS Application Pool. This is required to cleanup any
        existing conflicting apppools before setting up the endpoint.
#>
function Remove-AppPool
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AppPool
    )

    if ($DscWebServiceDefaultAppPoolName -eq $AppPool)
    {
        # Without this tests we may get a breaking error here, despite SilentlyContinue
        if (Test-Path -Path "IIS:\AppPools\$AppPool")
        {
            $bindingCount = (Get-AppPoolBinding -AppPool $AppPool | Measure-Object).Count

            if (0 -ge $bindingCount)
            {
                Remove-WebAppPool -Name $AppPool -ErrorAction SilentlyContinue
            }
            else
            {
                Write-Verbose -Message "Application pool [$AppPool] can't be deleted because it's still bound to a site or application"
            }
        }
    }
    else
    {
        Write-Verbose -Message "ApplicationPool can't be deleted because the name is different from built-in name [$DscWebServiceDefaultAppPoolName]."
    }
}

<#
    .SYNOPSIS
        Generate an IIS Site Id while setting up the endpoint. The Site Id will
        be the max available in IIS config + 1.
#>
function New-SiteID
{
    [CmdletBinding()]
    param ()

    return ((Get-Website | Foreach-Object -Process { $_.Id } | Measure-Object -Maximum).Maximum + 1)
}

<#
    .SYNOPSIS
        Copies the supplied PSWS config files to the IIS endpoint in inetpub
#>
function Copy-PSWSConfigurationToIISEndpointFolder
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $path,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $cfgfile,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $svc,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $mof,

        [Parameter()]
        [System.String]
        $dispatch,

        [Parameter()]
        [ValidateScript({Test-Path -Path $_})]
        [System.String]
        $asax,

        [Parameter()]
        [System.String[]]
        $dependentBinaries,

        [Parameter()]
        [System.String]
        $language,

        [Parameter()]
        [System.String[]]
        $dependentMUIFiles,

        [Parameter()]
        [System.String[]]
        $psFiles
    )

    if (!(Test-Path -Path $path))
    {
        $null = New-Item -ItemType container -Path $path
    }

    foreach ($dependentBinary in $dependentBinaries)
    {
        if (!(Test-Path -Path $dependentBinary))
        {
            throw "ERROR: $dependentBinary does not exist"
        }
    }

    Write-Verbose -Message 'Create the bin folder for deploying custom dependent binaries required by the endpoint'
    $binFolderPath = Join-Path -Path $path -ChildPath 'bin'
    $null = New-Item -Path $binFolderPath  -ItemType 'directory' -Force
    Copy-Item -Path $dependentBinaries -Destination $binFolderPath -Force

    foreach ($psFile in $psFiles)
    {
        if (!(Test-Path -Path $psFile))
        {
            throw "ERROR: $psFile does not exist"
        }

        Copy-Item -Path $psFile -Destination $path -Force
    }

    Copy-Item -Path $cfgfile (Join-Path -Path $path -ChildPath 'web.config') -Force
    Copy-Item -Path $svc -Destination $path -Force
    Copy-Item -Path $mof -Destination $path -Force

    if ($dispatch)
    {
        Copy-Item -Path $dispatch -Destination $path -Force
    }

    if ($asax)
    {
        Copy-Item -Path $asax -Destination $path -Force
    }
}

<#
    .SYNOPSIS
        Setup IIS Apppool, Site and Application
#>
function New-IISWebSite
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $site,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $port,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $app,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $appPool,

        [Parameter()]
        [System.String]
        $applicationPoolIdentityType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $certificateThumbPrint,

        [Parameter()]
        [System.Boolean]
        $enable32BitAppOnWin64
    )

    $siteID = New-SiteID

    if (Test-Path IIS:\AppPools\$appPool)
    {
        Write-Verbose -Message "Application Pool [$appPool] already exists"
    }
    else
    {
        Write-Verbose -Message "Adding App Pool [$appPool]"
        $null = New-WebAppPool -Name $appPool

        Write-Verbose -Message 'Set App Pool Properties'
        $appPoolIdentity = 4

        if ($applicationPoolIdentityType)
        {
            # LocalSystem = 0, LocalService = 1, NetworkService = 2, SpecificUser = 3, ApplicationPoolIdentity = 4
            switch ($applicationPoolIdentityType)
            {
                'LocalSystem'
                {
                    $appPoolIdentity = 0
                }

                'LocalService'
                {
                    $appPoolIdentity = 1
                }

                'NetworkService'
                {
                    $appPoolIdentity = 2
                }

                'ApplicationPoolIdentity'
                {
                    $appPoolIdentity = 4
                }

                default {
                    throw "Invalid value [$applicationPoolIdentityType] for parameter -applicationPoolIdentityType"
                }
            }
        }

        $appPoolItem = Get-Item -Path IIS:\AppPools\$appPool
        $appPoolItem.managedRuntimeVersion = 'v4.0'
        $appPoolItem.enable32BitAppOnWin64 = $enable32BitAppOnWin64
        $appPoolItem.processModel.identityType = $appPoolIdentity
        $appPoolItem | Set-Item

    }

    Write-Verbose -Message 'Add and Set Site Properties'

    if ($certificateThumbPrint -eq 'AllowUnencryptedTraffic')
    {
        $null = New-WebSite -Name $site -Id $siteID -Port $port -IPAddress "*" -PhysicalPath $path -ApplicationPool $appPool
    }
    else
    {
        $null = New-WebSite -Name $site -Id $siteID -Port $port -IPAddress "*" -PhysicalPath $path -ApplicationPool $appPool -Ssl

        # Remove existing binding for $port
        Remove-Item IIS:\SSLBindings\0.0.0.0!$port -ErrorAction Ignore

        # Create a new binding using the supplied certificate
        $null = Get-Item CERT:\LocalMachine\MY\$certificateThumbPrint | New-Item IIS:\SSLBindings\0.0.0.0!$port
    }

    Update-Site -siteName $site -siteAction Start
}

<#
    .SYNOPSIS
        Enable & Clear PSWS Operational/Analytic/Debug ETW Channels.
#>
function Enable-PSWSETW
{
    # Disable Analytic Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Analytic /e:false /q

    # Disable Debug Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Debug /e:false /q

    # Clear Operational Log
    $null = & $script:wevtutil cl Microsoft-Windows-ManagementOdataService/Operational

    # Enable/Clear Analytic Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Analytic /e:true /q

    # Enable/Clear Debug Log
    $null = & $script:wevtutil sl Microsoft-Windows-ManagementOdataService/Debug /e:true /q
}

<#
    .SYNOPSIS
        Create PowerShell WebServices IIS Endpoint

    .DESCRIPTION
        Creates a PSWS IIS Endpoint by consuming PSWS Schema and related
        dependent files

    .EXAMPLE
        New PSWS Endpoint [@ http://Server:39689/PSWS_Win32Process] by
        consuming PSWS Schema Files and any dependent scripts/binaries:

        New-PSWSEndpoint
            -site Win32Process
            -path $env:SystemDrive\inetpub\PSWS_Win32Process
            -cfgfile Win32Process.config
            -port 39689
            -app Win32Process
            -svc PSWS.svc
            -mof Win32Process.mof
            -dispatch Win32Process.xml
            -dependentBinaries ConfigureProcess.ps1, Rbac.dll
            -psFiles Win32Process.psm1
#>
function New-PSWSEndpoint
{
    [CmdletBinding()]
    param
    (
        # Unique Name of the IIS Site
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $site = 'PSWS',

        # Physical path for the IIS Endpoint on the machine (under inetpub)
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path = "$env:SystemDrive\inetpub\PSWS",

        # Web.config file
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $cfgfile = 'web.config',

        # Port # for the IIS Endpoint
        [Parameter()]
        [System.Int32]
        $port = 8080,

        # IIS Application Name for the Site
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $app = 'PSWS',

        # IIS Application Name for the Site
        [Parameter()]
        [System.String]
        $appPool,

        # IIS App Pool Identity Type - must be one of LocalService, LocalSystem, NetworkService, ApplicationPoolIdentity
        [Parameter()]
        [ValidateSet('LocalService', 'LocalSystem', 'NetworkService', 'ApplicationPoolIdentity')]
        [System.String]
        $applicationPoolIdentityType,

        # WCF Service SVC file
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $svc = 'PSWS.svc',

        # PSWS Specific MOF Schema File
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $mof,

        # PSWS Specific Dispatch Mapping File [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $dispatch,

        # Global.asax file [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $asax,

        # Any dependent binaries that need to be deployed to the IIS endpoint, in the bin folder
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentBinaries,

         # MUI Language [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $language,

        # Any dependent binaries that need to be deployed to the IIS endpoint, in the bin\mui folder [Optional]
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $dependentMUIFiles,

        # Any dependent PowerShell Scipts/Modules that need to be deployed to the IIS endpoint application root
        [Parameter()]
        [System.String[]]
        $psFiles,

        # True to remove all files for the site at first, false otherwise
        [Parameter()]
        [System.Boolean]
        $removeSiteFiles = $false,

        # Enable and Clear PSWS ETW
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $EnablePSWSETW,

        # Thumbprint of the Certificate in CERT:\LocalMachine\MY\ for Pull Server
        [Parameter()]
        [System.String]
        $certificateThumbPrint = 'AllowUnencryptedTraffic',

        # When this property is set to true, Pull Server will run on a 32 bit process on a 64 bit machine
        [Parameter()]
        [System.Boolean]
        $Enable32BitAppOnWin64 = $false
    )

    if (-not $appPool)
    {
        $appPool = $DscWebServiceDefaultAppPoolName
    }

    $script:wevtutil = "$env:windir\system32\Wevtutil.exe"

    $svcName = Split-Path $svc -Leaf
    $protocol = 'https:'

    if ($certificateThumbPrint -eq 'AllowUnencryptedTraffic')
    {
        $protocol = 'http:'
    }

    # Get Machine Name
    $cimInstance = Get-CimInstance -ClassName Win32_ComputerSystem -Verbose:$false

    Write-Verbose -Message "Setting up endpoint at - $protocol//$($cimInstance.Name):$port/$svcName"
    Initialize-Endpoint `
        -appPool $appPool `
        -site $site `
        -path $path `
        -cfgfile $cfgfile `
        -port $port `
        -app $app `
        -applicationPoolIdentityType $applicationPoolIdentityType `
        -svc $svc `
        -mof $mof `
        -dispatch $dispatch `
        -asax $asax `
        -dependentBinaries $dependentBinaries `
        -language $language `
        -dependentMUIFiles $dependentMUIFiles `
        -psFiles $psFiles `
        -removeSiteFiles $removeSiteFiles `
        -certificateThumbPrint $certificateThumbPrint `
        -enable32BitAppOnWin64 $Enable32BitAppOnWin64

    if ($EnablePSWSETW)
    {
        Enable-PSWSETW
    }
}

<#
    .SYNOPSIS
        Removes a DSC WebServices IIS Endpoint

    .DESCRIPTION
        Removes a PSWS IIS Endpoint

    .EXAMPLE
        Remove the endpoint with the specified name:

        Remove-PSWSEndpoint -siteName PSDSCPullServer
#>
function Remove-PSWSEndpoint
{
    [CmdletBinding()]
    param
    (
        # Unique Name of the IIS Site
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $siteName
    )

    # Get the site to remove
    $site = Get-Website -Name $siteName

    if ($site)
    {
        # And the pool it is using
        $pool = $site.applicationPool
        # Get the path so we can delete the files
        $filePath = $site.PhysicalPath

        # Remove the actual site.
        Update-Site -site $site -siteAction Remove

        # Remove the files for the site
        if (Test-Path -Path $filePath)
        {
            Get-ChildItem -Path $filePath -Recurse | Remove-Item -Recurse -Force
            Remove-Item -Path $filePath -Force
        }

        Remove-AppPool -appPool $pool
    }
    else
    {
        Write-Verbose -Message "Website with name [$siteName] does not exist"
    }
}

<#
    .SYNOPSIS
        Set the option into the web.config for an endpoint

    .DESCRIPTION
        Set the options into the web.config for an endpoint allowing
        customization.
#>
function Set-AppSettingsInWebconfig
{
    [CmdletBinding()]
    param
    (
        # Physical path for the IIS Endpoint on the machine (possibly under inetpub)
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        # Key to add/update
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Key,

        # Value
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Value
    )

    $webconfig = Join-Path -Path $Path -ChildPath 'web.config'
    [System.Boolean] $Found = $false

    if (Test-Path -Path $webconfig)
    {
        $xml = [System.Xml.XmlDocument] (Get-Content -Path $webconfig)
        $root = $xml.get_DocumentElement()

        foreach ($item in $root.appSettings.add)
        {
            if ($item.key -eq $Key)
            {
                $item.value = $Value;
                $Found = $true;
            }
        }

        if (-not $Found)
        {
            $newElement = $xml.CreateElement('add')
            $nameAtt1 = $xml.CreateAttribute('key')
            $nameAtt1.psbase.value = $Key;
            $null = $newElement.SetAttributeNode($nameAtt1)

            $nameAtt2 = $xml.CreateAttribute('value')
            $nameAtt2.psbase.value = $Value;
            $null = $newElement.SetAttributeNode($nameAtt2)

            $null = $xml.configuration['appSettings'].AppendChild($newElement)
        }
    }

    $xml.Save($webconfig)
}

<#
    .SYNOPSIS
        Set the binding redirect setting in the web.config to redirect 10.0.0.0
        version of microsoft.isam.esent.interop to 6.3.0.0.

    .DESCRIPTION
        This function creates the following section in the web.config:
        <runtime>
          <assemblyBinding xmlns='urn:schemas-microsoft-com:asm.v1'>
            <dependentAssembly>
              <assemblyIdentity name='microsoft.isam.esent.interop' publicKeyToken='31bf3856ad364e35' />
            <bindingRedirect oldVersion='10.0.0.0' newVersion='6.3.0.0' />
           </dependentAssembly>
          </assemblyBinding>
        </runtime>
#>
function Set-BindingRedirectSettingInWebConfig
{
    [CmdletBinding()]
    param
    (
        # Physical path for the IIS Endpoint on the machine (possibly under inetpub)
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $path,

        # old version of the assembly
        [Parameter()]
        [System.String]
        $oldVersion = '10.0.0.0',

        # new version to redirect to
        [Parameter()]
        [System.String]
        $newVersion = '6.3.0.0'
    )

    $webconfig = Join-Path $path 'web.config'

    if (Test-Path -Path $webconfig)
    {
        $xml = [System.Xml.XmlDocument] (Get-Content -Path $webconfig)

        if (-not($xml.get_DocumentElement().runtime))
        {
            # Create the <runtime> section
            $runtimeSetting = $xml.CreateElement('runtime')

            # Create the <assemblyBinding> section
            $assemblyBindingSetting = $xml.CreateElement('assemblyBinding')
            $xmlnsAttribute = $xml.CreateAttribute('xmlns')
            $xmlnsAttribute.Value = 'urn:schemas-microsoft-com:asm.v1'
            $assemblyBindingSetting.Attributes.Append($xmlnsAttribute)

            # The <assemblyBinding> section goes inside <runtime>
            $null = $runtimeSetting.AppendChild($assemblyBindingSetting)

            # Create the <dependentAssembly> section
            $dependentAssemblySetting = $xml.CreateElement('dependentAssembly')

            # The <dependentAssembly> section goes inside <assemblyBinding>
            $null = $assemblyBindingSetting.AppendChild($dependentAssemblySetting)

            # Create the <assemblyIdentity> section
            $assemblyIdentitySetting = $xml.CreateElement('assemblyIdentity')
            $nameAttribute = $xml.CreateAttribute('name')
            $nameAttribute.Value = 'microsoft.isam.esent.interop'
            $publicKeyTokenAttribute = $xml.CreateAttribute('publicKeyToken')
            $publicKeyTokenAttribute.Value = '31bf3856ad364e35'
            $null = $assemblyIdentitySetting.Attributes.Append($nameAttribute)
            $null = $assemblyIdentitySetting.Attributes.Append($publicKeyTokenAttribute)

            # <assemblyIdentity> section goes inside <dependentAssembly>
            $dependentAssemblySetting.AppendChild($assemblyIdentitySetting)

            # Create the <bindingRedirect> section
            $bindingRedirectSetting = $xml.CreateElement('bindingRedirect')
            $oldVersionAttribute = $xml.CreateAttribute('oldVersion')
            $newVersionAttribute = $xml.CreateAttribute('newVersion')
            $oldVersionAttribute.Value = $oldVersion
            $newVersionAttribute.Value = $newVersion
            $null = $bindingRedirectSetting.Attributes.Append($oldVersionAttribute)
            $null = $bindingRedirectSetting.Attributes.Append($newVersionAttribute)

            # The <bindingRedirect> section goes inside <dependentAssembly> section
            $dependentAssemblySetting.AppendChild($bindingRedirectSetting)

            # The <runtime> section goes inside <Configuration> section
            $xml.configuration.AppendChild($runtimeSetting)

            $xml.Save($webconfig)
        }
    }
}
