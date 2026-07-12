BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Repair-Date language-aware parsing (issue #167)' {
    InModuleScope kbupdate {
        Context 'US and database dates (no language)' {
            It 'normalizes a US M/d/yyyy catalog date' {
                Repair-Date -Date '7/8/2025' | Should -Be '2025-07-08'
            }

            It 'normalizes database-format dates with a two-digit day' {
                Repair-Date -Date '10/26/2016' | Should -Be '2016-10-26'
            }

            It 'returns null for empty input' {
                Repair-Date -Date $null | Should -BeNullOrEmpty
                Repair-Date -Date '' | Should -BeNullOrEmpty
            }

            It 'normalizes a real DateTime regardless of thread culture' {
                Repair-Date -Date ([datetime]'2020-01-15T09:30:00') | Should -Be '2020-01-15'
            }
        }

        Context 'Localized catalog dates match the requested language' {
            # The catalog returns 7/8/2025 (en-US), 08.07.2025 (de-DE) and 08/07/2025 (fr-FR)
            # for the very same update (8 July 2025), localized to the Accept-Language header.
            It 'parses a German dd.MM.yyyy date by language code' {
                Repair-Date -Date '08.07.2025' -Language 'de-DE' | Should -Be '2025-07-08'
            }

            It 'parses a French dd/MM/yyyy date without swapping month and day' {
                Repair-Date -Date '08/07/2025' -Language 'fr-FR' | Should -Be '2025-07-08'
            }

            It 'parses a German date whose day exceeds 12 (previously dropped)' {
                Repair-Date -Date '18.06.2019' -Language 'de' | Should -Be '2019-06-18'
            }

            It 'resolves a language display name to its culture' {
                Repair-Date -Date '18.06.2019' -Language 'German' | Should -Be '2019-06-18'
            }
        }

        Context 'Resilience' {
            It 'falls back to US parsing when a value is invalid for the language culture' {
                # 3/25/2019 is not a valid de-DE d/M/yyyy date (month 25), so it falls back to US M/d/yyyy
                Repair-Date -Date '3/25/2019' -Language 'de-DE' | Should -Be '2019-03-25'
            }

            It 'returns null for an unparseable value' {
                Repair-Date -Date 'not a date' -Language 'de-DE' | Should -BeNullOrEmpty
            }

            It 'falls back to en-US for an unknown language' {
                Repair-Date -Date '7/8/2025' -Language 'this-is-not-a-culture' | Should -Be '2025-07-08'
            }
        }
    }
}
