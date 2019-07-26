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
            #$results.Hotfix            | Should -Be $true
            $results.Size              | Should -Be "462 KB"
            $results.UpdateId          | Should -Be "0c84df7a-e685-466c-a545-a24de5ad2601"
            $results.RebootBehavior    | Should -Be "Can request restart"
            $results.RequestsUserInput | Should -Be $false
            $results.ExclusiveInstall  | Should -Be $false
            $results.NetworkRequired   | Should -Be $false
            $results.UninstallNotes    | Should -Be "This software update can be removed via Add or Remove Programs in Control Panel."
            $results.UninstallSteps    | Should -Be $null
            $results.SupersededBy      | Should -Be $null
            $results.Supersedes        | Should -Be $null
            $results.LastModified      | Should -Be "10/14/2014"
            $results.Link              | Should -Be "http://download.windowsupdate.com/c/msdownload/update/software/secu/2014/10/aspnetwebfxupdate_kb2992080_55c239c6b443cb122b04667a9be948b03046bf88.exe"
        }
        It "returns correct 404 when found in the catalog" {
            $foundit = Get-KbUpdate -Name 4482972 3>&1 | Out-String
            $foundit | Should -Match "results no longer exist"
        }
        It "returns correct 404 when not found in the catalog" {
            $notfound = Get-KbUpdate -Name 4482972abc123 3>&1 | Out-String
            $notfound | Should -Match "No results found"
        }
        It "returns objects for Supersedes and SupersededBy" {
            $results = Get-KbUpdate -Name KB4505225
            $results.Title | Should -Be 'Security Update for SQL Server 2017 RTM CU (KB4505225)'
            $results.Supersedes.KB | Should -Be @(
                '4293805',
                '4058562',
                '4494352',
                '4038634',
                '4342123',
                '4462262',
                '4464082',
                '4466404',
                '4484710',
                '4498951',
                '4052574',
                '4052987',
                '4056498',
                '4092643',
                '4101464',
                '4229789',
                '4338363',
                '4341265'
            )
        }

        It "properly supports languages" {
            $results = Get-KbUpdate -Pattern KB968930 -Language Japanese -Architecture x86 -Simple
            $results.Count -eq 4
            $results.Link | Select-Object -Last 1 | Should -Match jpn

            $results = Get-KbUpdate -Pattern "KB2764916 Nederlands" -Simple
            $results.Title.Count -eq 1
            $results.Link | Should -Match nl
        }

        It "properly supports OS searches" {
            $results = Get-KbUpdate -Pattern KB968930 -Language Japanese -Architecture x86 -OperatingSystem 'Windows XP'
            $results.Count -eq 1
            $results.SupportedProducts -eq 'Windows XP'
        }

        It "properly supports product" {
            $results = Get-KbUpdate -Pattern KB2920730 -Product 'Office 2013' | Select-Object -First 1
            $results.SupportedProducts -eq 'Office 2013'

            $results = Get-KbUpdate -Pattern KB2920730 -Product 'Office 2020' | Select-Object -First 1
            $null -eq $results
        }

        It "grabs the latest" {
            $results = Get-KbUpdate -Pattern 2416447, 979906
            $results.Count | Should -Be 6
            $results = Get-KbUpdate -Pattern 2416447
            $results.Count | Should -Be 3
            $results = Get-KbUpdate -Pattern 979906
            $results.Count | Should -Be 3
            $results = Get-KbUpdate -Pattern 2416447, 979906 -Latest
            $results.Count  | Should -Be 3
        }

        It "does not overwrite links" {
            $results = Get-KbUpdate -Pattern "sql 2016 sp1" -Latest -Language Japanese
            $results.Link.Count | Should -Be 3
            "$($results.Link)" -match "jpn_"
            "$($results.Link)" -notmatch "kor_"

            $results = Get-KbUpdate -Pattern "sql 2016 sp1" -Latest
            $results.Link.Count | Should -BeGreaterThan 3
            "$($results.Link)" -match "jpn_"
            "$($results.Link)" -match "kor_"
        }

        if ($env:USERDOMAIN -eq "BASE") {
            It "returns the proper results for -ComputerName" {
                $results = Get-KbUpdate -Pattern KB4509475 -ComputerName sql2012
                $results.Title.Count -eq 1
                $results.SupportedProducts | Should -Be 'Windows Server 2016'
            }
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
            $piperesults = Get-KbUpdate -Name KB2992080 | Select-Object -First 1 | Save-KbUpdate -Path C:\temp
            $piperesults.Name -match 'aspnet'
        }
        It "does not overwrite" {
            $results = Get-KbUpdate -Name KB2992080 | Select-Object -First 1 | Save-KbUpdate -Path C:\temp
            $results.LastWriteTime -eq $piperesults.LastWriteTime
        }
        It "does overwrite" {
            $results = Get-KbUpdate -Name KB2992080 | Select-Object -First 1 | Save-KbUpdate -Path C:\temp -AllowClobber
            $results.LastWriteTime -ne $piperesults.LastWriteTime
            $results | Remove-Item -Confirm:$false
        }
    }
}