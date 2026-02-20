$bytes = [System.IO.File]::ReadAllBytes('C:\Users\AVXUser\BMS_RH2_temp\source_prg\RPQC01V1')
$count = [Math]::Min(500, $bytes.Length)
$line = ''
for ($i = 0; $i -lt $count; $i++) {
    $line += ('{0:X2} ' -f $bytes[$i])
    if (($i + 1) % 32 -eq 0) {
        Write-Output $line
        $line = ''
    }
}
if ($line -ne '') { Write-Output $line }
Write-Output "---"
Write-Output "Total file size: $($bytes.Length) bytes"

# Find Hebrew-range bytes (128-255) to identify encoding
Write-Output "---"
Write-Output "Scanning for high bytes (128+) in first 2000 bytes..."
$scan = [Math]::Min(2000, $bytes.Length)
$highBytes = @{}
for ($i = 0; $i -lt $scan; $i++) {
    if ($bytes[$i] -ge 128) {
        $hex = '{0:X2}' -f $bytes[$i]
        if (-not $highBytes.ContainsKey($hex)) {
            $highBytes[$hex] = 0
        }
        $highBytes[$hex]++
    }
}
foreach ($k in ($highBytes.Keys | Sort-Object)) {
    Write-Output "  Byte 0x$k = $($highBytes[$k]) times"
}
