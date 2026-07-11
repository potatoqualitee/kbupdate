BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Test-KbSqliteSupport native provider probe' {
    InModuleScope kbupdate {
        BeforeEach {
            $script:sqlitesupport = $null
        }

        It 'reports support when the native SQLite provider loads' {
            Mock Invoke-SqliteQuery { [pscustomobject]@{ Probe = 1 } }

            Test-KbSqliteSupport | Should -BeTrue
        }

        It 'reports no support when the native SQLite provider cannot be loaded' {
            Mock Invoke-SqliteQuery {
                throw 'An attempt was made to load a program with an incorrect format. (Exception from HRESULT: 0x8007000B)'
            }

            Test-KbSqliteSupport | Should -BeFalse
        }

        It 'probes only once and caches the result for the session' {
            Mock Invoke-SqliteQuery { [pscustomobject]@{ Probe = 1 } }

            $null = Test-KbSqliteSupport
            $null = Test-KbSqliteSupport

            Should -Invoke Invoke-SqliteQuery -Times 1 -Exactly
        }
    }
}

Describe 'Get-KbUpdate graceful degradation without native SQLite (issue #230)' {
    InModuleScope kbupdate {
        BeforeEach {
            $script:sqlitesupport = $null
            $global:kbupdate = $null
            # Isolate from catalog results cached by other test files in the same session
            $script:kbcollection = [hashtable]::Synchronized(@{ })
        }

        It 'gives actionable guidance instead of the raw provider error for a database-only query' {
            Mock Invoke-SqliteQuery {
                throw 'An attempt was made to load a program with an incorrect format. (Exception from HRESULT: 0x8007000B)'
            }

            { Get-KbUpdate -Pattern KB5033372 -Source Database -EnableException } |
                Should -Throw '*x64 or x86 Windows PowerShell*'
        }

        It 'still returns web results when the local database is unavailable' {
            $guid = 'a2300001-0230-0230-0230-000000000230'
            $content = @"
enTitle = 'ARM64 web fallback update';
longLanguages = 'all';
updateID = '$guid';
isHotFix = false;
url = 'https://catalog.s.download.windowsupdate.com/test/arm64-fallback.msu';
"@
            Mock Invoke-TlsWebRequest { [pscustomobject]@{ Content = $content } }
            Mock Invoke-SqliteQuery {
                throw 'An attempt was made to load a program with an incorrect format. (Exception from HRESULT: 0x8007000B)'
            }

            $result = @(Get-KbUpdate -Pattern $guid -Source Web -Simple -EnableException)

            $result.Count | Should -Be 1
            $result[0].Link | Should -Be 'https://catalog.s.download.windowsupdate.com/test/arm64-fallback.msu'
        }

        It 'drops the database source but continues with the web source when both are requested' {
            $guid = 'a2300002-0230-0230-0230-000000000230'
            $content = @"
enTitle = 'ARM64 combined source update';
longLanguages = 'all';
updateID = '$guid';
isHotFix = false;
url = 'https://catalog.s.download.windowsupdate.com/test/arm64-combined.msu';
"@
            Mock Invoke-TlsWebRequest { [pscustomobject]@{ Content = $content } }
            Mock Invoke-SqliteQuery {
                throw 'An attempt was made to load a program with an incorrect format. (Exception from HRESULT: 0x8007000B)'
            }

            $result = @(Get-KbUpdate -Pattern $guid -Source Web, Database -Simple -EnableException)

            $result.Count | Should -Be 1
            $result[0].Link | Should -Be 'https://catalog.s.download.windowsupdate.com/test/arm64-combined.msu'
        }
    }
}
