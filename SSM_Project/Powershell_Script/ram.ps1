param(
    [int]$SystemMetricsId
)

# ==== PostgreSQL Connection Setup ====
$ConnectionString = "Driver={PostgreSQL Unicode}; Server=localhost; Port=5432; Database=SSM; Uid=postgres; Pwd=Vongola10;"
$connection = New-Object System.Data.Odbc.OdbcConnection($ConnectionString)
$connection.Open()

# ==== Get Total Physical RAM ====
$totalRAMBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory

# ==== Get Process and Service Data ====
$timestamp = Get-Date
$services = Get-WmiObject Win32_Service

$ramStats = @()

Get-Process | ForEach-Object {
    $proc = $_
    $ramUsedBytes = $proc.WorkingSet64

    if ($ramUsedBytes -gt 0) {
        $ramUsedGB = [math]::Round($ramUsedBytes / 1GB, 4)
        $ramPercent = [math]::Round(($ramUsedBytes / $totalRAMBytes) * 100, 2)

        $svc = $services | Where-Object { $_.ProcessId -eq $proc.Id }
        $displayName = if ($svc) { $svc.DisplayName } else { $proc.ProcessName }

        $ramStats += [PSCustomObject]@{
            PID = $proc.Id
            Name = $displayName
            RAMPercent = $ramPercent
            RAMUsedGB = $ramUsedGB
        }
    }
}

$topN = 10
$topProcesses = $ramStats | Sort-Object -Property RAMPercent -Descending | Select-Object -First $topN

foreach ($proc in $topProcesses) {
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = @"
        INSERT INTO ram_processes (system_metrics_id, pid, display_name, ram_percent, ram_used_gb)
        VALUES (?, ?, ?, ?, ?)
"@
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Int32]$SystemMetricsId))) | Out-Null
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Int32]$proc.PID)))        | Out-Null
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.String]$proc.Name)))      | Out-Null
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$proc.RAMPercent)))| Out-Null
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$proc.RAMUsedGB))) | Out-Null

    try {
        $cmd.ExecuteNonQuery()
        Write-Host "[$timestamp] PID $($proc.PID) [$($proc.Name)]: $($proc.RAMPercent)% - $($proc.RAMUsedGB) GB"
    } catch {
        Write-Host "Error inserting PID $($proc.PID): $_"
    }
}

$connection.Close()
