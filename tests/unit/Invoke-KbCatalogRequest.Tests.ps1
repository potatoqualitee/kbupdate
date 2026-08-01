BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Invoke-KbCatalogRequest retry behavior' {
    InModuleScope kbupdate {
        BeforeEach {
            $script:attempt = 0
            $script:websession = $null
            $script:previouspage = $null
            Mock Start-Sleep
        }

        It 'returns a later successful response after two transient failures' {
            Mock Invoke-TlsWebRequest {
                $script:attempt++
                if ($script:attempt -lt 3) {
                    throw 'temporary connection failure'
                }
                [pscustomobject]@{ Content = 'complete detail response' }
            }

            $result = Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=test' -RetryCount 2

            $result.Content | Should -Be 'complete detail response'
            Should -Invoke Invoke-TlsWebRequest -Times 3 -Exactly
            Should -Invoke Start-Sleep -Times 2 -Exactly
            Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 1 }
            Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 2 }
        }

        It 'throws the final transient error after exhausting retries' {
            Mock Invoke-TlsWebRequest {
                $script:attempt++
                throw "temporary failure $script:attempt"
            }

            { Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=test' -RetryCount 2 } |
                Should -Throw -ExpectedMessage '*temporary failure 3*'

            Should -Invoke Invoke-TlsWebRequest -Times 3 -Exactly
            Should -Invoke Start-Sleep -Times 2 -Exactly
        }

        It 'makes one attempt when RetryCount is zero' {
            Mock Invoke-TlsWebRequest {
                $script:attempt++
                throw 'fail fast'
            }

            { Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=test' -RetryCount 0 } |
                Should -Throw -ExpectedMessage '*fail fast*'

            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }

        It 'retries an incomplete search response and returns a later complete response' {
            Mock Invoke-TlsWebRequest {
                $script:attempt++
                if ($script:attempt -eq 1) {
                    return [pscustomobject]@{
                        Content     = '<html><body>temporary gateway page</body></html>'
                        InputFields = @()
                        Links       = @()
                    }
                }
                [pscustomobject]@{
                    Content     = '<html><body>catalog results</body></html>'
                    InputFields = @(
                        [pscustomobject]@{ Type = 'Button'; Value = 'Download'; ID = 'result-1' }
                    )
                    Links       = @()
                }
            }

            $result = Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/Search.aspx?q=KB1234567' -RetryCount 2

            $result.InputFields.ID | Should -Be 'result-1'
            Should -Invoke Invoke-TlsWebRequest -Times 2 -Exactly
            Should -Invoke Start-Sleep -Times 1 -Exactly
        }

        It 'does not retry an explicit catalog no-results response' {
            Mock Invoke-TlsWebRequest {
                $script:attempt++
                [pscustomobject]@{
                    Content     = '<html><body>We did not find any results for "not-a-real-kb"</body></html>'
                    InputFields = @()
                    Links       = @()
                }
            }

            $result = Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/Search.aspx?q=not-a-real-kb' -RetryCount 2

            $result.Content | Should -Match 'did not find any results'
            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }

        It 'throws after every search response is incomplete' {
            Mock Invoke-TlsWebRequest {
                $script:attempt++
                [pscustomobject]@{
                    Content     = '<html><body>temporary gateway page</body></html>'
                    InputFields = @()
                    Links       = @()
                }
            }

            { Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/Search.aspx?q=KB1234567' -RetryCount 2 } |
                Should -Throw -ExpectedMessage '*incomplete*'

            Should -Invoke Invoke-TlsWebRequest -Times 3 -Exactly
            Should -Invoke Start-Sleep -Times 2 -Exactly
        }

        It 'does not retry a proxy authentication failure' {
            $script:proxyException = [System.Net.Http.HttpRequestException]::new(
                'proxy authentication required',
                $null,
                [System.Net.HttpStatusCode]::ProxyAuthenticationRequired
            )
            Mock Invoke-TlsWebRequest {
                $script:attempt++
                throw $script:proxyException
            }

            { Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/Search.aspx?q=KB1234567' -RetryCount 2 } |
                Should -Throw -ExpectedMessage '*proxy authentication required*'

            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }

        It 'retries an HTTP service-unavailable response' {
            $script:httpException = [System.Net.Http.HttpRequestException]::new(
                'service unavailable',
                $null,
                [System.Net.HttpStatusCode]::ServiceUnavailable
            )
            Mock Invoke-TlsWebRequest {
                $script:attempt++
                if ($script:attempt -eq 1) {
                    throw $script:httpException
                }
                [pscustomobject]@{ Content = 'service recovered' }
            }

            $result = Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=test' -RetryCount 2

            $result.Content | Should -Be 'service recovered'
            Should -Invoke Invoke-TlsWebRequest -Times 2 -Exactly
            Should -Invoke Start-Sleep -Times 1 -Exactly
        }

        It 'does not retry an HTTP not-found response' {
            $script:httpException = [System.Net.Http.HttpRequestException]::new(
                'not found',
                $null,
                [System.Net.HttpStatusCode]::NotFound
            )
            Mock Invoke-TlsWebRequest { throw $script:httpException }

            { Invoke-KbCatalogRequest -Uri 'https://support.microsoft.com/en-us/topic/missing' -RetryCount 2 } |
                Should -Throw -ExpectedMessage '*not found*'

            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }

        It 'forwards timeout and authenticated proxy settings to the shared request helper' {
            $credential = New-Object pscredential 'proxy-user', (ConvertTo-SecureString 'proxy-password' -AsPlainText -Force)
            $proxy = [uri]'http://proxy.contoso.com:8080'
            Mock Invoke-TlsWebRequest { [pscustomobject]@{ Content = 'forwarded' } }

            $result = Invoke-KbCatalogRequest -Uri 'https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=test' -TimeoutSec 7 -Proxy $proxy -ProxyCredential $credential -RetryCount 0

            $result.Content | Should -Be 'forwarded'
            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly -ParameterFilter {
                $TimeoutSec -eq 7 -and $Proxy -eq $proxy -and $ProxyCredential.UserName -eq 'proxy-user'
            }
        }
    }
}
