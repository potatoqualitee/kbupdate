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

function Get-Info {
    #Invoke-SqliteQuery -DataSource $dailydb -Query "select * from Kb"
    #Invoke-SqliteQuery -DataSource $dailydb -Query "select * from SupersededBy"
    #Invoke-SqliteQuery -DataSource $dailydb -Query "select * from Supersedes"
    Invoke-SqliteQuery -DataSource $dailydb -Query "select * from Link"
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

    $script:db = "C:\github\kbupdate-library\library\kb.sqlite"
    $dailydb = "C:\github\kbupdate\library\db\kb.sqlite"
    #$query = "SELECT CAST(UpdateId AS VARCHAR(36)) as UpdateId FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate] Where ArrivalDate >= DATEADD(hour,-4, GETDATE())"
    $query = "SELECT CAST(UpdateId AS VARCHAR(36)) as UpdateId FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate] Where ArrivalDate >= DATEADD(hour,-24, GETDATE())"
    #$query = "SELECT CAST(UpdateId AS VARCHAR(36)) as UpdateId FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate] Where ArrivalDate >= DATEADD(hour,-120, GETDATE())"
    #$query = "SELECT CAST(UpdateId AS VARCHAR(36)) as UpdateId FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate] Where ArrivalDate >= '2019-07-20 18:02:25.127' and ArrivalDate <= DATEADD(hour,-24, GETDATE())"

    $new = (Invoke-DbaQuery -SqlInstance wsus -Database SUSDB -Query $query).UpdateId

    foreach ($guid in $new) {
        $update = Get-KbUpdate -Pattern $guid -Source Web
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

            $update
            $null = Add-Content -Value $guid -Path C:\updates\NewAll.txt
        } catch {
            Stop-PSFFunction -Message $guid -ErrorRecord $_ -Continue
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
                Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Dupe = $file.BaseName } |
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
}