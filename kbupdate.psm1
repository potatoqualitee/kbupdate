#requires -Version 3.0

function Get-KbUpdate {
    <#
    .SYNOPSIS
        Gets download links and detailed information for KB files (SPs/hotfixes/CUs, etc)

    .DESCRIPTION
        Parses catalog.update.microsoft.com and grabs details for KB files (SPs/hotfixes/CUs, etc)

        Because Microsoft's RSS feed does not work, the command has to parse a few webpages which can result in slowness.

        Use the Simple parameter for simplified output and faster results.

    .PARAMETER Name
        The KB name or number. For example, KB4057119 or 4057119.

    .PARAMETER Architecture
        Can be x64, x86, ia64 or "All". Defaults to All.

    .PARAMETER Simple
        A lil faster. Returns, at the very least: Title, Architecture, Language, Hotfix, UpdateId and Link

    .NOTES
        Tags: Update
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Get-KbUpdate -Name KB4057119

        Gets detailed information about KB4057119. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Name KB4057119, 4057114

        Gets detailed information about KB4057119 and KB4057114. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Name KB4057119, 4057114 -Simple

        A lil faster. Returns, at the very least: Title, Architecture, Language, Hotfix, UpdateId and Link
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Name,
        [ValidateSet("x64", "x86", "ia64", "All")]
        [string]$Architecture = "All",
        [switch]$Simple
    )
    begin {
        function Get-SuperInfo ($Text, $Pattern) {
            $info = $Text -Split $Pattern
            if ($Pattern -match "supersededbyInfo") {
                $part = ($info[1] -Split '<span id="ScopedViewHandler_labelSupersededUpdates_Separator" class="labelTitle">')[0]
            } else {
                $part = ($info[1] -Split '<div id="languageBox" style="display: none">')[0]
            }
            $nomarkup = ($part -replace '<[^>]+>', '').Trim() -split [Environment]::NewLine
            foreach ($line in $nomarkup) {
                $clean = $line.Trim()
                if ($clean) { $clean }
            }
        }

        $baseproperties = "Title",
        "Description",
        "Architecture",
        "Language",
        "Classification",
        "SupportedProducts",
        "MSRCNumber",
        "MSRCSeverity",
        "Hotfix",
        "Size",
        "UpdateId",
        "RebootBehavior",
        "RequestsUserInput",
        "ExclusiveInstall",
        "NetworkRequired",
        "UninstallNotes",
        "UninstallSteps",
        "SupersededBy",
        "Supersedes",
        "LastModified",
        "Link"
    }
    process {
        foreach ($kb in $Name) {
            Write-Progress -Activity "Getting information for $kb" -Id 1
            try {
                # Thanks! https://keithga.wordpress.com/2017/05/21/new-tool-get-the-latest-windows-10-cumulative-updates/
                $kb = $kb.Replace("KB", "").Replace("kb", "").Replace("Kb", "")

                $results = Invoke-TlsWebRequest -Uri "http://www.catalog.update.microsoft.com/Search.aspx?q=KB$kb" -UseBasicParsing -ErrorAction Stop

                $kbids = $results.InputFields |
                    Where-Object { $_.type -eq 'Button' -and $_.Value -eq 'Download' } |
                    Select-Object -ExpandProperty  ID

                if (-not $kbids) {
                    Write-Warning -Message "No results found for $Name"
                    return
                }

                Write-Verbose -Message "$kbids"

                $guids = $results.Links |
                    Where-Object ID -match '_link' |
                    Where-Object { $_.OuterHTML -match ( "(?=.*" + ( $Filter -join ")(?=.*" ) + ")" ) } |
                    ForEach-Object { $_.id.replace('_link', '') } |
                    Where-Object { $_ -in $kbids }

                foreach ($guid in $guids) {
                    Write-Verbose -Message "Downloading information for $guid"
                    $post = @{ size = 0; updateID = $guid; uidInfo = $guid } | ConvertTo-Json -Compress
                    $body = @{ updateIDs = "[$post]" }
                    $downloaddialog = Invoke-TlsWebRequest -Uri 'http://www.catalog.update.microsoft.com/DownloadDialog.aspx' -Method Post -Body $body -UseBasicParsing -ErrorAction Stop | Select-Object -ExpandProperty Content

                    # changed to regex, the language of the mystics and psychopaths (included \s? for optional whitespace as some lines are a bit whacko)
                    $title = [regex]::Match($downloaddialog, "enTitle =\s?'(.*?)';").Groups[1].Value
                    $arch = [regex]::Match($downloaddialog, "architectures =\s?'(.*?)';").Groups[1].Value
                    $longlang = [regex]::Match($downloaddialog, "longLanguages =\s?'(.*?)';").Groups[1].Value
                    $updateid = [regex]::Match($downloaddialog, "updateID =\s?'(.*?)';").Groups[1].Value
                    $ishotfix = [regex]::Match($downloaddialog, "isHotFix =\s?'(.*?)';").Groups[1].Value

                    if ($ishotfix) {
                        $ishotfix = "True"
                    } else {
                        $ishotfix = "False"
                    }
                    if ($longlang -eq "all") {
                        $longlang = "All"
                    }
                    if ($arch -eq "AMD64") {
                        $arch = "x64"
                    }
                    if ($title -match '64-Bit' -and $title -notmatch '32-Bit' -and -not $arch) {
                        $arch = "x64"
                    }
                    if ($title -notmatch '64-Bit' -and $title -match '32-Bit' -and -not $arch) {
                        $arch = "x86"
                    }

                    if ($arch -and $Architecture -ne "All" -and $arch -ne $Architecture) {
                        continue
                    }

                    if (-not $Simple) {
                        # it aint much prettier but eh, will do superinfo parsing later
                        $detaildialog = Invoke-TlsWebRequest -Uri "https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=$updateid" -UseBasicParsing -ErrorAction Stop
                        $description = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_desc">(.*?)<\/span>').Groups[1].Value
                        $lastmodified = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_date">(.*?)<\/span>').Groups[1].Value
                        $size = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_size">(.*?)<\/span>').Groups[1].Value
                        $classification = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_labelClassification_Separator" class="labelTitle">(.*?)<\/span>').Groups[1].Value
                        $supportedproducts = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_labelSupportedProducts_Separator" class="labelTitle">(.*?)<\/span>').Groups[1].Value
                        $msrcnumber = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_labelSecurityBulliten_Separator" class="labelTitle">(.*?)<\/span>').Groups[1].Value
                        $msrcseverity = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_msrcSeverity">(.*?)<\/span>').Groups[1].Value
                        $rebootbehavior = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_rebootBehavior">(.*?)<\/span>').Groups[1].Value
                        $requestuserinput = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_userInput">(.*?)<\/span>').Groups[1].Value
                        $exclusiveinstall = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_installationImpact">(.*?)<\/span>').Groups[1].Value
                        $networkrequired = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_connectivity">(.*?)<\/span>').Groups[1].Value
                        $uninstallnotes = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_labelUninstallNotes_Separator" class="labelTitle">(.*?)<\/span>').Groups[1].Value
                        $uninstallsteps = [regex]::Match($detaildialog, '<span id="ScopedViewHandler_labelUninstallSteps_Separator" class="labelTitle">(.*?)<\/span>').Groups[1].Value
                        $supersededby = Get-SuperInfo -Text $detaildialog -Pattern '<div id="supersededbyInfo" TABINDEX="1" >'
                        $supersedes = Get-SuperInfo -Text $detaildialog -Pattern '<div id="supersedesInfo" TABINDEX="1">'

                        $product = $supportedproducts -split ","
                        if ($product.Count -gt 1) {
                            $supportedproducts = @()
                            foreach ($line in $product) {
                                $clean = $line.Trim()
                                if ($clean) { $supportedproducts += $clean }
                            }
                        }
                    }

                    $links = $downloaddialog | Select-String -AllMatches -Pattern "(http[s]?\://download\.windowsupdate\.com\/[^\'\""]*)" | Select-Object -Unique

                    foreach ($link in $links) {
                        $properties = $baseproperties

                        if ($Simple) {
                            $properties = $properties | Where-Object { $PSItem -notin "LastModified", "Description", "Size", "Classification", "SupportedProducts", "MSRCNumber", "MSRCSeverity", "RebootBehavior", "RequestsUserInput", "ExclusiveInstall", "NetworkRequired", "UninstallNotes", "UninstallSteps", "SupersededBy", "Supersedes" }
                        }

                        [pscustomobject]@{
                            Title             = $title
                            Architecture      = $arch
                            Language          = $longlang
                            Hotfix            = $ishotfix
                            Description       = $description
                            LastModified      = $lastmodified
                            Size              = $size
                            Classification    = $classification
                            SupportedProducts = $supportedproducts
                            MSRCNumber        = $msrcnumber
                            MSRCSeverity      = $msrcseverity
                            RebootBehavior    = $rebootbehavior
                            RequestsUserInput = $requestuserinput
                            ExclusiveInstall  = $exclusiveinstall
                            NetworkRequired   = $networkrequired
                            UninstallNotes    = $uninstallnotes
                            UninstallSteps    = $uninstallsteps
                            UpdateId          = $updateid
                            Supersedes        = $supersedes
                            SupersededBy      = $supersededby
                            Link              = $link.matches.value
                        } | Select-DefaultView -Property $properties
                    }
                }
            } catch {
                throw $_
            }
            Write-Progress -Activity "Getting information for $kb" -Id 1 -Completed
        }
    }
}

function Save-KbUpdate {
    <#
    .SYNOPSIS
        Downloads patches from Microsoft

    .DESCRIPTION
         Downloads patches from Microsoft

    .PARAMETER Name
        The KB name or number. For example, KB4057119 or 4057119.

    .PARAMETER Path
        The directory to save the file.

    .PARAMETER FilePath
        The exact file name to save to, otherwise, it uses the name given by the webserver

     .PARAMETER Architecture
        Can be x64, x86, ia64 or "All". Defaults to All.

    .PARAMETER InputObject
        Enables piping from Get-KbUpdate

    .NOTES
        Tags: Update
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Save-KbUpdate -Name KB4057119

        Downloads KB4057119 to the current directory. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Name 3118347 -Simple -Architecture x64 | Out-GridView -Passthru | Save-KbUpdate

        Downloads the selected files from KB4057119 to the current directory.

    .EXAMPLE
        PS C:\> Save-KbUpdate -Name KB4057119, 4057114 -Architecture x64 -Path C:\temp

        Downloads KB4057119 and the x64 version of KB4057114 to C:\temp.

    .EXAMPLE
        PS C:\> Save-KbUpdate -Name KB4057114 -Path C:\temp

        Downloads all versions of KB4057114 and the x86 version of KB4057114 to C:\temp.
#>
    [CmdletBinding()]
    param(
        [string[]]$Name,
        [string]$Path = ".",
        [string]$FilePath,
        [ValidateSet("x64", "x86", "ia64", "All")]
        [string]$Architecture = "All",
        [parameter(ValueFromPipeline)]
        [pscustomobject]$InputObject
    )
    process {
        if ($Name.Count -gt 0 -and $PSBoundParameters.FilePath) {
            Write-Warning -Message "You can only specify one KB when using FilePath"
            return
        }

        if (-not $PSBoundParameters.InputObject -and -not $PSBoundParameters.Name) {
            Write-Warning -Message "You must specify a KB name or pipe in results from Get-KbUpdate"
            return
        }

        foreach ($kb in $Name) {
            $InputObject += Get-KbUpdate -Name $kb -Architecture $Architecture
        }

        foreach ($object in $InputObject) {
            if ($Architecture -ne "All") {
                $templinks = $object.Link | Where-Object { $PSItem -match "$($Architecture)_" }

                if (-not $templinks) {
                    $templinks = $object | Where-Object Architecture -eq $Architecture
                }

                if ($templinks) {
                    $object = $templinks
                } else {
                    Write-Warning -Message "Could not find architecture match, downloading all"
                }
            }

            foreach ($link in $object.Link) {
                if (-not $PSBoundParameters.FilePath) {
                    $FilePath = Split-Path -Path $link -Leaf
                } else {
                    $Path = Split-Path -Path $FilePath
                }

                $file = "$Path$([IO.Path]::DirectorySeparatorChar)$FilePath"

                if ((Get-Command Start-BitsTransfer -ErrorAction Ignore)) {
                    Start-BitsTransfer -Source $link -Destination $file
                } else {
                    # IWR is crazy slow for large downloads
                    Write-Progress -Activity "Downloading $FilePath" -Id 1
                    Invoke-TlsWebRequest -OutFile $file -Uri $link -UseBasicParsing
                    Write-Progress -Activity "Downloading $FilePath" -Id 1 -Completed
                }
                if (Test-Path -Path $file) {
                    Get-ChildItem -Path $file
                }
            }
        }
    }
}

function Invoke-TlsWebRequest {

    <#
    Internal utility that mimics invoke-webrequest
    but enables all tls available version
    rather than the default, which on a lot
    of standard installations is just TLS 1.0

       #>

    # IWR is crazy slow for large downloads
    $currentProgressPref = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    $currentVersionTls = [Net.ServicePointManager]::SecurityProtocol
    $currentSupportableTls = [Math]::Max($currentVersionTls.value__, [Net.SecurityProtocolType]::Tls.value__)
    $availableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -gt $currentSupportableTls }
    $availableTls | ForEach-Object {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $_
    }

    Invoke-WebRequest @Args

    [Net.ServicePointManager]::SecurityProtocol = $currentVersionTls
    $ProgressPreference = $currentProgressPref
}

function Select-DefaultView {
    <#

    This command enables us to send full on objects to the pipeline without the user seeing it

    See it in action in Get-DbaDbSnapshot and Remove-DbaDbSnapshot

    a lot of this is from boe, thanks boe!
    https://learn-powershell.net/2013/08/03/quick-hits-set-the-default-property-display-in-powershell-on-custom-objects/

    TypeName creates a new type so that we can use ps1xml to modify the output
    #>

    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        [psobject]$InputObject,
        [string[]]$Property,
        [string[]]$ExcludeProperty,
        [string]$TypeName
    )
    process {

        if ($null -eq $InputObject) { return }

        if ($TypeName) {
            $InputObject.PSObject.TypeNames.Insert(0, "dbatools.$TypeName")
        }

        if ($ExcludeProperty) {
            if ($InputObject.GetType().Name.ToString() -eq 'DataRow') {
                $ExcludeProperty += 'Item', 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors'
            }

            $props = ($InputObject | Get-Member | Where-Object MemberType -in 'Property', 'NoteProperty', 'AliasProperty' | Where-Object { $_.Name -notin $ExcludeProperty }).Name
            $defaultset = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$props)
        } else {
            # property needs to be string
            if ("$property" -like "* as *") {
                $property =
                @(foreach ($p in $property) {
                        if ($p -like "* as *") {
                            $old, $new = $p -isplit " as "
                            # Do not be tempted to not pipe here
                            $inputobject | Add-Member -Force -MemberType AliasProperty -Name $new -Value $old -ErrorAction SilentlyContinue
                            $new
                        } else {
                            $p
                        }
                    })
            }
            $defaultset =

            $defaultset = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$Property)
        }

        $standardmembers = [Management.Automation.PSMemberInfo[]]@($defaultset)

        # Do not be tempted to not pipe here
        $inputobject | Add-Member -Force -MemberType MemberSet -Name PSStandardMembers -Value $standardmembers -ErrorAction SilentlyContinue

        $inputobject
    }
}