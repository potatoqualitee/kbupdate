Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\..\constants.ps1"

Describe "Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        if ($env:appveyor) {
            $env:psmodulepath = "$env:psmodulepath; C:\projects; C:\projects\kbupdate"
        }
    }

    Context "Get works" {
        It "returns some good results" {
            $results = Get-KbUpdate -Name KB2992080
            $results.Language | Should -Be "All"
        }
    }
    Context "Save works" {
        It "downloads a small update" {
            $results = Save-KbUpdate -Name KB2992080 -Path C:\temp
            $results.Name -match 'aspnet'
            $results | Remove-Item -Confirm:$false
        }
        It "supports piping" {
            $results = Get-KbUpdate -Name KB2992080 | Select-Object -First 1 | Save-KbUpdate -Path C:\temp
            $results.Name -match 'aspnet'
            $results | Remove-Item -Confirm:$false
        }
    }
}