BeforeAll {
    function Invoke-PSFCommand { param($Computer, $Credential, $ArgumentList, $ScriptBlock) }
    function Write-PSFMessage { }
    . (Join-Path $PSScriptRoot '../../private/Resolve-KbScanFilePath.ps1')
}

Describe 'Resolve-KbScanFilePath' {
    BeforeEach {
        Mock Write-PSFMessage
        Mock Copy-Item
    }

    It 'stages a UNC scan file locally without requiring Force' {
        $sourcePath = '\\fileserver\updates\wsusscn2.cab'
        $destinationPath = Join-Path ([IO.Path]::GetTempPath()) 'wsusscn2.cab'
        $computer = [pscustomobject]@{
            ComputerName = 'localhost'
            IsLocalHost  = $true
        }
        Mock Get-Item {
            if ($LiteralPath -eq $sourcePath) {
                [pscustomobject]@{ Name = 'wsusscn2.cab'; Length = 100 }
            }
        }

        $result = Resolve-KbScanFilePath -ScanFilePath $sourcePath -ComputerName $computer

        $result | Should -Be $destinationPath
        Should -Invoke Copy-Item -Times 1 -Exactly -ParameterFilter {
            $LiteralPath -eq $sourcePath -and $Destination -eq $destinationPath -and $Force
        }
    }

    It 'reuses a matching local staged file' {
        $sourcePath = '\\fileserver\updates\wsusscn2.cab'
        $destinationPath = Join-Path ([IO.Path]::GetTempPath()) 'wsusscn2.cab'
        $computer = [pscustomobject]@{
            ComputerName = 'localhost'
            IsLocalHost  = $true
        }
        Mock Get-Item {
            if ($LiteralPath -eq $sourcePath) {
                [pscustomobject]@{ Name = 'wsusscn2.cab'; Length = 100 }
            } elseif ($LiteralPath -eq $destinationPath) {
                [pscustomobject]@{ Name = 'wsusscn2.cab'; Length = 100 }
            }
        }

        $result = Resolve-KbScanFilePath -ScanFilePath $sourcePath -ComputerName $computer

        $result | Should -Be $destinationPath
        Should -Invoke Copy-Item -Times 0 -Exactly
    }

    It 'resolves a cached remote UNC file without requiring Force' {
        $sourcePath = '\\fileserver\updates\wsusscn2.cab'
        $destinationPath = Join-Path '/tmp' 'wsusscn2.cab'
        $computer = [pscustomobject]@{
            ComputerName = 'remote-host'
            IsLocalHost  = $false
        }
        Mock Get-Item {
            [pscustomobject]@{ Name = 'wsusscn2.cab'; Length = 100 }
        }
        Mock Invoke-PSFCommand {
            if ($ArgumentList) {
                [pscustomobject]@{ Name = 'wsusscn2.cab'; Length = 100 }
            } else {
                '/tmp'
            }
        }

        $result = Resolve-KbScanFilePath -ScanFilePath $sourcePath -ComputerName $computer

        $result | Should -Be $destinationPath
        Should -Invoke Invoke-PSFCommand -Times 2 -Exactly
        Should -Invoke Copy-Item -Times 0 -Exactly
    }

    It 'leaves a target-local path unchanged when staging is not requested' {
        $sourcePath = 'C:\scan\wsusscn2.cab'
        $computer = [pscustomobject]@{
            ComputerName = 'localhost'
            IsLocalHost  = $true
        }
        Mock Get-Item

        $result = Resolve-KbScanFilePath -ScanFilePath $sourcePath -ComputerName $computer

        $result | Should -Be $sourcePath
        Should -Invoke Get-Item -Times 0 -Exactly
        Should -Invoke Copy-Item -Times 0 -Exactly
    }
}
