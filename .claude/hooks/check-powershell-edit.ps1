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

$filePath = [string]$hookInput.tool_input.file_path
if ([string]::IsNullOrWhiteSpace($filePath) -or [IO.Path]::GetExtension($filePath) -notin '.ps1', '.psm1', '.psd1') {
    return
}

if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
    return
}

$tokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    foreach ($parseError in $parseErrors) {
        [Console]::Error.WriteLine(('{0}:{1}: {2}' -f $filePath, $parseError.Extent.StartLineNumber, $parseError.Message))
    }
    exit 2
}

