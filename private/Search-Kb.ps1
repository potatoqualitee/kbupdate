
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
        [string]$Language,
        [string[]]$Source,
        [parameter(ValueFromPipeline)]
        [pscustomobject[]]$InputObject
    )
    process {
        if (-not $OperatingSystem -and -not $Architecture -and -not $Product -and -not $script:ConnectedWsus) {
            return $InputObject
        } else {
            $allobjects += $InputObject
        }
    }
    end {
        foreach ($object in $allobjects) {
            if ($script:ConnectedWsus -and $Source -contains "WSUS") {
                if ($object.Id) {
                    $result = Get-PSWSUSUpdate -Update $object.Id | Select-Object -First 1
                } else {
                    $result = Get-PSWSUSUpdate -Update $object.Title | Select-Object -First 1
                }
                # gotta keep going and also implement in get-kbupdate
                $link = $result.FileUri
                if (-not $lnk) {
                    $link = $result.OriginUri
                }
                $object.Link = $link
            }

            if ($OperatingSystem) {
                $match = @()
                $allmatch = @()
                foreach ($os in $OperatingSystem) {
                    $allmatch += $allobjects | Where-Object SupportedProducts -Contains $os
                    #$allmatch += $allobjects | Where-Object Title -match $os.Replace(' ', '.*')
                }

                foreach ($os in $OperatingSystem) {
                    $match += $object | Where-Object SupportedProducts -Contains $os
                    #$match += $object | Where-Object Title -match $os.Replace(' ', '.*')
                }
                if (-not $match -and $allmatch) {
                    continue
                }
            }

            if ($Product) {
                $match = @()
                $allmatch = @()
                foreach ($os in $OperatingSystem) {
                    $allmatch += $allobjects | Where-Object SupportedProducts -Contains $os
                    # $allmatch += $allobjects | Where-Object Title -match $os.Replace(' ', '.*')
                }

                foreach ($item in $Product) {
                    $match += $object | Where-Object SupportedProducts -match $item.Replace(' ', '.*')
                    $match += $object | Where-Object Title -match $item.Replace(' ', '.*')
                }
                if (-not $match -and $allmatch) {
                    continue
                }
            }

            if ($Architecture) {
                $match = @()
                # turn x64 to 64 to accomodate for AMD64
                if ("x64" -in $Architecture) {
                    $Architecture += "AMD64"
                }
                foreach ($arch in $Architecture) {
                    $match += $object | Where-Object Title -match $arch
                    $match += $object | Where-Object Architecture -in $arch, $null, "All"
                    $match += $object | Where-Object Architecture -match $arch

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



