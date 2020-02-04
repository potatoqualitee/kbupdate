function Invoke-TlsWebRequest {

    <#
    Internal utility that mimics invoke-webrequest
    but enables all tls available version
    rather than the default, which on a lot
    of standard installations is just TLS 1.0

    #>

    # IWR is crazy slow for large downloads
    $currentProgressPref = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"

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

    if ($script:websession) {
        Invoke-WebRequest @Args -WebSession $script:websession -UseBasicParsing -ErrorAction Stop
    } else {
        Invoke-WebRequest @Args -SessionVariable websession -UseBasicParsing -ErrorAction Stop
        $script:websession = $websession
    }

    [Net.ServicePointManager]::SecurityProtocol = $currentVersionTls
    $ProgressPreference = $currentProgressPref
}



