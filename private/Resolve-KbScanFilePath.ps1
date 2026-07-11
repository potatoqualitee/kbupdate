function Resolve-KbScanFilePath {
    [CmdletBinding()]
    param(
        [string]$ScanFilePath,
        [Parameter(Mandatory)]
        $ComputerName,
        [pscredential]$Credential,
        [switch]$Force
    )

    if (-not $ScanFilePath) {
        return $ScanFilePath
    }

    $isUncPath = $ScanFilePath.StartsWith('\\')
    $shouldStage = $isUncPath -or ($Force -and -not $ComputerName.IsLocalHost)
    if (-not $shouldStage) {
        return $ScanFilePath
    }

    $sourceFile = Get-Item -LiteralPath $ScanFilePath -ErrorAction Stop
    $computer = $ComputerName.ComputerName
    if ($ComputerName.IsLocalHost) {
        $tempPath = [IO.Path]::GetTempPath()
    } else {
        $tempPath = Invoke-PSFCommand -Computer $computer -Credential $Credential -ErrorAction Stop -ScriptBlock {
            [IO.Path]::GetTempPath()
        }
    }

    $destinationPath = Join-Path -Path $tempPath -ChildPath $sourceFile.Name
    if ($ComputerName.IsLocalHost) {
        $existingFile = Get-Item -LiteralPath $destinationPath -ErrorAction Ignore
        if (-not $existingFile -or $existingFile.Length -ne $sourceFile.Length) {
            Write-PSFMessage -Level Verbose -Message "Copying $ScanFilePath to $destinationPath"
            $null = Copy-Item -LiteralPath $ScanFilePath -Destination $destinationPath -Force -ErrorAction Stop
        } else {
            Write-PSFMessage -Level Verbose -Message "$destinationPath already matches the source size. Skipping copy."
        }
        return $destinationPath
    }

    $existingFile = Invoke-PSFCommand -Computer $computer -Credential $Credential -ArgumentList $destinationPath -ErrorAction Stop -ScriptBlock {
        Get-Item -LiteralPath $args -ErrorAction Ignore
    }
    if ($existingFile -and $existingFile.Length -eq $sourceFile.Length) {
        Write-PSFMessage -Level Verbose -Message "$destinationPath already matches the source size on $computer. Skipping copy."
        return $destinationPath
    }

    $remoteSession = Get-PSSession | Where-Object Name -eq "kbupdate-$computer"
    if (-not $remoteSession) {
        $null = Invoke-KbCommand -ComputerName $computer -Credential $Credential -ScriptBlock { Get-ChildItem }
        $remoteSession = Get-PSSession | Where-Object Name -eq "kbupdate-$computer"
    }
    if (-not $remoteSession) {
        throw "Session for $computer cannot be found or no runspaces are available."
    }

    Write-PSFMessage -Level Verbose -Message "Copying $ScanFilePath to $destinationPath on $computer"
    $null = Copy-Item -LiteralPath $ScanFilePath -Destination $tempPath -ToSession $remoteSession -Force -ErrorAction Stop
    $destinationPath
}
