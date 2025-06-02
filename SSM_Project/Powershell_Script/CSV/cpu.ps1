# ==== Settings ====
$sampleInterval = 10
$topN = 10
$metricsDir = "C:\Metrics"
$csvPath = "$metricsDir\cpu_metrics.csv"

# ==== Get CPU count with Get-CimInstance ====
$cpuCount = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors

# ==== Ensure Metrics Directory Exists ====
if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir | Out-Null
}

# ==== Start Monitoring Loop ====
while ($true) {
    # Snapshot 1
    $procs1 = Get-Process | Where-Object { $_.CPU -ne $null }
    $snap1 = @{}
    foreach ($proc in $procs1) {
        $snap1[$proc.Id] = $proc.CPU
    }

    Start-Sleep -Seconds $sampleInterval

    # Snapshot 2
    $timestamp = Get-Date
    $roundedMinute = Get-Date -Year $timestamp.Year -Month $timestamp.Month -Day $timestamp.Day `
    -Hour $timestamp.Hour -Minute $timestamp.Minute -Second 0

    $procs2 = Get-Process | Where-Object { $_.CPU -ne $null }
    $services = Get-CimInstance -ClassName Win32_Service

    $cpuDeltas = @()

    foreach ($proc in $procs2) {
        if ($snap1.ContainsKey($proc.Id)) {
            $deltaCPU = $proc.CPU - $snap1[$proc.Id]
            if ($deltaCPU -gt 0) {
                $cpuPercent = [math]::Round(($deltaCPU / $sampleInterval) * 100 / $cpuCount, 2)
                $svc = $services | Where-Object { $_.ProcessId -eq $proc.Id }
                $displayName = if ($svc) { $svc.DisplayName } else { $proc.ProcessName }

                $cpuDeltas += [PSCustomObject]@{
                    Timestamp   = $roundedMinute
                    PID         = $proc.Id
                    DisplayName = $displayName
                    CPUPercent  = $cpuPercent
                }
            }
        }
    }

    if ($cpuDeltas.Count -gt 0) {
        $topProcesses = $cpuDeltas | Sort-Object CPUPercent -Descending | Select-Object -First $topN

        if (-not (Test-Path $csvPath)) {
            $topProcesses | Export-Csv -Path $csvPath -NoTypeInformation
        } else {
            $topProcesses | Export-Csv -Path $csvPath -NoTypeInformation -Append
        }

        Write-Host "[$timestamp] Logged top $topN processes."
    } else {
        Write-Host "[$timestamp] No processes with CPU activity."
    }
}
