BeforeAll {
    function Stop-PSFFunction { param($Message, [switch]$Continue) }
    function Get-BitsTransfer { }
    function Complete-BitsTransfer { param($BitsJob) }
    function Resume-BitsTransfer { param($BitsJob, [switch]$Asynchronous) }
    function Remove-BitsTransfer { param($BitsJob, [switch]$Confirm) }

    . (Join-Path $PSScriptRoot '../../private/Start-BitsJobProcess.ps1')
}

Describe 'Start-BitsJobProcess job lifecycle' {
    BeforeEach {
        Mock Write-PSFMessage
        Mock Write-Progress
        Mock Start-Sleep
        Mock Get-ChildItem { @() }
        Mock Complete-BitsTransfer
        Mock Resume-BitsTransfer
        Mock Remove-BitsTransfer
        Mock Stop-PSFFunction
    }

    It 'removes one current error job without processing an unrelated stale job' {
        $fileList = [pscustomobject]@{
            Count     = 1
            LocalName = @('C:\temp\current.msu')
        }
        $testJob = [pscustomobject]@{
            JobId            = [guid]::NewGuid()
            FileList         = $fileList
            BytesTotal       = 1024
            BytesTransferred = 0
            Description      = 'kbupdate - current update'
            JobState         = 'Error'
            ErrorDescription = 'file not found'
        }

        $staleJob = [pscustomobject]@{
            JobId            = [guid]::NewGuid()
            FileList         = $fileList
            BytesTotal       = 1024
            BytesTransferred = 0
            Description      = 'kbupdate - stale update'
            JobState         = 'Error'
        }

        $script:pollCount = 0
        Mock Get-BitsTransfer {
            $script:pollCount++
            if ($script:pollCount -eq 1) {
                @($testJob, $staleJob)
            } else {
                @()
            }
        }

        $testJob | Start-BitsJobProcess

        Should -Invoke Remove-BitsTransfer -Times 1 -ParameterFilter {
            $BitsJob.JobId -eq $testJob.JobId
        }
        Should -Invoke Remove-BitsTransfer -Times 0 -ParameterFilter {
            $BitsJob.JobId -eq $staleJob.JobId
        }
    }

    It 'bounds suspended job retries and removes the job after the limit' {
        $fileList = [pscustomobject]@{
            Count     = 1
            LocalName = @('C:\temp\suspended.msu')
        }
        $testJob = [pscustomobject]@{
            JobId            = [guid]::NewGuid()
            FileList         = $fileList
            BytesTotal       = 1024
            BytesTransferred = 0
            Description      = 'kbupdate - suspended update'
            JobState         = 'Suspended'
        }

        $script:pollCount = 0
        Mock Get-BitsTransfer {
            $script:pollCount++
            if ($script:pollCount -le 3) {
                $testJob
            } else {
                @()
            }
        }

        $testJob | Start-BitsJobProcess

        Should -Invoke Resume-BitsTransfer -Times 2
        Should -Invoke Remove-BitsTransfer -Times 1
        Should -Invoke Stop-PSFFunction -Times 1 -ParameterFilter {
            $Message -match 'after 3 retries'
        }
    }
}
