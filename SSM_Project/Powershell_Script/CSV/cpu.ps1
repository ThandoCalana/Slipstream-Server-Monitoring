param (
    [string]$ControlFile = "C:\Metrics\monitoring.lock",
    [int]$Interval = 5
)

# Error handling function
function Handle-Error {
    param ($ErrorRecord)
    Write-Host "ERROR [$($ErrorRecord.Exception.GetType().Name)]: $($ErrorRecord.Exception.Message)"
    Write-Host "Continuing monitoring..."
}

# Initialize CSV files with proper error handling
try {
    $cpuCsv  = "C:\Metrics\cpu.csv"
    $ramCsv  = "C:\Metrics\ram.csv"
    $diskCsv = "C:\Metrics\disk.csv"

    # Create directory if it doesn't exist
    if (-not (Test-Path "C:\Metrics")) {
        New-Item -ItemType Directory -Path "C:\Metrics" -Force | Out-Null
    }

    # Create headers if needed
    if (-not (Test-Path $cpuCsv)) {
        "Timestamp,ProcessName,CPU_Usage_Percent" | Out-File $cpuCsv
    }
    # Similar for other files...
}
catch {
    Handle-Error $_
    exit 1
}

try {
    # Get system info once
    $systemInfo = Get-CimInstance Win32_ComputerSystem
    $totalRAM = $systemInfo.TotalPhysicalMemory
    $logicalCores = $systemInfo.NumberOfLogicalProcessors

    $startTime = Get-Date
    Write-Host "Monitoring started at: $startTime"
    $runCounter = 0

    while ($true) {
        try {
            if (-not (Test-Path $ControlFile)) {
                Write-Host "Control file removed, stopping monitoring..."
                break
            }

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $runCounter++
            Write-Host "Run $runCounter at $timestamp"

            # === CPU Monitoring ===
            try {
                $cpuData = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
                    Where-Object { $_.Name -notmatch '^Idle$|^_Total$' }

                foreach ($proc in $cpuData) {
                    $cpuPct = [math]::Round($proc.PercentProcessorTime / $logicalCores, 2)
                    "$timestamp,$($proc.Name),$cpuPct" | Out-File -Append $cpuCsv
                }
            }
            catch { Handle-Error $_ }

            # Similar improved blocks for RAM and Disk monitoring...

            Start-Sleep -Seconds $Interval
        }
        catch {
            Handle-Error $_
            Start-Sleep -Seconds $Interval
            continue
        }
    }
}
finally {
    Write-Host "Monitoring stopped at $(Get-Date). Total runs: $runCounter"
}