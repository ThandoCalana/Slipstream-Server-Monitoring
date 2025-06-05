# Output CSV paths
$cpuCsv  = "C:\Metrics\cpu.csv"
$ramCsv  = "C:\Metrics\ram.csv"
$diskCsv = "C:\Metrics\disk.csv"

# ===== Helper Functions =====
function Write-CsvHeader {
    param ([string]$FilePath, [string]$Header)
    try {
        if (-not (Test-Path $FilePath)) {
            $Header | Out-File -FilePath $FilePath -Force
        }
        else {
            # Ensure header exists and is correct
            $existingHeader = Get-Content -Path $FilePath -First 1 -ErrorAction SilentlyContinue
            if ($existingHeader -ne $Header) {
                $Header | Out-File -FilePath $FilePath -Force
            }
        }
    }
    catch {
        Write-Host "ERROR: Failed to write header to $FilePath - $($_.Exception.Message)"
    }
}

# ===== Initialise CSV Headers (Ensures they exist and are correct) =====
Write-CsvHeader -FilePath $cpuCsv  -Header "Timestamp,ProcessName,CPU_Usage_Percent"
Write-CsvHeader -FilePath $ramCsv  -Header "Timestamp,ProcessName,RAM_Used_MB,RAM_Used_Percent"
Write-CsvHeader -FilePath $diskCsv -Header "Timestamp,UsedSpace_GB,FreeSpace_GB,TotalSpace_GB"

# ===== Get System Info (Once at startup) =====
try {
    $systemInfo = Get-CimInstance -ClassName Win32_ComputerSystem
    $totalRAM = $systemInfo.TotalPhysicalMemory
    $logicalCores = $systemInfo.NumberOfLogicalProcessors
    $systemInfo.Dispose() 
}
catch {
    Write-Host "ERROR: Failed to get system info - $($_.Exception.Message)"
    exit 1
}

# ===== Main Monitoring Loop =====
$startTime = Get-Date
Write-Host "Monitoring started at: $startTime"
$runCounter = 0

while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $runCounter++
    Write-Host "Run $runCounter at $timestamp"

    # === CPU Monitoring ===
    try {
        $cpuPerfData = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
            Where-Object { $_.Name -notmatch '^Idle$|^_Total$' }

        foreach ($proc in $cpuPerfData) {
            $cpuPct = [math]::Round($proc.PercentProcessorTime / $logicalCores, 2)
            "$timestamp,$($proc.Name),$cpuPct" | Out-File -Append $cpuCsv
        }
        $cpuPerfData.Dispose()
    }
    catch {
        Write-Host "CPU Monitoring Error: $($_.Exception.Message)"
    }

    # === RAM Monitoring ===
    try {
        $processes = Get-Process -ErrorAction Stop
        foreach ($proc in $processes) {
            $ramMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            $ramPct = if ($totalRAM -gt 0) {
                [math]::Round(($proc.WorkingSet64 / $totalRAM) * 100, 2)
            } else { 0 }
            "$timestamp,$($proc.ProcessName),$ramMB,$ramPct" | Out-File -Append $ramCsv
        }
        $processes | ForEach-Object { $_.Dispose() }
    }
    catch {
        Write-Host "RAM Monitoring Error: $($_.Exception.Message)"
    }

    # === Disk Monitoring (C:) ===
    try {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = 'C:'" -ErrorAction Stop
        if ($disk) {
            $total = [math]::Round($disk.Size / 1GB, 2)
            $free = [math]::Round($disk.FreeSpace / 1GB, 2)
            $used = [math]::Round($total - $free, 2)
            "$timestamp,$used,$free,$total" | Out-File -Append $diskCsv
            $disk.Dispose() 
        }
    }
    catch {
        Write-Host "Disk Monitoring Error: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 5
}

Write-Host "Monitoring stopped at $(Get-Date). Total runs: $runCounter"