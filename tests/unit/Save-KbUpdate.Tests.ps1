BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Save-KbUpdate download handling' {
    InModuleScope kbupdate {
        BeforeAll {
            function Get-BitsTransfer { }
        }

        BeforeEach {
            Mock Test-Path { $false }
            Mock Get-Command { [pscustomobject]@{ Name = 'Start-BitsTransfer' } }
            Mock Get-BitsTransfer { @() }
            Mock Start-BitsJobProcess
        }

        It 'queues every input link with its own filename and the update title' -Skip:($env:OS -ne 'Windows_NT') {
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

        It 'returns the downloaded file when BITS falls back to a web request' -Skip:($env:OS -ne 'Windows_NT') {
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

        It 'downloads the exact link from a serialized needed-update object without re-querying it' {
            Mock Get-Command { $null }
            Mock Get-KbUpdate
            Mock Invoke-TlsWebRequest

            $exactLink = 'https://catalog.s.download.windowsupdate.com/test/exact-offline-scan.cab'
            $update = [pscustomobject]@{
                Title      = 'Exact offline scan update'
                KBUpdate   = 'KB5048652'
                UpdateId   = 'abfafad8-5378-48df-a64f-deedc7de0f5a'
                Link       = $exactLink
            }
            $serialized = [Management.Automation.PSSerializer]::Serialize($update)
            $restored = [Management.Automation.PSSerializer]::Deserialize($serialized)

            $null = $restored | Save-KbUpdate -Path $TestDrive -Confirm:$false

            Should -Invoke Get-KbUpdate -Times 0 -Exactly
            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
        }

        It 'skips null links and continues downloading valid objects in the same pipeline' {
            Mock Get-Command { $null }
            Mock Get-KbUpdate
            Mock Invoke-TlsWebRequest
            Mock Write-PSFMessage

            $validLink = 'https://catalog.s.download.windowsupdate.com/test/valid-after-null.msu'
            $updates = @(
                [pscustomobject]@{
                    Title    = 'Missing link update'
                    KBUpdate = 'KB5000001'
                    UpdateId = '11111111-1111-1111-1111-111111111111'
                    Link     = $null
                }
                [pscustomobject]@{
                    Title    = 'Valid link update'
                    KBUpdate = 'KB5000002'
                    UpdateId = '22222222-2222-2222-2222-222222222222'
                    Link     = $validLink
                }
            )

            $null = $updates | Save-KbUpdate -Path $TestDrive -Confirm:$false

            Should -Invoke Get-KbUpdate -Times 0 -Exactly
            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
            Should -Invoke Write-PSFMessage -Times 1 -Exactly -ParameterFilter {
                $Message -match '11111111-1111-1111-1111-111111111111' -and
                    $Message -match 'Skipping'
            }
        }

        It 'still resolves an explicitly supplied pattern' {
            Mock Get-Command { $null }
            Mock Get-KbUpdate {
                [pscustomobject]@{
                    Title    = 'Explicit pattern update'
                    UpdateId = '33333333-3333-3333-3333-333333333333'
                    Link     = 'https://catalog.s.download.windowsupdate.com/test/explicit-pattern.msu'
                }
            }
            Mock Invoke-TlsWebRequest

            $null = Save-KbUpdate -Pattern KB5000003 -Path $TestDrive -Confirm:$false

            Should -Invoke Get-KbUpdate -Times 1 -Exactly -ParameterFilter {
                $Pattern -eq 'KB5000003'
            }
            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
        }

        It 'forwards a custom proxy and alternate credential to lookup and download' {
            Mock Get-Command { $null }
            Mock Get-KbUpdate {
                [pscustomobject]@{
                    Title    = 'Authenticated proxy update'
                    UpdateId = '44444444-4444-4444-4444-444444444444'
                    Link     = 'https://catalog.s.download.windowsupdate.com/test/proxy.msu'
                }
            }
            Mock Invoke-TlsWebRequest

            $credential = New-Object pscredential 'proxy-user', (ConvertTo-SecureString 'proxy-password' -AsPlainText -Force)
            $proxy = [uri]'http://proxy.contoso.com:8080'

            $null = Save-KbUpdate -Pattern KB5000004 -Path $TestDrive -Proxy $proxy -ProxyCredential $credential -Confirm:$false

            Should -Invoke Get-KbUpdate -Times 1 -Exactly -ParameterFilter {
                $Proxy -eq $proxy -and $ProxyCredential.UserName -eq 'proxy-user'
            }
            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly -ParameterFilter {
                $Proxy -eq $proxy -and $ProxyCredential.UserName -eq 'proxy-user'
            }
        }

        It 'forwards custom authenticated proxy settings to BITS' -Skip:($env:OS -ne 'Windows_NT') {
            Mock Start-BitsTransfer

            $credential = New-Object pscredential 'proxy-user', (ConvertTo-SecureString 'proxy-password' -AsPlainText -Force)
            $proxy = [uri]'http://proxy.contoso.com:8080'

            $null = Save-KbUpdate -Link 'https://catalog.s.download.windowsupdate.com/test/proxy-bits.msu' -Path 'C:\Temp\kbupdate-tests' -Proxy $proxy -ProxyCredential $credential -Confirm:$false

            Should -Invoke Start-BitsTransfer -Times 1 -Exactly -ParameterFilter {
                $ProxyUsage -eq 'Override' -and
                    $ProxyList -eq $proxy -and
                    $ProxyCredential.UserName -eq 'proxy-user'
            }
        }

        It 'uses preconfigured BITS proxy detection with an alternate credential' -Skip:($env:OS -ne 'Windows_NT') {
            Mock Start-BitsTransfer

            $credential = New-Object pscredential 'proxy-user', (ConvertTo-SecureString 'proxy-password' -AsPlainText -Force)

            $null = Save-KbUpdate -Link 'https://catalog.s.download.windowsupdate.com/test/auto-proxy-bits.msu' -Path 'C:\Temp\kbupdate-tests' -ProxyCredential $credential -Confirm:$false

            Should -Invoke Start-BitsTransfer -Times 1 -Exactly -ParameterFilter {
                $ProxyUsage -eq 'SystemDefault' -and
                    -not $ProxyList -and
                    $ProxyCredential.UserName -eq 'proxy-user'
            }
        }
    }
}
