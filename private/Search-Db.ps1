Function Search-Filenames {
    <#
			.SYNOPSIS
			Performs a LIKE query on the SQLite database.

			.OUTPUT
			System.Data.Datatable

			#>

    param(
        [string]$filename,
        [string]$locatepath,
        [bool]$s,
        [string]$sql,
        [string[]]$columns,
        [string]$where,
        [string]$orderby,
        [bool]$descending
    )

    # Get variables, load assembly
    if ($locatepath -eq $null) { $locatepath = "$env:LOCALAPPDATA\locate" }
    if ([Reflection.Assembly]::LoadWithPartialName("System.Data.SQLite") -eq $null) { [void][Reflection.Assembly]::LoadFile("$locatepath\System.Data.SQLite.dll") }

    # Setup connect
    $database = "$locatepath\locate.sqlite"
    $connString = "Data Source=$database"
    try { $connection = New-Object System.Data.SQLite.SQLiteConnection($connString) }
    catch { throw "Can't load System.Data.SQLite.SQLite. Architecture mismatch or access denied. Quitting." }
    $connection.Open()
    $command = $connection.CreateCommand()

    # Allow users to use * as wildcards and ? as single characters.
    $filename = $filename.Replace('*', '%')
    $filename = $filename.Replace('?', '_')
    # Escape SQL string
    $filename = $filename.Replace("'", "''")

    if ($columns.length -eq 0) { $columns = "*" } else { $columns = $columns -join ", " }

    if ($sql.length -eq 0) {
        if ($s -eq $false) {
            $sql = "PRAGMA case_sensitive_like = 0;select $columns from files where fullname like '%$filename%'"
        } else { $sql = "PRAGMA case_sensitive_like = 1;select $columns from files where fullname like '%$filename%'" }
    }

    if ($where.length -gt 0) {
        $where = $where.Replace(" -eq ", " = ")
        $where = $where.Replace(" -ne ", " != ")
        $where = $where.Replace(" -gt ", " > ")
        $where = $where.Replace(" -lt ", " < ")
        $where = $where.Replace(" -ge ", " >= ")
        $where = $where.Replace(" -le ", " <= ")
        $where = $where.Replace(" -and ", " and ")
        $where = $where.Replace(" -or ", " or ")
        $sql += " and $where"
    }

    if ($orderby.length -gt 0) {
        $sql += " order by $orderby"
        if ($descending) { $sql += " DESC" }
    }

    if ($limit -gt 0) {
        $sql += " LIMIT $limit"
    }

    Write-Verbose "SQL string executed: $sql"
    $command.CommandText = $sql.Trim()

    # Create datatable and fill it with results
    $datatable = New-Object System.Data.DataTable
    try { $datatable.load($command.ExecuteReader()) }
    catch {
        $msg = $_.Exception.InnerException.Message.ToString() -replace "`r`n", ". "
        Write-Host $msg -BackgroundColor Black -ForegroundColor Red
        Show-SQLcolumns -connection $connection -tablename files
    }
    $command.Dispose()
    $connection.Close()
    $connection.Dispose()

    # return the datatable
    return $datatable
}


$connString = "Data Source=C:\temp\file.sqllite"
$connection = New-Object System.Data.SQLite.SQLiteConnection($connString)
$connection.Open()
$command = $connection.CreateCommand()

New-SQLiteConnection -DataSource C:\temp\updates.sqlite


Invoke-SqliteQuery -DataSource C:\temp\updates.sqlite -Query "CREATE TABLE [newtable](
	[UpdateId] [uniqueidentifier] NOT NULL,
	[RevisionNumber] [int] NOT NULL,
	[DefaultTitle] [nvarchar](200) NOT NULL,
	[DefaultDescription] [nvarchar](1500) NULL,
	[ClassificationId] [uniqueidentifier] NOT NULL,
	[ArrivalDate] [datetime] NOT NULL,
	[CreationDate] [datetime] NOT NULL,
	[IsDeclined] [bit] NOT NULL,
	[IsWsusInfrastructureUpdate] [bit] NOT NULL,
	[MsrcSeverity] [nvarchar](20) NOT NULL,
	[PublicationState] [nvarchar](9) NULL,
	[UpdateType] [nvarchar](256) NOT NULL,
	[UpdateSource] [nvarchar](15) NOT NULL,
	[KnowledgebaseArticle] [nvarchar](15) NULL,
	[SecurityBulletin] [nvarchar](15) NULL,
	[InstallationCanRequestUserInput] [bit] NOT NULL,
	[InstallationRequiresNetworkConnectivity] [bit] NOT NULL,
	[InstallationImpact] [nvarchar](25) NOT NULL,
	[InstallationRebootBehavior] [nvarchar](20) NOT NULL)"



Invoke-SQLiteBulkCopy -DataTable (Invoke-DbaQuery -SqlInstance sql2017 -Database susdb -Query "SELECT top 6 [UpdateId]
      ,[RevisionNumber]
      ,[DefaultTitle]
      ,[DefaultDescription]
      ,[ClassificationId]
      ,[ArrivalDate]
      ,[CreationDate]
      ,[IsDeclined]
      ,[IsWsusInfrastructureUpdate]
      ,[MsrcSeverity]
      ,[PublicationState]
      ,[UpdateType]
      ,[UpdateSource]
      ,[KnowledgebaseArticle]
      ,[SecurityBulletin]
      ,[InstallationCanRequestUserInput]
      ,[InstallationRequiresNetworkConnectivity]
      ,[InstallationImpact]
      ,[InstallationRebootBehavior]
  FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate]" -As DataTable) -DataSource "C:\temp\file.sqllite" -Table newtable -NotifyAfter 1000 -ConflictClause Ignore -Verbose


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
 M.PublicationState,
 M.CreationDate,
 IsDeployed = CASE WHEN EXISTS (
 SELECT 1
 FROM
 dbo.tbDeployment _d
 WHERE
 _d.RevisionID = M.RevisionID
 AND (
 _d.ActionID IN (0, 1)
 OR (
 @apiVersion < 0x00030000
 AND _d.ActionID IN (2, 5)
 )
 )
 AND _d.TargetGroupTypeID = 0
 ) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
 M.State,
 M.EulaID,
 M.RequiresEulaAcceptance,
 M.Declined,
 M.HasStaleDeployments,
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
 @allUpdatesTable AS U
 INNER JOIN dbo.vwMinimalUpdate AS M ON M.RevisionID = U.RevisionID
 INNER JOIN dbo.vwDefaultLocalizedProperty AS DLP ON DLP.RevisionID = U.RevisionID
 LEFT OUTER JOIN dbo.tbPreComputedLocalizedProperty AS Preferred ON Preferred.RevisionID = U.RevisionID AND Preferred.ShortLanguage = @preferredCulture



#>