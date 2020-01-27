$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlAlias'

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName
    )

    $returnValue = @{
        Name = [System.String] $Name
        Protocol = [System.String] ''
        ServerName = [System.String] $ServerName
        TcpPort = [System.UInt16] 0
        UseDynamicTcpPort = [System.Boolean] $false
        PipeName = [System.String] ''
        Ensure = [System.String] 'Absent'
    }

    $protocolTcp = 'DBMSSOCN'
    $protocolNamedPipes = 'DBNMPNTW'

    Write-Verbose -Message (
        $script:localizedData.GetClientAlias -f $Name
    )

    $itemValue = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo' `
                                  -Name $Name `
                                  -ErrorAction SilentlyContinue

    if (((Get-CimInstance -ClassName win32_OperatingSystem).OSArchitecture) -eq '64-bit')
    {
        Write-Verbose -Message (
            $script:localizedData.OSArchitecture64Bit -f $Name
        )

        $isWow6432Node = $true
        $itemValueWow6432Node = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo' `
                                                 -Name $Name `
                                                 -ErrorAction SilentlyContinue
    }

    if ((-not $isWow6432Node -and $null -ne $itemValue ) -or `
       (($null -ne $itemValue -and $null -ne $itemValueWow6432Node) -and `
       ($isWow6432Node -and $itemValueWow6432Node."$Name" -eq $itemValue."$Name")))
    {
        $itemConfig = $itemValue."$Name" | ConvertFrom-Csv -Header 'Protocol','ServerName','TcpPort'
        if ($itemConfig)
        {
            if ($itemConfig.Protocol -eq $protocolTcp)
            {
                $returnValue.Ensure = 'Present'
                $returnValue.Protocol = 'TCP'
                $returnValue.ServerName = $itemConfig.ServerName
                if ($itemConfig.TcpPort)
                {
                    $returnValue.TcpPort = $itemConfig.TcpPort
                    $returnValue.UseDynamicTcpPort = $false
                }
                else
                {
                    $returnValue.UseDynamicTcpPort = $true
                    $returnValue.TcpPort = 0
                }
            }
            elseif ($itemConfig.Protocol -eq $protocolNamedPipes)
            {
                $returnValue.Ensure = 'Present'
                $returnValue.Protocol = 'NP'
                $returnValue.PipeName = $itemConfig.ServerName
            }
        }
        else
        {
            $returnValue.Ensure = 'Absent'
        }
    }
    else
    {
        $returnValue.Ensure = 'Absent'
    }

    $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('TCP','NP')]
        [System.String]
        $Protocol = 'TCP',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter()]
        [System.UInt16]
        $TcpPort = 1433,

        [Parameter()]
        [System.Boolean]
        $UseDynamicTcpPort = $false,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    if ($Protocol -eq 'NP')
    {
        $itemValue = "DBNMPNTW,\\$ServerName\PIPE\sql\query"
    }

    if ($Protocol -eq 'TCP')
    {
        $itemValue = "DBMSSOCN,$ServerName"
        if (-not $UseDynamicTcpPort)
        {
            $itemValue += ",$TcpPort"
        }
    }

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo'
    $registryPathWow6432Node = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo'

    if ($Ensure -eq 'Present')
    {
        Write-Verbose -Message (
            $script:localizedData.AddClientAlias64Bit -f $Name
        )

        if (-not (Test-Path -Path $registryPath))
        {
            New-Item -Path $registryPath -Force | Out-Null
        }

        Set-ItemProperty -Path $registryPath -Name $Name -Value $itemValue | Out-Null

        # If this is a 64-bit OS then also update Wow6432Node
        if (((Get-CimInstance -ClassName win32_OperatingSystem).OSArchitecture) -eq '64-bit')
        {
            Write-Verbose -Message (
                $script:localizedData.AddClientAlias32Bit -f $Name
            )

            if (-not (Test-Path -Path $registryPathWow6432Node))
            {
                New-Item -Path $registryPathWow6432Node -Force | Out-Null
            }

            Set-ItemProperty -Path $registryPathWow6432Node -Name $Name -Value $itemValue | Out-Null
        }
    }

    if ($Ensure -eq 'Absent')
    {
        Write-Verbose -Message (
            $script:localizedData.RemoveClientAlias64Bit -f $Name
        )

        if (Test-Path -Path $registryPath)
        {
            Remove-ItemProperty -Path $registryPath -Name $Name
        }

        # If this is a 64-bit OS then also remove from Wow6432Node
        if (((Get-CimInstance -ClassName win32_OperatingSystem).OSArchitecture) -eq '64-bit' `
              -and (Test-Path -Path $registryPathWow6432Node))
        {
            Write-Verbose -Message (
                $script:localizedData.RemoveClientAlias32Bit -f $Name
            )

            Remove-ItemProperty -Path $registryPathWow6432Node -Name $Name
        }
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('TCP','NP')]
        [System.String]
        $Protocol = 'TCP',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter()]
        [System.UInt16]
        $TcpPort = 1433,

        [Parameter()]
        [System.Boolean]
        $UseDynamicTcpPort = $false,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name
    )

    $result = $false

    $parameters = @{
        Name = $PSBoundParameters.Name
        ServerName = $PSBoundParameters.ServerName
    }

    $currentValues = Get-TargetResource @parameters

    if ($Ensure -eq $currentValues.Ensure)
    {
        if ($Ensure -eq 'Absent')
        {
            Write-Verbose -Message (
                $script:localizedData.ClientAliasMissing -f $Name
            )

            $result = $true
        }
        else
        {
            Write-Verbose -Message (
                $script:localizedData.ClientAliasPresent -f $Name
            )

            if ($Protocol -eq $currentValues.Protocol)
            {
                if ($Protocol -eq 'NP' -and
                    $currentValues.PipeName -eq "\\$ServerName\PIPE\sql\query")
                {
                    $result = $true
                }
                elseif ($Protocol -eq 'TCP' -and
                    $UseDynamicTcpPort -and
                    $currentValues.ServerName -eq $ServerName)
                {
                    $result = $true
                }
                elseif ($Protocol -eq 'TCP' -and
                    -not $UseDynamicTcpPort -and
                    $currentValues.ServerName -eq $ServerName -and
                    $currentValues.TcpPort -eq $TcpPort)
                {
                    $result = $true
                }
            }
        }
    }

    if ($result)
    {
        Write-Verbose -Message (
            $script:localizedData.InDesiredState -f $Name
        )
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.NotInDesiredState -f $Name
        )
    }

    return $result
}

Export-ModuleMember -Function *-TargetResource
