# ===== Configuration =====
$server = "XAN"
$database = "Metric_DB"

# Use Integrated Security (Windows Authentication)
$connectionString = "Server=$server;Database=$database;Integrated Security=SSPI;"

# Create SQL connection object
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

# ===== SQL Helper =====
function Execute-SqlNonQuery {
    param (
        [string]$query
    )
    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    try {
        $connection.Open()
        $command.ExecuteNonQuery() | Out-Null
    } catch {
        Write-Host "SQL Error: $($_.Exception.Message)"
    } finally {
        $connection.Close()
        $connection.Dispose()
    }
}

# ===== Table Names =====
$cpuTable = "cpu_metrics"
$ramTable = "ram_metrics"
$diskTable = "disk_metrics"

# ===== Truncate Timer Setup =====
$lastTruncateTime = Get-Date

# ===== System Info =====
$systemInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$totalRAM = $systemInfo.TotalPhysicalMemory
$logicalCores = $systemInfo.NumberOfLogicalProcessors
$systemInfo.Dispose()

# ===== Main Loop =====
$runCounter = 0
$startTime = Get-Date
Write-Host "Monitoring started at: $startTime"

while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $runCounter++
    Write-Host "Run $runCounter at $timestamp"

    # === Truncate Every 3 Hours ===
    if ((New-TimeSpan -Start $lastTruncateTime -End (Get-Date)).TotalHours -ge 3) {
        Write-Host "Truncating tables..."
        Execute-SqlNonQuery "TRUNCATE TABLE $cpuTable"
        Execute-SqlNonQuery "TRUNCATE TABLE $ramTable"
        Execute-SqlNonQuery "TRUNCATE TABLE $diskTable"
        $lastTruncateTime = Get-Date
    }

    # === CPU ===
    try {
        $cpuData = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process | Where-Object { $_.Name -notmatch '^Idle$|^_Total$' }
        foreach ($proc in $cpuData) {
            $cpuPct = [math]::Round($proc.PercentProcessorTime / $logicalCores, 2)
            $sql = "INSERT INTO $cpuTable (Timestamp, ProcessName, CPU_Usage_Percent) VALUES ('$timestamp', '$($proc.Name.Replace("'", "''"))', $cpuPct)"
            Execute-SqlNonQuery $sql
        }
        $cpuData.Dispose()
    } catch {
        Write-Host "CPU Error: $($_.Exception.Message)"
    }

    # === RAM ===
    try {
        $procs = Get-Process
        foreach ($proc in $procs) {
            $ramMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            $ramPct = if ($totalRAM -gt 0) {
                [math]::Round(($proc.WorkingSet64 / $totalRAM) * 100, 2)
            } else { 0 }
            $sql = "INSERT INTO $ramTable (Timestamp, ProcessName, RAM_Used_MB, RAM_Used_Percent) VALUES ('$timestamp', '$($proc.ProcessName.Replace("'", "''"))', $ramMB, $ramPct)"
            Execute-SqlNonQuery $sql
        }
        $procs | ForEach-Object { $_.Dispose() }
    } catch {
        Write-Host "RAM Error: $($_.Exception.Message)"
    }

    # === Disk ===
    try {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = 'C:'"
        if ($disk) {
            $total = [math]::Round($disk.Size / 1GB, 2)
            $free = [math]::Round($disk.FreeSpace / 1GB, 2)
            $used = [math]::Round($total - $free, 2)
            $sql = "INSERT INTO $diskTable (Timestamp, UsedSpace_GB, FreeSpace_GB, TotalSpace_GB) VALUES ('$timestamp', $used, $free, $total)"
            Execute-SqlNonQuery $sql
            $disk.Dispose()
        }
    } catch {
        Write-Host "Disk Error: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 5
}
