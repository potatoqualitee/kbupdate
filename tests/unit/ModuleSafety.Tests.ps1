BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'AI-safe command metadata' {
    It 'supports WhatIf for every file or machine mutator' {
        $commands = Get-Command Save-KbUpdate, Save-KbScanFile, Install-KbUpdate, Uninstall-KbUpdate

        foreach ($command in $commands) {
            $command.Parameters.Keys | Should -Contain 'WhatIf'
            $command.Parameters.Keys | Should -Contain 'Confirm'
        }
    }

    It 'exports every public function and no private helper' {
        $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $expected = Get-ChildItem (Join-Path $repositoryRoot 'public') -File -Filter '*.ps1' |
            Select-Object -ExpandProperty BaseName |
            Sort-Object
        $actual = Get-Command -Module kbupdate -CommandType Function |
            Where-Object Source -EQ 'kbupdate' |
            Select-Object -ExpandProperty Name |
            Sort-Object

        Compare-Object -ReferenceObject $expected -DifferenceObject $actual |
            Should -BeNullOrEmpty
    }

    It 'does not leak a remote credential into local background jobs' {
        $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $installCommand = Get-Content -LiteralPath (Join-Path $repositoryRoot 'public/Install-KbUpdate.ps1') -Raw

        $installCommand | Should -Not -Match '\$PSDefaultParameterValues\["\*:Credential"\]'
    }

    It 'reuses local cached sessions instead of querying remote sessions without credentials' {
        $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $dscWorker = Get-Content -LiteralPath (Join-Path $repositoryRoot 'private/Start-DscUpdate.ps1') -Raw

        $dscWorker | Should -Not -Match 'Get-PSSession\s+-ComputerName'
    }
}

