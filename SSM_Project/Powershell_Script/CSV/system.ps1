$intervalSeconds = 30
$metricsDir = "C:\Metrics"
$csvPath = "$metricsDir\system_metrics.csv"

if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir | Out-Null
}

# Initialize CSV if not exists
if (-not (Test-Path $csvPath)) {
    # Create CSV with headers only - no dummy data row
    $headers = @{
        Timestamp         = ''
        CPU_Percent       = [int]0
        RAM_Percent       = [double]0
        Disk_Total_GB     = [double]0
        Disk_Free_GB      = [double]0
        Disk_Used_Percent = [double]0
        Total_Mem_MB      = [double]0
        Mem_Free_MB       = [double]0
        Mem_Used_Percent  = [double]0
    }
    $headers.GetEnumerator() | 
        ForEach-Object { $_.Value = $null } # clear values to just create header

    # Export an empty array with headers only
    @() | Select-Object -Property ($headers.Keys | ForEach-Object { $_ }) | Export-Csv -Path $csvPath -NoTypeInformation
}

while ($true) {
    $timestamp = Get-Date
    $roundedMinute = Get-Date -Year $timestamp.Year -Month $timestamp.Month -Day $timestamp.Day `
    -Hour $timestamp.Hour -Minute $timestamp.Minute -Second 0


    $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

    $ram = Get-CimInstance Win32_OperatingSystem
    $ramUsedPercent = [math]::Round((($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory) / $ram.TotalVisibleMemorySize) * 100, 2)

    $totalMem = [math]::Round($ram.TotalVisibleMemorySize / 1024, 2)  # MB
    $freeMem  = [math]::Round($ram.FreePhysicalMemory / 1024, 2)      # MB
    $usedMem  = [math]::Round($totalMem - $freeMem, 2)
    $memPercentUsed = [math]::Round(($usedMem / $totalMem) * 100, 2)

    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskTotal = $disk.Size
    $diskFree  = $disk.FreeSpace

    $totalSizeGB = if ($diskTotal) { [math]::Round($diskTotal / 1GB, 2) } else { 0 }
    $diskFreeGB  = if ($diskFree) { [math]::Round($diskFree / 1GB, 2) } else { 0 }
    $diskUsedPercent = if ($diskTotal -and $diskTotal -ne 0) {
        [math]::Round((($diskTotal - $diskFree) / $diskTotal) * 100, 2)
    } else {
        0
    }

    [PSCustomObject]@{
        Timestamp         = $roundedMinute
        CPU_Percent       = $cpuLoad
        RAM_Percent       = $ramUsedPercent
        Disk_Total_GB     = $totalSizeGB
        Disk_Free_GB      = $diskFreeGB
        Disk_Used_Percent = $diskUsedPercent
        Total_Mem_MB      = $totalMem
        Mem_Free_MB       = $freeMem
        Mem_Used_Percent  = $memPercentUsed
    } | Export-Csv -Path $csvPath -NoTypeInformation -Append

    Start-Sleep -Seconds $intervalSeconds
}
