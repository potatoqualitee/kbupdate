BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Select-KbDatabaseUpdate catch-up selection' {
    InModuleScope kbupdate {
        It 'includes missing updates regardless of age and refreshes recent known updates' {
            $cutoff = [datetime]'2026-04-01'
            $updates = @(
                [pscustomobject]@{
                    UpdateId     = 'missing-old'
                    CreationDate = '2024-01-01'
                }
                [pscustomobject]@{
                    UpdateId     = 'known-recent'
                    CreationDate = '2026-06-01'
                }
                [pscustomobject]@{
                    UpdateId     = 'known-old'
                    CreationDate = '2024-01-01'
                }
            )

            $result = @(
                $updates |
                    Select-KbDatabaseUpdate -KnownUpdateId 'known-recent', 'known-old' -RecentSince $cutoff
            )

            $result.UpdateId | Should -Contain 'missing-old'
            $result.UpdateId | Should -Contain 'known-recent'
            $result.UpdateId | Should -Not -Contain 'known-old'
            $result.Count | Should -Be 2
        }

        It 'includes a known update whose creation date cannot be parsed' {
            Mock Write-PSFMessage { }
            $update = [pscustomobject]@{
                UpdateId     = 'known-invalid-date'
                CreationDate = 'not-a-date'
            }

            $result = @(
                $update |
                    Select-KbDatabaseUpdate -KnownUpdateId 'known-invalid-date' -RecentSince ([datetime]'2026-04-01')
            )

            $result.UpdateId | Should -Be 'known-invalid-date'
        }
    }
}
