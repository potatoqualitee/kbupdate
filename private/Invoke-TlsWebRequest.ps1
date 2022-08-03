function Invoke-TlsWebRequest {
    $script:arrgs = $Args
    $PSDefaultParameterValues["Invoke-WebRequest:UseBasicParsing"] = $true
    $PSDefaultParameterValues["Invoke-WebRequest:WebSession"] = $script:websession
    $PSDefaultParameterValues["Invoke-WebRequest:OutVariable"] = "script:previouspage"
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
        $proxy = $regproxy.ProxyServer

        if ($proxy -and -not ([System.Net.Webrequest]::DefaultWebProxy).Address -and $regproxy.ProxyEnable) {
            [System.Net.Webrequest]::DefaultWebProxy = New-object System.Net.WebProxy $proxy
            [System.Net.Webrequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
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

    if ($script:Maxpages -eq 1 -or $args[1] -notmatch "Search.aspx") {
        Write-PSFMessage -Level Verbose -Message "URL: $($args[1])"
        if ($script:websession -and $script:websession.Headers."Accept-Language" -eq $Language) {
            Invoke-WebRequest @Args
        } else {
            Invoke-WebRequest @Args -SessionVariable websession -Headers @{ "Accept-Language" = $Language } -WebSession $null
            $script:websession = $websession
        }
    } else {
        1..$script:MaxPages | ForEach-Object -Process {
            Write-PSFMessage -Level Verbose -Message "URL: $($arrgs[1])"
            if ($PSItem -gt 1) {
                $body = @{
                    '__EVENTTARGET'        = 'ctl00$catalogBody$nextPageLinkText'
                    '__VIEWSTATE'          = ($script:previouspage.InputFields | Where-Object Name -eq __VIEWSTATE).Value
                    '__EVENTARGUMENT'      = ($script:previouspage.InputFields | Where-Object Name -eq __EVENTARGUMENT).Value
                    '__VIEWSTATEGENERATOR' = ($script:previouspage.InputFields | Where-Object Name -eq __VIEWSTATEGENERATOR).Value
                    '__EVENTVALIDATION'    = ($script:previouspage.InputFields | Where-Object Name -eq __EVENTVALIDATION).Value
                }
                $pages = @{
                    Body   = $body
                    Method = "POST"
                }
            } else {
                $pages = @{}
            }

            if ($script:websession -and $script:websession.Headers."Accept-Language" -eq $Language) {
                if ($pages -and $arrgs[3] -ne "POST") {
                    Invoke-WebRequest @arrgs @pages
                } else {
                    Invoke-WebRequest @arrgs
                }
            } else {
                Invoke-WebRequest @arrgs -SessionVariable websession -Headers @{ "Accept-Language" = $Language } -WebSession $null
                $script:websession = $websession
            }
        }
    }

    [Net.ServicePointManager]::SecurityProtocol = $currentVersionTls

    if ($PSversionTable.PSEdition -ne "Core") {
        $ProgressPreference = $currentProgressPref
    }
}