BeforeAll {
    function Get-BitsTransfer { }
    . (Join-Path $PSScriptRoot '../../private/Start-BitsJobProcess.ps1')
}

Describe 'Start-BitsJobProcess PowerShell compatibility' {
    It 'accepts a BITS-shaped object without requiring the Windows-only BitsJob type' {
        $file = [pscustomobject]@{
            Count     = 1
            LocalName = 'C:\temp\update.msu'
        }
        $job = [pscustomobject]@{
            JobId            = [guid]::NewGuid()
            BytesTotal       = 1024
            BytesTransferred = 0
            FileList         = $file
        }

        Mock Get-BitsTransfer { @() }
        Mock Get-ChildItem { @() }
        Mock Write-Progress

        { $job | Start-BitsJobProcess } | Should -Not -Throw
        Should -Invoke Get-BitsTransfer -Times 1
    }

    It 'declares InputObject using a runtime-neutral object array' {
        (Get-Command Start-BitsJobProcess).Parameters.InputObject.ParameterType | Should -Be ([object[]])
    }
}
