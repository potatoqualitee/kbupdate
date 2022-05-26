function buildfromwsus {
    $temp = Get-PSFPath -Name Temp
    $basedir = Join-PSFPath -Path $temp wsus
    if (-not (Test-Path -Path $basedir)) {
        $null = mkdir $basedir
    }
    #Set-Location $basedir

    # Download WSUS database
    if (-not (Test-Path -Path "$basedir\wsusscn2.cab")) {
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri http://download.windowsupdate.com/microsoftupdate/v6/wsusscan/wsusscn2.cab -OutFile $basedir\wsusscn2.cab
    }


    $cab = New-Object Microsoft.Deployment.Compression.Cab.Cabinfo $basedir\wsusscn2.cab
    $null = $cab.UnpackFile("package.cab", "$basedir\package.cab")
    $xmlfile = "$basedir\package.xml"
    $cab = New-Object Microsoft.Deployment.Compression.Cab.Cabinfo $basedir\package.cab
    $null = $cab.UnpackFile("package.xml", $xmlfile)
    $xml = [xml](Get-Content -Path $xmlfile)

    $newer = $xml.OfflineSyncPackage.Updates.Update #| Where-Object CreationDate -gt "2022-02-09 23:19:20"


    $ds = New-Object System.Data.DataSet
    $ds.ReadXml($xmlfile)
    ($ds.Tables["FileLocation"].Select("Id = '$fileid'")).Url


    $newer = Import-Csv C:\temp\kb\products.csv
    $newer | Where-Object UpdateId | Invoke-Parallel -ImportVariables -ImportFunctions -RunspaceTimeout 180 -Quiet -ScriptBlock {
        $guid = $PSItem.UpdateId
        if ((Get-KbUpdate -Pattern $guid -OutVariable output -Source Web)) {
            $output | Export-CliXml C:\temp\kb\newoutput\$guid.xml
        } else {
            write-warning $guid
        }
    }



    #($xml.OfflineSyncPackage.FileLocations | Select-XML -Xpath "//*[@Id='$fileid']").Node.Url



    $temp = Get-PSFPath -Name Temp
    $basedir = Join-PSFPath -Path $temp wsus
    if (-not (Test-Path -Path $basedir)) {
        $null = mkdir $basedir
    }
    #Set-Location $basedir

    # Download WSUS database
    if (-not (Test-Path -Path "$basedir\wsusscn2.cab")) {
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri http://download.windowsupdate.com/microsoftupdate/v6/wsusscan/wsusscn2.cab -OutFile $basedir\wsusscn2.cab
    }

    $db = "C:\github\kbupdate-library\library\kb.sqlite"
    $cab = New-Object Microsoft.Deployment.Compression.Cab.Cabinfo $basedir\wsusscn2.cab
    $null = $cab.UnpackFile("package.cab", "$basedir\package.cab")
    $xmlfile = "$basedir\package.xml"
    $cab = New-Object Microsoft.Deployment.Compression.Cab.Cabinfo $basedir\package.cab
    $null = $cab.UnpackFile("package.xml", $xmlfile)
    $xml = [xml](Get-Content -Path $xmlfile)

    $newer = $xml.OfflineSyncPackage.Updates.Updates
    $ds = New-Object System.Data.DataSet
    $ds.ReadXml($xmlfile)

    $updates = $xml.OfflineSyncPackage.Updates
    foreach ($update in $updates.Update) {
        if ($update.PayloadFiles.File) {
            Invoke-SqliteQuery -DataSource $db -Query "delete from Link where UpdateId = '$($update.UpdateId)'"
        }
        foreach ($file in $update.PayloadFiles.File) {
            $fileid = $file.id
            $url = ($ds.Tables["FileLocation"].Select("Id = '$fileid'")).Url
            $url = $url.Replace("http://download.windowsupdate.com", "https://catalog.s.download.windowsupdate.com")
            $url = $url.Replace("http://www.download.windowsupdate.com", "https://catalog.s.download.windowsupdate.com")

            if ($url) {
                Invoke-SQLiteBulkCopy -DataTable (
                    [pscustomobject]@{
                        UpdateId = $update.UpdateId
                        Link     = $url
                    } | ConvertTo-DbaDataTable) -DataSource $db -Table Link -Confirm:$false
            }
        }
    }


}