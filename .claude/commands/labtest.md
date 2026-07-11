---
description: Discover and run the disposable kbupdate Hyper-V lab
argument-hint: [probe|quick|scan]
---

Read `AGENTS.md` and use `build/Invoke-KbUpdateHyperVLab.ps1`.

Interpret `$ARGUMENTS` as follows:

- `probe`: run `./build/Invoke-KbUpdateHyperVLab.ps1 -ProbeOnly` and summarize availability.
- `quick`: run `./build/Invoke-KbUpdateHyperVLab.ps1 -UsePublicLabCredential` for catalog, WinRM, and installed-software inventory coverage.
- `scan`, an empty argument, or any unrecognized argument: run `./build/Invoke-KbUpdateHyperVLab.ps1 -UsePublicLabCredential -ScanNeededUpdates` for the complete read-only suite.

Do not print the credential in the response. Do not stop, restart, checkpoint, revert, rebuild, or remove a VM merely to run tests. Do not install or remove an update unless the user separately authorizes one exact guest and KB. Report passed, failed, and skipped counts plus any guest filtered out during authentication.
