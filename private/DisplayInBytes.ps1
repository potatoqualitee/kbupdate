function DisplayInBytes($num) {
    <#Credit to Mladen Mihajlovic
https://stackoverflow.com/questions/24616806/powershell-display-files-size-as-kb-mb-or-gb/40887001#40887001#>

    $suffix = "B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"
    $index = 0
    while ($num -gt 1kb) {
        $num = $num / 1kb
        $index++
    }

    "{0:N1} {1}" -f $num, $suffix[$index]
}