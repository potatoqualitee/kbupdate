BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Save-KbUpdate download handling' {
    InModuleScope kbupdate {
        BeforeEach {
            Mock Test-Path { $false }
            Mock Get-Command { [pscustomobject]@{ Name = 'Start-BitsTransfer' } }
            Mock Get-BitsTransfer { @() }
            Mock Start-BitsJobProcess
        }

        It 'queues every input link with its own filename and the update title' {
            Mock Start-BitsTransfer

            $update = [pscustomobject]@{
                Title = 'Test cumulative update'
                Link  = @(
                    'https://catalog.s.download.windowsupdate.com/test/update-one.msu'
                    'https://catalog.s.download.windowsupdate.com/test/update-two.msu'
                )
            }

            $null = $update | Save-KbUpdate -Path 'C:\Temp\kbupdate-tests' -Confirm:$false

            Should -Invoke Start-BitsTransfer -Times 2 -Exactly
            Should -Invoke Start-BitsTransfer -Times 1 -Exactly -ParameterFilter {
                (Split-Path -Path $Destination -Leaf) -eq 'update-one.msu'
            }
            Should -Invoke Start-BitsTransfer -Times 1 -Exactly -ParameterFilter {
                (Split-Path -Path $Destination -Leaf) -eq 'update-two.msu'
            }
            Should -Invoke Start-BitsTransfer -Times 2 -Exactly -ParameterFilter {
                $Description -eq 'kbupdate - Test cumulative update'
            }
        }

        It 'returns the downloaded file when BITS falls back to a web request' {
            Mock Start-BitsTransfer { throw 'BITS failed' }
            Mock Invoke-TlsWebRequest
            Mock Get-ChildItem {
                [pscustomobject]@{ FullName = $Path }
            }

            $parameters = @{
                Link    = 'https://catalog.s.download.windowsupdate.com/test/fallback.msu'
                Path    = 'C:\Temp\kbupdate-tests'
                Confirm = $false
            }
            $result = @(Save-KbUpdate @parameters)

            $result.Count | Should -Be 1
            $result[0].FullName | Should -Be 'C:\Temp\kbupdate-tests\fallback.msu'
            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
            Should -Invoke Get-ChildItem -Times 1 -Exactly -ParameterFilter {
                $Path -eq 'C:\Temp\kbupdate-tests\fallback.msu'
            }
        }
    }
}
