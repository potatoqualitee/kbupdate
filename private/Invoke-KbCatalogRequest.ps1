function Test-KbTransientCatalogError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Exception
    )

    $statusCode = $null
    if ($Exception.PSObject.Properties['StatusCode'] -and $null -ne $Exception.StatusCode) {
        $statusCode = [int]$Exception.StatusCode
    } elseif ($Exception.PSObject.Properties['Response'] -and $Exception.Response -and
        $Exception.Response.PSObject.Properties['StatusCode']) {
        $statusCode = [int]$Exception.Response.StatusCode
    }

    if ($null -eq $statusCode) {
        return $true
    }

    $statusCode -eq 408 -or $statusCode -eq 429 -or $statusCode -ge 500
}

function Test-KbCompleteCatalogSearchResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Response
    )

    $downloadFields = @(
        $Response |
            ForEach-Object { $PSItem.InputFields } |
            Where-Object {
                $PSItem.Type -eq 'Button' -and
                ($PSItem.Value -eq 'Download' -or $PSItem.Class -eq 'flatBlueButtonDownload focus-only')
            }
    )
    if ($downloadFields.Count -gt 0) {
        return $true
    }

    $content = ($Response | ForEach-Object { [string]$PSItem.Content }) -join "`n"
    $content -match 'We did not find any results for'
}

function Invoke-KbCatalogRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,
        [string]$Method,
        [object]$Body,
        [ValidateRange(1, [int]::MaxValue)]
        [int]$TimeoutSec,
        [uri]$Proxy,
        [pscredential]$ProxyCredential,
        [ValidateRange(0, [int]::MaxValue)]
        [int]$RetryCount = 2
    )

    $requestParameters = @{
        Uri = $Uri
    }
    foreach ($parameterName in 'Method', 'Body', 'TimeoutSec', 'Proxy', 'ProxyCredential') {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $requestParameters[$parameterName] = $PSBoundParameters[$parameterName]
        }
    }

    $validateSearchResponse = $Uri.Host -eq 'www.catalog.update.microsoft.com' -and
        $Uri.AbsolutePath -eq '/Search.aspx'
    [long]$totalAttempts = [long]$RetryCount + 1
    for ([long]$attempt = 1; $attempt -le $totalAttempts; $attempt++) {
        $retryReason = $null
        try {
            $response = @(Invoke-TlsWebRequest @requestParameters)
            if (-not $validateSearchResponse -or (Test-KbCompleteCatalogSearchResponse -Response $response)) {
                $response
                return
            }

            if ($attempt -ge $totalAttempts) {
                $message = "Microsoft Update Catalog returned an incomplete search response after $totalAttempts attempts."
                throw (New-Object -TypeName System.IO.InvalidDataException -ArgumentList $message)
            }
            $retryReason = 'Microsoft Update Catalog returned an incomplete search response.'
        } catch {
            if ($attempt -ge $totalAttempts -or -not (Test-KbTransientCatalogError -Exception $PSItem.Exception)) {
                throw
            }
            $retryReason = $PSItem.Exception.Message
        }

        $script:websession = $null
        $script:previouspage = $null
        $retryDelay = if ($attempt -eq 1) { 1 } else { 2 }
        Write-PSFMessage -Level Verbose -Message "Catalog request attempt $attempt of $totalAttempts failed. Retrying in $retryDelay seconds. $retryReason"
        Start-Sleep -Seconds $retryDelay
    }
}
