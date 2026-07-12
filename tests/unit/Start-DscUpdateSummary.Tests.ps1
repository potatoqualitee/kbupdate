BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Start-DscUpdate returns a summary for a successful install that DSC reports as an error (issue #161)' {
    InModuleScope kbupdate {
        It 'still emits a summary when the install threw an unrecognized message but the update is present' {
            $sqlcu = [pscustomobject]@{
                ComputerName = 'sql01'
                KBUpdate     = 'KB5016394'
                UpdateId     = 'aaaaaaaa-1111-2222-3333-444444444444'
                Title        = 'Cumulative Update 17 for SQL Server 2019 (KB5016394)'
                Link         = @('https://catalog.s.download.windowsupdate.com/d/sqlserver2019-kb5016394-x64_deadbeef.exe')
            }

            # Local, fully-mocked path so nothing real runs.
            Mock Import-Module { }
            Mock Invoke-KbCommand { 'C:\Users\test' }
            # The actual DSC install (only this call uses WarningVariable 'dscwarnings') throws a
            # message that is not one of the specially-handled ones -- as a SQL CU can.
            Mock Invoke-KbCommand -ParameterFilter { $WarningVariable -eq 'dscwarnings' } {
                throw 'The return code 3010 was not expected. Configuration of the additional properties may be needed.'
            }
            # ...but the update is in fact installed on the target.
            Mock Get-KbInstalledSoftware {
                [pscustomobject]@{ Title = 'Hotfix 5016394 for SQL Server 2019'; Summary = 'Installed' }
            }
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
                $file | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.FullName } -Force -PassThru
            }

            $savedDefaults = @{}
            foreach ($key in $PSDefaultParameterValues.Keys) { $savedDefaults[$key] = $PSDefaultParameterValues[$key] }
            try {
                $raw = @(Start-DscUpdate -ComputerName 'sql01' -IsLocalHost $true -HotfixId 'KB5016394' -InputObject @($sqlcu) -ModulePath @((Get-Module kbupdate).Path) -EnableException)
            } finally {
                $PSDefaultParameterValues.Clear()
                foreach ($key in $savedDefaults.Keys) { $PSDefaultParameterValues[$key] = $savedDefaults[$key] }
            }

            $summary = @($raw | Where-Object { $PSItem.PSObject.Properties.Name -contains 'Status' })

            $summary.Count | Should -Be 1
            $summary[0].Status | Should -Match 'Install successful'
            $summary[0].ID | Should -Be 'KB5016394'
            $summary[0].ComputerName | Should -Be 'sql01'
        }
    }
}
