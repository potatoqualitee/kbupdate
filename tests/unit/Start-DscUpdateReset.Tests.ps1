BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Start-DscUpdate resets per-update state across a batch (issue #203)' {
    InModuleScope kbupdate {
        It 'installs each update''s own file and id instead of repeating the first' {
            $u1 = [pscustomobject]@{
                ComputerName = 'wks'
                KBUpdate     = 'KB1111111'
                UpdateId     = '11111111-1111-1111-1111-111111111111'
                Title        = 'Security Update One'
                Link         = @('https://catalog.s.download.windowsupdate.com/d/updateone_aaaa.exe')
            }
            $u2 = [pscustomobject]@{
                ComputerName = 'wks'
                KBUpdate     = 'KB2222222'
                UpdateId     = '22222222-2222-2222-2222-222222222222'
                Title        = 'Security Update Two'
                Link         = @('https://catalog.s.download.windowsupdate.com/d/updatetwo_bbbb.exe')
            }

            # Keep everything on the local, no-network path so no real remoting/DSC/download runs.
            # Import-Module is a no-op so Start-DscUpdate's job-context re-import does not re-run the
            # module's initialization (which would rewrite PSFramework source config for later tests).
            Mock Import-Module { }
            Mock Invoke-KbCommand { 'C:\Users\test' }
            Mock Get-KbInstalledSoftware { }
            Mock Save-KbUpdate { }
            Mock Copy-Item { }
            Mock New-Item { }
            Mock Write-Progress { }
            Mock Test-Path { $true }
            Mock Get-ChildItem {
                param($Path)
                $leaf = Split-Path -Path "$Path" -Leaf
                $file = [pscustomobject]@{
                    Name        = $leaf
                    FullName    = "$Path"
                    BaseName    = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
                    VersionInfo = [pscustomobject]@{ ProductName = $leaf }
                }
                # a real FileInfo stringifies to its path; the code relies on that (e.g. Split-Path -Leaf $updatefile)
                $file | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.FullName } -Force -PassThru
            }

            $computer = [pscustomobject]@{ ComputerName = 'wks'; IsLocalHost = $true }

            # Start-DscUpdate normally runs in an isolated job; called inline it mutates the shared
            # $PSDefaultParameterValues (EnableException, Invoke-KbCommand:*). Snapshot and restore so
            # this test does not leak defaults into later test files.
            $savedDefaults = @{}
            foreach ($key in $PSDefaultParameterValues.Keys) { $savedDefaults[$key] = $PSDefaultParameterValues[$key] }
            try {
                $raw = @(Start-DscUpdate -ComputerName $computer -IsLocalHost $true -InputObject @($u1, $u2) -ModulePath @((Get-Module kbupdate).Path) -EnableException)
            } finally {
                $PSDefaultParameterValues.Clear()
                foreach ($key in $savedDefaults.Keys) { $PSDefaultParameterValues[$key] = $savedDefaults[$key] }
            }
            # Start-DscUpdate emits its install-summary objects (which carry a Status); ignore any
            # incidental values that leak from uncaptured internal helper calls under mocking.
            $result = @($raw | Where-Object { $PSItem.PSObject.Properties.Name -contains 'Status' })

            $result.Count | Should -Be 2
            (@($result.FileName) | Sort-Object -Unique).Count | Should -Be 2
            $result.FileName | Should -Contain 'updateone_aaaa.exe'
            $result.FileName | Should -Contain 'updatetwo_bbbb.exe'
            (@($result.ID) | Sort-Object -Unique).Count | Should -Be 2
        }
    }
}
