# ==== CONFIGURATION ====
$sampleInterval = 5  # seconds


# ==== Fetch Static System Info ====
$totalRAMBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
$totalRAMGB = [math]::Round($totalRAMBytes / 1GB, 2)

$diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
$totalDiskBytes = $diskInfo.Size
$totalDiskGB = [math]::Round($totalDiskBytes / 1GB, 2)


# ==== PostgreSQL Connection Setup ====
$ConnectionString = "Driver={PostgreSQL Unicode}; Server=localhost; Port=5432; Database=SSM; Uid=postgres; Pwd=Vongola10;"
$connection = New-Object System.Data.Odbc.OdbcConnection($ConnectionString)
$connection.Open()

# ==== Metric Collection Loop ====
while ($true) {
    $timestamp = Get-Date

    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $ram = (Get-Counter '\Memory\% Committed Bytes In Use').CounterSamples.CookedValue

    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freeDiskGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedPercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)

    $cmd = $connection.CreateCommand()
    $cmd.CommandText = @"
        INSERT INTO system_metrics (timestamp, cpu_percent, ram_percent, disk_free_gb, disk_used_percent)
        VALUES (?, ?, ?, ?, ?)
"@

    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.DateTime]$timestamp)))
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$cpu)))
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$ram)))
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$freeDiskGB)))
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$usedPercent)))


    try {
        $cmd.ExecuteNonQuery()
        Write-Host "[$timestamp] CPU: $cpu%, RAM: $ram%, Read: $readBps B/s, Write: $writeBps B/s"
    } catch {
        Write-Host "Error inserting into DB: $_"
    }

    Start-Sleep -Seconds $sampleInterval
}

Write-Host "- Total RAM: $totalRAMGB GB (static)"
Write-Host "- Total Disk Size (C:): $totalDiskGB GB (static)"
