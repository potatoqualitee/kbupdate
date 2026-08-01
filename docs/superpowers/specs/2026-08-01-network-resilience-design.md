# KBUpdate Network Resilience Design

## Goal

Prevent Microsoft Update Catalog lookups from hanging indefinitely and let noninteractive download jobs avoid BITS, while preserving unlimited time for large update-file downloads.

## Scope

- Add `TimeoutSec` to `Get-KbUpdate`, validated from 1 through `Int32.MaxValue`, with a default of 30 seconds.
- Forward the timeout through `Invoke-TlsWebRequest` to every `Invoke-WebRequest` used by a `Get-KbUpdate` web lookup.
- Add `UseWebRequest` to `Save-KbUpdate` so callers can bypass BITS for both direct links and resolved update objects.
- Keep the existing automatic BITS-to-web-request fallback.
- Leave `Save-KbUpdate` file transfers without a default timeout so large packages are not interrupted.

## Design

`Invoke-TlsWebRequest` will accept an optional validated `TimeoutSec`. It will add that value to the `Invoke-WebRequest` splat only when the caller supplied it. `Get-KbUpdate` will always supply its public default or caller-provided value. Other callers, including update-file downloads and scan-file downloads, retain their current indefinite behavior.

`Save-KbUpdate` will use its existing web-request paths when `UseWebRequest` is present. The BITS availability checks in both parameter-set paths will be guarded by `-not $UseWebRequest`; no download loop or BITS lifecycle code will be restructured.

## Error Handling and Compatibility

- `TimeoutSec 0` and negative values fail parameter binding consistently instead of meaning different things across PowerShell editions.
- `TimeoutSec` is passed by that portable name: it is the formal parameter on Windows PowerShell and an alias of `ConnectionTimeoutSeconds` on PowerShell 7.4 and later.
- Existing `EnableException`, proxy, `ShouldProcess`, duplicate-link, and BITS fallback behavior remain unchanged.
- Module code remains compatible with Windows PowerShell 3.0.

## Tests

- Verify `Get-KbUpdate` forwards the default timeout and an explicit timeout to the shared request helper, and rejects zero.
- Verify `Invoke-TlsWebRequest` forwards a supplied timeout to `Invoke-WebRequest`.
- Verify `Save-KbUpdate -UseWebRequest` bypasses an available BITS command for both direct-link and piped-object downloads.
- Run the focused unit tests, the deterministic quality gate, and live read-only Catalog probes for both legacy `download.windowsupdate.com` and `delivery.mp.microsoft.com` result shapes.

## Alternatives Considered

1. Give every `Invoke-TlsWebRequest` call a 30-second default. Rejected because it would also change large file-download behavior.
2. Add `TimeoutSec` to every public download command. Rejected as a broader API change without an upstream requirement.
3. Apply only `UseWebRequest`. Rejected because the newly merged dbatools timeout fix addresses a separate indefinite-hang failure that exists in this implementation too.
