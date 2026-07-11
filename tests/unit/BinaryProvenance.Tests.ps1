Describe 'Vendored binary provenance' {
    It 'matches the tracked SHA-256 manifest' {
        $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $verificationScript = Join-Path $repositoryRoot 'build/Test-KbUpdateBinaryProvenance.ps1'

        { & $verificationScript } | Should -Not -Throw
    }
}
