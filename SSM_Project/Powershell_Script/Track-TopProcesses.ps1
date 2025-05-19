# ==== CONFIGURATION ====
$outputDir = "C:\Metrics"
$logFile = Join-Path $outputDir "TopProcesses.csv"
$sampleInterval = 10  # seconds between samples

# ==== Ensure Output Directory Exists ====
if (!(Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# ==== Prepare CSV Header if File Doesn't Exist ====
if (!(Test-Path -Path $logFile)) {
    "Timestamp,ProcessName,Id,CPUSeconds,RAM_MB" | Out-File -FilePath $logFile -Encoding utf8
}

while ($true) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    # Get top 3 processes by CPU (total processor time)
    $topCPU = Get-Process | Where-Object { $_.CPU -ne $null } |
        Sort-Object CPU -Descending |
        Select-Object -First 3

    # Get top 3 processes by RAM (working set)
    $topRAM = Get-Process | Sort-Object WS -Descending | Select-Object -First 3

    # Combine and remove duplicates (by process ID)
    $combined = $topCPU + $topRAM | Sort-Object Id -Unique

    foreach ($proc in $combined) {
        $cpuSeconds = if ($proc.CPU) { [math]::Round($proc.CPU, 2) } else { 0 }
        $ramMB = [math]::Round($proc.WorkingSet / 1MB, 2)
        $line = "$timestamp,$($proc.ProcessName),$($proc.Id),$cpuSeconds,$ramMB"
        Add-Content -Path $logFile -Value $line
    }

    Start-Sleep -Seconds $sampleInterval
}
