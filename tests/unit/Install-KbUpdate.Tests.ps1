BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Install-KbUpdate ShouldProcess safety' {
    InModuleScope kbupdate {
        BeforeEach {
            Mock Start-DscUpdate
            Mock Start-Job
        }

        It 'does not launch a background install under -WhatIf' {
            $null = Install-KbUpdate -ComputerName 'server.example.test' -HotfixId KB1234567 -WhatIf

            Should -Invoke Start-Job -Times 0 -Exactly
            Should -Invoke Start-DscUpdate -Times 0 -Exactly
        }

        It 'does not launch an inline install under -WhatIf -NoMultithreading' {
            $null = Install-KbUpdate -ComputerName 'server.example.test' -HotfixId KB1234567 -NoMultithreading -WhatIf

            Should -Invoke Start-DscUpdate -Times 0 -Exactly
            Should -Invoke Start-Job -Times 0 -Exactly
        }

        It 'launches a background install when confirmation is bypassed' -Skip:($env:OS -ne 'Windows_NT') {
            $null = Install-KbUpdate -ComputerName 'server.example.test' -HotfixId KB1234567 -Confirm:$false

            Should -Invoke Start-Job -Times 1 -Exactly
        }
    }
}
