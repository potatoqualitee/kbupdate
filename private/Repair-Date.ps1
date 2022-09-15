function Repair-Date ($date) {
    if ($date) {
        $date = $date.Replace(" ", "").Replace(".","/")
        if ("$(Get-Culture)" -ne "en-US") {
            try {
                $datetime = [DateTime]::ParseExact("$date 12:00:00 AM", "M/d/yyyy h:mm:ss tt",[System.Globalization.DateTimeFormatInfo]::InvariantInfo, "None")
                Get-Date $datetime -Format "yyyy-MM-dd" -ErrorAction Stop
            } catch {
                $null
            }
        } else {
            try {
                Get-Date $date -Format "yyyy-MM-dd" -ErrorAction Stop
            } catch {
                $null
            }
        }
    } else {
        $null
    }
}