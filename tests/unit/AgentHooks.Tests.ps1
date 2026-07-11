BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:guardPath = Join-Path $repositoryRoot '.claude/hooks/guard-kbupdate-command.ps1'
}

Describe 'AI command safety hook' {
    It 'blocks an unapproved update installation' {
        $payload = @{ tool_input = @{ command = 'Install-KbUpdate -ComputerName server01 -HotfixId KB1234567' } } | ConvertTo-Json -Compress
        $inputPath = Join-Path $TestDrive 'blocked-input.json'
        $errorPath = Join-Path $TestDrive 'blocked-error.txt'
        Set-Content -LiteralPath $inputPath -Value $payload
        $process = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList '-NoProfile', '-File', $script:guardPath -NoNewWindow -PassThru -RedirectStandardInput $inputPath -RedirectStandardError $errorPath
        $process.WaitForExit()

        $process.ExitCode | Should -Be 2
    }

    It 'allows a dry-run update installation' {
        $payload = @{ tool_input = @{ command = 'Install-KbUpdate -ComputerName server01 -HotfixId KB1234567 -WhatIf' } } | ConvertTo-Json -Compress
        $inputPath = Join-Path $TestDrive 'allowed-input.json'
        Set-Content -LiteralPath $inputPath -Value $payload
        $process = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList '-NoProfile', '-File', $script:guardPath -NoNewWindow -PassThru -RedirectStandardInput $inputPath
        $process.WaitForExit()

        $process.ExitCode | Should -Be 0
    }
}
