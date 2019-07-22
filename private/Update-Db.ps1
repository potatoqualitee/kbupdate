function new-db {
    Remove-Item -Path $db -ErrorAction Ignore
    $null = New-SQLiteConnection -DataSource $db
    # updateid is not uniqueidentifier cuz I can't figure out how to do WHERE
    # and it gets in the way of the import
    Invoke-SqliteQuery -DataSource $db -Query "CREATE TABLE [Kb](
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

    Invoke-SqliteQuery -DataSource $db -Query "CREATE TABLE [SupersededBy](
        [UpdateId] [nvarchar](36) NOT NULL,
        [Kb] int NULL,
        [Description] [nvarchar](200) NULL
    )"

    Invoke-SqliteQuery -DataSource $db -Query "CREATE TABLE [Supersedes](
        [UpdateId] [nvarchar](36) NOT NULL,
        [Kb] int NULL,
        [Description] [nvarchar](200) NULL
    )"

    Invoke-SqliteQuery -DataSource $db -Query "CREATE TABLE [Link](
        [UpdateId] [nvarchar](36) NOT NULL,
        [Link] [nvarchar](512) NULL
    )"

    Invoke-SqliteQuery -DataSource $db -Query "CREATE TABLE [KbDupe](
        [UpdateId] [nvarchar](36) NOT NULL,
        [Dupe] [nvarchar](36) NOT NULL
    )"

    Invoke-SqliteQuery -DataSource $db -Query "CREATE TABLE [notfound](
        [UpdateId] [nvarchar](36) NOT NULL
    )"


    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_kb ON Kb (UpdateId)"
    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_superby ON SupersededBy (UpdateId)"
    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_supers ON Supersedes (UpdateId)"
    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_link ON Link (UpdateId)"
    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_dupe ON KbDupe (Dupe)"
}

function Get-Info {
    #Invoke-SqliteQuery -DataSource $db -Query "select * from Kb"
    #Invoke-SqliteQuery -DataSource $db -Query "select * from SupersededBy"
    #Invoke-SqliteQuery -DataSource $db -Query "select * from Supersedes"
    Invoke-SqliteQuery -DataSource $db -Query "select * from Link"
    #Invoke-SqliteQuery -DataSource $db -Query "select * from KbDupe"
}

function New-Index {
    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_kb ON Kb (UpdateId)"
    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_superby ON SupersededBy (UpdateId)"
    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_supers ON Supersedes (UpdateId)"
    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_link ON Link (UpdateId)"
    Invoke-SqliteQuery -DataSource $db -Query "CREATE INDEX tag_uid_dupe ON KbDupe (Dupe)"
}

function Update-Db {
    [CmdletBinding()]
    param()
    Import-Module C:\github\dbatools
    #$all = Get-Content -Path C:\Users\ctrlb\Desktop\guidsall.txt
    #$exists = $all -join "','"

    $query = "SELECT CAST(UpdateId AS VARCHAR(36)) as UpdateId FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate] Where ArrivalDate >= DATEADD(hour,-4, GETDATE())"
    $query = "SELECT TOP 10 CAST(UpdateId AS VARCHAR(36)) as UpdateId FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate] Where ArrivalDate >= DATEADD(minute,-1420, GETDATE())"

    $new = (Invoke-DbaQuery -SqlInstance wsus -Database SUSDB -Query $query).UpdateId
    #$new = "9D442AA2-8250-4BCE-A4CB-D5C0F0E940C3"
    foreach ($guid in $new) {
        $query = "select updateid from Kb where updateid = '$guid'"
        $exists = Invoke-SqliteQuery -DataSource $db -Query $query

        if (-not $exists) {
            $update = Get-KbUpdate -Pattern $guid
            $Kb = $update | Select -Property * -ExcludeProperty SupersededBy, Supersedes, Link, InputObject
            $SupersededBy = $update.SupersededBy
            $Supersedes = $update.Supersedes
            $Link = $update.Link

            foreach ($item in $Kb) {
                Invoke-SQLiteBulkCopy -DataTable ($item | ConvertTo-DbaDataTable) -DataSource $db -Table Kb -Confirm:$false
            }
            foreach ($item in $SupersededBy) {
                Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Kb = $item.Kb; Description = $item.Description } |
                ConvertTo-DbaDataTable) -DataSource $db -Table SupersededBy -Confirm:$false
            }
            foreach ($item in $Supersedes) {
                Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Kb = $item.Kb; Description = $item.Description } |
                ConvertTo-DbaDataTable) -DataSource $db -Table Supersedes -Confirm:$false
            }
            foreach ($item in $Link) {
                Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{UpdateId = $guid; Link = $item} |
                ConvertTo-DbaDataTable) -DataSource $db -Table Link -Confirm:$false
            }

            $null = Add-Content -Value $guid -Path C:\Users\ctrlb\Desktop\guidsall.txt
        }
    }
}

function Update-DbFromFile {
    [CmdletBinding()]
    param()
    #new-db
    $files = Get-ChildItem -Path C:\temp\kbs\new\*.xml -Recurse
    $i = 0
    foreach ($file in $files) {
        $update = Import-CliXml $file.FullName
        $guid = $update.UpdateId

        #$query = "select updateid from Kb where updateid = '$guid'"
        #$exists = Invoke-SqliteQuery -DataSource $db -Query $query
        $i++
        if (($i % 100) -eq 0) { write-warning $i }
        if (-not $exists) {
            $kb = $update | Select -Property * -ExcludeProperty SupersededBy, Supersedes, Link, InputObject
            $SupersededBy = $update.SupersededBy
            $Supersedes = $update.Supersedes
            $Link = $update.Link

            try {
                Invoke-SQLiteBulkCopy -DataTable ($kb | ConvertTo-DbaDataTable) -DataSource $db -Table Kb -Confirm:$false
            } catch {
                Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Dupe = $file.BaseName } |
                ConvertTo-DbaDataTable) -DataSource $db -Table KbDupe -Confirm:$false
                #Add-Content -Path C:\temp\dupes.txt -Value $guid, $file.BaseName

                Stop-PSFFunction -Message $guid -ErrorRecord $_ -Continue
            }
            try {
                foreach ($item in $SupersededBy) {
                    Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Kb = $item.Kb; Description = $item.Description } |
                    ConvertTo-DbaDataTable) -DataSource $db -Table SupersededBy -Confirm:$false
                }
                foreach ($item in $Supersedes) {
                    Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{ UpdateId = $guid; Kb = $item.Kb; Description = $item.Description } |
                    ConvertTo-DbaDataTable) -DataSource $db -Table Supersedes -Confirm:$false
                }
                foreach ($item in $Link) {
                    Invoke-SQLiteBulkCopy -DataTable ([pscustomobject]@{UpdateId = $guid; Link = $item} |
                    ConvertTo-DbaDataTable) -DataSource $db -Table Link -Confirm:$false
                }
            } catch {
                Stop-PSFFunction -Message $guid -ErrorRecord $_ -Continue
            }
        }
    }
}

function blah {
    Invoke-SqliteQuery -DataSource $db -Query "select * from link"
    continue

    foreach ($guid in (Get-Content -Path C:\Users\ctrlb\Desktop\guidsall.txt)) {
        Invoke-SQLiteBulkCopy -DataTable (Invoke-DbaQuery -SqlInstance sql2017 -Database susdb -Query $query -As DataTable) -DataSource $db -Table Kb -Confirm:$false

        if (-not (Test-Path -Path "C:\temp\Kbs\$guid.xml")) {
            $update = Get-KbUpdate -Pattern $guid
            if ($update) {
                $update | Export-CliXml -Path "C:\temp\Kbs\$guid.xml"
            }
        }
    }
    # https://www.mssqltips.com/sqlservertip/3087/creating-a-sql-server-linked-server-to-sqlite-to-import-data/

    <#
    exec spGetUpdatesThatSupersedeUpdate @preferredCulture=N'en',@updateID='339FAF61-7694-49FD-8C86-E3D067736A51',@revisionNumber=201,@apiVersion=204800
    exec spGetLanguagesForUpdate @updateID='339FAF61-7694-49FD-8C86-E3D067736A51',@revisionNumber=201
    exec spGetUpdatesSupersededByUpdate @preferredCulture=N'en',@updateID='FE266538-B590-470C-BEFF-174D94FE14D7',@revisionNumber=200,@apiVersion=204800


    exec spSearchUpdates @updateScopeXml=N'<?xml version="1.0" encoding="utf-16"?><UpdateScope ApprovedStates="4" UpdateTypes="-1" FromArrivalDate="01-01-1753 00:00:00.000" ToArrivalDate="12-31-9999 23:59:59.997" Classifications="&lt;root&gt;&lt;CategoryID&gt;0fa1201d-4330-4fa8-8ae9-b877473b6441&lt;/CategoryID&gt;&lt;/root&gt;" IncludedInstallationStates="108" ExcludedInstallationStates="0" IsWsusInfrastructureUpdate="0" FromCreationDate="01-01-1753 00:00:00.000" ToCreationDate="12-31-9999 23:59:59.997" UpdateApprovalActions="-1" UpdateSources="1" ExcludeOptionalUpdates="0" />',@preferredCulture=N'en',@apiVersion=204800

    exec spSearchUpdates @updateScopeXml=N'<?xml version="1.0" encoding="utf-16"?><UpdateScope ExcludeOptionalUpdates="0" />',@preferredCulture=N'en',@apiVersion=204800


    USE [SUSDB]
    GO
    /****** Object:  StoredProcedure [dbo].[spSearchUpdates]    Script Date: 7/18/2019 3:39:32 AM ******/
    SET ANSI_NULLS ON
    GO
    SET QUOTED_IDENTIFIER ON
    GO

    create PROCEDURE [dbo].[spSearchUpdates2]
    @updateScopeXml ntext = null,
    @publicationState int = null,
    @preferredCulture nvarchar(16) = 'en',
    @apiVersion int = 0x00020000
    AS
    SET NOCOUNT ON
    DECLARE @allUpdatesTable TABLE (RevisionID int PRIMARY KEY)
    INSERT INTO @allUpdatesTable
        EXEC dbo.spFilterUpdatesByScopeInternal
            @updateScopeXml = @updateScopeXml
            , @publicationState = @publicationState
            , @preferredCulture = @preferredCulture
            , @apiVersion = @apiVersion
            , @includeDeclinedUpdates = 1
    IF @@ERROR<>0
    BEGIN
        RAISERROR('Failed to get list of matching updates', 16, -1)
        RETURN(1)
    END

    SELECT
    M.UpdateID,
    M.RevisionNumber,
    M.RevisionID,
    M.LocalUpdateID,
    M.IsLeaf,
    M.InstallationSupported,
    M.InstallationImpact,
    M.InstallationRebootBehavior,
    M.InstallationRequiresNetworkConnectivity,
    M.InstallationCanRequestUserInput,
    M.UninstallationSupported,
    M.UninstallationImpact,
    M.UninstallationRebootBehavior,
    M.UninstallationRequiresNetworkConnectivity,
    M.UninstallationCanRequestUserInput,
    M.UpdateType,
    M.CreationDate,
    M.State,
    M.EulaID,
    M.RequiresEulaAcceptance,
    M.IsLatestRevision,
    M.ReceivedFromCreatorService,
    M.HasSupersededUpdates,
    M.LegacyName,
    M.MsrcSeverity,
    Title=ISNULL(Preferred.Title, DLP.Title),
    Description=ISNULL(Preferred.Description, DLP.Description),
    ReleaseNotes=ISNULL(Preferred.ReleaseNotes, DLP.ReleaseNotes),
    M.HasEarlierRevision,
    M.IsMandatory,
    M.IsSuperseded,
    M.IsEditable,
    M.UpdateSource
    FROM
    dbo.vwDefaultLocalizedProperty AS DLP
    INNER JOIN dbo.vwMinimalUpdate AS M ON M.RevisionID = DLP.RevisionID
    LEFT OUTER JOIN dbo.tbPreComputedLocalizedProperty AS Preferred ON Preferred.RevisionID = DLP.RevisionID AND Preferred.ShortLanguage = N'en'

    Microsoft.UpdateServices.Administration")
    $server = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()
    $config = $server.GetConfiguration()
    $config.MUUrl = "https://sws.update.microsoft.com"
    $config.RedirectorChangeNumber = 4002
    $config.Save();
    iisreset
    Restart-Service *Wsus* -v


    SELECT CAST(UpdateId AS VARCHAR(36)) as UpdateId FROM tbUpdate
    #>
}