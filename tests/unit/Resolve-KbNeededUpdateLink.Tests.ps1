BeforeAll {
    function Get-KbUpdate { param($Pattern, $Simple, $ComputerName, $Credential) }
    function Write-PSFMessage { }
    . (Join-Path $PSScriptRoot '../../private/Resolve-KbNeededUpdateLink.ps1')
}

Describe 'Resolve-KbNeededUpdateLink' {
    BeforeEach {
        Mock Write-PSFMessage
    }

    It 'looks up and selects links by exact UpdateId' {
        $updateId = 'abfafad8-5378-48df-a64f-deedc7de0f5a'
        $exactLink = 'https://catalog.s.download.windowsupdate.com/test/exact.cab'
        Mock Get-KbUpdate {
            @(
                [pscustomobject]@{
                    Title    = 'KB5048652 alternate artifact'
                    UpdateId = '99999999-9999-9999-9999-999999999999'
                    Link     = 'https://catalog.s.download.windowsupdate.com/test/alternate.msu'
                }
                [pscustomobject]@{
                    Title    = 'KB5048652 exact artifact'
                    UpdateId = $updateId
                    Link     = @($exactLink, $null)
                }
            )
        }
        $neededUpdate = [pscustomobject]@{
            ComputerName = 'offline-host'
            Title        = 'KB5048652 needed update'
            KBUpdate     = 'KB5048652'
            UpdateId     = $updateId
            Link         = $null
        }

        $result = $neededUpdate | Resolve-KbNeededUpdateLink

        $result.Link | Should -Be @($exactLink)
        Should -Invoke Get-KbUpdate -Times 1 -Exactly -ParameterFilter {
            $Pattern -eq $updateId -and $ComputerName -eq 'offline-host'
        }
    }

    It 'leaves an existing scan link unchanged without a lookup' {
        Mock Get-KbUpdate
        $exactLink = 'https://catalog.s.download.windowsupdate.com/test/from-scan.cab'
        $neededUpdate = [pscustomobject]@{
            ComputerName = 'offline-host'
            Title        = 'KB5048652 needed update'
            KBUpdate     = 'KB5048652'
            UpdateId     = 'abfafad8-5378-48df-a64f-deedc7de0f5a'
            Link         = $exactLink
        }

        $result = $neededUpdate | Resolve-KbNeededUpdateLink

        $result.Link | Should -Be $exactLink
        Should -Invoke Get-KbUpdate -Times 0 -Exactly
    }

    It 'falls back to the KB identity when UpdateId is unavailable' {
        Mock Get-KbUpdate {
            [pscustomobject]@{
                Title    = 'Security update KB5000004'
                UpdateId = '44444444-4444-4444-4444-444444444444'
                Link     = 'https://catalog.s.download.windowsupdate.com/test/kb-fallback.msu'
            }
        }
        $neededUpdate = [pscustomobject]@{
            ComputerName = 'offline-host'
            Title        = 'Security update KB5000004'
            KBUpdate     = 'KB5000004'
            Link         = $null
        }

        $result = $neededUpdate | Resolve-KbNeededUpdateLink

        $result.Link | Should -Match 'kb-fallback\.msu$'
        Should -Invoke Get-KbUpdate -Times 1 -Exactly -ParameterFilter {
            $Pattern -eq 'KB5000004'
        }
    }
}
