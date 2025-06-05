# Output CSV paths
$cpuCsv  = "C:\Metrics\cpu.csv"
$ramCsv  = "C:\Metrics\ram.csv"
$diskCsv = "C:\Metrics\disk.csv"

# Script start time
$startTime = Get-Date
Write-Host "=== Monitoring started at $startTime ===`n"

# Create headers if files don't exist
if (-not (Test-Path $cpuCsv)) {
    "Timestamp,ProcessName,CPU_Usage_Percent" | Out-File $cpuCsv
}
if (-not (Test-Path $ramCsv)) {
    "Timestamp,ProcessName,RAM_Used_MB,RAM_Used_Percent" | Out-File $ramCsv
}
if (-not (Test-Path $diskCsv)) {
    "Timestamp,UsedSpace_GB,FreeSpace_GB,TotalSpace_GB" | Out-File $diskCsv
}

# Get total system memory once for RAM percentage
$totalRAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory

# Run loop
$runCounter = 1
while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "Run #$runCounter - $timestamp"

    # === CPU Monitoring ===
    Get-Process | ForEach-Object {
        $cpu = [math]::Round($_.CPU, 2)
        "$timestamp,$($_.ProcessName),$cpu" | Out-File -Append $cpuCsv
    }

    # === RAM Monitoring ===
    Get-Process | ForEach-Object {
        $workingSet = $_.WorkingSet64
        $workingSetMB = [math]::Round($workingSet / 1MB, 2)
        $percent = if ($totalRAM -gt 0) {
            [math]::Round(($workingSet / $totalRAM) * 100, 2)
        } else { 0 }
        "$timestamp,$($_.ProcessName),$workingSetMB,$percent" | Out-File -Append $ramCsv
    }

    # === Disk Monitoring ===
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = 'C:'"
    if ($disk) {
        $total = [math]::Round($disk.Size / 1GB, 2)
        $free = [math]::Round($disk.FreeSpace / 1GB, 2)
        $used = [math]::Round($total - $free, 2)
        "$timestamp,$used,$free,$total" | Out-File -Append $diskCsv
    }

    $runCounter++
    Start-Sleep -Seconds 5
}
