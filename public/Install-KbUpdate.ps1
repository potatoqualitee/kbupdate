# requires 5
function Install-KbUpdate {
    <#
    .SYNOPSIS
        Installs KBs on local and remote servers on Windows-based systems

    .DESCRIPTION
        Installs KBs on local and remote servers on Windows-based systems

        PowerShell 5.1 must be installed and enabled on the target machine and the target machine must be Windows-based

        Note that if you use a DSC Pull server, this may impact your LCM

    .PARAMETER ComputerName
        Used to connect to a remote host

    .PARAMETER Credential
        The optional alternative credential to be used when connecting to ComputerName

    .PARAMETER PSDscRunAsCredential
        Run the install as a specific user (other than SYSTEM) on the target node

    .PARAMETER HotfixId
        The HotfixId of the patch

    .PARAMETER FilePath
        The filepath of the patch. Not required - if you don't have it, we can grab it from the internet

        Note this does place the hotfix files in your local and remote Downloads directories

    .PARAMETER Guid
        If the file is an exe and no GUID is specified, we will have to get it from Get-KbUpdate

    .PARAMETER Title
        If the file is an exe and no Title is specified, we will have to get it from Get-KbUpdate

    .PARAMETER Method
        Used to specify DSC or WindowsUpdate. By default, WindowsUpdate is used on localhost and DSC is used on remote servers.

    .PARAMETER ArgumentList
        This is an advanced parameter for those of you who need special argumentlists for your platform-specific update.

        The argument list required by SQL updates are already accounted for.

    .PARAMETER InputObject
        Allows infos to be piped in from Get-KbUpdate

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Chrissy LeMaire (@cl), Jess Pomfret (@jpomfret)
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -FilePath C:\temp\windows10.0-kb4534273-x64_74bf76bc5a941bbbd0052caf5c3f956867e1de38.msu

        Installs KB4534273 from the C:\temp directory on sql2017

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -FilePath \\dc\sql\windows10.0-kb4532947-x64_20103b70445e230e5994dc2a89dc639cd5756a66.msu

        Installs KB4534273 from the \\dc\sql\ directory on sql2017

    .EXAMPLE
        PS C:\> Install-KbUpdate -ComputerName sql2017 -HotfixId kb4486129

        Downloads an update, stores it in Downloads and installs it from there

    .EXAMPLE
        PS C:\> $params = @{
            ComputerName = "sql2017"
            FilePath = "C:\temp\sqlserver2017-kb4498951-x64_b143d28a48204eb6ebab62394ce45df53d73f286.exe"
            Verbose = $true
        }
        PS C:\> Install-KbUpdate @params
        PS C:\> Uninstall-KbUpdate -ComputerName sql2017 -HotfixId KB4498951

        Installs KB4498951 on sql2017 then uninstalls it ✔

    .EXAMPLE
        PS C:\> Get-KbNeededUpdate -OutVariable needed | Save-KbUpdate -Path C:\temp
        PS C:\> $needed | Install-KbUpdate -RepositoryPath C:\temp

        Saves the files for needed updates then installs them from that path

    .EXAMPLE
        PS C:\> Get-KbNeededUpdate | Install-KbUpdate -Method WindowsUpdate -Verbose

        Installs needed updates, only works on localhost

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [PSFComputer[]]$ComputerName = $env:ComputerName,
        [PSCredential]$Credential,
        [PSCredential]$PSDscRunAsCredential,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Name", "KBUpdate", "Id")]
        [string]$HotfixId,
        [Alias("Path")]
        [string]$FilePath,
        [string]$RepositoryPath,
        [ValidateSet("WindowsUpdate", "DSC")]
        [string]$Method,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("UpdateId")]
        [string]$Guid,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Title,
        [string]$ArgumentList,
        [Parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject,
        [switch]$EnableException
    )
    process {
        if (-not $PSBoundParameters.HotfixId -and -not $PSBoundParameters.FilePath -and -not $PSBoundParameters.InputObject) {
            Stop-PSFFunction -EnableException:$EnableException -Message "You must specify either HotfixId or FilePath or pipe in the results from Get-KbUpdate"
            return
        }

        if ($IsLinux -or $IsMacOs) {
            Stop-PSFFunction -Message "This command using remoting and only supports Windows at this time" -EnableException:$EnableException
            return
        }

        if (-not $HotfixId.ToUpper().StartsWith("KB") -and $PSBoundParameters.HotfixId) {
            $HotfixId = "KB$HotfixId"
        }

        if ($Credential.UserName) {
            $PSDefaultParameterValues["*:Credential"] = $Credential
        }

        if (-not $PSBoundParameters.ComputerName -and $InputObject) {
            $ComputerName = [PSFComputer]$InputObject.ComputerName
            Write-PSFMessage -Level Verbose -Message "Added $ComputerName"
        }

        foreach ($item in $ComputerName) {
            $computer = $item.ComputerName
            $completed++

            if ($item.IsLocalHost -and -not (Test-ElevationRequirement -ComputerName $computer)) {
                Stop-PSFFunction -EnableException:$EnableException -Message "You must be an administrator to run this command on the local host" -Continue
            }

            if (-not $item.IsLocalHost -and $Method -eq "WindowsUpdate") {
                Stop-PSFFunction -EnableException:$EnableException -Message "The Windows Update method is only supported on localhost due to Windows security restrictions" -Continue
            }

            if ((Get-Service wuauserv | Where-Object StartType -ne Disabled) -and $Method -eq "WindowsUpdate") {
                Stop-PSFFunction -EnableException:$EnableException -Message "The Windows Update method cannot be used when the Windows Update service is stopped on $computer" -Continue
            }

        }

        foreach ($item in $ComputerName) {
            $computer = $item.ComputerName
            Write-PSFMessage -Level Verbose -Message "Processing $computer"
            if ($item.IsLocalhost -and $Method -ne "DSC") {
                if ((Get-Service wuauserv | Where-Object StartType -ne Disabled)) {
                    $dowin = $true
                } else {
                    $dowin = $false
                }
            }

            if ($dowin -or $Method -eq "WindowsUpdate") {
                Start-WindowsUpdate
            } else {
                Start-DscUpdate
            }
        }
    }
}