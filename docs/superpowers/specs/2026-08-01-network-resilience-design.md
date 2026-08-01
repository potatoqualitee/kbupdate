# KBUpdate Network Resilience Design

## Goal

Prevent Microsoft Update Catalog lookups from hanging indefinitely and let noninteractive download jobs avoid BITS, while preserving unlimited time for large update-file downloads.

## Scope

- Add `TimeoutSec` to `Get-KbUpdate`, validated from 1 through `Int32.MaxValue`, with a default of 30 seconds.
- Add `RetryCount` to `Get-KbUpdate`, validated from 0 through `Int32.MaxValue`, with a default of 2 additional attempts (3 total attempts).
- Forward the timeout through `Invoke-TlsWebRequest` to every `Invoke-WebRequest` used by a `Get-KbUpdate` web lookup.
- Add `UseWebRequest` to `Save-KbUpdate` so callers can bypass BITS for both direct links and resolved update objects.
- Keep the existing automatic BITS-to-web-request fallback.
- Leave `Save-KbUpdate` file transfers without a default timeout so large packages are not interrupted.

## Design

`Invoke-TlsWebRequest` will accept an optional validated `TimeoutSec`. It will add that value to the `Invoke-WebRequest` splat only when the caller supplied it. `Get-KbUpdate` will always supply its public default or caller-provided value. Other callers, including update-file downloads and scan-file downloads, retain their current indefinite behavior.

`Save-KbUpdate` will use its existing web-request paths when `UseWebRequest` is present. The BITS availability checks in both parameter-set paths will be guarded by `-not $UseWebRequest`; no download loop or BITS lifecycle code will be restructured.

`Get-KbUpdate` will route Catalog and Microsoft support-page requests through a catalog-specific retry wrapper. The wrapper will make one initial attempt plus `RetryCount` additional attempts. It will wait 1 second before the first retry and 2 seconds before the second retry, write a verbose message for every retry, and clear the cached web session before trying again. Retry behavior remains outside `Invoke-TlsWebRequest` so update-file and scan-file downloads do not inherit it.

The wrapper will retry connection failures, timeouts, HTTP 408 and 429 responses, HTTP 5xx responses, and structurally incomplete Catalog search pages. A search page is complete when it contains download controls or the Catalog's explicit no-results indicator. A valid no-results page returns immediately. HTTP 400, 401, 403, 404, and 407 responses fail immediately because repeating the same request will not repair a query, permission, or proxy-authentication problem. If every attempt returns an incomplete page, the command reports an actionable incomplete-response error instead of treating the page as a legitimate empty result.

## Error Handling and Compatibility

- `TimeoutSec 0` and negative values fail parameter binding consistently instead of meaning different things across PowerShell editions.
- `RetryCount 0` preserves fail-fast behavior, while the default value of 2 permits 3 total attempts.
- `TimeoutSec` applies to each attempt. With defaults, a persistently hanging request can take about 93 seconds including retry delays.
- `TimeoutSec` is passed by that portable name: it is the formal parameter on Windows PowerShell and an alias of `ConnectionTimeoutSeconds` on PowerShell 7.4 and later.
- Existing `EnableException`, proxy, `ShouldProcess`, duplicate-link, and BITS fallback behavior remain unchanged.
- Module code remains compatible with Windows PowerShell 3.0.

## Tests

- Verify `Get-KbUpdate` forwards the default timeout and an explicit timeout to the shared request helper, and rejects zero.
- Verify the catalog wrapper succeeds after transient failures, stops after the configured attempt limit, and reports each retry.
- Verify HTTP 407 and other nonretryable client errors fail on the first attempt.
- Verify incomplete search responses are retried, explicit no-results responses are not retried, and exhausted incomplete responses fail clearly.
- Verify `Get-KbUpdate` defaults to 2 retries, accepts `RetryCount 0`, and rejects negative values.
- Verify `Invoke-TlsWebRequest` forwards a supplied timeout to `Invoke-WebRequest`.
- Verify `Save-KbUpdate -UseWebRequest` bypasses an available BITS command for both direct-link and piped-object downloads.
- Run the focused unit tests, the deterministic quality gate, and live read-only Catalog probes for both legacy `download.windowsupdate.com` and `delivery.mp.microsoft.com` result shapes.

## Alternatives Considered

1. Give every `Invoke-TlsWebRequest` call a 30-second default. Rejected because it would also change large file-download behavior.
2. Add `TimeoutSec` to every public download command. Rejected as a broader API change without an upstream requirement.
3. Apply only `UseWebRequest`. Rejected because the newly merged dbatools timeout fix addresses a separate indefinite-hang failure that exists in this implementation too.
4. Retry only in GitHub Actions. Rejected because it would not help module users behind corporate proxies, TLS inspection, or intermittently failing gateways.
5. Put retry logic in `Invoke-TlsWebRequest`. Rejected because that helper is also used for large downloads and non-Catalog requests that must keep their current behavior.
6. Retry every empty result. Rejected because a valid Catalog no-results response is a normal query outcome and should not be delayed.
