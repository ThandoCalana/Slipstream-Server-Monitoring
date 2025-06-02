# ==== Settings ====
$metricsDir = "C:\Metrics"
$csvPath = "$metricsDir\disk_processes.csv"
$intervalSeconds = 10
$topN = 10

# ==== Ensure Metrics Directory Exists ====
if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir | Out-Null
}

# ==== Create CSV with headers if missing ====
if (-not (Test-Path $csvPath)) {
    [PSCustomObject]@{
        SystemMetricsId = ''
        Timestamp       = ''
        PID             = ''
        Name            = ''
        ReadKB          = ''
        WriteKB         = ''
        TotalKB         = ''
    } | Export-Csv -Path $csvPath -NoTypeInformation
}

while ($true) {
    # Update SystemMetricsId dynamically
    $currentIdFile = "$metricsDir\current_id.txt"
    if (Test-Path $currentIdFile) {
        $SystemMetricsId = Get-Content $currentIdFile | Select-Object -Last 1
    } else {
        $SystemMetricsId = 0
    }

    $timestamp = Get-Date
    $roundedMinute = Get-Date -Year $timestamp.Year -Month $timestamp.Month -Day $timestamp.Day `
    -Hour $timestamp.Hour -Minute $timestamp.Minute -Second 0


    # Cache services by PID for quick lookup
    $allServices = Get-CimInstance Win32_Service | Group-Object ProcessId -AsHashTable -AsString

    $diskStats = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $_.IDProcess -gt 0 -and $_.Name -ne "_Total" -and $_.Name -ne "Idle" } |
        Select-Object IDProcess, Name, IOReadBytesPersec, IOWriteBytesPersec

    $result = @()

    foreach ($entry in $diskStats) {
        try {
            $procId = $entry.IDProcess
            $svc = $allServices["$procId"]
            $description = if ($svc -and $svc.DisplayName) { $svc.DisplayName } else { $entry.Name }

            $readKB = [math]::Round($entry.IOReadBytesPersec / 1024, 2)
            $writeKB = [math]::Round($entry.IOWriteBytesPersec / 1024, 2)
            $totalKB = [math]::Round($readKB + $writeKB, 2)

            $result += [PSCustomObject]@{
                Timestamp       = $roundedMinute
                PID             = $procId
                Name            = $description
                ReadKB          = $readKB
                WriteKB         = $writeKB
                TotalKB         = $totalKB
            }
        } catch {
            # skip problematic entries
            continue
        }
    }

    $topProcesses = $result | Sort-Object -Property TotalKB -Descending | Select-Object -First $topN

    if ($topProcesses.Count -gt 0) {
        $topProcesses | Export-Csv -Path $csvPath -NoTypeInformation -Append
        Write-Host "[$timestamp] Logged top $topN Disk processes."
    } else {
        Write-Host "[$timestamp] No disk I/O data found."
    }

    Start-Sleep -Seconds $intervalSeconds
}
