BeforeAll {
    . (Join-Path $PSScriptRoot '../../private/Get-Software.ps1')
}

Describe 'Get-Software package provider fallback' {
    BeforeEach {
        Mock Get-ChildItem
        Mock Get-PackageProvider { throw 'Unable to find package provider.' }
        Mock Get-Package
        Mock Get-Service { [pscustomobject]@{ StartType = 'Disabled' } }
        Mock Get-CimInstance
        Mock Get-ItemProperty {
            if ($Path -like '*CurrentVersion\Uninstall\*') {
                [pscustomobject]@{
                    DisplayName     = 'Contoso PowerShell Tool'
                    DisplayVersion  = '1.2.3'
                    Publisher       = 'Contoso'
                    UninstallString = 'uninstall.exe'
                }
                [pscustomobject]@{
                    DisplayName     = 'Fabrikam Utility'
                    DisplayVersion  = '4.5.6'
                    Publisher       = 'Fabrikam'
                    UninstallString = 'remove.exe'
                }
            }
        }
    }

    It 'uses uninstall registry entries when Windows package providers are unavailable' -Skip:($env:OS -ne 'Windows_NT') {
        $result = @(Get-Software -IncludeHidden:$false -VerbosePreference SilentlyContinue)

        $result.Name | Should -Contain 'Contoso PowerShell Tool'
        $result.Name | Should -Contain 'Fabrikam Utility'
        ($result | Where-Object Name -eq 'Contoso PowerShell Tool').ProviderName | Should -Be 'Programs'
        Should -Invoke Get-Package -Times 0 -Exactly
    }

    It 'filters registry fallback results by pattern' -Skip:($env:OS -ne 'Windows_NT') {
        $result = @(Get-Software -Pattern 'PowerShell' -IncludeHidden:$false -VerbosePreference SilentlyContinue)

        $result.Name | Should -Contain 'Contoso PowerShell Tool'
        $result.Name | Should -Not -Contain 'Fabrikam Utility'
        Should -Invoke Get-Package -Times 0 -Exactly
    }
}
