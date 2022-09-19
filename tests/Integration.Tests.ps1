Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        if ($env:appveyor) {
            $env:psmodulepath = "$env:psmodulepath; C:\projects; C:\projects\kbupdate"
        }
    }

    Context "Get-KbUpdate works" {
        It "returns correct detailed results" {
            $results = Get-KbUpdate -Name KB2992080
            $results.Id | Should -Be 2992080
            $results.Language | Should -Be "All"
            $results.Title | Should -Be "Security Update for Microsoft ASP.NET MVC 5.0 (KB2992080)"
            $results.Description | Should -Match 'A security issue \(MS14\-059\) has been identified in a Microsoft software product that could affect your system\. You can protect your system by'
            $results.Architecture | Should -Be $null
            $results.Language | Should -Be "All"
            $results.Classification | Should -Be "Security Updates"
            $results.SupportedProducts | Should -Be "ASP.NET Web Frameworks"
            $results.MSRCNumber | Should -Be "MS14-059"
            $results.MSRCSeverity | Should -Be "Important"
            #$results.Hotfix            | Should -Be $true
            $results.Size | Should -Be "462 KB"
            $results.UpdateId | Should -Be "0c84df7a-e685-466c-a545-a24de5ad2601"
            $results.RebootBehavior | Should -Be "Can request restart"
            $results.RequestsUserInput | Should -Be $false
            $results.ExclusiveInstall | Should -Be $false
            $results.NetworkRequired | Should -Be $false
            $results.UninstallNotes | Should -Be "This software update can be removed via Add or Remove Programs in Control Panel."
            $results.UninstallSteps | Should -Be $null
            $results.SupersededBy | Should -Be $null
            $results.Supersedes | Should -Be $null
            $results.LastModified | Should -Be "2014-10-14"
            $results.Link | Should -Be "https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/secu/2014/10/aspnetwebfxupdate_kb2992080_55c239c6b443cb122b04667a9be948b03046bf88.exe"
        }

        It "finds results in the database" {
            $results = Get-KbUpdate -Name e86b7a53-d7b2-42af-b960-d165391b0fe3 -Source Database
            $results.UpdateId | Should -eq 'e86b7a53-d7b2-42af-b960-d165391b0fe3'
            $results = Get-KbUpdate -Name 0c84df7a-e685-466c-a545-a24de5ad2601 -Source Database
            $results.UpdateId | Should -eq '0c84df7a-e685-466c-a545-a24de5ad2601'
        }

        It "returns correct 404 when found in the catalog" {
            $foundit = Get-KbUpdate -Name 4482972 3>&1 | Out-String
            $foundit | Should -Match "results no longer exist"
        }
        It "returns objects for Supersedes and SupersededBy" {
            $results = Get-KbUpdate -Name KB4505225
            $results.Title | Should -Be 'Security Update for SQL Server 2017 RTM CU (KB4505225)'
            $results.Supersedes.KB | Sort-Object | Should -Be @(
                4038634,
                4052574,
                4052987,
                4056498,
                4058562,
                4092643,
                4101464,
                4229789,
                4293805,
                4338363,
                4341265,
                4342123,
                4462262,
                4464082,
                4466404,
                4484710,
                4494352,
                4498951
            )
        }

        It "properly supports languages" {
            $results = Get-KbUpdate -Pattern KB968930 -Language Japanese -Architecture x86 -Simple
            $results.Count -eq 5
            $results.Link | Select-Object -Last 1 | Should -Match jpn

            $results = Get-KbUpdate -Pattern "KB2764916 Nederlands" -Simple
            $results.Title.Count -eq 1
            $results.Link | Should -Match nl
        }

        It "properly supports OS searches" {
            $results = Get-KbUpdate -Pattern KB968930 -Architecture x86 -OperatingSystem 'Windows XP'
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
            $results.Count | Should -Be 3
        }

        It -Skip "does not overwrite links" {
            $results = Get-KbUpdate -Pattern "sql 2016 sp1" -Latest -Language Japanese -Source Web
            $results.Link.Count | Should -Be 6
            "$($results.Link)" -match "jpn_"
            "$($results.Link)" -notmatch "kor_"
        }

        It "Calls with specific language" {
            $results = Get-KbUpdate -Name KB5003279 -Language ja
            $results.Classification -match 'Service Packs'
            $results.Link -match '-jpn_'
        }
        # microsoft's CDN appears to be having massive issues and sometimes this does not appear
        It "x64 should work when AMD64 is used (#52)" {
            $results = Get-KbUpdate 2864dff9-d197-48b8-82e3-f36ad242928d -Architecture x64 -Source Web
            $results.Architecture | Should -BeIn "AMD64", "x64"
        }


        # microsoft's CDN appears to be having massive issues and sometimes this does not appear
        # Langauges are now supported via headers
        It "should find langauge in langauge (#50)" {
            $results = Get-KbUpdate 40B42C1B-086F-4E4A-B020-000ABCDC89C7 -Source Web -Language Slovenian -WarningAction SilentlyContinue
            $results.Language | Should -match "Slovenian"
        }

        # CDN is too flakey right now
        It -Skip "web and database results match" {
            $db = Get-KbUpdate -Pattern 4057113 -Source Database | Select-Object -First 1
            $web = Get-KbUpdate -Pattern 4057113 -Source Web | Select-Object -First 1

            $db.Id | Should -Be $web.Id
            $db.Title | Should -Be $web.Title
            $db.Description | Should -Be $web.Description
            $db.Architecture | Should -Be $web.Architecture
            if ($db.Language) {
                $db.Language | Should -Be $web.Language
            }
            $db.Classification | Should -Be $web.Classification
            $db.SupportedProducts | Should -Be $web.SupportedProducts
            $db.MSRCNumber | Should -Be $web.MSRCNumber
            #$db.MSRCSeverity | Should -Be $web.MSRCSeverity
            $db.Size | Should -Be $web.Size
            $db.UpdateId | Should -Be $web.UpdateId
            $db.RebootBehavior | Should -Be $web.RebootBehavior
            $db.RequestsUserInput | Should -Be $web.RequestsUserInput
            #$db.ExclusiveInstall | Should -Be $web.ExclusiveInstall
            $db.NetworkRequired | Should -Be $web.NetworkRequired
            $db.UninstallNotes | Should -Be $web.UninstallNotes
            $db.UninstallSteps | Should -Be $web.UninstallSteps
            $db.SupersededBy.Kb | Should -Be $web.SupersededBy.Kb
            $db.Supersedes.Kb | Should -Be $web.Supersedes.Kb
            $db.LastModified | Should -Be $web.LastModified
            $db.Link | Sort-Object | Should -Be ($web.Link | Sort-Object)
        }

        It "only get one of the latest" {
            [array]$results = Get-KbUpdate -Pattern 'sql 2019' | Where-Object Classification -eq Updates | Select-KbLatest
            $results.Count | Should -Be 1
            $results.UpdateId | Should -Not -BeNullOrEmpty
        }

        if ($env:USERDOMAIN -eq "AD") {
            It "returns the proper results for -ComputerName" {
                $results = Get-KbUpdate -Pattern KB4468550 -ComputerName SQLCS
                $results.Title.Count -eq 1
                $results.Title | Should -match 'Windows'
            }
        }

        It "always gets a Link" {
            $results = Get-KbUpdate -Pattern KB4527377 -Source Database
            $results.Link | Should -Not -BeNullOrEmpty
        }
    }

    Context "Save-KbUpdate works" {

        # RESULTS ARE DOUBLING
        It "supports multiple saves" {
            $results = Save-KbUpdate -Path C:\temp -Name KB2992080, KB2994397
            $results[0].Name -match 'aspnet'
            $results | Remove-Item -Confirm:$false
        }
        It "downloads a small update" {
            $results = Save-KbUpdate -Name KB2992080 -Path C:\temp
            $results.Name | Should -Be 'aspnetwebfxupdate_kb2992080_55c239c6b443cb122b04667a9be948b03046bf88.exe'
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

    Context "Install-KbUpdate works" {
        It "installs a patch" {
            $update = Get-KbUpdate -Pattern KB4527377 | Save-KbUpdate -Path C:\temp
            $results = Install-KbUpdate -ComputerName localhost -Path $update
            $results | Should -Not -BeNullOrEmpty
        }
    }

    Context "Get-KbInstalledUpdate works" {
        It "gets some installed updates" {
            $results = Get-KbInstalledUpdate -Pattern Windows | Where-Object FastPackageReference
            $results.Count | Should -BeGreaterThan 5
        }
        It "confirms that KB4527377 was actually installed" {
            [array]$results = Get-KbInstalledUpdate -Pattern KB4527377
            $results.Count | Should -BeGreaterThan 0
        }
    }

    Context "Uninstall-KbUpdate works" {
        It -Skip "Uninstalls a patch" {
            $results = Uninstall-KbUpdate -ComputerName $env:computername -HotfixId KB4527377 -Confirm:$false
            $results | Should -Not -BeNullOrEmpty
        }
        It -Skip "Uninstalls a patch" {
            $results = Get-KbInstalledUpdate -Pattern KB4527377 | Uninstall-KbUpdate -Confirm:$false
            $results | Should -Not -BeNullOrEmpty
        }
    }


    Context "Supports exclude" {
        It "only returns one match" {
            $results = Get-KbUpdate -OperatingSystem 'Windows Server 2019' -Latest -Architecture x64 -Pattern KB5015878 -Exclude 20H2, 21h2
            $results.Id.Count | Should -Be 1
        }
    }

    Context "Get-KbUpdate regression test for #127" {
        It "Finds multiple OSes from web results" {
            $results = Get-KbUpdate -Pattern 4507004 | Where-Object SupportedProducts -contains "Windows 7" | Select-Object -First 1
            $results.SupportedProducts.Count | Should -BeGreaterThan 1
        }

        It "Finds multiple OSes from db" {
            $results = Get-KbUpdate -Pattern KB2393802 -Source Database | Select-Object -Last 1
            $results.SupportedProducts.Count | Should -BeGreaterThan 1
        }
    }
    Context "Paging" {
        It "pages to get additional results" {
            $results = Get-KbUpdate -Pattern "Windows Server 2019" -MaxPages 2 -Source Web
            $results.Count | Should -Be 50
        }
    }
}
