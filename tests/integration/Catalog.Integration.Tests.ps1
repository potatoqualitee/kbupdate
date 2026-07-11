BeforeDiscovery {
    $context = $global:KbUpdateIntegrationContext
}

BeforeAll {
    $context = $global:KbUpdateIntegrationContext
    Import-Module (Join-Path $context.RepositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Live Microsoft Update Catalog' -Tag 'Integration', 'Catalog' {
    It 'parses a legacy Windows Update download host result' {
        $result = @(Get-KbUpdate -Name KB2992080 -Source Web -Simple -EnableException)

        $result.Count | Should -BeGreaterThan 0
        $result.Link | Should -Not -BeNullOrEmpty
        @($result.Link | Where-Object { $PSItem -match '^https://(?:[a-z0-9-]+\.)*download\.windowsupdate\.com/' }).Count |
            Should -BeGreaterThan 0
    }

    It 'parses modern Microsoft delivery host results with every package link' {
        $result = @(Get-KbUpdate -Name KB5065426 -Source Web -Simple -Force -EnableException)

        $result.Count | Should -BeGreaterThan 0
        $links = @($result.Link | Where-Object { $PSItem })
        $links.Count | Should -BeGreaterThan 1
        $links | Should -Not -Contain $null
        @($links | Where-Object { $PSItem -match '^https://catalog\.sf\.dl\.delivery\.mp\.microsoft\.com/' }).Count |
            Should -Be $links.Count
    }

    It 'returns results for current Windows Server catalog regressions' -ForEach @(
        @{ Kb = 'KB5064401' }
        @{ Kb = 'KB5065425' }
        @{ Kb = 'KB5065426' }
    ) {
        $result = @(Get-KbUpdate -Name $Kb -Source Web -Simple -Force -EnableException)

        $result.Count | Should -BeGreaterThan 0
        $result.Link | Should -Not -BeNullOrEmpty
    }

    It 'keeps Save-KbUpdate side-effect free under WhatIf' {
        $targetPath = Join-Path $context.DownloadPath 'whatif'
        $null = New-Item -ItemType Directory -Path $targetPath -Force
        $link = 'https://catalog.s.download.windowsupdate.com/test/whatif-fixture.msu'

        Save-KbUpdate -Link $link -Path $targetPath -WhatIf

        Get-ChildItem -LiteralPath $targetPath -File | Should -BeNullOrEmpty
    }

    It 'downloads and returns a small package fixture when requested' -Skip:(-not $context.IncludeDownloads) {
        $targetPath = Join-Path $context.DownloadPath 'fixture'
        $null = New-Item -ItemType Directory -Path $targetPath -Force
        $result = @(Save-KbUpdate -Name KB2992080 -Path $targetPath -AllowClobber -Confirm:$false -EnableException)

        $result.Count | Should -BeGreaterThan 0
        foreach ($file in $result) {
            $file.Exists | Should -BeTrue
            $file.Length | Should -BeGreaterThan 0
        }
    }
}

