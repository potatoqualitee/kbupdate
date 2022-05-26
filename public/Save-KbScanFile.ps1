function Save-KbScanFile {
    <#
    .SYNOPSIS
    Retrieve the latest WSUSSCN2.cab file from Windows Update

    .DESCRIPTION
    Windows Update Agent (WUA) can be used to scan computers for security updates without connecting to Windows Update or to a Windows Server Update Services (WSUS) server, which enables computers that are not connected to the Internet to be scanned for security updates.

    .PARAMETER Path
    The directory where the WSUSSCN2.cab scan file will be saved.

    .PARAMETER Source
    The URL for the WSUSSCN2.cab file. Defaults to a secure download from Microsoft.

    .PARAMETER AllowClobber
    Allow overwriting of an existing WSUSSCN2.cab file.

    .LINK
    https://docs.microsoft.com/en-us/windows/win32/wua_sdk/using-wua-to-scan-for-updates-offline

    .EXAMPLE
    PS> Save-KbScanFile -Verbose

    Saves the cab file to a temporary directory and shows verbose output, then returns the results of Get-ChildItem for the cab file.

    .EXAMPLE
    PS> Save-KbScanFile -Path C:\temp -AllowClobber

    Saves the cab file to C:\temp and overwrite file if it exists

    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Path,
        [string]$Source = "https://catalog.s.download.windowsupdate.com/microsoftupdate/v6/wsusscan/wsusscn2.cab",
        [switch]$AllowClobber
    )
    process {
        Write-PSFMessage -Level Verbose "Grabbing headers from catalog site"
        $request = Invoke-TlsWebRequest -Uri $Source -Method HEAD

        $lastmodified = $Request.Headers['Last-Modified']
        $size = [int]($Request.Headers['Content-Length'] | Select-Object -First 1)
        $size = [math]::Round(($size / 1MB),2)
        $filename = (Split-Path -Path $Source -Leaf)

        Write-PSFMessage -Level Verbose -Message "Last Modified: $lastmodified"
        Write-PSFMessage -Level Verbose -Message "Size: $size MB"

        if (-not $Path) {
            $temp = Get-PSFPath -Name Temp
            $Path = Join-PSFPath -Path $temp wsus
            if (-not (Test-Path -Path $Path)) {
                $null = New-Item -Type Directory -Path $Path
            }
        }

        $outfile = Join-PSFPath -Path $Path $filename
        # Download WSUS database
        if (-not (Test-Path -Path $outfile) -or $AllowClobber) {
            Write-PSFMessage -Level Verbose -Message "Downloading $filename from $Source"
            Invoke-TlsWebRequest -Uri $Source -OutFile $outfile
        }

        Get-ChildItem -Path $outfile -ErrorAction SilentlyContinue
    }
}