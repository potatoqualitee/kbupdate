# Vendored binary provenance

kbupdate vendors a small set of third-party binaries so that update discovery and installation can work on systems where the corresponding SDKs are not installed. The tracked `binary-hashes.sha256` file records every DLL under `library/` and is verified by the deterministic test suite.

The hashes prove that a checkout contains the same bytes reviewed in this repository. They do not, by themselves, prove who originally produced an unsigned file. Review the source and signature information below before approving the module for a privileged environment.

## Deployment Tools Foundation

`Microsoft.Deployment.Compression.dll` and `Microsoft.Deployment.Compression.Cab.dll` are Deployment Tools Foundation assemblies from WiX Toolset 3.11.2 (file version 3.11.2.4516). Their managed assembly names use Microsoft public key token `ce35f76fcda82bad`. They are not Authenticode-signed.

- Upstream project: https://github.com/wixtoolset/wix3
- WiX Toolset releases: https://github.com/wixtoolset/wix3/releases

kbupdate uses these assemblies to inspect CAB-based update packages.

## PoshWSUS and WSUS assemblies

`library/PoshWSUS/2.3.1.6` is the PoshWSUS 2.3.1.6 module distribution. Its `Libraries/x86` and `Libraries/x64` directories contain Microsoft WSUS 3.0 administration assemblies and `SusNativeCommon.dll`. The managed Microsoft assemblies use public key token `31bf3856ad364e35`. The files in this vendored distribution are not Authenticode-signed.

- PoshWSUS package: https://www.powershellgallery.com/packages/PoshWSUS/2.3.1.6
- PoshWSUS source: https://github.com/proxb/PoshWSUS
- Microsoft WSUS administration API: https://learn.microsoft.com/previous-versions/windows/desktop/aa970757(v=vs.85)

The x86 and x64 managed assemblies are byte-identical. The two native `SusNativeCommon.dll` files are architecture-specific and therefore have different hashes.

## Verification

From the repository root, run:

```powershell
./build/Test-KbUpdateBinaryProvenance.ps1
```

The command fails when a DLL is missing, an untracked DLL is present, or a SHA-256 value differs from the reviewed manifest. Run the full deterministic gate before publishing changes:

```powershell
./build/Invoke-KbUpdateQualityGate.ps1 -Bootstrap
```

When intentionally updating a binary, obtain it from the documented upstream source, review its version and signature, update `binary-hashes.sha256` in the same pull request, and explain the provenance change in the pull request description.
