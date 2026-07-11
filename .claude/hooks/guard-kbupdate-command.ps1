[CmdletBinding()]
param()

$payload = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($payload)) {
    return
}

try {
    $hookInput = $payload | ConvertFrom-Json -ErrorAction Stop
} catch {
    return
}

$command = [string]$hookInput.tool_input.command
if ([string]::IsNullOrWhiteSpace($command)) {
    return
}

$kbMutation = '(?i)\b(Install-KbUpdate|Uninstall-KbUpdate)\b'
$fileMutation = '(?i)\b(Save-KbUpdate|Save-KbScanFile)\b'
$vmMutation = '(?i)\b(Remove-VM|Stop-VM|Checkpoint-VM|Restore-VMSnapshot|Restart-Computer|Stop-Computer)\b'
$hasWhatIf = $command -match '(?i)(?:^|\s)-WhatIf(?::\$(?:true|false))?(?:\s|$)'

if ($command -match $kbMutation -and -not $hasWhatIf -and $env:KBUPDATE_ALLOW_MUTATION -ne '1') {
    [Console]::Error.WriteLine('BLOCKED: Install-KbUpdate and Uninstall-KbUpdate require -WhatIf. Set KBUPDATE_ALLOW_MUTATION=1 only after the exact targets are authorized.')
    exit 2
}

if ($command -match $fileMutation -and -not $hasWhatIf -and $env:KBUPDATE_ALLOW_DOWNLOAD -ne '1') {
    [Console]::Error.WriteLine('BLOCKED: Save-KbUpdate and Save-KbScanFile require -WhatIf. Set KBUPDATE_ALLOW_DOWNLOAD=1 only for an authorized download test.')
    exit 2
}

if ($command -match $vmMutation -and $env:KBUPDATE_ALLOW_LAB_MUTATION -ne '1') {
    [Console]::Error.WriteLine('BLOCKED: VM or host mutation is outside the default test scope. Set KBUPDATE_ALLOW_LAB_MUTATION=1 only for an explicitly authorized lab operation.')
    exit 2
}

