BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Get-KbUpdate authenticated proxy handling' {
    InModuleScope kbupdate {
        It 'forwards a custom proxy and alternate credential to catalog requests' {
            $guid = '55555555-5555-5555-5555-555555555555'
            $content = @"
enTitle = 'Authenticated proxy update';
longLanguages = 'all';
updateID = '$guid';
isHotFix = false;
url = 'https://catalog.s.download.windowsupdate.com/test/proxy-catalog.msu';
"@
            Mock Invoke-TlsWebRequest {
                [pscustomobject]@{ Content = $content }
            }

            $credential = New-Object pscredential 'proxy-user', (ConvertTo-SecureString 'proxy-password' -AsPlainText -Force)
            $proxy = [uri]'http://proxy.contoso.com:8080'

            $result = @(Get-KbUpdate -Pattern $guid -Source Web -Simple -Proxy $proxy -ProxyCredential $credential -EnableException)

            $result.Count | Should -Be 1
            $result[0].Link | Should -Be 'https://catalog.s.download.windowsupdate.com/test/proxy-catalog.msu'
            Should -Invoke Invoke-TlsWebRequest -Times 1 -Exactly -ParameterFilter {
                $Proxy -eq $proxy -and $ProxyCredential.UserName -eq 'proxy-user'
            }
        }
    }
}
