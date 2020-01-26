# requires 5
function Install-KbUpdate {
    <#
    .SYNOPSIS
        Installs

    .DESCRIPTION
        Installs etc

    .PARAMETER ComputerName
        Get the Operating System and architecture information automatically

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Update
        Author: Jess Pomfret (@jpomfret)
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -HotfixId KB4534273 -FilePath C:\temp\windows10.0-kb4534273-x64_74bf76bc5a941bbbd0052caf5c3f956867e1de38.msu

        Installs KB4534273 from the C:\temp directory on sql2017

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern MS15-101 -Source Web

        Downloads KBs related to MSRC MS15-101 to the current directory. Only searches the web and not the local db or WSUS.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern MS15-101 -Source Web

        Downloads KBs related to MSRC MS15-101 to the current directory. Only searches the web and not the local db or WSUS.
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [string[]]$ComputerName = $env:ComputerName,
        [PSCredential]$Credential,
        [PSCredential]$PSDscRunAsCredential,
        [string]$HotfixId,
        [string]$FilePath,
        [switch]$EnableException
    )
    begin {
        if (-not $HotfixId.ToUpper().StartsWith("KB")) {
            $HotfixId = "KB$HotfixId"
        }
    }
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.FilePath) {
            Stop-Function -EnableException:$EnableException -Message "You must specify either HotfixId or FilePath"
            return
        }

        foreach ($computer in $ComputerName) {
            # first check for that file then do the routine just once
            $exists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $HotfixId -ScriptBlock {
                Get-HotFix -Id $args -ErrorAction SilentlyContinue
            }

            if ($exists) {
                Stop-Function -EnableException:$EnableException -Message "$hotfixid is already installed on $computer" -Continue
            }

            $remotesession = Get-PSSession -ComputerName $computer | Where-Object Availability -eq Available

            if (-not $remotesession) {
                Stop-Function -EnableException:$EnableException -Message "Session for $computer can't be found. Please file an issue on the GitHub repo at https://github.com/potatoqualitee/kbupdate/issues" -Continue
            }

            $remotehome = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock { $home }
            $null = Copy-Item -Path "$script:ModuleRoot\library\xWindowsUpdate" -Destination "$remotehome\xWindowsUpdate" -ToSession $remotesession -Recurse -Force

            if ($FilePath) {
                $remoteexists = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ArgumentList $FileName -ScriptBlock { Get-ChildItem -Path $args }
            }

            if (-not $remoteexists -or -not $FilePath) {
                if ($PSCmdlet.ShouldProcess($computer, "File not detected, downloading now")) {
                    $updatefile = Get-KbUpdate -ComputerName $computer -Architecture x64 -Credential $credential -Latest -Pattern $HotfixId | Select-Object -First 1 | Save-KbUpdate -Path $home
                    if (-not $FilePath) {
                        $FilePath = "$remotehome\$(Split-Path -Leaf $updateFile)"
                        write-warning $filepath
                    }
                    if ($updatefile) {
                        write-warning $updatefile
                        $null = Copy-Item -Path $updatefile -Destination $FilePath -ToSession $remotesession -Force

                    } else {
                        Stop-Function -EnableException:$EnableException -Message "Could not find $HotfixId and no file was specified" -Continue
                    }
                }
            }

            # if user doesnt add kb, add it for them
            $hotfix = @{
                Name       = 'xHotFix'
                ModuleName = 'xWindowsUpdate'
                Property   = @{
                    Id     = $HotfixId
                    Path   = $FilePath
                    Ensure = 'Present'
                    #PSDscRunAsCredential = $cred -- this would mean it doesn't run as system on the target node
                }
            }


            if ($PSCmdlet.ShouldProcess($computer, "Installing Hotfix $HotfixId from $FilePath")) {
                Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock {
                    param (
                        $Hotfix
                    )
                    write-warning $home
                    # Extract exes, cabs? exe = /extract
                    Import-Module "$home\xWindowsUpdate" -Force
                    write-host ("Installing {0} from {1}" -f $hotfix.property.id, $hotfix.property.path)
                    #if (-not (Invoke-DscResource @hotfix -Method Test -verbose)) {
                    #    Invoke-DscResource @hotfix -Method Set -verbose
                    #    write-host 'done'
                    #}
                    # IF SUCCESSFUL then delete, offer parameter to not delete but by default cleanup
                    Remove-Module xWindowsUpdate
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path "$home\xWindowsUpdate"
                } -ArgumentList $hotfix

                # remove file AFTER all $ComputerName has been processed
            }
        }
    }
}

## xHotFix resource needs to be available on target machine - could we look for it and ship it out if it's needed?
## could also use xPendingReboot to look for pending reboots and handle?

<#
Error - installs the hotfix successfully then :

Serialized XML is nested too deeply. Line 1, position 3507.
    + CategoryInfo          : OperationStopped: (dscsvr2:String) [], PSRemotingTransportException
    + FullyQualifiedErrorId : JobFailure
    + PSComputerName        : dscsvr2

#>