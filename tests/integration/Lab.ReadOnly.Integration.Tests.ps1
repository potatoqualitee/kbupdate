BeforeDiscovery {
    $context = $global:KbUpdateIntegrationContext
    $labCases = @(
        foreach ($computer in $context.ComputerName) {
            @{ ComputerName = $computer }
        }
    )
}

BeforeAll {
    $context = $global:KbUpdateIntegrationContext
    Import-Module (Join-Path $context.RepositoryRoot 'kbupdate.psd1') -Force -ErrorAction Stop
}

Describe 'Authorized Windows lab read-only coverage' -Tag 'Integration', 'Lab' -Skip:($context.ComputerName.Count -eq 0) {
    It 'accepts PowerShell remoting on <ComputerName>' -ForEach $labCases {
        $result = Test-WSMan -ComputerName $ComputerName -Credential $context.Credential -Authentication Negotiate -ErrorAction Stop

        $result.ProductVersion | Should -Not -BeNullOrEmpty
    }

    It 'inventories installed software on <ComputerName>' -ForEach $labCases {
        $result = @(Get-KbInstalledSoftware -ComputerName $ComputerName -Credential $context.Credential -EnableException)

        $result.Count | Should -BeGreaterThan 0
        $result.Name | Should -Not -BeNullOrEmpty
    }

    It 'scans needed updates on <ComputerName> when requested' -ForEach $labCases -Skip:(-not $context.ScanNeededUpdates) {
        $parameters = @{
            ComputerName    = $ComputerName
            Credential      = $context.Credential
            EnableException = $true
        }
        if ($context.ScanFilePath) {
            $parameters.ScanFilePath = $context.ScanFilePath
        }

        $result = @(Get-KbNeededUpdate @parameters)

        $result | Should -Not -BeNull
        $missingLinks = @(
            $result | Where-Object { $PSItem.KBUpdate -and -not $PSItem.Link }
        )
        $missingLinks | Should -BeNullOrEmpty
    }
}

