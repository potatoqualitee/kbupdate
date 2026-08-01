# KBUpdate Network Resilience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound Microsoft Update Catalog lookup waits, retry transient Catalog failures, and provide a reliable non-BITS download path for noninteractive jobs.

**Architecture:** Add an optional timeout to the shared web-request helper, but bind its 30-second default only at the `Get-KbUpdate` public boundary. Route only `Get-KbUpdate` Catalog/support requests through a retry wrapper with response validation, leaving downloads unchanged. Add a `Save-KbUpdate` switch that selects the already-existing web-request branches instead of BITS, preserving fallback and large-download behavior.

**Tech Stack:** Windows PowerShell 3.0-compatible PowerShell module code, Pester 6 unit tests, PSFramework, Microsoft Update Catalog.

## Global Constraints

- Preserve Windows PowerShell 3.0 compatibility in module code.
- Use full command names, `$PSItem`, splatting for long commands, and no backtick line continuations.
- Keep `Save-KbUpdate` confirmation-aware through its existing `ShouldProcess` flow.
- Do not give large update-file downloads a default timeout.
- Default `Get-KbUpdate` to 2 additional retries (3 total attempts), with `RetryCount 0` preserving fail-fast behavior.
- Retry only transient web failures and incomplete Catalog search responses; never retry valid no-results or nonretryable HTTP client errors.
- Run only read-only live Catalog verification; do not install, remove, or otherwise mutate Windows updates.

---

### Task 1: Bound Catalog Lookup Requests

**Files:**
- Modify: `tests/unit/Get-KbUpdateProxy.Tests.ps1`
- Modify: `tests/unit/Invoke-TlsWebRequest.Tests.ps1`
- Modify: `public/Get-KbUpdate.ps1`
- Modify: `private/Invoke-TlsWebRequest.ps1`

**Interfaces:**
- Consumes: Existing `Get-KbUpdate` web-source calls and `Invoke-TlsWebRequest` request splat.
- Produces: `Get-KbUpdate [-TimeoutSec <int>]`, default 30; `Invoke-TlsWebRequest [-TimeoutSec <int>]`, optional and forwarded only when supplied.

- [ ] **Step 1: Write failing public-boundary tests**

Add tests in `Get-KbUpdateProxy.Tests.ps1` that reuse the controlled Catalog fixture and assert:

```powershell
Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly -ParameterFilter {
    $TimeoutSec -eq 30
}
```

for an omitted value, and:

```powershell
$null = Get-KbUpdate -Pattern $guid -Source Web -Simple -TimeoutSec 7 -EnableException
Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly -ParameterFilter {
    $TimeoutSec -eq 7
}
```

for an explicit value. Add a binding test:

```powershell
{ Get-KbUpdate -Pattern test -Source Database -TimeoutSec 0 } |
    Should -Throw -ExpectedMessage '*minimum allowed range*'
```

- [ ] **Step 2: Write the failing helper-boundary test**

Add to `Invoke-TlsWebRequest.Tests.ps1`:

```powershell
It 'passes a supplied timeout to Invoke-WebRequest' {
    $null = Invoke-TlsWebRequest -Uri 'https://www.catalog.update.microsoft.com/' -TimeoutSec 7

    Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
        $TimeoutSec -eq 7
    }
}
```

This catches omission of the value at the final network boundary, not merely existence of a public parameter.

- [ ] **Step 3: Run the tests and verify RED**

Run:

```powershell
./build/Invoke-KbUpdateQualityGate.ps1 -Bootstrap
```

Expected: failures because `Get-KbUpdate` and `Invoke-TlsWebRequest` do not accept `TimeoutSec` and the expected network parameters are absent.

- [ ] **Step 4: Implement the helper timeout**

Add the optional helper parameter:

```powershell
[ValidateRange(1, [int]::MaxValue)]
[int]$TimeoutSec
```

After constructing `$requestParameters`, add it only when explicitly bound:

```powershell
if ($PSBoundParameters.ContainsKey('TimeoutSec')) {
    $requestParameters.TimeoutSec = $TimeoutSec
}
```

Do not assign a helper-level default.

- [ ] **Step 5: Implement the public Catalog timeout**

Add complete comment-based help for `TimeoutSec`, add this public parameter near other web controls:

```powershell
[ValidateRange(1, [int]::MaxValue)]
[int]$TimeoutSec = 30,
```

and initialize the existing lookup splat with:

```powershell
$webRequestParameters = @{
    TimeoutSec = $TimeoutSec
}
```

Add an example showing `Get-KbUpdate -Pattern KB4057119 -Source Web -TimeoutSec 10`.

- [ ] **Step 6: Run the tests and verify GREEN**

Run the full deterministic gate again. Expected: all deterministic tests pass with zero failures.

- [ ] **Step 7: Commit the timeout change**

```powershell
git add public/Get-KbUpdate.ps1 private/Invoke-TlsWebRequest.ps1 tests/unit/Get-KbUpdateProxy.Tests.ps1 tests/unit/Invoke-TlsWebRequest.Tests.ps1
git commit -m 'Bound Microsoft Update Catalog request waits'
```

### Task 2: Let Noninteractive Downloads Bypass BITS

**Files:**
- Modify: `tests/unit/Save-KbUpdate.Tests.ps1`
- Modify: `public/Save-KbUpdate.ps1`

**Interfaces:**
- Consumes: Existing direct-link and piped-object download paths, existing BITS fallback, and existing `Invoke-TlsWebRequest` branches.
- Produces: `Save-KbUpdate [-UseWebRequest]`, which never calls `Start-BitsTransfer` when present.

- [ ] **Step 1: Write the failing direct-link behavior test**

With `Get-Command` still mocked to report BITS as available, add:

```powershell
It 'uses a web request for a direct link when UseWebRequest is specified' {
    Mock Start-BitsTransfer
    Mock Invoke-TlsWebRequest

    $null = Save-KbUpdate -Link 'https://catalog.s.download.windowsupdate.com/test/direct-web.msu' -Path $TestDrive -UseWebRequest -Confirm:$false

    Should -Invoke Start-BitsTransfer -Times 0 -Exactly
    Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
}
```

- [ ] **Step 2: Write the failing piped-object behavior test**

Add a second test using a real update-shaped object:

```powershell
It 'uses a web request for a piped update when UseWebRequest is specified' {
    Mock Start-BitsTransfer
    Mock Invoke-TlsWebRequest

    $update = [pscustomobject]@{
        Title = 'Noninteractive update'
        Link  = 'https://catalog.s.download.windowsupdate.com/test/piped-web.msu'
    }

    $null = $update | Save-KbUpdate -Path $TestDrive -UseWebRequest -Confirm:$false

    Should -Invoke Start-BitsTransfer -Times 0 -Exactly
    Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
}
```

- [ ] **Step 3: Run the tests and verify RED**

Run the deterministic quality gate. Expected: parameter binding fails because `UseWebRequest` does not exist.

- [ ] **Step 4: Implement the BITS bypass**

Add complete parameter help and:

```powershell
[switch]$UseWebRequest,
```

Change both BITS-selection conditions to:

```powershell
if (-not $UseWebRequest -and (Get-Command Start-BitsTransfer -ErrorAction Ignore)) {
```

Do not change the existing catch fallback, asynchronous job processing, proxy splats, or `ShouldProcess` guards. Add an example for a scheduled task or SQL Agent job.

- [ ] **Step 5: Run the tests and verify GREEN**

Run the full deterministic quality gate. Expected: all deterministic tests pass with zero failures.

- [ ] **Step 6: Commit the download change**

```powershell
git add public/Save-KbUpdate.ps1 tests/unit/Save-KbUpdate.Tests.ps1
git commit -m 'Allow Save-KbUpdate to bypass BITS'
```

### Task 3: Verify the Integrated Change and Publish It

**Files:**
- Verify: all files changed since `origin/main`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: Reviewed branch and draft pull request against `main`.

- [ ] **Step 1: Run the deterministic gate fresh**

```powershell
./build/Invoke-KbUpdateQualityGate.ps1 -Bootstrap
```

Expected: parser, manifest, analyzer, and all deterministic Pester tests pass.

- [ ] **Step 2: Run the local read-only integration suite**

```powershell
./build/Invoke-KbUpdateIntegration.ps1
```

Expected: live Catalog scenarios pass when the Catalog is reachable. Do not run a mutation-enabled lab command.

- [ ] **Step 3: Verify both Catalog delivery-host shapes**

Run read-only web-source probes for known legacy and current delivery results:

```powershell
$legacy = @(Get-KbUpdate -Pattern KB4057119 -Source Web -Simple -TimeoutSec 30 -EnableException)
$delivery = @(Get-KbUpdate -Pattern KB5003279 -Source Web -Simple -TimeoutSec 30 -EnableException)
$legacy.Link | Where-Object { $PSItem -match 'download\.windowsupdate\.com' }
$delivery.Link | Where-Object { $PSItem -match 'delivery\.mp\.microsoft\.com' }
```

If either known KB no longer exposes the expected host, use another result returned by the live Catalog and record the exact read-only evidence in the PR body.

- [ ] **Step 4: Review the diff against the design**

Check every requirement in `docs/superpowers/specs/2026-08-01-network-resilience-design.md`, run `git diff --check origin/main...HEAD`, and inspect `git status --short` for unrelated files.

- [ ] **Step 5: Request an independent code review**

Provide the reviewer the design path, base SHA from `origin/main`, head SHA, and the exact verification results. Fix all Critical and Important findings, then rerun the relevant tests.

- [ ] **Step 6: Push and open a draft PR**

Push `codex/kbupdate-network-resilience`, open a draft PR against `main`, and describe the root causes, compatibility boundary, and tests.

### Task 4: Add a Catalog-Specific Retry Boundary

**Files:**
- Create: `private/Invoke-KbCatalogRequest.ps1`
- Create: `tests/unit/Invoke-KbCatalogRequest.Tests.ps1`

**Interfaces:**
- Consumes: `Invoke-TlsWebRequest [-Uri] <uri> [-Method <string>] [-Body <object>] [-TimeoutSec <int>] [-Proxy <uri>] [-ProxyCredential <pscredential>]`.
- Produces: `Invoke-KbCatalogRequest [-Uri] <uri> [-Method <string>] [-Body <object>] [-TimeoutSec <int>] [-Proxy <uri>] [-ProxyCredential <pscredential>] [-RetryCount <int>]`, with `RetryCount` representing additional attempts.

- [ ] **Step 1: Write failing transient-retry tests**

Create `tests/unit/Invoke-KbCatalogRequest.Tests.ps1`. Mock only `Invoke-TlsWebRequest` and `Start-Sleep`; call the real retry wrapper. Cover a generic connection exception that succeeds on attempt 3, exhaustion after 3 attempts, and `RetryCount 0` making one attempt. Assert returned data or the thrown error, plus exact attempt and sleep counts.

```powershell
It 'returns a later successful response after two transient failures' {
    $script:attempt = 0
    Mock Invoke-TlsWebRequest {
        $script:attempt++
        if ($script:attempt -lt 3) { throw 'temporary connection failure' }
        [pscustomobject]@{ Content = 'complete detail response' }
    }

    $result = Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=test' -RetryCount 2

    $result.Content | Should -Be 'complete detail response'
    Should -Invoke Invoke-TlsWebRequest -Times 3 -Exactly
    Should -Invoke Start-Sleep -Times 2 -Exactly
}
```

- [ ] **Step 2: Run the retry tests and verify RED**

Run:

```powershell
Invoke-Pester -Path tests/unit/Invoke-KbCatalogRequest.Tests.ps1 -Output Detailed
```

Expected: FAIL because `Invoke-KbCatalogRequest` does not exist.

- [ ] **Step 3: Implement the minimal retry loop**

Create `private/Invoke-KbCatalogRequest.ps1`. Build a splat containing only bound request parameters. Use a `[long]` attempt counter so `RetryCount = [int]::MaxValue` cannot overflow. Retry an exception without an HTTP status, HTTP 408/429, or HTTP 5xx. Fail immediately for other HTTP status codes. Before each retry, clear `$script:websession` and `$script:previouspage`, write a verbose message, and sleep for 1 second before the first retry and 2 seconds before later retries.

```powershell
[ValidateRange(0, [int]::MaxValue)]
[int]$RetryCount = 2
```

Status extraction must support both `Exception.StatusCode` and `Exception.Response.StatusCode` without referencing PowerShell-7-only exception types.

- [ ] **Step 4: Run the retry tests and verify GREEN**

Run the new test file. Expected: all transient, exhaustion, and fail-fast cases pass.

- [ ] **Step 5: Write failing response-validation tests**

Add tests using complete response-shaped objects with `Content`, `InputFields`, and `Links`:

- an incomplete `Search.aspx` response is retried and a later response with a Download input field is returned;
- an explicit `We did not find any results for` response is returned without retry;
- repeated incomplete responses throw an error containing `incomplete` after the configured attempts;
- an HTTP 407 exception is not retried.

- [ ] **Step 6: Run the validation tests and verify RED**

Expected: incomplete responses return immediately instead of retrying, and the nonretryable-status branch is not yet complete.

- [ ] **Step 7: Implement Catalog search-response validation**

For `https://www.catalog.update.microsoft.com/Search.aspx`, treat the response as structurally complete only when it has a Download input field or its content contains the explicit Catalog no-results message. Retry incomplete responses; after the final incomplete response, throw `System.IO.InvalidDataException` with an actionable message. Do not apply structural validation to DownloadDialog, ScopedViewInline, Microsoft support pages, or any file download.

- [ ] **Step 8: Run all helper tests and verify GREEN**

Run the new helper test file and `tests/unit/Invoke-TlsWebRequest.Tests.ps1`. Expected: all pass without real network calls.

### Task 5: Expose Retries Through Get-KbUpdate

**Files:**
- Modify: `tests/unit/Get-KbUpdateProxy.Tests.ps1`
- Modify: `public/Get-KbUpdate.ps1`

**Interfaces:**
- Consumes: `Invoke-KbCatalogRequest` from Task 4.
- Produces: `Get-KbUpdate [-RetryCount <int>]`, default 2 additional attempts.

- [ ] **Step 1: Write failing public-boundary tests**

Update the controlled Catalog tests to mock `Invoke-KbCatalogRequest`. Add behavior tests proving the default value 2 and explicit value 0 are forwarded, and that `RetryCount -1` fails parameter binding. Keep existing timeout and proxy assertions.

```powershell
It 'forwards the default retry count to catalog requests' {
    $null = Get-KbUpdate -Pattern KB1234567 -Source Web -Simple
    Should -Invoke Invoke-KbCatalogRequest -ParameterFilter { $RetryCount -eq 2 }
}
```

- [ ] **Step 2: Run the public tests and verify RED**

Expected: parameter binding rejects `RetryCount` because the public parameter does not exist, and existing mocks no longer describe the desired boundary.

- [ ] **Step 3: Add RetryCount and route Catalog calls**

Add complete comment-based help, one example, and:

```powershell
[ValidateRange(0, [int]::MaxValue)]
[int]$RetryCount = 2
```

Add `RetryCount` to `$webRequestParameters`. Replace only the `Invoke-TlsWebRequest @webRequestParameters` calls inside `Get-KbUpdate` with `Invoke-KbCatalogRequest @webRequestParameters`. Do not change `Save-KbUpdate`, scan-file downloads, or `Invoke-TlsWebRequest`.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run `Get-KbUpdateProxy.Tests.ps1`, `Invoke-KbCatalogRequest.Tests.ps1`, `Invoke-TlsWebRequest.Tests.ps1`, and `Save-KbUpdate.Tests.ps1`. Expected: all pass.

- [ ] **Step 5: Run full and live verification**

Run `./build/Invoke-KbUpdateQualityGate.ps1 -Bootstrap`, the read-only integration suite, and direct read-only probes for legacy and modern Microsoft delivery hosts. Exercise a controlled retry with mocks; do not cause update installation, removal, or full package downloads.

- [ ] **Step 6: Review, commit, push, and recheck PR 266**

Review the complete diff against the design, commit the retry implementation and tests, push the existing branch, update the PR body, and wait for GitHub checks. Record any external live-Catalog failure separately from deterministic failures.
