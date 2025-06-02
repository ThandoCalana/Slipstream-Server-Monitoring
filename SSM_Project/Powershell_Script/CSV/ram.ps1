# ==== Settings ====
$metricsDir = "C:\Metrics"
$csvPath = "$metricsDir\ram_metrics.csv"
$intervalSeconds = 10
$topN = 10

# ==== Ensure Metrics Directory Exists ====
if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir | Out-Null
}

# ==== Create CSV with headers if missing ====
if (-not (Test-Path $csvPath)) {
    [PSCustomObject]@{
        Timestamp  = ''
        PID        = ''
        Name       = ''
        RAMPercent = ''
        RAMUsedGB  = ''
    } | Export-Csv -Path $csvPath -NoTypeInformation
}

# ==== Infinite Monitoring Loop ====
while ($true) {
    $timestamp = Get-Date
    $roundedMinute = Get-Date -Year $timestamp.Year -Month $timestamp.Month -Day $timestamp.Day `
    -Hour $timestamp.Hour -Minute $timestamp.Minute -Second 0


    $totalRAMBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
    $services = Get-CimInstance -ClassName Win32_Service

    $ramStats = @()

    Get-Process | ForEach-Object {
        $proc = $_
        $ramUsedBytes = $proc.WorkingSet64

        if ($ramUsedBytes -gt 0) {
            $ramUsedGB = [math]::Round($ramUsedBytes / 1GB, 4)
            $ramPercent = [math]::Round(($ramUsedBytes / $totalRAMBytes) * 100, 2)

            $svc = $services | Where-Object { $_.ProcessId -eq $proc.Id }
            $displayName = if ($svc) { $svc.DisplayName } else { $proc.ProcessName }

            $ramStats += [PSCustomObject]@{
                Timestamp  = $roundedMinute
                PID        = $proc.Id
                Name       = $displayName
                RAMPercent = $ramPercent
                RAMUsedGB  = $ramUsedGB
            }
        }
    }

    $topProcesses = $ramStats | Sort-Object -Property RAMPercent -Descending | Select-Object -First $topN

    if ($topProcesses.Count -gt 0) {
        $topProcesses | Export-Csv -Path $csvPath -NoTypeInformation -Append
        Write-Host "[$timestamp] Logged top $topN RAM processes."
    } else {
        Write-Host "[$timestamp] No RAM usage data found."
    }

    Start-Sleep -Seconds $intervalSeconds
}
