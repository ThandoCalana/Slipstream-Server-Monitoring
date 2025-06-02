# ==== PostgreSQL Connection ====
$ConnectionString = "Driver={PostgreSQL Unicode}; Server=localhost; Port=5432; Database=SSM; Uid=postgres; Pwd=Vongola10;"
$connection = New-Object System.Data.Odbc.OdbcConnection($ConnectionString)
$connection.Open()

# ==== Gather Metrics ====
$timestamp = Get-Date

# ==== CPU ====
$cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

# ==== RAM ====
$ram = Get-CimInstance Win32_OperatingSystem
$ramUsedPercent = [math]::Round((($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory) / $ram.TotalVisibleMemorySize) * 100, 2)

# ==== Memory ====
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$totalMem = [math]::Round($os.TotalVisibleMemorySize / 1024, 2)  # MB
$freeMem  = [math]::Round($os.FreePhysicalMemory / 1024, 2)      # MB
$usedMem  = [math]::Round($totalMem - $freeMem, 2)
$memPercentUsed = [math]::Round(($usedMem / $totalMem) * 100, 2)

# ==== Disk ====
$diskInfo  = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
$diskTotal = ($diskInfo | Measure-Object -Property Size -Sum).Sum
$diskFree  = ($diskInfo | Measure-Object -Property FreeSpace -Sum).Sum

$totalSizeGB = [math]::Round($diskTotal / 1GB, 2)
$diskFreeGB  = [math]::Round($diskFree / 1GB, 2)
$diskUsedPercent = if ($diskTotal -ne 0) {
    [math]::Round((($diskTotal - $diskFree) / $diskTotal) * 100, 2)
} else {
    0
}

# ==== Insert and return ID ====
$cmd = $connection.CreateCommand()
$cmd.CommandText = @"
    INSERT INTO system_metrics (
        timestamp, cpu_percent, ram_percent, 
        disk_total_gb, disk_free_gb, disk_used_percent, 
        total_mem, mem_free, mem_used_percent
    ) 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id;
"@

$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.DateTime]$timestamp)))      | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$cpuLoad)))          | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$ramUsedPercent)))   | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$totalSizeGB)))      | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$diskFreeGB)))       | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$diskUsedPercent)))  | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$totalMem)))         | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$freeMem)))          | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$memPercentUsed)))   | Out-Null

try {
    $reader = $cmd.ExecuteReader()
    if ($reader.Read()) {
        $systemMetricsId = $reader.GetInt32(0)
        Write-Output $systemMetricsId
    } else {
        Write-Error "Insert executed but no ID returned."
        exit 1
    }
    $reader.Close()
} catch {
    Write-Error "Insert failed: $_"
    exit 1
}

$connection.Close()
exit 0
