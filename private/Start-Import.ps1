$script:imports = @{}

function Start-Import {
    [CmdletBinding()]
    param (
        [string]$Name,
        [scriptblock]$ScriptBlock
    )
    begin {
        if (-not $global:kbupdate) {
            Write-PSFMessage -Level Verbose -Message "Creating database hashtables"
            $global:kbupdate = @{}
            $global:kbupdate["linkhash"] = [hashtable]::Synchronized(@{})
            $global:kbupdate["superbyhash"] = [hashtable]::Synchronized(@{})
            $global:kbupdate["superhash"] = [hashtable]::Synchronized(@{})
            $global:runspaces = @()
            Write-PSFMessage -Level Verbose -Message "Done database hashtables"
        }
    }
    process {
        Write-PSFMessage -Level Verbose -Message "Creating Link process"
        $ps = [PowerShell]::Create()
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Name = $Name
        $runspace.Open()
        $runspace.SessionStateProxy.SetVariable("linkhash", $global:kbupdate["linkhash"])
        $runspace.SessionStateProxy.SetVariable("basedb", $script:basedb)
        $runspace.SessionStateProxy.SetVariable("superbyhash", $global:kbupdate["superbyhash"])
        $runspace.SessionStateProxy.SetVariable("superhash", $global:kbupdate["superhash"])
        $ps.Runspace = $runspace
        $null = $ps.AddScript($ScriptBlock)
        $script:runspaces += [PSCustomObject]@{
            Pipe   = $ps
            Status = $ps.BeginInvoke()
        }
    }
}