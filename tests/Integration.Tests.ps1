Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        if ($env:appveyor) {
            $env:psmodulepath = "$env:psmodulepath; C:\projects; C:\projects\kbupdate"
        }
    }

    Context "Get works" {
        It "returns correct detailed results" {
            $results = Get-KbUpdate -Name KB2992080
            $results.Id                | Should -Be 2992080
            $results.Language          | Should -Be "All"
            $results.Title             | Should -Be "Security Update for Microsoft ASP.NET MVC 5.0 (KB2992080)"
            $results.Description       | Should -Match 'A security issue \(MS14\-059\) has been identified in a Microsoft software product that could affect your system\. You can protect your system by'
            $results.Architecture      | Should -Be $null
            $results.Language          | Should -Be "All"
            $results.Classification    | Should -Be "Security Updates"
            $results.SupportedProducts | Should -Be "ASP.NET Web Frameworks"
            $results.MSRCNumber        | Should -Be "MS14-059"
            $results.MSRCSeverity      | Should -Be "Important"
            $results.Hotfix            | Should -Be "True"
            $results.Size              | Should -Be "462 KB"
            $results.UpdateId          | Should -Be "0c84df7a-e685-466c-a545-a24de5ad2601"
            $results.RebootBehavior    | Should -Be "Can request restart"
            $results.RequestsUserInput | Should -Be "No"
            $results.ExclusiveInstall  | Should -Be "No"
            $results.NetworkRequired   | Should -Be "No"
            $results.UninstallNotes    | Should -Be "This software update can be removed via Add or Remove Programs in Control Panel."
            $results.UninstallSteps    | Should -Be "n/a"
            $results.SupersededBy      | Should -Be "n/a"
            $results.Supersedes        | Should -Be "n/a"
            $results.LastModified      | Should -Be "10/14/2014"
            $results.Link              | Should -Be "http://download.windowsupdate.com/c/msdownload/update/software/secu/2014/10/aspnetwebfxupdate_kb2992080_55c239c6b443cb122b04667a9be948b03046bf88.exe"
        }
        It "returns correct 404 when found in the catalog" {
            $null = Get-KbUpdate -Name 4482972 -WarningVariable foundit 3>$null
            $foundit | Should -Match "KB4482972 was found but has been removed from the catalog"
        }
        It "returns correct 404 when not found in the catalog" {
            $null = Get-KbUpdate -Name 4482972abc123 -WarningVariable notfound 3>$null
            $notfound | Should -Match "No results found for"
        }
    }
    Context "Save works" {
        It "supports multiple saves" {
            $results = Save-KbUpdate -Path C:\temp -Name KB2992080, KB2994397
            $results[0].Name -match 'aspnet'
            $results | Remove-Item -Confirm:$false
        }
        It "downloads a small update" {
            $results = Save-KbUpdate -Name KB2992080 -Path C:\temp
            $results.Name -match 'aspnet'
            Get-ChildItem -Path $results.FullName | Should -Not -Be $null
            $results | Remove-Item -Confirm:$false
        }
        It "supports piping" {
            $results = Get-KbUpdate -Name KB2992080 | Select-Object -First 1 | Save-KbUpdate -Path C:\temp
            $results.Name -match 'aspnet'
            $results | Remove-Item -Confirm:$false
        }
    }
}