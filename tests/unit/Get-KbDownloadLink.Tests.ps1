BeforeAll {
    . (Join-Path $PSScriptRoot '../../private/Get-KbDownloadLink.ps1')
}

Describe 'Get-KbDownloadLink' {
    It 'extracts both Microsoft catalog delivery host formats' {
        $content = @'
url = 'https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/test/legacy.msu';
url = 'https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/abc/public/current.msu';
'@

        $result = @(Get-KbDownloadLink -Content $content)

        $result.Count | Should -Be 2
        $result[0] | Should -Be 'https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/test/legacy.msu'
        $result[1] | Should -Be 'https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/abc/public/current.msu'
    }

    It 'normalizes legacy insecure and www links' {
        $content = "url = 'http://www.download.windowsupdate.com/test/update.cab';"

        Get-KbDownloadLink -Content $content |
            Should -Be 'https://catalog.s.download.windowsupdate.com/test/update.cab'
    }

    It 'decodes HTML entities and removes duplicates' {
        $url = 'https://catalog.s.download.windowsupdate.com/test/update.cab?one=1&amp;two=2'
        $content = "url = '$url'; duplicate = '$url';"

        $result = @(Get-KbDownloadLink -Content $content)

        $result.Count | Should -Be 1
        $result[0] | Should -Be 'https://catalog.s.download.windowsupdate.com/test/update.cab?one=1&two=2'
    }

    It 'ignores lookalike and unrelated hosts' {
        $content = @'
url = 'https://download.windowsupdate.com.evil.example/update.msu';
url = 'https://example.com/update.msu';
'@

        @(Get-KbDownloadLink -Content $content).Count | Should -Be 0
    }
}

