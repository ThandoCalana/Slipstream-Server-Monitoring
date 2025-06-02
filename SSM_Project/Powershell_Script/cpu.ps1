param(
    [int]$SystemMetricsId
)

# ==== PostgreSQL Connection Setup ====
$ConnectionString = "Driver={PostgreSQL Unicode}; Server=localhost; Port=5432; Database=SSM; Uid=postgres; Pwd=Vongola10;"
$connection = New-Object System.Data.Odbc.OdbcConnection($ConnectionString)
$connection.Open()

# ==== Snapshot Config ====
$sampleInterval = 10
$topN = 10
$cpuCount = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors

# ==== Snapshot 1 ====
$procs1 = Get-Process | Where-Object { $_.CPU -ne $null }
$snap1 = @{}
foreach ($proc in $procs1) {
    $snap1[$proc.Id] = $proc.CPU
}
Start-Sleep -Seconds $sampleInterval

# ==== Snapshot 2 ====
$timestamp = Get-Date
$procs2 = Get-Process | Where-Object { $_.CPU -ne $null }
$services = Get-WmiObject Win32_Service

$cpuDeltas = @()

foreach ($proc in $procs2) {
    if ($snap1.ContainsKey($proc.Id)) {
        $deltaCPU = $proc.CPU - $snap1[$proc.Id]
        if ($deltaCPU -gt 0) {
            $cpuPercent = [math]::Round(($deltaCPU / $sampleInterval) * 100 / $cpuCount, 2)
            $svc = $services | Where-Object { $_.ProcessId -eq $proc.Id }
            $displayName = if ($svc) { $svc.DisplayName } else { $proc.ProcessName }

            $cpuDeltas += [PSCustomObject]@{
                PID = $proc.Id
                Name = $displayName
                CPUPercent = $cpuPercent
            }
        }
    }
}

$topProcesses = $cpuDeltas | Sort-Object -Property CPUPercent -Descending | Select-Object -First $topN

foreach ($proc in $topProcesses) {
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = @"
        INSERT INTO cpu_processes (system_metrics_id, pid, display_name, cpu_percent)
        VALUES (?, ?, ?, ?)
"@
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Int32]$SystemMetricsId))) | Out-Null
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Int32]$proc.PID)))        | Out-Null
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.String]$proc.Name)))      | Out-Null
    $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$proc.CPUPercent)))| Out-Null

    try {
        $cmd.ExecuteNonQuery()
        Write-Host "[$timestamp] PID $($proc.PID) [$($proc.Name)]: $($proc.CPUPercent)%"
    } catch {
        Write-Host "Insert error for PID $($proc.PID): $_"
    }
}

$connection.Close()
