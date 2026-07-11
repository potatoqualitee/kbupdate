BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'kbupdate proxy configuration' {
    InModuleScope kbupdate {
        It 'reports configuration without returning the credential object' {
            $credential = New-Object pscredential 'proxy-user', (ConvertTo-SecureString 'proxy-password' -AsPlainText -Force)
            Mock Get-PSFConfigValue {
                if ($FullName -eq 'kbupdate.app.proxy') {
                    return [uri]'http://proxy.contoso.com:8080'
                }
                if ($FullName -eq 'kbupdate.app.proxycredential') {
                    return $credential
                }
            }

            $result = Get-KbProxy

            $result.Mode | Should -Be 'Custom'
            $result.Proxy.AbsoluteUri | Should -Be 'http://proxy.contoso.com:8080/'
            $result.CredentialConfigured | Should -BeTrue
            $result.CredentialUserName | Should -Be 'proxy-user'
            $result.PSObject.Properties.Name | Should -Not -Contain 'ProxyCredential'
        }

        It 'stores a custom proxy and credential for the current session' {
            Mock Set-PSFConfig
            Mock Get-KbProxy { [pscustomobject]@{ Mode = 'Custom' } }
            $credential = New-Object pscredential 'proxy-user', (ConvertTo-SecureString 'proxy-password' -AsPlainText -Force)
            $proxy = [uri]'http://proxy.contoso.com:8080'

            $result = Set-KbProxy -Proxy $proxy -ProxyCredential $credential -Confirm:$false

            $result.Mode | Should -Be 'Custom'
            Should -Invoke Set-PSFConfig -Times 1 -Exactly -ParameterFilter {
                $FullName -eq 'kbupdate.app.proxy' -and $Value -eq $proxy
            }
            Should -Invoke Set-PSFConfig -Times 1 -Exactly -ParameterFilter {
                $FullName -eq 'kbupdate.app.proxycredential' -and $Value.UserName -eq 'proxy-user'
            }
        }

        It 'returns to automatic detection and clears the alternate credential' {
            Mock Set-PSFConfig
            Mock Get-KbProxy { [pscustomobject]@{ Mode = 'Automatic' } }

            $result = Set-KbProxy -AutoDetect -Confirm:$false

            $result.Mode | Should -Be 'Automatic'
            Should -Invoke Set-PSFConfig -Times 1 -Exactly -ParameterFilter {
                $FullName -eq 'kbupdate.app.proxy' -and $null -eq $Value
            }
            Should -Invoke Set-PSFConfig -Times 1 -Exactly -ParameterFilter {
                $FullName -eq 'kbupdate.app.proxycredential' -and $null -eq $Value
            }
        }

        It 'does not change configuration under WhatIf' {
            Mock Set-PSFConfig
            Mock Get-KbProxy

            $null = Set-KbProxy -AutoDetect -WhatIf

            Should -Invoke Set-PSFConfig -Times 0 -Exactly
            Should -Invoke Get-KbProxy -Times 0 -Exactly
        }
    }
}
