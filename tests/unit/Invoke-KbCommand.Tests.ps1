BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Invoke-KbCommand remoting' {
    InModuleScope kbupdate {
        BeforeEach {
            $securePassword = ConvertTo-SecureString 'unit-test-only' -AsPlainText -Force
            $script:testCredential = [pscredential]::new('TEST\User', $securePassword)
            Mock Get-PSSession
            Mock New-PSSession {
                throw 'stop after parameter capture'
            }
            Mock Invoke-PSFCommand
            Mock Get-PSFConfigValue {
                if ($FullName -eq 'PSRemoting.Sessions.Enable' -or $Name -eq 'PSRemoting.Sessions.Enable') {
                    return $true
                }
                return $false
            }
        }

        It 'passes an explicit credential when creating a cached session' -Skip:($env:OS -ne 'Windows_NT') {
            { Invoke-KbCommand -ComputerName 'server.example.test' -Credential $script:testCredential -ScriptBlock { 'test' } -EnableException } |
                Should -Throw

            Should -Invoke New-PSSession -Times 1 -ParameterFilter {
                $Credential.UserName -eq 'TEST\User'
            }
        }
    }
}
