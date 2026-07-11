BeforeAll {
    . (Join-Path $PSScriptRoot '../../public/Select-KbLatest.ps1')
}

Describe 'Select-KbLatest' {
    It 'preserves distinct catalog variants with the same KB and modified date' {
        $lastModified = [datetime]'2022-10-18'
        $updates = @(
            [pscustomobject]@{ Id = '5020435'; LastModified = $lastModified; UpdateId = '11111111-1111-1111-1111-111111111111'; Link = 'https://example.test/x64.msu'; Supersedes = @() }
            [pscustomobject]@{ Id = '5020435'; LastModified = $lastModified; UpdateId = '22222222-2222-2222-2222-222222222222'; Link = 'https://example.test/x86.msu'; Supersedes = @() }
            [pscustomobject]@{ Id = '5020435'; LastModified = $lastModified; UpdateId = '33333333-3333-3333-3333-333333333333'; Link = 'https://example.test/arm64.msu'; Supersedes = @() }
        )

        $result = @($updates | Select-KbLatest)

        $result.Count | Should -Be 3
        $result.UpdateId | Should -Be $updates.UpdateId
    }

    It 'preserves multiple download files for one catalog update' {
        $updateId = '11111111-1111-1111-1111-111111111111'
        $updates = @(
            [pscustomobject]@{ Id = '5020435'; LastModified = [datetime]'2022-10-18'; UpdateId = $updateId; Link = 'https://example.test/update.cab'; Supersedes = @() }
            [pscustomobject]@{ Id = '5020435'; LastModified = [datetime]'2022-10-18'; UpdateId = $updateId; Link = 'https://example.test/update.msu'; Supersedes = @() }
        )

        $result = @($updates | Select-KbLatest)

        $result.Count | Should -Be 2
        $result.Link | Should -Be $updates.Link
    }

    It 'removes a KB superseded by another KB in the batch' {
        $updates = @(
            [pscustomobject]@{ Id = '5000001'; LastModified = [datetime]'2022-09-01'; UpdateId = '11111111-1111-1111-1111-111111111111'; Link = 'https://example.test/old.msu'; Supersedes = @() }
            [pscustomobject]@{ Id = '5000002'; LastModified = [datetime]'2022-10-01'; UpdateId = '22222222-2222-2222-2222-222222222222'; Link = 'https://example.test/new.msu'; Supersedes = @([pscustomobject]@{ KB = '5000001' }) }
        )

        $result = @($updates | Select-KbLatest)

        $result.Count | Should -Be 1
        $result.Id | Should -Be '5000002'
    }
}
