BeforeDiscovery {
    $context = $global:KbUpdateIntegrationContext
}

BeforeAll {
    $context = $global:KbUpdateIntegrationContext
    Import-Module (Join-Path $context.RepositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Explicit authorized lab update installation' -Tag 'Integration', 'Lab', 'Mutation' -Skip:(-not $context.AllowMutation) {
    It 'downloads, installs, and verifies the one explicitly authorized KB' {
        $targetPath = Join-Path $context.DownloadPath 'mutation'
        $null = New-Item -ItemType Directory -Path $targetPath -Force
        $needed = @(
            Get-KbNeededUpdate -ComputerName $context.MutationComputerName -Credential $context.Credential -EnableException |
                Where-Object KBUpdate -EQ $context.MutationKb
        )
        if ($needed.Count -eq 0) {
            $installed = @(
                Get-KbInstalledSoftware -ComputerName $context.MutationComputerName -Credential $context.Credential -Pattern $context.MutationKb -EnableException
            )
            if ($installed.Count -eq 0) {
                throw "$($context.MutationKb) is neither installed nor currently needed on $($context.MutationComputerName)."
            }
            $installed.Count | Should -BeGreaterThan 0
            return
        }

        $updateFiles = @(
            $needed | Save-KbUpdate -Path $targetPath -AllowClobber -Confirm:$false -EnableException
        )
        $updateFiles.Count | Should -BeGreaterThan 0

        $installErrors = @()
        foreach ($updateFile in $updateFiles) {
            Install-KbUpdate -ComputerName $context.MutationComputerName -Credential $context.Credential -FilePath $updateFile.FullName -Confirm:$false -EnableException -ErrorVariable +installErrors
        }
        $installErrors | Should -BeNullOrEmpty

        $scanErrors = @()
        $stillNeeded = @(
            Get-KbNeededUpdate -ComputerName $context.MutationComputerName -Credential $context.Credential -EnableException -ErrorVariable +scanErrors |
                Where-Object KBUpdate -EQ $context.MutationKb
        )
        $scanErrors | Should -BeNullOrEmpty
        $stillNeeded | Should -BeNullOrEmpty
    }
}
