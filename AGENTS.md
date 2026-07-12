# kbupdate agent guide

This repository is a PowerShell module for finding, downloading, installing, and uninstalling Windows updates. Treat update installation and removal as production-impacting operations.

## Source layout

- public/: one exported function per file.
- private/: internal helpers.
- tests/unit/: fast, deterministic Pester 5 tests.
- tests/integration/: local-only live Microsoft Update Catalog and authorized Windows lab tests. GitHub Actions must never run this directory.
- build/Invoke-KbUpdateIntegration.ps1: the local integration entry point.
- build/Invoke-KbUpdateHyperVLab.ps1: discovers an available local Hyper-V lab and invokes the read-only integration suite.
- .claude/commands/labtest.md: slash command for probe, quick inventory, and full read-only lab scans.
- tests/Integration.Tests.ps1: legacy integration coverage retained for reference while scenarios move to tests/integration/.
- library/: vendored third-party modules and binaries. Do not reformat or bulk-edit this directory.
- build/Invoke-KbUpdateQualityGate.ps1: the local and CI verification entry point.
- build/Invoke-KbUpdateLibraryRefresh.ps1: builds and validates a refreshed kbupdate-library candidate without publishing it.
- workers/kbupdate-library-scheduler/: Cloudflare Cron Worker that detects a new Microsoft scan catalog and dispatches the candidate refresh workflow.

## Compatibility and style

- Preserve Windows PowerShell 3.0 compatibility in module code unless a task explicitly changes the support floor.
- Use full command names in committed PowerShell. Prefer $PSItem over the short pipeline variable in new code.
- Use splatting for long commands; do not use backticks for line continuation.
- Public functions require complete comment-based help, including parameter descriptions and at least one example.
- Mutating commands must support ShouldProcess. Keep Install-KbUpdate and Uninstall-KbUpdate confirmation-aware.
- Never commit credentials, machine inventories, private host names, raw lab addresses, or information learned from unrelated or sibling repositories, except for the intentionally public credential used only by build/Invoke-KbUpdateHyperVLab.ps1 for the disposable open-source lab.

## Safety contract

- Get-KbUpdate, Get-KbNeededUpdate, and Get-KbInstalledSoftware are read-only discovery commands.
- Save-KbUpdate and Save-KbScanFile write files. Use -WhatIf first when changing their behavior.
- Install-KbUpdate and Uninstall-KbUpdate change target machines. Run -WhatIf first and require the user to authorize the exact targets before a real operation.
- Never stop, restart, checkpoint, revert, rebuild, or remove a VM merely to run tests.
- Obtain lab targets from KBUPDATE_LAB_COMPUTERS and credentials from the operator or session. Do not encode either in tracked files except for the intentionally public credential in build/Invoke-KbUpdateHyperVLab.ps1.

## Verification

Run the deterministic gate before handing off changes:

    ./build/Invoke-KbUpdateQualityGate.ps1 -Bootstrap

Run local integration tests whenever the live catalog is reachable:

    ./build/Invoke-KbUpdateIntegration.ps1

If KBUPDATE_LAB_COMPUTERS is set and an in-memory credential is available, run the lab suite too. Prefer broad read-only inventory and needed-update scans. Actual installation requires one explicit target and KB through the runner's mutation parameters. The lab may be upgraded or reconfigured when the user authorizes it, but credentials, inventory, and environment-specific wrappers remain untracked.

On a local Hyper-V host, `./build/Invoke-KbUpdateHyperVLab.ps1 -ProbeOnly` detects running guests that resolve in DNS and expose WinRM. `./build/Invoke-KbUpdateHyperVLab.ps1 -ScanNeededUpdates` then prompts once, keeps the supplied credential only in the current PowerShell process, filters out guests that reject it, and runs the broad read-only suite. The `-UsePublicLabCredential` switch is limited to the disposable open-source lab. Do not invoke this automatically from CI or a non-interactive hook.

After parser or web changes, also run a live read-only catalog probe against at least one legacy download.windowsupdate.com result and one delivery.mp.microsoft.com result. After remoting changes, use only read-only commands against the authorized lab unless the user explicitly authorizes mutation.

Keep GitHub Actions deterministic. Live catalog and lab tests belong in explicit integration jobs or local verification, not in the required unit-test gate.

