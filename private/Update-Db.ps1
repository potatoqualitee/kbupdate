function new-db {
    $script:dailydb = "C:\github\kbupdate\library\db\kb.sqlite"
    Remove-Item -Path $dailydb -ErrorAction Ignore
    $null = New-SQLiteConnection -DataSource $dailydb
    # updateid is not uniqueidentifier cuz I can't figure out how to do WHERE
    # and it gets in the way of the import
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE TABLE [Kb](
        [UpdateId] [nvarchar](36) PRIMARY KEY NOT NULL,
        [Title] [nvarchar](200) NOT NULL,
        [Id] int NULL,
        [Architecture] [nvarchar](5) NULL,
        [Language] [nvarchar](25) NULL,
        [Hotfix] bit NULL,
        [Description] [nvarchar](1500) NULL,
        [LastModified] smalldatetime NULL,
        [Size] [nvarchar](50) NULL,
        [Classification] [nvarchar](512) NULL,
        [SupportedProducts] [nvarchar](50) NULL,
        [MSRCNumber] [nvarchar](25) NULL,
        [MSRCSeverity] [nvarchar](50) NULL,
        [RebootBehavior] [nvarchar](50) NULL,
        [RequestsUserInput] bit NULL,
        [ExclusiveInstall] bit NULL,
        [NetworkRequired] bit NULL,
        [UninstallNotes] [nvarchar](1500) NULL,
        [UninstallSteps] [nvarchar](1500) NULL
    )"

    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE TABLE [SupersededBy](
        [UpdateId] [nvarchar](36) NOT NULL,
        [Kb] int NULL,
        [Description] [nvarchar](200) NULL
    )"

    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE TABLE [Supersedes](
        [UpdateId] [nvarchar](36) NOT NULL,
        [Kb] int NULL,
        [Description] [nvarchar](200) NULL
    )"

    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE TABLE [Link](
        [UpdateId] [nvarchar](36) NOT NULL,
        [Link] [nvarchar](512) NULL
    )"

    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE TABLE [KbDupe](
        [UpdateId] [nvarchar](36) NOT NULL,
        [Dupe] [nvarchar](36) NOT NULL
    )"

    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE TABLE [notfound](
        [UpdateId] [nvarchar](36) NOT NULL
    )"


    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_kb ON Kb (UpdateId)"
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_superby ON SupersededBy (UpdateId)"
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_supers ON Supersedes (UpdateId)"
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_link ON Link (UpdateId)"
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_dupe ON KbDupe (Dupe)"

    Get-ChildItem $dailydb
}

function Get-Info1 {
    #Invoke-SqliteQuery -DataSource $dailydb -Query "select * from Kb"
    #Invoke-SqliteQuery -DataSource $dailydb -Query "select * from SupersededBy"
    #Invoke-SqliteQuery -DataSource $dailydb -Query "select * from Supersedes"
    #Invoke-SqliteQuery -DataSource $dailydb -Query "select * from Link"
    #Invoke-SqliteQuery -DataSource $dailydb -Query "select * from KbDupe"
}

function New-Index {
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_kb ON Kb (UpdateId)"
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_superby ON SupersededBy (UpdateId)"
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_supers ON Supersedes (UpdateId)"
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_link ON Link (UpdateId)"
    Invoke-SqliteQuery -DataSource $dailydb -Query "CREATE INDEX tag_uid_dupe ON KbDupe (Dupe)"
}

function Update-Db {
    [CmdletBinding()]
    param()
    Import-Module C:\github\dbatools

    $script:db = "C:\github\sqldb\kbold.sqlite"
    $dailydb = "C:\github\sqldb\kbnew.sqlite"
    #$new = (Get-ChildItem C:\temp\kb\newoutput).BaseName

    $new = "313e209f-aaac-4694-ac61-675f6e9e6b60","4eb83e93-c0f2-4a71-ba43-053787ecfa2e","b46acc67-3232-4a91-88d2-867cb9d0286c","be4386c2-16b5-4f26-a574-915648bcec2d","d0478bde-b17d-4cd7-9cbc-939c62b62c96"
    $new | Invoke-Parallel -ImportVariables -ImportFunctions -RunspaceTimeout 180 -Quiet -ScriptBlock {
        Import-Module PSFramework, PSSQLite, dbatools
        #$update = Get-KbUpdate -Pattern $guid -Source Web
        $guid = $PSItem
        $update = Get-KbUpdate -Pattern $guid
        if ($update.SupportedProducts) {
            $update.SupportedProducts = $update.SupportedProducts -join "|"
        }
        $Kb = $update | Select-Object -Property * -ExcludeProperty SupersededBy, Supersedes, Link, InputObject
        $SupersededBy = $update.SupersededBy
        $Supersedes = $update.Supersedes
        $Link = $update.Link

        if ($update.UpdateId) {
            # delete old entries
            Invoke-SqliteQuery -DataSource $script:db -Query "delete from Kb where UpdateId = '$($update.UpdateId)'"
            Invoke-SqliteQuery -DataSource $dailydb -Query "delete from Kb where UpdateId = '$($update.UpdateId)'"

            Invoke-SqliteQuery -DataSource $script:db -Query "delete from SupersededBy where UpdateId = '$($update.UpdateId)'"
            Invoke-SqliteQuery -DataSource $dailydb -Query "delete from SupersededBy where UpdateId = '$($update.UpdateId)'"

            Invoke-SqliteQuery -DataSource $script:db -Query "delete from Supersedes where UpdateId = '$($update.UpdateId)'"
            Invoke-SqliteQuery -DataSource $dailydb -Query "delete from Supersedes where UpdateId = '$($update.UpdateId)'"

            Invoke-SqliteQuery -DataSource $script:db -Query "delete from Link where UpdateId = '$($update.UpdateId)'"
            Invoke-SqliteQuery -DataSource $dailydb -Query "delete from Link where UpdateId = '$($update.UpdateId)'"
        }

        foreach ($item in $Kb) {
            $null = Add-Member -InputObject $item -NotePropertyName DateAdded -NotePropertyValue (Get-Date) -Force
            try {
                Invoke-SQLiteBulkCopy -DataTable ($item | ConvertTo-DbaDataTable) -DataSource $dailydb -Table Kb -Confirm:$false
            } catch {
                $null = Add-Content -Value $PSItem -Path C:\temp\kbs\new\Dupes.txt
                Stop-PSFFunction -Message $PSItem -ErrorRecord $_ -Continue
            }
        }
        try {
            foreach ($item in $SupersededBy) {
                if ($null -ne $item.Kb -and '' -ne $item.Kb) {
                    if ($item.Kb) {
                        Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $update.UpdateId; Kb = $item.Kb; Description = $item.Description } |
                                ConvertTo-DbaDataTable) -DataSource $dailydb -Table SupersededBy -Confirm:$false
                        }
                    }
                }
                foreach ($item in $Supersedes) {
                    if ($null -ne $item.Kb -and '' -ne $item.Kb) {
                        if ($item.Kb) {
                            Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $update.UpdateId; Kb = $item.Kb; Description = $item.Description } |
                                    ConvertTo-DbaDataTable) -DataSource $dailydb -Table Supersedes -Confirm:$false
                            }
                        }
                    }

                    foreach ($item in $Link) {
                        Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{UpdateId = $update.UpdateId; Link = $item } |
                                ConvertTo-DbaDataTable) -DataSource $dailydb -Table Link -Confirm:$false
                        }
                        $null = Add-Content -Value $guid -Path C:\temp\kbs\new\NewAll.txt
                    } catch {
                        $null = Add-Content -Value $PSItem -Path C:\temp\kbs\new\errors.txt
                        Stop-PSFFunction -Message $gui$PSItemd -ErrorRecord $_ -Continue
                    }
                }


            }

            function Update-DbFromFile {
                [CmdletBinding()]
                param()
                $files = Get-ChildItem -Path C:\temp\kbs\new\*.xml -Recurse
                $i = 0
                foreach ($file in $files) {
                    $update = Import-CliXml $file.FullName
                    $guid = $update.UpdateId

                    $i++
                    if (($i % 100) -eq 0) { write-warning $i }
                    if (-not $exists) {
                        $kb = $update | Select-Object -Property * -ExcludeProperty SupersededBy, Supersedes, Link, InputObject
                        $SupersededBy = $update.SupersededBy
                        $Supersedes = $update.Supersedes
                        $Link = $update.Link

                        try {
                            Invoke-SQLiteBulkCopy -DataTable ($kb | ConvertTo-DbaDataTable) -DataSource $dailydb -Table Kb -Confirm:$false
                        } catch {
                            $value = $file
                            if ($file.BaseName) {
                                $value = $file.BaseName
                            } else {
                                $value = $file
                            }
                            Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Dupe = $value } |
                                    ConvertTo-DbaDataTable) -DataSource $dailydb -Table KbDupe -Confirm:$false
                #Add-Content -Path C:\temp\dupes.txt -Value $guid, $file.BaseName

                Stop-PSFFunction -Message $guid -ErrorRecord $_ -Continue
            }
            try {
                foreach ($item in $SupersededBy) {
                    Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Kb = $item.Kb; Description = $item.Description } |
                            ConvertTo-DbaDataTable) -DataSource $dailydb -Table SupersededBy -Confirm:$false
                }
                foreach ($item in $Supersedes) {
                    Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Kb = $item.Kb; Description = $item.Description } |
                            ConvertTo-DbaDataTable) -DataSource $dailydb -Table Supersedes -Confirm:$false
                }
                foreach ($item in $Link) {
                    Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{UpdateId = $guid; Link = $item } |
                            ConvertTo-DbaDataTable) -DataSource $dailydb -Table Link -Confirm:$false
                }
            } catch {
                Stop-PSFFunction -Message $guid -ErrorRecord $_ -Continue
            }
        }
    }
}

function Add-Kb {
    [CmdletBinding()]
    param(
        [string[]]$Name
    )

    foreach ($guid in $Name) {
        $update = Get-KbUpdate -Pattern $guid -Source Web
        $update.SupportedProducts = $update.SupportedProducts -join ", "
        $Kb = $update | Select-Object -Property * -ExcludeProperty SupersededBy, Supersedes, Link, InputObject
        $SupersededBy = $update.SupersededBy
        $Supersedes = $update.Supersedes
        $Link = $update.Link

        if ($update.UpdateId) {
            # delete old entries
            Invoke-SqliteQuery -DataSource $script:db -Query "delete from Kb where UpdateId = '$($update.UpdateId)'"
            Invoke-SqliteQuery -DataSource $dailydb -Query "delete from Kb where UpdateId = '$($update.UpdateId)'"

            Invoke-SqliteQuery -DataSource $script:db -Query "delete from SupersededBy where UpdateId = '$($update.UpdateId)'"
            Invoke-SqliteQuery -DataSource $dailydb -Query "delete from SupersededBy where UpdateId = '$($update.UpdateId)'"

            Invoke-SqliteQuery -DataSource $script:db -Query "delete from Supersedes where UpdateId = '$($update.UpdateId)'"
            Invoke-SqliteQuery -DataSource $dailydb -Query "delete from Supersedes where UpdateId = '$($update.UpdateId)'"

            Invoke-SqliteQuery -DataSource $script:db -Query "delete from Link where UpdateId = '$($update.UpdateId)'"
            Invoke-SqliteQuery -DataSource $dailydb -Query "delete from Link where UpdateId = '$($update.UpdateId)'"
        }

        foreach ($item in $Kb) {
            $null = Add-Member -InputObject $item -NotePropertyName DateAdded -NotePropertyValue (Get-Date) -Force
            try {
                Invoke-SQLiteBulkCopy -DataTable ($item | ConvertTo-DbaDataTable) -DataSource $dailydb -Table Kb -Confirm:$false
            } catch {
                $null = Add-Content -Value $guid -Path C:\updates\Dupes.txt
                Stop-PSFFunction -Message $guid -ErrorRecord $_ -Continue
            }
        }
        try {
            foreach ($item in $SupersededBy) {
                if ($null -ne $item.Kb -and '' -ne $item.Kb) {
                    Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Kb = $item.Kb; Description = $item.Description } |
                            ConvertTo-DbaDataTable) -DataSource $dailydb -Table SupersededBy -Confirm:$false
                }
            }
            foreach ($item in $Supersedes) {
                if ($null -ne $item.Kb -and '' -ne $item.Kb) {
                    Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Kb = $item.Kb; Description = $item.Description } |
                            ConvertTo-DbaDataTable) -DataSource $dailydb -Table Supersedes -Confirm:$false
                }
            }
            foreach ($item in $Link) {
                Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{UpdateId = $guid; Link = $item } |
                        ConvertTo-DbaDataTable) -DataSource $dailydb -Table Link -Confirm:$false
            }

            $update
            $null = Add-Content -Value $guid -Path C:\updates\NewAll.txt
        } catch {
            Stop-PSFFunction -Message $guid -ErrorRecord $_ -Continue
        }
    }





    $newer = $xml.OfflineSyncPackage.Updates.Update


    $ds = New-Object System.Data.DataSet
    $ds.ReadXml($xmlfile)
    ($ds.Tables["FileLocation"].Select("Id = '$fileid'")).Url







    function Fix-Db {
        [CmdletBinding()]
        param()

        function Get-Info ($Text, $Pattern) {
            if ($Pattern -match "labelTitle") {
                if ($Pattern -match "SupportedProducts") {
                    # no idea what the regex below does but it's not working for SupportedProducts
                    # do it the manual way instead
                    $block = [regex]::Match($Text, $Pattern + '[\s\S]*?\s*(.*?)\s*<\/div>').Groups[0].Value
                    $supported = $block -split "</span>" | Select-Object -Last 1
                    $supported.Trim().Replace("</div>","").Split(",").Trim()
                } else {
                    # this should work... not accounting for multiple divs however?
                    [regex]::Match($Text, $Pattern + '[\s\S]*?\s*(.*?)\s*<\/div>').Groups[1].Value
                }
            } elseif ($Pattern -match "span ") {
                [regex]::Match($Text, $Pattern + '(.*?)<\/span>').Groups[1].Value
            } else {
                [regex]::Match($Text, $Pattern + "\s?'?(.*?)'?;").Groups[1].Value
            }
        }

        $new = (Invoke-SqliteQuery -DataSource "C:\github\kbupdate-library\library\kb.sqlite" -Query "select UpdateId from kb where Classification like '%security%' and MSRCNumber is NULL").UpdateId
        #$new | Invoke-Parallel -ImportVariables -ImportFunctions -RunspaceTimeout 180 -ScriptBlock {
        Import-Module PSSQLite
        $new | ForEach-Object {
            $updateid = $PSItem

            $detaildialog = Invoke-TlsWebRequest -Uri "https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=$updateid"
            $msrcnumber = Get-Info -Text $detaildialog -Pattern '<span id="ScopedViewHandler_labelSecurityBulliten_Separator" class="labelTitle">'

            if ($msrcnumber -eq "n/a" -or $msrcnumber -eq "Unspecified") {
                $msrcnumber = $null
            }

            if ($msrcnumber) {
                $query = "update Kb set MSRCNumber = '$msrcnumber' where UpdateId = '$updateid';"
                write-warning $query
                Invoke-SqliteQuery -DataSource "C:\github\kbupdate-library\library\kb.sqlite" -Query $query
            } else {
                write-warning nope
            }
        }




    }





}

