$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlWindowsFirewall'

<#
    .SYNOPSIS
        Returns the current state of the firewall rules.

    .PARAMETER SourcePath
        The path to the root of the source files for installation. I.e and UNC path to a shared resource.  Environment variables can be used in the path.

    .PARAMETER Features
        One or more SQL feature to create default firewall rules for. Each feature should be separated with a comma, i.e. 'SQLEngine,IS,RS'.

    .PARAMETER SourceCredential
        Credentials used to access the path set in the parameter `SourcePath`.

    .PARAMETER InstanceName
        Name of the instance to get firewall rules for.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter()]
        [System.String]
        $SourcePath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Features,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $SourceCredential
    )

    $InstanceName = $InstanceName.ToUpper()

    Write-Verbose -Message (
        $script:localizedData.EnumeratingFirewallRules -f $InstanceName
    )

    $SourcePath = [Environment]::ExpandEnvironmentVariables($SourcePath)

    if ($SourceCredential)
    {
        $userName = "$($SourceCredential.GetNetworkCredential().Domain)\$($SourceCredential.GetNetworkCredential().UserName)"

        Write-Verbose -Message (
            $script:localizedData.ConnectUsingCredential -f $SourcePath, $userName
        )

        $newSmbMappingParameters = @{
            RemotePath = $SourcePath
            UserName   = $userName
            Password   = $($SourceCredential.GetNetworkCredential().Password)
        }

        $null = New-SmbMapping @newSmbMappingParameters
    }

    $pathToSetupExecutable = Join-Path -Path $SourcePath -ChildPath 'setup.exe'

    Write-Verbose -Message (
        $script:localizedData.UsingPath -f $pathToSetupExecutable
    )

    $sqlVersion = Get-SqlMajorVersion -Path $pathToSetupExecutable

    Write-Verbose -Message (
        $script:localizedData.MajorVersion -f $sqlVersion
    )

    if ($SourceCredential)
    {
        Remove-SmbMapping -RemotePath $SourcePath -Force
    }

    if ($InstanceName -eq 'MSSQLSERVER')
    {
        $databaseServiceName = 'MSSQLSERVER'
        $reportServiceName = 'ReportServer'
        $analysisServiceName = 'MSSQLServerOLAPService'
    }
    else
    {
        $databaseServiceName = 'MSSQL${0}' -f $InstanceName
        $reportServiceName = 'ReportServer${0}' -f $InstanceName
        $analysisServiceName = 'MSOLAP${0}' -f $InstanceName
    }

    $integrationServiceName = 'MsDtsServer{0}0' -f $sqlVersion
    $browserServiceName = 'SQLBrowser'

    $ensure = 'Present'
    $featuresInstalled = ''

    $services = Get-Service

    foreach ($currentFeature in $Features.Split(','))
    {
        switch ($currentFeature)
        {
            'SQLENGINE'
            {
                if ($services | Where-Object {$_.Name -eq $databaseServiceName})
                {
                    $featuresInstalled += "$_,"

                    $pathToDatabaseEngineExecutable = Join-Path -Path (Get-SQLPath -Feature $_ -InstanceName $InstanceName) -ChildPath 'sqlservr.exe'
                    $databaseEngineFirewallRuleDisplayName = "SQL Server Database Engine instance $InstanceName"

                    $databaseEngineFirewallRuleParameters = @{
                        DisplayName = $databaseEngineFirewallRuleDisplayName
                        Program     = $pathToDatabaseEngineExecutable
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (Test-IsFirewallRuleInDesiredState @databaseEngineFirewallRuleParameters)
                    {
                        $databaseEngineFirewall = $true
                    }
                    else
                    {
                        $databaseEngineFirewall = $false
                    }

                    $browserFirewallRuleDisplayName = 'SQL Server Browser'

                    $browserFirewallRuleParameters = @{
                        DisplayName = $browserFirewallRuleDisplayName
                        Service     = $browserServiceName
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (Test-IsFirewallRuleInDesiredState @browserFirewallRuleParameters)
                    {
                        $browserFirewall = $true
                    }
                    else
                    {
                        $browserFirewall = $false
                    }
                }
            }

            'RS'
            {
                if ($services | Where-Object {$_.Name -eq $reportServiceName})
                {
                    $featuresInstalled += "$_,"

                    $reportingServicesNoSslProtocol = 'TCP'
                    $reportingServicesNoSslLocalPort = '80'
                    $reportingServicesNoSslFirewallRuleDisplayName = 'SQL Server Reporting Services 80'

                    $reportingServicesNoSslFirewallRuleParameters = @{
                        DisplayName = $reportingServicesNoSslFirewallRuleDisplayName
                        Protocol    = $reportingServicesNoSslProtocol
                        LocalPort   = $reportingServicesNoSslLocalPort
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    $reportingServicesSslProtocol = 'TCP'
                    $reportingServicesSslLocalPort = '443'
                    $reportingServicesSslFirewallRuleDisplayName = 'SQL Server Reporting Services 443'

                    $reportingServicesSslFirewallRuleParameters = @{
                        DisplayName = $reportingServicesSslFirewallRuleDisplayName
                        Protocol    = $reportingServicesSslProtocol
                        LocalPort   = $reportingServicesSslLocalPort
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if ((Test-IsFirewallRuleInDesiredState @reportingServicesNoSslFirewallRuleParameters) `
                            -and (Test-IsFirewallRuleInDesiredState @reportingServicesSslFirewallRuleParameters))
                    {
                        $reportingServicesFirewall = $true
                    }
                    else
                    {
                        $reportingServicesFirewall = $false
                    }
                }
            }

            'AS'
            {
                if ($services | Where-Object {$_.Name -eq $analysisServiceName})
                {
                    $featuresInstalled += "$_,"

                    $analysisServicesFirewallRuleDisplayName = "SQL Server Analysis Services instance $InstanceName"

                    $analysisServicesFirewallRuleParameters = @{
                        DisplayName = $analysisServicesFirewallRuleDisplayName
                        Service     = $analysisServiceName
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (Test-IsFirewallRuleInDesiredState @analysisServicesFirewallRuleParameters)
                    {
                        $analysisServicesFirewall = $true
                    }
                    else
                    {
                        $analysisServicesFirewall = $false
                    }

                    $browserFirewallRuleDisplayName = 'SQL Server Browser'

                    $browserFirewallRuleParameters = @{
                        DisplayName = $browserFirewallRuleDisplayName
                        Service     = $browserServiceName
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (Test-IsFirewallRuleInDesiredState @browserFirewallRuleParameters)
                    {
                        $browserFirewall = $true
                    }
                    else
                    {
                        $browserFirewall = $false
                    }
                }
            }

            'IS'
            {
                if ($services | Where-Object {$_.Name -eq $integrationServiceName})
                {
                    $featuresInstalled += "$_,"

                    $integrationServicesRuleApplicationDisplayName = 'SQL Server Integration Services Application'
                    $pathToIntegrationServicesExecutable = (Join-Path -Path (Join-Path -Path (Get-SQLPath -Feature 'IS' -SQLVersion $sqlVersion) -ChildPath 'Binn') -ChildPath 'MsDtsSrvr.exe')

                    $integrationServicesFirewallRuleApplicationParameters = @{
                        DisplayName = $integrationServicesRuleApplicationDisplayName
                        Program     = $pathToIntegrationServicesExecutable
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    $integrationServicesProtocol = 'TCP'
                    $integrationServicesLocalPort = '135'
                    $integrationServicesFirewallRuleDisplayName = 'SQL Server Integration Services Port'

                    $integrationServicesFirewallRulePortParameters = @{
                        DisplayName = $integrationServicesFirewallRuleDisplayName
                        Protocol    = $integrationServicesProtocol
                        LocalPort   = $integrationServicesLocalPort
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if ((Test-IsFirewallRuleInDesiredState @integrationServicesFirewallRuleApplicationParameters) `
                            -and (Test-IsFirewallRuleInDesiredState @integrationServicesFirewallRulePortParameters))
                    {
                        $integrationServicesFirewall = $true
                    }
                    else
                    {
                        $integrationServicesFirewall = $false
                    }
                }
            }
        }
    }

    if (
        ($Features -match 'SQLENGINE' -and -not ($databaseEngineFirewall -and $browserFirewall)) `
            -or ($Features -match 'RS' -and -not $reportingServicesFirewall) `
            -or ($Features -match 'AS' -and -not ($analysisServicesFirewall -and $browserFirewall)) `
            -or ($Features -match 'IS' -and -not $integrationServicesFirewall)
    )
    {
        $ensure = 'Absent'
    }


    $featuresInstalled = $featuresInstalled.Trim(',')

    return @{
        Ensure                      = $ensure
        SourcePath                  = $SourcePath
        Features                    = $featuresInstalled
        InstanceName                = $InstanceName
        DatabaseEngineFirewall      = $databaseEngineFirewall
        BrowserFirewall             = $browserFirewall
        ReportingServicesFirewall   = $reportingServicesFirewall
        AnalysisServicesFirewall    = $analysisServicesFirewall
        IntegrationServicesFirewall = $integrationServicesFirewall
    }
}

<#
    .SYNOPSIS
        Creates, updates or remove the firewall rules.

    .PARAMETER Ensure
        If the firewall rules should be present ('Present') or absent ('Absent'). The default value is 'Present'.

    .PARAMETER SourcePath
        The path to the root of the source files for installation. I.e and UNC path to a shared resource.  Environment variables can be used in the path.

    .PARAMETER Features
        One or more SQL feature to create default firewall rules for. Each feature should be separated with a comma, i.e. 'SQLEngine,IS,RS'.

    .PARAMETER SourceCredential
        Credentials used to access the path set in the parameter `SourcePath`.

    .PARAMETER InstanceName
        Name of the instance to get firewall rules for.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $SourcePath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Features,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $SourceCredential
    )

    $InstanceName = $InstanceName.ToUpper()

    Write-Verbose -Message (
        $script:localizedData.ModifyFirewallRules -f $InstanceName
    )

    $SourcePath = [Environment]::ExpandEnvironmentVariables($SourcePath)

    if ($SourceCredential)
    {
        $userName = "$($SourceCredential.GetNetworkCredential().Domain)\$($SourceCredential.GetNetworkCredential().UserName)"

        Write-Verbose -Message (
            $script:localizedData.ConnectUsingCredential -f $SourcePath, $userName
        )

        $newSmbMappingParameters = @{
            RemotePath = $SourcePath
            UserName   = $userName
            Password   = $($SourceCredential.GetNetworkCredential().Password)
        }

        $null = New-SmbMapping @newSmbMappingParameters
    }

    $pathToSetupExecutable = Join-Path -Path $SourcePath -ChildPath 'setup.exe'

    Write-Verbose -Message (
        $script:localizedData.UsingPath -f $pathToSetupExecutable
    )

    $sqlVersion = Get-SqlMajorVersion -Path $pathToSetupExecutable

    Write-Verbose -Message (
        $script:localizedData.MajorVersion -f $sqlVersion
    )

    if ($SourceCredential)
    {
        Remove-SmbMapping -RemotePath $SourcePath -Force
    }

    if ($InstanceName -eq 'MSSQLSERVER')
    {
        $analysisServiceName = 'MSSQLServerOLAPService'
    }
    else
    {
        $analysisServiceName = 'MSOLAP${0}' -f $InstanceName
    }

    $browserServiceName = 'SQLBrowser'

    $getTargetResourceResult = Get-TargetResource -SourcePath $SourcePath -Features $Features -InstanceName $InstanceName

    foreach ($currentFeature in $getTargetResourceResult.Features.Split(','))
    {
        switch ($currentFeature)
        {
            'SQLENGINE'
            {
                if (-not ($getTargetResourceResult.DatabaseEngineFirewall))
                {
                    $pathToDatabaseEngineExecutable = Join-Path -Path (Get-SQLPath -Feature $_ -InstanceName $InstanceName) -ChildPath 'sqlservr.exe'
                    $databaseEngineFirewallRuleDisplayName = "SQL Server Database Engine instance $InstanceName"

                    $databaseEngineFirewallRuleParameters = @{
                        DisplayName = $databaseEngineFirewallRuleDisplayName
                        Program     = $pathToDatabaseEngineExecutable
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (-not (Test-IsFirewallRuleInDesiredState @databaseEngineFirewallRuleParameters))
                    {
                        $databaseEngineFirewallRule = Get-NetFirewallRule | Where-Object -FilterScript {
                            $_.DisplayName -eq $databaseEngineFirewallRuleDisplayName
                        }

                        if ($databaseEngineFirewallRule)
                        {
                            Set-NetFirewallRule @databaseEngineFirewallRuleParameters
                        }
                        else
                        {
                            New-NetFirewallRule @databaseEngineFirewallRuleParameters
                        }
                    }
                }

                if (-not ($getTargetResourceResult.BrowserFirewall))
                {
                    $browserFirewallRuleDisplayName = 'SQL Server Browser'

                    $browserFirewallRuleParameters = @{
                        DisplayName = $browserFirewallRuleDisplayName
                        Service     = $browserServiceName
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (-not (Test-IsFirewallRuleInDesiredState @browserFirewallRuleParameters))
                    {
                        New-NetFirewallRule @browserFirewallRuleParameters
                    }
                }
            }

            'RS'
            {
                if (-not ($getTargetResourceResult.ReportingServicesFirewall))
                {
                    $reportingServicesNoSslProtocol = 'TCP'
                    $reportingServicesNoSslLocalPort = '80'
                    $reportingServicesNoSslFirewallRuleDisplayName = 'SQL Server Reporting Services 80'

                    $reportingServicesNoSslFirewallRuleParameters = @{
                        DisplayName = $reportingServicesNoSslFirewallRuleDisplayName
                        Protocol    = $reportingServicesNoSslProtocol
                        LocalPort   = $reportingServicesNoSslLocalPort
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (-not (Test-IsFirewallRuleInDesiredState @reportingServicesNoSslFirewallRuleParameters))
                    {
                        New-NetFirewallRule @reportingServicesNoSslFirewallRuleParameters
                    }

                    $reportingServicesSslProtocol = 'TCP'
                    $reportingServicesSslLocalPort = '443'
                    $reportingServicesSslFirewallRuleDisplayName = 'SQL Server Reporting Services 443'

                    $reportingServicesSslFirewallRuleParameters = @{
                        DisplayName = $reportingServicesSslFirewallRuleDisplayName
                        Protocol    = $reportingServicesSslProtocol
                        LocalPort   = $reportingServicesSslLocalPort
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (-not (Test-IsFirewallRuleInDesiredState @reportingServicesSslFirewallRuleParameters))
                    {
                        New-NetFirewallRule @reportingServicesSslFirewallRuleParameters
                    }
                }
            }

            'AS'
            {
                if (-not ($getTargetResourceResult.AnalysisServicesFirewall))
                {
                    $analysisServicesFirewallRuleDisplayName = "SQL Server Analysis Services instance $InstanceName"

                    $analysisServicesFirewallRuleParameters = @{
                        DisplayName = $analysisServicesFirewallRuleDisplayName
                        Service     = $analysisServiceName
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (-not (Test-IsFirewallRuleInDesiredState @analysisServicesFirewallRuleParameters))
                    {
                        New-NetFirewallRule @analysisServicesFirewallRuleParameters
                    }
                }

                if (-not ($getTargetResourceResult.BrowserFirewall))
                {
                    $browserFirewallRuleDisplayName = 'SQL Server Browser'

                    $browserFirewallRuleParameters = @{
                        DisplayName = $browserFirewallRuleDisplayName
                        Service     = $browserServiceName
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (-not (Test-IsFirewallRuleInDesiredState @browserFirewallRuleParameters))
                    {
                        New-NetFirewallRule @browserFirewallRuleParameters
                    }
                }
            }

            'IS'
            {
                if (!($getTargetResourceResult.IntegrationServicesFirewall))
                {
                    $integrationServicesRuleApplicationDisplayName = 'SQL Server Integration Services Application'
                    $pathToIntegrationServicesExecutable = (Join-Path -Path (Join-Path -Path (Get-SQLPath -Feature 'IS' -SQLVersion $sqlVersion) -ChildPath 'Binn') -ChildPath 'MsDtsSrvr.exe')

                    $integrationServicesFirewallRuleApplicationParameters = @{
                        DisplayName = $integrationServicesRuleApplicationDisplayName
                        Program     = $pathToIntegrationServicesExecutable
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (-not (Test-IsFirewallRuleInDesiredState @integrationServicesFirewallRuleApplicationParameters))
                    {
                        New-NetFirewallRule @integrationServicesFirewallRuleApplicationParameters
                    }

                    $integrationServicesProtocol = 'TCP'
                    $integrationServicesLocalPort = '135'
                    $integrationServicesFirewallRuleDisplayName = 'SQL Server Integration Services Port'

                    $integrationServicesFirewallRulePortParameters = @{
                        DisplayName = $integrationServicesFirewallRuleDisplayName
                        Protocol    = $integrationServicesProtocol
                        LocalPort   = $integrationServicesLocalPort
                        Enabled     = 'True'
                        Profile     = 'Any'
                        Direction   = 'Inbound'
                    }

                    if (-not (Test-IsFirewallRuleInDesiredState @integrationServicesFirewallRulePortParameters))
                    {
                        New-NetFirewallRule @integrationServicesFirewallRulePortParameters
                    }
                }
            }
        }
    }

    if (-not (Test-TargetResource -SourcePath $SourcePath -Features $Features -InstanceName $InstanceName))
    {
        $errorMessage = $script:localizedData.TestFailedAfterSet
        New-InvalidResultException -Message $errorMessage
    }
}

<#
    .SYNOPSIS
        Test if the firewall rules are in desired state.

    .PARAMETER Ensure
        If the firewall rules should be present ('Present') or absent ('Absent'). The default value is 'Present'.

    .PARAMETER SourcePath
        The path to the root of the source files for installation. I.e and UNC path to a shared resource.  Environment variables can be used in the path.

    .PARAMETER Features
        One or more SQL feature to create default firewall rules for. Each feature should be separated with a comma, i.e. 'SQLEngine,IS,RS'.

    .PARAMETER SourceCredential
        Credentials used to access the path set in the parameter `SourcePath`.

    .PARAMETER InstanceName
        Name of the instance to get firewall rules for.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $SourcePath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Features,

        [Parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $SourceCredential
    )

    Write-Verbose -Message (
        $script:localizedData.EvaluatingFirewallRules -f $sqlVersion
    )

    $getTargetResourceResult = Get-TargetResource -SourcePath $SourcePath -Features $Features -InstanceName $InstanceName

    $isInDesiredState = $getTargetResourceResult.Ensure -eq $Ensure

    if ($isInDesiredState)
    {
        Write-Verbose -Message (
            $script:localizedData.InDesiredState
        )
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.NotInDesiredState
        )
    }

    return $isInDesiredState
}

<#
    .SYNOPSIS
        Get the path to SQL Server executable.

    .PARAMETER Feature
        String containing the feature name for which to get the path.

    .PARAMETER InstanceName
        String containing the name of the instance for which to get the path.

    .PARAMETER SQLVersion
        String containing the major version of the SQL server to get the path for.
        This is used to evaluate the Integration Services version number.
#>
function Get-SQLPath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Feature,

        [Parameter()]
        [System.String]
        $InstanceName,

        [Parameter()]
        [System.String]
        $SQLVersion
    )

    if (($Feature -eq 'SQLENGINE') -or ($Feature -eq 'AS'))
    {
        switch ($Feature)
        {
            'SQLENGINE'
            {
                $productInstanceId = 'SQL'
            }

            'AS'
            {
                $productInstanceId = 'OLAP'
            }
        }

        $instanceId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\$($productInstanceId)" -Name $InstanceName).$InstanceName
        $path = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($instanceId)\setup" -Name 'SQLBinRoot').SQLBinRoot
    }

    if ($Feature -eq 'IS')
    {
        $path = (Get-ItemProperty -Path ("HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($SQLVersion)0\DTS\setup") -Name 'SQLPath').SQLPath
    }

    return $path
}

<#
    .SYNOPSIS
        Evaluates if the firewall rule is in desired state.

    .PARAMETER DisplayName
        String containing the display name for the firewall rule.

    .PARAMETER Enabled
        String containing either 'True' or 'False' meaning if the firewall rule should be active or not.

    .PARAMETER Profile
        String containing one or more profiles to which the firewall rule is assigned.

    .PARAMETER Direction
        String containing the direction of traffic for the the firewall rule. It can be either 'Inbound' or 'Outbound'.

    .PARAMETER Program
        String containing the path to an executable. This parameter is optional.

    .PARAMETER Service
        String containing the name of a service for the firewall rule. This parameter is optional.

    .PARAMETER Protocol
        String containing the protocol for the local port parameter. This parameter is optional.

    .PARAMETER LocalPort
        String containing the local port for the firewall rule. This parameter is optional, with the exception that if
        the parameter Protocol is specified this parameter must also be specified.
#>
function Test-IsFirewallRuleInDesiredState
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $DisplayName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('True', 'False')]
        [System.String]
        $Enabled,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        [ValidateSet('Any', 'Domain', 'Private', 'Public', 'NotApplicable')]
        $Profile,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Inbound', 'Outbound')]
        [System.String]
        $Direction,

        [Parameter()]
        [System.String]
        $Program,

        [Parameter()]
        [System.String]
        $Service,

        [Parameter()]
        [ValidateSet('TCP', 'UDP', 'ICMPv4', 'ICMPv6')]
        [System.String]
        $Protocol,

        [Parameter()]
        [System.String]
        $LocalPort
    )

    $isRuleInDesiredState = $false

    if ($firewallRule = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction 'SilentlyContinue')
    {
        if (($firewallRule.Enabled -eq $Enabled) -and ($firewallRule.Profile -eq $Profile) -and ($firewallRule.Direction -eq $Direction))
        {
            if ($PSBoundParameters.ContainsKey('Program'))
            {
                if ($firewallApplicationFilter = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $firewallRule -ErrorAction 'SilentlyContinue')
                {
                    if ($firewallApplicationFilter.Program -eq $Program)
                    {
                        $isRuleInDesiredState = $true
                    }
                }
            }

            if ($PSBoundParameters.ContainsKey('Service'))
            {
                if ($firewallServiceFilter = Get-NetFirewallServiceFilter -AssociatedNetFirewallRule $firewallRule -ErrorAction 'SilentlyContinue')
                {
                    if ($firewallServiceFilter.Service -eq $Service)
                    {
                        $isRuleInDesiredState = $true
                    }
                }
            }

            if ($PSBoundParameters.ContainsKey('Protocol') -and $PSBoundParameters.ContainsKey('LocalPort'))
            {
                if ($firewallPortFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $firewallRule -ErrorAction 'SilentlyContinue')
                {
                    if ($firewallPortFilter.Protocol -eq $Protocol -and $firewallPortFilter.LocalPort -eq $LocalPort)
                    {
                        $isRuleInDesiredState = $true
                    }
                }
            }
        }
    }

    return $isRuleInDesiredState
}

<#
    .SYNOPSIS
        Returns the SQL Server major version from the setup.exe executable provided in the Path parameter.

    .PARAMETER Path
        String containing the path to the SQL Server setup.exe executable.
#>
function Get-SqlMajorVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $path
    )

    (Get-Item -Path $path).VersionInfo.ProductVersion.Split('.')[0]
}

Export-ModuleMember -Function *-TargetResource
