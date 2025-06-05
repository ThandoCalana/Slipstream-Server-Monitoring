# ==== Settings ====
$metricsDir = "C:\Metrics"
$csvPath = "$metricsDir\memory.csv"

# ==== Ensure Metrics Directory Exists ====
if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir | Out-Null
}

# ==== Create CSV with headers if missing ====
if (-not (Test-Path $csvPath)) {
    [PSCustomObject]@{
        Timestamp  = ''
        Name       = ''
        RAMPercent = ''
        RAMUsedMB  = ''
    } | Export-Csv -Path $csvPath -NoTypeInformation
}

# ==== Infinite Monitoring Loop ====
while ($true) {
    $timestamp = Get-Date

    $totalRAMBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
    $services = Get-CimInstance -ClassName Win32_Service

    $ramStats = @()

    Get-Process | ForEach-Object {
        $proc = $_
        $ramUsedBytes = $proc.WorkingSet64

        if ($ramUsedBytes -gt 0) {
            $ramUsedMB = [math]::Round($ramUsedBytes / 1MB, 2)
            $ramPercent = [math]::Round(($ramUsedBytes / $totalRAMBytes) * 100, 2)

            $svc = $services | Where-Object { $_.ProcessId -eq $proc.Id }
            $displayName = if ($svc) { $svc.DisplayName } else { $proc.ProcessName }

            $ramStats += [PSCustomObject]@{
                Timestamp  = $timestamp
                Name       = $displayName
                RAMPercent = $ramPercent
                RAMUsedMB  = $ramUsedMB
            }
        }
    }


    # ==== Writes to CSV file ====
    $allProcesses = $ramStats | Sort-Object -Property RAMPercent -Descending

    if ($allProcesses.Count -gt 0) {
        $allProcesses | Export-Csv -Path $csvPath -NoTypeInformation -Append
    } else {
        Write-Host "[$timestamp] No RAM usage data found."
    }
}
