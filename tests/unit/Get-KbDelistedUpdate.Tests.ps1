BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Get-KbUpdate delisted source' {
    It 'returns every curated KB4503294 package from trusted Microsoft HTTPS hosts' {
        $result = @(Get-KbUpdate -Pattern KB4503294 -Source Delisted -Simple -EnableException)

        $result.Count | Should -Be 2
        $result.Architecture | Should -Contain 'x86'
        $result.Architecture | Should -Contain 'x64'
        $result.Source | Should -Contain 'Delisted'
        foreach ($link in $result.Link) {
            $link | Should -Match '^https://(?:[a-z0-9-]+\.)*download\.windowsupdate\.com/'
        }
    }

    It 'accepts a numeric KB identity and filters architecture' {
        $result = @(Get-KbUpdate -Pattern 4503294 -Source Delisted -Architecture x64 -Simple -EnableException)

        $result.Count | Should -Be 1
        $result[0].Architecture | Should -Be 'x64'
        $result[0].Link | Should -Match 'windows10.0-kb4503294-x64_'
    }
}

Describe 'Get-KbDelistedUpdate trust boundary' {
    InModuleScope kbupdate {
        It 'rejects curated data outside the trusted Microsoft host boundary' {
            $originalModuleRoot = $script:ModuleRoot
            $dataPath = Join-Path $TestDrive 'data'
            $null = New-Item -ItemType Directory -Path $dataPath
            @"
KBUpdate,Title,Architecture,LastModified,SupportedProducts,Size,SupportUrl,Link
KB4503294,Untrusted package,x64,2019-06-18,Windows Server 2016,1,https://support.microsoft.com/,https://example.test/update.msu
"@ | Set-Content -LiteralPath (Join-Path $dataPath 'delisted-updates.csv')

            try {
                $script:ModuleRoot = $TestDrive
                { Get-KbDelistedUpdate -Pattern KB4503294 } |
                    Should -Throw '*untrusted Microsoft download link*'
            } finally {
                $script:ModuleRoot = $originalModuleRoot
            }
        }
    }
}
