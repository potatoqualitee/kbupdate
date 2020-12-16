function Get-KbWSUSSCNFile {
    <#
    .SYNOPSIS
    Retrieve the latest WSUSSCN2.cab file from Windows Update

    .DESCRIPTION
    Windows Update Agent (WUA) can be used to scan computers for security updates without connecting to Windows Update or to a Windows Server Update Services (WSUS) server, which enables computers that are not connected to the Internet to be scanned for security updates.

    .PARAMETER Source
    Parameter description

    .EXAMPLE
    An example

    .NOTES
    General notes

    .LINK
    https://docs.microsoft.com/en-us/windows/win32/wua_sdk/using-wua-to-scan-for-updates-offline
    #>
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        [string]
        $Source = "http://download.windowsupdate.com/microsoftupdate/v6/wsusscan/wsusscn2.cab"
    )

    begin {

    }

    process {
        $Request = Invoke-WebRequest -UseBasicParsing -Uri $Source -Method head

        [datetime]$LastModified = $Request.Headers['Last-Modified'] | Out-String
        [int]$Size = $Request.Headers['Content-Length'] | Out-String

        [PSCustomObject]@{
            FileName     = ($Source -split "/")[-1]
            LastModified = $LastModified
            Size         = DisplayInBytes $Size
            Source       = $Source
        }
    }

    end {

    }
}