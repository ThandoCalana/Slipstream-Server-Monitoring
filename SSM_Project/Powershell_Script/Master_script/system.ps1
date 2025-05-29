# ==== PostgreSQL Connection ====
$ConnectionString = "Driver={PostgreSQL Unicode}; Server=localhost; Port=5432; Database=SSM; Uid=postgres; Pwd=Vongola10;"
$connection = New-Object System.Data.Odbc.OdbcConnection($ConnectionString)
$connection.Open()

# ==== Gather Metrics ====
$timestamp = Get-Date

$cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$ram = Get-CimInstance Win32_OperatingSystem
$ramUsedPercent = [math]::Round((($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory) / $ram.TotalVisibleMemorySize) * 100, 2)

$disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Measure-Object -Property FreeSpace -Sum
$diskTotal = (Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Measure-Object -Property Size -Sum).Sum
$diskFreeGB = [math]::Round($disk.Sum / 1GB, 2)
$diskUsedPercent = if ($diskTotal -ne 0) { [math]::Round((($diskTotal - $disk.Sum) / $diskTotal) * 100, 2) } else { 0 }

# ==== Insert and get ID ====
$cmd = $connection.CreateCommand()
$cmd.CommandText = @"
    INSERT INTO system_metrics (timestamp, cpu_percent, ram_percent, disk_free_gb, disk_used_percent)
    VALUES (?, ?, ?, ?, ?)
    RETURNING id
"@
$cmd.Parameters.Clear()
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.DateTime]$timestamp))) | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$cpuLoad))) | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$ramUsedPercent))) | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$diskFreeGB))) | Out-Null
$cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$diskUsedPercent))) | Out-Null

try {
    $reader = $cmd.ExecuteReader()
    if ($reader.Read()) {
        $systemMetricsId = $reader.GetInt32(0)
        # Output only the ID to stdout
        Write-Output $systemMetricsId
    }
    $reader.Close()
} catch {
    Write-Error "Insert failed: $_"
    exit 1
}

$connection.Close()
exit 0
