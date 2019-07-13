
function Search-Kb {
    <#
    .SYNOPSIS
        Searches the kb results
    #>
    [CmdletBinding()]
    param(
        [string[]]$Architecture,
        [string[]]$OperatingSystem,
        [string[]]$Product,
        [string[]]$Language,
        [parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject
    )
    process {
        if (-not $OperatingSystem -and -not $Architecture -and -not $Product -and -not $Language) {
            return $InputObject
        }

        foreach ($object in $InputObject) {
            # i am terrible at search logic, if anyone else knows how to do this better, please do
            if ($ComputerName) {
                # if they specify a computername and it's a SQL patch - grab it
                # if they specify comptutername and not $Architecture, grab the unique architecutre
                # will need credential
                # if they specify comptuername and they have kbs already installed that supercedes, warn (Maybe Test output?)
            }

            if ($OperatingSystem) {
                $match = @()
                foreach ($os in $OperatingSystem) {
                    $match += $object | Where-Object SupportedProducts -match $os.Replace(' ', '.*')
                    $match += $object | Where-Object Title -match $os.Replace(' ', '.*')
                }
                if (-not $match) {
                    continue
                }
            }

            if ($Product) {
                $match = @()
                foreach ($item in $Product) {
                    $match += $object | Where-Object SupportedProducts -match $item.Replace(' ', '.*')
                    $match += $object | Where-Object Title -match $item.Replace(' ', '.*')
                }
                if (-not $match) {
                    continue
                }
            }

            if ($Language) {
                # object.Language cannot be trusted
                # are there any language matches at all? if not just skip.
                $languagespecific = $false
                foreach ($key in $script:languages.Keys) {
                    $shortname = $key.Split(" ")[0]
                    $code = $script:languages[$key]
                    if ($object.Link -match '-.._' -or $object.Link -match "-$($code)_" -or ($object.Title -match $shortname -or $object.Description -match $shortname)) {
                        $languagespecific = $true
                    }
                }

                if ($languagespecific) {
                    $textmatch = $false
                    $matches = @()
                    foreach ($item in $Language) {
                        $shortname = $item.Split(" ")[0]
                        $matches += $object.Link -match "$($script:languages[$item])_"
                        if ($object.Title -match $shortname -or $object.Description -match $shortname) {
                            $textmatch = $true
                        }
                    }
                    if ($matches -match 'http') {
                        $object.Link = $matches
                    } else {
                        if (-not $textmatch) {
                            Write-PSFMessage -Level Verbose -Message "Skipping $($object.Title) - no match to $Language"
                            continue
                        }
                    }
                }
            }

            if ($Architecture) {
                $match = @()
                foreach ($arch in $Architecture) {
                    $match += $object | Where-Object Title -match $arch
                    $match += $object | Where-Object Architecture -in $arch, $null, "All"

                    # if architecture from user is -ne all and then multiple files are listed? how to just get that link
                    # perhaps this is where we can check the pipeline, if save, then hardcore filter
                    $match += $object | Where-Object Link -match "$($arch)_"

                    # if architecture from microsoft is all but then listed in the title without the others
                    # oh my, this needs some regex
                    if ($object.Title -match $arch) {
                        $tempvalue = $object
                        foreach ($value in $arch) {
                            if ($tempvalue.Title -match $value -and $arch -ne $value) {
                                $tempvalue = $null
                            }
                        }
                        if ($tempvalue) {
                            $match += $object
                        }
                    }
                }
                if (-not $match) {
                    continue
                }
            }
            $object
        }
    }
}