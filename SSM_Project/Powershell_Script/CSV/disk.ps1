# ==== Settings ====
$metricsDir = "C:\Metrics"
$csvPath = "$metricsDir\disk.csv"

# ==== Ensure Metrics Directory Exists ====
if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir | Out-Null
}

# ==== Create CSV with headers if missing ====
if (-not (Test-Path $csvPath)) {
    [PSCustomObject]@{
        Timestamp     = ''
        Free_GB       = ''
        Total_GB      = ''
        Percent_Used  = ''
    } | Export-Csv -Path $csvPath -NoTypeInformation
}

while ($true) {
    $timestamp = Get-Date

    try {
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = 'C:'"

        $totalGB = [math]::Round($disk.Size / 1GB, 2)
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $usedPercent = if ($totalGB -gt 0) {
            [math]::Round((($totalGB - $freeGB) / $totalGB) * 100, 2)
        } else {
            0
        }

        $record = [PSCustomObject]@{
            Timestamp     = $timestamp
            Disk          = $disk.DeviceID
            Free_GB       = $freeGB
            Total_GB      = $totalGB
            Percent_Used  = $usedPercent
        }

        $record | Export-Csv -Path $csvPath -NoTypeInformation -Append
    } catch {
        Write-Host "[$timestamp] Failed to retrieve C: drive info."
    }
}
