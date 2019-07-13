
function Search-Kb {
    <#
    .SYNOPSIS
        Searches the kb results

    .DESCRIPTION
         Searches patches from Microsoft

    .PARAMETER Name
        The KB name or number. For example, KB4057119 or 4057119.

    .PARAMETER Architecture
        Can be x64, x86, ia64 or ARM.

    .PARAMETER InputObject
        Enables piping from Get-KbUpdate

    .NOTES
        Tags: Update
        Author: Chrissy LeMaire (@cl), netnerds.net
        Copyright: (c) licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .EXAMPLE
        PS C:\> Search-KbUpdate -Pattern KB4057119

        Downloads KB4057119 to the current directory. This works for SQL Server or any other KB.

    .EXAMPLE
        PS C:\> Get-KbUpdate -Pattern 3118347 -Simple -Architecture x64 | Out-GridView -Passthru | Search-KbUpdate

        Downloads the selected files from KB4057119 to the current directory.

    .EXAMPLE
        PS C:\> Search-KbUpdate -Pattern KB4057119, 4057114 -Architecture x64 -Path C:\temp

        Downloads KB4057119 and the x64 version of KB4057114 to C:\temp.

    .EXAMPLE
        PS C:\> Search-KbUpdate -Pattern KB4057114 -Path C:\temp

        Downloads all versions of KB4057114 and the x86 version of KB4057114 to C:\temp.
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
        if (-not $PSBoundParameters.OperatingSystem -and -not $PSBoundParameters.Architecture) {
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

            if ($Language) {
                # object.Language cannot be trusted
                # are there any language matches at all? if not just skip.
                $match = $false
                foreach ($code in $script:languages.Values) {
                    if ($object | Where-Object Link -match "-$($code)_") {
                        $match = $true
                    }
                }
                if ($match) {
                    $matches = @()
                    foreach ($item in $Language) {
                        # In case I end up going back to getcultures
                        # $codes = [System.Globalization.CultureInfo]::GetCultures("AllCultures") | Where-Object DisplayName -in $Language | Select-Object -ExpandProperty Name
                        $code = $item[$item]
                        $matches += $object | Where-Object Link -match "$($code)_"
                    }
                    if (-not $matches) {
                        continue
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