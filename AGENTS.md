# kbupdate agent guide

This repository is a PowerShell module for finding, downloading, installing, and uninstalling Windows updates. Treat update installation and removal as production-impacting operations.

## Source layout

- public/: one exported function per file.
- private/: internal helpers.
- tests/unit/: fast, deterministic Pester 5 tests.
- tests/integration/: local-only live Microsoft Update Catalog and authorized Windows lab tests. GitHub Actions must never run this directory.
- build/Invoke-KbUpdateIntegration.ps1: the local integration entry point.
- tests/Integration.Tests.ps1: legacy integration coverage retained for reference while scenarios move to tests/integration/.
- library/: vendored third-party modules and binaries. Do not reformat or bulk-edit this directory.
- build/Invoke-KbUpdateQualityGate.ps1: the local and CI verification entry point.

## Compatibility and style

- Preserve Windows PowerShell 3.0 compatibility in module code unless a task explicitly changes the support floor.
- Use full command names in committed PowerShell. Prefer $PSItem over the short pipeline variable in new code.
- Use splatting for long commands; do not use backticks for line continuation.
- Public functions require complete comment-based help, including parameter descriptions and at least one example.
- Mutating commands must support ShouldProcess. Keep Install-KbUpdate and Uninstall-KbUpdate confirmation-aware.
- Never commit credentials, machine inventories, private host names, raw lab addresses, or information learned from unrelated or sibling repositories.

## Safety contract

- Get-KbUpdate, Get-KbNeededUpdate, and Get-KbInstalledSoftware are read-only discovery commands.
- Save-KbUpdate and Save-KbScanFile write files. Use -WhatIf first when changing their behavior.
- Install-KbUpdate and Uninstall-KbUpdate change target machines. Run -WhatIf first and require the user to authorize the exact targets before a real operation.
- Never stop, restart, checkpoint, revert, rebuild, or remove a VM merely to run tests.
- Obtain lab targets from KBUPDATE_LAB_COMPUTERS and credentials from the operator or session. Do not encode either in tracked files.

## Verification

Run the deterministic gate before handing off changes:

    ./build/Invoke-KbUpdateQualityGate.ps1 -Bootstrap

Run local integration tests whenever the live catalog is reachable:

    ./build/Invoke-KbUpdateIntegration.ps1

If KBUPDATE_LAB_COMPUTERS is set and an in-memory credential is available, run the lab suite too. Prefer broad read-only inventory and needed-update scans. Actual installation requires one explicit target and KB through the runner's mutation parameters. The lab may be upgraded or reconfigured when the user authorizes it, but credentials, inventory, and environment-specific wrappers remain untracked.

After parser or web changes, also run a live read-only catalog probe against at least one legacy download.windowsupdate.com result and one delivery.mp.microsoft.com result. After remoting changes, use only read-only commands against the authorized lab unless the user explicitly authorizes mutation.

Keep GitHub Actions deterministic. Live catalog and lab tests belong in explicit integration jobs or local verification, not in the required unit-test gate.

