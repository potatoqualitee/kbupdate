$script:resourceHelperModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Modules\DscResource.Common'

Import-Module -Name $script:resourceHelperModulePath

$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

$script:WuaSearchString = 'IsAssigned=1 and IsHidden=0 and IsInstalled=0'
$script:retryAttempts = 3
$script:retryDelay = 0
$script:lastHResult = 0
$script:errorCount = 0

function Get-WuaServiceManager
{
    return (New-Object -ComObject Microsoft.Update.ServiceManager)
}

function Add-WuaService
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ServiceId,

        [Parameter()]
        [System.Int32]
        $Flags = 7,

        [Parameter()]
        [System.String]
        $AuthorizationCabPath = [System.String]::Empty

    )

    $wuaServiceManager = Get-WuaServiceManager
    $wuaServiceManager.AddService2($ServiceId, $Flags, $AuthorizationCabPath)
}

function Remove-WuaService
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ServiceId
    )

    $wuaServiceManager = Get-WuaServiceManager
    $wuaServiceManager.RemoveService($ServiceId)
}

function Get-WuaSearchString
{
    param
    (
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $security,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $optional,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $important
    )

    $securityCategoryId = "'0FA1201D-4330-4FA8-8AE9-B877473B6441'"
    <#
        invalid, would not install anything - not security and not optional and not important
    #>

    # security and optional and important
    # not security and optional and important
    if ($optional -and $important)
    {
        # Installing everything not hidden and not already installed
        return 'IsHidden=0 and IsInstalled=0'
    }
    # security and optional and not important
    elseif ($security -and $optional)
    {
        # or can only be used at the top most boolean expression
        return "(IsAssigned=0 and IsHidden=0 and IsInstalled=0) or (CategoryIds contains $securityCategoryId and IsHidden=0 and IsInstalled=0)"
    }
    # security and not optional and important
    elseif ($security -and $important )
    {
        # Installing everything not hidden,
        # not optional (optional are not assigned) and not already installed
        return 'IsAssigned=1 and IsHidden=0 and IsInstalled=0'
    }
    elseif ($optional -and $important)
    {
        # Installing everything not hidden,
        # not optional (optional are not assigned) and not already installed
        return 'IsHidden=0 and IsInstalled=0'

    }
    # security and not optional and not important
    elseif ($security)
    {
        # Installing everything that is security and not hidden,
        #  and not already installed
        return "CategoryIds contains $securityCategoryId and IsHidden=0 and IsInstalled=0"
    }
    # not security and not optional and important
    elseif ($important)
    {
        # Installing everything that is not hidden,
        # is assigned (not optional) and not already installed
        # not valid cannot do  not contains or a boolean not
        # Note important updates will include security updates
        return 'IsAssigned=1 and IsHidden=0 and IsInstalled=0'
    }
    # not security and optional and not important
    elseif ($optional)
    {
        # Installing everything that is not hidden,
        # is not assigned (is optional) and not already installed
        # not valid cannot do  not contains or a boolean not

        # Note optional updates may include security updates
        return 'IsAssigned=0 and IsHidden=0 and IsInstalled=0'
    }

    return "CategoryIds contains $securityCategoryId and IsHidden=0 and IsInstalled=0"

}

function Get-WuaAu
{
    return (New-Object -ComObject 'Microsoft.Update.AutoUpdate')
}

function Get-WuaAuSettings
{
    return (Get-WuaAu).Settings
}

function Assert-Retry
{
    param
    (
        [Parameter()]
        $ErrorObject
    )

    if ($ErrorObject.Retryable)
    {
        if ($ErrorObject.Exception.HResult -ne $script:lastHResult)
        {
            $script:lastHResult = $ErrorObject.Exception.HResult
            $script:errorCount = 0
        }

        if ($script:errorCount++ -lt $script:retryAttempts)
        {
            Write-Warning "$($ErrorObject.WarningText) Retrying..."

            return $true
        }
        else
        {
            throw $ErrorObject.Exception
        }

        Start-Sleep -Seconds $script:retryDelay
    }
    else
    {
        return $false
    }
}

function Get-WuaWrapper
{
    param
    (
        [Parameter()]
        [ScriptBlock]
        $tryBlock,

        [Parameter()]
        [object[]]
        $argumentList,

        [Parameter(ParameterSetName = 'OneValue')]
        [object]
        $ExceptionReturnValue = $null
    )

    $script:lastHResult = 0
    $script:errorCount = 0

    while ($true)
    {
        try
        {
            return Invoke-Command -ScriptBlock $tryBlock -NoNewScope -ArgumentList $argumentList
        }
        catch [System.Runtime.InteropServices.COMException]
        {
            $errorObj = [PSCustomObject]@{
                Exception   = $_.Exception
                WarningText = ''
                Retryable   = $false
            }

            switch ($_.Exception.HResult)
            {
                # 0x8024001e    -2145124322    WU_E_SERVICE_STOP    Operation did not complete because the service or system was being shut down.    wuerror.h
                -2145124322
                {
                    $errorObj.WarningText = 'Got an error that WU service is stopping.  Handling the error.'
                    return $ExceptionReturnValue
                }

                # 0x8024402c    -2145107924    WU_E_PT_WINHTTP_NAME_NOT_RESOLVED    Same as ERROR_WINHTTP_NAME_NOT_RESOLVED - the proxy server or target server name cannot be resolved.    wuerror.h
                -2145107924
                {
                    $errorObj.WarningText = 'Got an error that WU could not resolve the name of the update service.'
                    $errorObj.Retryable = $true
                }

                # 0x8024401c    -2145107940    WU_E_PT_HTTP_STATUS_REQUEST_TIMEOUT    Same as HTTP status 408 - the server timed out waiting for the request.    wuerror.h
                -2145107940
                {
                    $errorObj.WarningText = 'Got an error a request timed out (http status 408 or equivalent) when WU was communicating with the update service.'
                    $errorObj.Retryable = $true
                }

                # 0x8024402f    -2145107921    WU_E_PT_ECP_SUCCEEDED_WITH_ERRORS    External cab file processing completed with some errors.    wuerror.h
                -2145107921
                {
                    # No retry needed
                    $errorObj.WarningText = 'Got an error that CAB processing completed with some errors.'
                    return $ExceptionReturnValue
                }

                # 0x80244022    -2145107934    WU_E_PT_HTTP_STATUS_SERVICE_UNAVAIL  Same as HTTP status 503 - the service is temporarily overloaded.    wuerror.h
                -2145107934
                {
                    $errorObj.WarningText = 'Error communicating with the update service, HTTP 503, The service is temporarily overloaded.'
                    $errorObj.Retryable = $true
                }

                # 0x80244010    ‭-2145107952‬    The maximum allowed number of round trips to the server was exceeded
                -2145107952
                {
                    $errorObj.WarningText = 'The maximum allowed number of round trips to the server was exceeded.'
                    $errorObj.Retryable = $true
                }

                default
                {
                    throw
                }
            }

            if (-not (Assert-Retry $errorObj))
            {
                return $ExceptionReturnValue
            }
        }
    }
}

function Get-WuaAuNotificationLevel
{
    return Get-WuaWrapper -tryBlock {
        switch ((Get-WuaAuSettings).NotificationLevel)
        {
            0
            {
                return 'Not Configured'
            }

            1
            {
                return 'Disabled'
            }

            2
            {
                return 'Notify before download'
            }

            3
            {
                return 'Notify before installation'
            }

            4
            {
                return 'Scheduled installation'
            }

            default
            {
                return 'Reserved'
            }
        }
    } -ExceptionReturnValue [System.String]::Empty
}

function Invoke-WuaDownloadUpdates
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]
        $UpdateCollection
    )

    $downloader = (Get-WuaSession).CreateUpdateDownloader()

    $downloader.Updates = $UpdateCollection

    Write-Verbose -Message 'Downloading updates...'

    $null = $downloader.Download()
}

function Invoke-WuaInstallUpdates
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]
        $UpdateCollection
    )

    $installer = (Get-WuaSession).CreateUpdateInstaller()

    $installer.Updates = $UpdateCollection

    Write-Verbose -Message 'Installing updates...'

    $null = $installer.Install()
}

function Set-WuaAuNotificationLevel
{
    param
    (
        [Parameter()]
        [ValidateSet('Not Configured', 'Disabled', 'Notify before download', 'Notify before installation', 'Scheduled installation', 'ScheduledInstallation')]
        [System.String]
        $notificationLevel
    )

    $intNotificationLevel = Get-WuaAuNotificationLevelInt -notificationLevel $notificationLevel

    $settings = Get-WuaAuSettings
    $settings.NotificationLevel = $intNotificationLevel
    $settings.Save()
}

function Get-WuaAuNotificationLevelInt
{
    param
    (
        [Parameter()]
        [ValidateSet('Not Configured', 'Disabled', 'Notify before download', 'Notify before installation', 'Scheduled installation', 'ScheduledInstallation')]
        [System.String]
        $notificationLevel
    )

    $intNotificationLevel = 0

    switch -Regex ($notificationLevel)
    {
        '^Not\s*Configured$'
        {
            $intNotificationLevel = 0
        }

        '^Disabled$'
        {
            $intNotificationLevel = 1
        }

        '^Notify\s*before\s*download$'
        {
            $intNotificationLevel = 2
        }

        '^Notify\s*before\s*installation$'
        {
            $intNotificationLevel = 3
        }

        '^Scheduled\s*installation$'
        {
            $intNotificationLevel = 4
        }

        default
        {
            throw 'Invalid notification level'
        }
    }

    return $intNotificationLevel
}

function Get-WuaSystemInfo
{
    return (New-Object -ComObject 'Microsoft.Update.SystemInfo')
}

function Get-WuaRebootRequired
{
    return Get-WuaWrapper -tryBlock {
        Write-Verbose -Message 'TryGet RebootRequired...'

        $rebootRequired = (Get-WuaSystemInfo).rebootRequired

        Write-Verbose -Message "Got rebootRequired: $rebootRequired"

        return $rebootRequired
    } -ExceptionReturnValue $true
}

function Get-WuaSession
{
    return (New-Object -ComObject 'Microsoft.Update.Session')
}

function Get-WuaSearcher
{
    [CmdletBinding(DefaultParameterSetName = 'category')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'searchString')]
        [System.String]
        $SearchString,

        [Parameter(ParameterSetName = 'category')]
        [ValidateSet('Security', 'Important', 'Optional')]
        [AllowEmptyCollection()]
        [AllowNull()]
        [System.String[]]
        $Category = @('Security')
    )

    $memberSearchString = $SearchString

    if ($PSCmdlet.ParameterSetName -eq 'category')
    {
        $searchStringParams = @{ }

        foreach ($CategoryItem in $Category)
        {
            $searchStringParams[$CategoryItem] = $true
        }

        $memberSearchString = (Get-WuaSearchString @searchStringParams)
    }

    return Get-WuaWrapper -tryBlock {
        param
        (
            [Parameter(Mandatory = $true)]
            [System.String]
            $memberSearchString
        )

        Write-Verbose -Message "Searching for updating using: $memberSearchString"

        return ((Get-WuaSession).CreateUpdateSearcher()).Search($memberSearchString)
    } -argumentList @($memberSearchString)
}

function Test-SearchResult
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Object]
        $SearchResult
    )

    if (!(@($SearchResult | Get-Member | Select-Object -ExpandProperty Name) -contains 'Updates'))
    {
        Write-Verbose 'Did not find updates on SearchResult'

        return $false
    }

    if (!(@(Get-Member -InputObject $SearchResult.Updates | Select-Object -ExpandProperty Name) -contains 'Count'))
    {
        Write-Verbose 'Did not find count on updates on SearchResult'

        return $false
    }

    return $true
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance,

        [Parameter()]
        [ValidateSet('Security', 'Important', 'Optional')]
        [AllowEmptyCollection()]
        [AllowNull()]
        [System.String[]]
        $Category = @('Security'),

        [Parameter()]
        [ValidateSet('Disabled', 'ScheduledInstallation')]
        [System.String]
        $Notifications,

        [Parameter(Mandatory = $true)]
        [ValidateSet('WindowsUpdate', 'MicrosoftUpdate', 'WSUS')]
        [System.String]
        $Source,

        [Parameter()]
        [System.Int32]
        $RetryAttempts = -1,

        [Parameter()]
        [System.Int32]
        $RetryDelay = -1,

        [Parameter()]
        [System.Boolean]
        $UpdateNow = $false
    )

    if ($RetryAttempts -ge 0)
    {
        $script:retryAttempts = $RetryAttempts
    }

    if ($RetryDelay -ge 0)
    {
        $script:retryDelay = $RetryAttempts
    }

    Test-TargetResourceProperties @PSBoundParameters

    $totalUpdatesNotInstalled = $null
    $UpdateNowReturn = $null
    $rebootRequired = $null

    if ($UpdateNow)
    {
        $rebootRequired = Get-WuaRebootRequired
        $SearchResult = (Get-WuaSearcher -Category $Category)
        $totalUpdatesNotInstalled = 0

        if ($SearchResult -and (Test-SearchResult -SearchResult $SearchResult))
        {
            $totalUpdatesNotInstalled = $SearchResult.Updates.Count
        }

        $UpdateNowReturn = $false

        if ($totalUpdatesNotInstalled -eq 0 -and !$rebootRequired)
        {
            $UpdateNowReturn = $true
        }
    }

    $notificationLevel = (Get-WuaAuNotificationLevel)

    $CategoryReturn = $Category
    $SourceReturn = 'WindowsUpdate'
    $UpdateServices = (Get-WuaServiceManager).Services

    #Check if the microsoft update service is registered
    $defaultService = @($UpdateServices).where{ $_.IsDefaultAuService }

    Write-Verbose -Message "Get default search service: $($defaultService.ServiceId)"

    if ($defaultService.ServiceId -eq '7971f918-a847-4430-9279-4a52d1efe18d')
    {
        $SourceReturn = 'MicrosoftUpdate'
    }
    elseif ($defaultService.IsManaged)
    {
        $SourceReturn = 'WSUS'
    }

    $returnValue = @{
        IsSingleInstance                    = 'Yes'
        Category                            = $CategoryReturn
        AutomaticUpdatesNotificationSetting = $notificationLevel
        TotalUpdatesNotInstalled            = $totalUpdatesNotInstalled
        RebootRequired                      = $rebootRequired
        Notifications                       = $notificationLevel
        Source                              = $SourceReturn
        UpdateNow                           = $UpdateNowReturn
    }
    $returnValue
}

function Set-TargetResource
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance,

        [Parameter()]
        [ValidateSet('Security', 'Important', 'Optional')]
        [System.String[]]
        $Category = @('Security'),

        [Parameter()]
        [ValidateSet('Disabled', 'ScheduledInstallation')]
        [System.String]
        $Notifications,

        [Parameter(Mandatory = $true)]
        [ValidateSet('WindowsUpdate', 'MicrosoftUpdate', 'WSUS')]
        [System.String]
        $Source,

        [Parameter()]
        [System.Int32]
        $RetryAttempts = -1,

        [Parameter()]
        [System.Int32]
        $RetryDelay = -1,

        [Parameter()]
        [System.Boolean]
        $UpdateNow = $false
    )

    if ($RetryAttempts -ge 0)
    {
        $script:retryAttempts = $RetryAttempts
    }
    if ($RetryDelay -ge 0)
    {
        $script:retryDelay = $RetryAttempts
    }

    Test-TargetResourceProperties @PSBoundParameters

    $Get = Get-TargetResource @PSBoundParameters

    $updateCompliant = ($UpdateNow -eq $false -or $Get.UpdateNow -eq $UpdateNow)

    Write-Verbose "updateNow compliant: $updateCompliant"

    $notificationCompliant = (!$Notifications -or $Notifications -eq $Get.Notifications)

    Write-Verbose "notifications compliant: $notificationCompliant"

    $SourceCompliant = (!$Source -or $Source -eq $Get.Source)

    Write-Verbose "service compliant: $SourceCompliant"

    if (!$updateCompliant)
    {
        $SearchResult = (Get-WuaSearcher -Category $Category)

        if ($SearchResult -and $SearchResult.Updates.Count -gt 0)
        {
            Write-Verbose -Message 'Installing updates...'

            #Write Results
            foreach ($update in $SearchResult.Updates)
            {
                $title = $update.Title

                Write-Verbose -Message "Found update: $Title"
            }

            Invoke-WuaDownloadUpdates -UpdateCollection $SearchResult.Updates

            Invoke-WuaInstallUpdates -UpdateCollection $SearchResult.Updates
        }
        else
        {
            Write-Verbose -Message 'No updates'
        }

        Write-Verbose -Message 'Checking for a reboot...'

        $rebootRequired = (Get-WuaRebootRequired)

        if ($rebootRequired)
        {
            Write-Verbose -Message 'A reboot was required'

            $global:DSCMachineStatus = 1
        }
        else
        {
            Write-Verbose -Message 'A reboot was NOT required'
        }
    }

    if (!$notificationCompliant)
    {
        try
        {
            <#
                TODO: verify that group policy is not overriding this settings
                if it is throw an error, if it conflicts.
            #>
            Set-WuaAuNotificationLevel -notificationLevel $Notifications
        }
        catch
        {
            $ErrorMsg = $_.Exception.Message

            Write-Verbose $ErrorMsg
        }
    }

    if (!$SourceCompliant )
    {
        if ($Source -eq 'MicrosoftUpdate')
        {
            Write-Verbose 'Enable the Microsoft Update setting'

            Add-WuaService -ServiceId '7971f918-a847-4430-9279-4a52d1efe18d'

            Restart-Service wuauserv -ErrorAction SilentlyContinue
        }
        else
        {
            Write-Verbose 'Disable the Microsoft Update setting'

            Remove-WuaService -ServiceId '7971f918-a847-4430-9279-4a52d1efe18d'
        }
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance,

        [Parameter()]
        [ValidateSet('Security', 'Important', 'Optional')]
        [System.String[]]
        $Category = @('Security'),

        [Parameter()]
        [ValidateSet('Disabled', 'ScheduledInstallation')]
        [System.String]
        $Notifications,

        [Parameter(Mandatory = $true)]
        [ValidateSet('WindowsUpdate', 'MicrosoftUpdate', 'WSUS')]
        [System.String]
        $Source,

        [Parameter()]
        [System.Int32]
        $RetryAttempts = -1,

        [Parameter()]
        [System.Int32]
        $RetryDelay = -1,

        [Parameter()]
        [System.Boolean]
        $UpdateNow = $false
    )

    Test-TargetResourceProperties @PSBoundParameters

    # Output the result of Get-TargetResource function.
    $Get = Get-TargetResource @PSBoundParameters

    $updateCompliant = ($UpdateNow -eq $false -or $Get.UpdateNow -eq $UpdateNow)

    Write-Verbose "updateNow compliant: $updateCompliant"

    $notificationCompliant = (!$Notifications -or $Notifications -eq $Get.Notifications)

    Write-Verbose "notifications compliant: $notificationCompliant"

    $SourceCompliant = (!$Source -or $Source -eq $Get.Source)

    Write-Verbose "service compliant: $SourceCompliant"

    if ($updateCompliant -and $notificationCompliant -and $SourceCompliant)
    {
        return $true
    }
    else
    {
        return $false
    }
}

function Test-TargetResourceProperties
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance,

        [Parameter()]
        [ValidateSet('Security', 'Important', 'Optional')]
        [AllowEmptyCollection()]
        [AllowNull()]
        [System.String[]]
        $Category,

        [Parameter()]
        [ValidateSet('Disabled', 'ScheduledInstallation')]
        [System.String]
        $Notifications,

        [Parameter(Mandatory = $true)]
        [ValidateSet('WindowsUpdate', 'MicrosoftUpdate', 'WSUS')]
        [System.String]
        $Source,

        [Parameter()]
        [System.Boolean]
        $UpdateNow
    )

    $searchStringParams = @{ }

    foreach ($CategoryItem in $Category)
    {
        $searchStringParams[$CategoryItem.ToLowerInvariant()] = $true
    }

    if ($UpdateNow -and (!$Category -or $Category.Count -eq 0))
    {
        Write-Warning 'Defaulting to updating to security updates only. Please specify Category to avoid this warning.'
    }
    elseif ($searchStringParams.ContainsKey('important') -and !$searchStringParams.ContainsKey('security') )
    {
        Write-Warning 'Important updates will include security updates. Please include Security in category to avoid this warning.'
    }
    elseif ($searchStringParams.ContainsKey('optional') -and !$searchStringParams.ContainsKey('security') )
    {
        Write-Verbose 'Optional updates may include security updates.'
    }

    if ($Source -eq 'WSUS')
    {
        throw 'The WSUS service option is not implemented.'
    }
}

Export-ModuleMember -Function *-TargetResource
