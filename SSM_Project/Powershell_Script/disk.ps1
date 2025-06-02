param(
    [int]$SystemMetricsId
)

# ==== PostgreSQL Connection ====
$ConnectionString = "Driver={PostgreSQL Unicode}; Server=localhost; Port=5432; Database=SSM; Uid=postgres; Pwd=Vongola10;"
$connection = New-Object System.Data.Odbc.OdbcConnection($ConnectionString)
$connection.Open()

$timestamp = Get-Date

# Cache services by PID
$allServices = Get-WmiObject Win32_Service | Group-Object ProcessId -AsHashTable -AsString

$diskStats = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process |
    Where-Object { $_.IDProcess -gt 0 -and $_.Name -ne "_Total" -and $_.Name -ne "Idle" } |
    Select-Object IDProcess, Name, IOReadBytesPersec, IOWriteBytesPersec

$result = @()

foreach ($entry in $diskStats) {
    try {
        $procId = $entry.IDProcess
        $svc = $allServices["$procId"]
        $description = if ($svc -and $svc.DisplayName) { $svc.DisplayName } else { $entry.Name }

        $readKB = [math]::Round($entry.IOReadBytesPersec / 1024, 2)
        $writeKB = [math]::Round($entry.IOWriteBytesPersec / 1024, 2)
        $totalKB = [math]::Round($readKB + $writeKB, 2)

        $result += [PSCustomObject]@{
            ProcId = $procId
            Name = $description
            ReadKB = $readKB
            WriteKB = $writeKB
            TotalKB = $totalKB
        }
    } catch {
        continue
    }
}

$topN = 10
$topProcesses = $result | Sort-Object -Property TotalKB -Descending | Select-Object -First $topN

foreach ($proc in $topProcesses) {
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = @"
        INSERT INTO disk_processes (system_metrics_id, pid, display_name, read_kb_s, write_kb_s, total_disk_kb_s)
        VALUES (?, ?, ?, ?, ?, ?)
"@
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Int32]$SystemMetricsId)))
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Int32]$proc.ProcId)))
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.String]$proc.Name)))
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$proc.ReadKB)))
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$proc.WriteKB)))
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$proc.TotalKB)))

    try {
        $cmd.ExecuteNonQuery()
        Write-Host "[$timestamp] PID $($proc.ProcId) [$($proc.Name)] - R: $($proc.ReadKB) KB/s | W: $($proc.WriteKB) KB/s"
    } catch {
        Write-Host "DB insert error for PID $($proc.ProcId): $_"
    }
}

$connection.Close()
