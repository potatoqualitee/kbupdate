Function Invoke-WsusDbQuery {
    [CmdletBinding()]
    param (
        [string]$ComputerName,
        [PSCredential]$Credential,
        [string]$Pattern,
        [string]$UpdateId,
        [switch]$EnableException
    )
    process {
        $scriptblock = {
            Function Invoke-DbQuery {
                [CmdletBinding()]
                param (
                    [string]$Connstring,
                    [string]$Query
                )
                process {
                    $conn = New-Object System.Data.SqlClient.SqlConnection
                    $conn.ConnectionString = $Connstring
                    $conn.Open()
                    $cmd = New-Object System.Data.SqlClient.SqlCommand($Query, $conn)
                    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter
                    $adapter.SelectCommand = $cmd
                    $dataset = New-Object System.Data.DataSet
                    $adapter.Fill($dataset)
                    $results = $dataset.Tables[0]
                    $conn.Close()
                    $results
                }
            }

            $sqlinstance = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name SqlServerName).SqlServerName
            $database = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name SqlDatabaseName).SqlDatabaseName
            $auth = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name SqlAuthenticationMode).SqlAuthenticationMode

            if ($sqlinstance -match '##') {
                if ([System.Environment]::OSVersion.Version.Major -lt 7 -and [System.Environment]::OSVersion.Version.Minor -lt 2) {
                    $sqlinstance = "\\.\pipe\$sqlinstance\sql\query"
                } else {
                    $sqlinstance = "\\.\pipe\$sqlinstance\tsql\query"
                }
            }

            if ($auth -ne 'WindowsAuthentication' -and -not $SqlCredential) {
                # may need to transform sql pw if the theory below does not work
                # https://social.technet.microsoft.com/Forums/lync/en-US/552b14bf-1d26-4a8f-8e06-5b39ec0783d8/wsus-database-susdb-authentication-via-sql?forum=winserverwsus

                $username = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name SqlUserName).SqlUserName
                $pw = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name SqlEncryptedPassword).SqlEncryptedPassword
                $SqlCredential = New-Object System.Management.Automation.PSCredential($username, $pw)
            }

            if ($SqlCredential) {
                $connstring = "Server=$sqlinstance;Database=$database;User ID=$($SqlCredential.UserName);Password=$($credential.GetNetworkCredential().Password);"
            } else {
                $connstring = "Server=$sqlinstance;Database=$database;Integrated Security=True;"
            }

            if ($Pattern) {
                $items = Invoke-DbQuery -Connstring $connstring -Query "SELECT DefaultTitle as Title
                ,UpdateId
                ,NULL as Architecture
                ,NULL as Language
                ,NULL as Link
                FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate]
                WHERE KnowledgebaseArticle like '%$pattern%' or DefaultTitle like '%$pattern%' or DefaultDescription like '%$pattern%'"
            }

            if ($UpdateId) {
                $items = Invoke-DbQuery -Connstring $connstring -Query "SELECT DefaultTitle as Title
                ,UpdateId
                ,NULL as Architecture
                ,NULL as Language
                ,NULL as Link
                FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate]
                WHERE UpdateId = '$updateid'"

                foreach ($item in $items) {
                    $updateid = $item.UpdateID
                    $links = Invoke-DbQuery -Connstring $connstring -Query "select u.UpdateID,
                    COALESCE (NULLIF(USSURL, ''), MUURL) as Link from dbo.tbfile as f
                    inner join dbo.tbfileforrevision as fr on
                    f.filedigest=fr.filedigest
                    inner join dbo.tbrevision as r on
                    fr.revisionid=r.revisionid
                    inner join dbo.tbupdate as u on
                    r.localupdateid=u.localupdateid
                    inner join dbo.tbLocalizedPropertyforRevision as lr on
                    r.revisionid=lr.revisionid
                    where u.UpdateID = '$updateid'"
                    $item.Link = $links.Link
                }
            }

            # Get results from sqlite then add links
            # If no matches, get results from WSUS
        }

        try {
            $results = Invoke-PSFCommand -ComputerName $computer -Credential $Credential -ScriptBlock $scriptblock -ArgumentList @{ Pattern = $Pattern; UpdateId = $UpdateId } -ErrorAction Stop
        } catch {
            Stop-PSFFunction -Message "Failure" -ErrorRecord $_ -EnableException:$EnableException
            return
        }
    }
}