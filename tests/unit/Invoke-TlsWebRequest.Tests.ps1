BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Invoke-TlsWebRequest proxy handling' {
    InModuleScope kbupdate {
        BeforeEach {
            $script:MaxPages = 1
            $script:websession = $null
            $script:previouspage = $null
            Mock Get-ItemProperty { [pscustomobject]@{ ProxyServer = $null; ProxyEnable = 0 } }
            Mock Invoke-WebRequest { [pscustomobject]@{ Content = 'ok' } }
        }

        It 'passes a custom proxy and alternate credential to Invoke-WebRequest' {
            $credential = New-Object pscredential 'proxy-user', (ConvertTo-SecureString 'proxy-password' -AsPlainText -Force)
            $proxy = [uri]'http://proxy.contoso.com:8080'

            $result = Invoke-TlsWebRequest -Uri 'https://www.catalog.update.microsoft.com/' -Proxy $proxy -ProxyCredential $credential

            $result.Content | Should -Be 'ok'
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Proxy -eq $proxy -and $ProxyCredential.UserName -eq 'proxy-user'
            }
        }

        It 'uses default credentials with a custom proxy when none are supplied' {
            $proxy = [uri]'http://proxy.contoso.com:8080'

            $null = Invoke-TlsWebRequest -Uri 'https://www.catalog.update.microsoft.com/' -Proxy $proxy

            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Proxy -eq $proxy -and $ProxyUseDefaultCredentials
            }
        }

        It 'detects the system proxy when only an alternate credential is supplied' {
            $originalProxy = [Net.WebRequest]::DefaultWebProxy
            $proxy = [uri]'http://system-proxy.contoso.com:8080'
            $credential = New-Object pscredential 'proxy-user', (ConvertTo-SecureString 'proxy-password' -AsPlainText -Force)

            try {
                [Net.WebRequest]::DefaultWebProxy = New-Object Net.WebProxy $proxy
                $null = Invoke-TlsWebRequest -Uri 'https://www.catalog.update.microsoft.com/' -ProxyCredential $credential
            } finally {
                [Net.WebRequest]::DefaultWebProxy = $originalProxy
            }

            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Proxy -eq $proxy -and $ProxyCredential.UserName -eq 'proxy-user'
            }
        }

        It 'keeps multi-page catalog requests working after proxy parameter binding' {
            $script:MaxPages = 2
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    Content = 'ok'
                    InputFields = @(
                        [pscustomobject]@{ Name = '__VIEWSTATE'; Value = 'state' }
                        [pscustomobject]@{ Name = '__EVENTARGUMENT'; Value = 'argument' }
                        [pscustomobject]@{ Name = '__VIEWSTATEGENERATOR'; Value = 'generator' }
                        [pscustomobject]@{ Name = '__EVENTVALIDATION'; Value = 'validation' }
                    )
                }
            }

            $result = @(Invoke-TlsWebRequest -Uri 'https://www.catalog.update.microsoft.com/Search.aspx?q=test')

            $result.Count | Should -Be 2
            Should -Invoke Invoke-WebRequest -Times 2 -Exactly
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Body['__VIEWSTATE'] -eq 'state'
            }
        }
    }
}
