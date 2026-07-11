function Invoke-TlsWebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,
        [string]$Method,
        [object]$Body,
        [string]$OutFile,
        [uri]$Proxy,
        [pscredential]$ProxyCredential
    )

    $requestParameters = @{
        Uri = $Uri
    }
    foreach ($parameterName in 'Method', 'Body', 'OutFile') {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $requestParameters[$parameterName] = $PSBoundParameters[$parameterName]
        }
    }

    $effectiveProxy = $Proxy
    if ($ProxyCredential -and -not $effectiveProxy) {
        $systemProxy = [System.Net.WebRequest]::DefaultWebProxy
        if ($systemProxy) {
            $detectedProxy = $systemProxy.GetProxy($Uri)
            if ($detectedProxy -and $detectedProxy -ne $Uri) {
                $effectiveProxy = $detectedProxy
            }
        }
    }
    $PSDefaultParameterValues["Invoke-WebRequest:UseBasicParsing"] = $true
    $PSDefaultParameterValues["Invoke-WebRequest:WebSession"] = $script:websession
    $PSDefaultParameterValues["Invoke-WebRequest:OutVariable"] = "script:previouspage"

    $PSDefaultParameterValues.Remove("*:ErrorAction")
    $PSDefaultParameterValues["Invoke-WebRequest:ErrorAction"] = "Stop"

    <#
    Internal utility that mimics invoke-webrequest
    but enables all tls available version
    rather than the default, which on a lot
    of standard installations is just TLS 1.0

    #>

    # IWR is crazy slow for large downloads
    if ($PSversionTable.PSEdition -ne "Core") {
        $currentProgressPref = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
    }

    if (-not $IsLinux -and -not $IsMacOs) {
        $regproxy = Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        $registryProxy = $regproxy.ProxyServer

        if ($registryProxy -and -not ([System.Net.Webrequest]::DefaultWebProxy).Address -and $regproxy.ProxyEnable) {
            [System.Net.Webrequest]::DefaultWebProxy = New-Object System.Net.WebProxy $registryProxy
            [System.Net.Webrequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
            if ($ProxyCredential -and -not $effectiveProxy) {
                $effectiveProxy = [uri]$registryProxy
            }
        }
    }

    if ($ProxyCredential -and -not $effectiveProxy) {
        throw 'No system proxy was detected. Specify Proxy when using ProxyCredential.'
    }

    if ($effectiveProxy) {
        $requestParameters.Proxy = $effectiveProxy
        if ($ProxyCredential) {
            $requestParameters.ProxyCredential = $ProxyCredential
        } else {
            $requestParameters.ProxyUseDefaultCredentials = $true
        }
    }

    $currentVersionTls = [Net.ServicePointManager]::SecurityProtocol
    $currentSupportableTls = [Math]::Max($currentVersionTls.value__, [Net.SecurityProtocolType]::Tls.value__)
    $availableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -gt $currentSupportableTls }
    $availableTls | ForEach-Object {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $_
    }

    if ($Language.Length -gt 3) {
        # It's auto-complete, translate it to the list
        $OriginalLanguage = $Language
        $Language = ($script:languagescsv | Where-Object Name -eq $Language).Code

        if (-not $Language) {
            $Language = $OriginalLanguage
        }
    }

    if (-not $Language) {
        $Language = "en-US;q=0.5,en;q=0.3"
    }

    if ($script:Maxpages -eq 1 -or $Uri.AbsoluteUri -notmatch "Search.aspx") {
        Write-PSFMessage -Level Verbose -Message "URL: $Uri"
        if ($script:websession -and $script:websession.Headers."Accept-Language" -eq $Language) {
            Invoke-WebRequest @requestParameters
        } else {
            $sessionParameters = $requestParameters.Clone()
            $sessionParameters.SessionVariable = 'websession'
            $sessionParameters.Headers = @{ "Accept-Language" = $Language }
            $sessionParameters.WebSession = $null
            Invoke-WebRequest @sessionParameters
            $script:websession = $websession
        }
    } else {
        1..$script:MaxPages | ForEach-Object -Process {
            Write-PSFMessage -Level Verbose -Message "URL: $Uri"
            $pageParameters = $requestParameters.Clone()
            if ($PSItem -gt 1) {
                $body = @{
                    '__EVENTTARGET'        = 'ctl00$catalogBody$nextPageLinkText'
                    '__VIEWSTATE'          = ($script:previouspage.InputFields | Where-Object Name -eq __VIEWSTATE).Value
                    '__EVENTARGUMENT'      = ($script:previouspage.InputFields | Where-Object Name -eq __EVENTARGUMENT).Value
                    '__VIEWSTATEGENERATOR' = ($script:previouspage.InputFields | Where-Object Name -eq __VIEWSTATEGENERATOR).Value
                    '__EVENTVALIDATION'    = ($script:previouspage.InputFields | Where-Object Name -eq __EVENTVALIDATION).Value
                }
                $pageParameters.Body = $body
                $pageParameters.Method = "POST"
            }

            if ($script:websession -and $script:websession.Headers."Accept-Language" -eq $Language) {
                Invoke-WebRequest @pageParameters
            } else {
                $pageParameters.SessionVariable = 'websession'
                $pageParameters.Headers = @{ "Accept-Language" = $Language }
                $pageParameters.WebSession = $null
                Invoke-WebRequest @pageParameters
                $script:websession = $websession
            }
        }
    }

    [Net.ServicePointManager]::SecurityProtocol = $currentVersionTls

    if ($PSversionTable.PSEdition -ne "Core") {
        $ProgressPreference = $currentProgressPref
    }
}