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

    It 'refreshes the displayed total after BITS discovers the file size' {
        $jobId = [guid]::NewGuid()
        $file = [pscustomobject]@{
            Count     = 1
            LocalName = 'C:\temp\update.msu'
        }
        $queuedJob = [pscustomobject]@{
            JobId            = $jobId
            BytesTotal       = [uint64]::MaxValue
            BytesTransferred = 0
            FileList         = $file
        }
        $activeJob = [pscustomobject]@{
            JobId            = $jobId
            BytesTotal       = 5MB
            BytesTransferred = 2MB
            FileList         = $file
            Description      = 'kbupdate - test update'
            JobState         = 'Connecting'
        }

        $script:pollCount = 0
        Mock Get-BitsTransfer {
            $script:pollCount++
            if ($script:pollCount -eq 1) {
                $activeJob
            } else {
                @()
            }
        }
        Mock Get-ChildItem { @() }
        Mock Write-Progress
        Mock Write-PSFMessage
        Mock Start-Sleep

        $queuedJob | Start-BitsJobProcess

        Should -Invoke Write-Progress -Times 1 -ParameterFilter {
            $Activity -eq 'Downloaded 2 MB of at least 5 MB total from 1 files in this batch.'
        }
    }
}
