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
        CPU_Used_Percent       = [int]0
        RAM_Used_Percent       = [double]0
        RAM_Total_GB      = [double]0
        RAM_Free_GB       = [double]0
        Disk_Used_Percent = [double]0
        Disk_Total_GB     = [double]0
        Disk_Free_GB      = [double]0
    }
    $headers.GetEnumerator() | 
        ForEach-Object { $_.Value = $null } # clear values to just create header

    # Export an empty array with headers only
    @() | Select-Object -Property ($headers.Keys | ForEach-Object { $_ }) | Export-Csv -Path $csvPath -NoTypeInformation
}

while ($true) {
    $timestamp = Get-Date

    $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

    $ram = Get-CimInstance Win32_OperatingSystem
    $ramUsedPercent = [math]::Round((($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory) / $ram.TotalVisibleMemorySize) * 100, 2)

    $totalRAM = [math]::Round($ram.TotalVisibleMemorySize / 1024 / 1000, 2)  # in GB
    $freeRAM  = [math]::Round($ram.FreePhysicalMemory / 1024 / 1000, 2)      # in GB

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
        Timestamp         = $timestamp
        CPU_Percent       = $cpuLoad
        RAM_Percent       = $ramUsedPercent
        RAM_Total_MB      = $totalRAM
        RAM_Free_GB       = $freeRAM
        Disk_Used_Percent = $diskUsedPercent
        Disk_Total_GB     = $totalSizeGB
        Disk_Free_GB      = $diskFreeGB
    } | Export-Csv -Path $csvPath -NoTypeInformation -Append
}
