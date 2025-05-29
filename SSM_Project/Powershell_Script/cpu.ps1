# ==== CONFIGURATION ====
$sampleInterval = 5  # seconds
$topN = 10

# ==== PostgreSQL Connection Setup ====
$ConnectionString = "Driver={PostgreSQL Unicode}; Server=localhost; Port=5432; Database=SSM; Uid=postgres; Pwd=Vongola10;"
$connection = New-Object System.Data.Odbc.OdbcConnection($ConnectionString)
$connection.Open()

# ==== CPU Usage Snapshot Dictionary ====
$prevCPU = @{}
$cpuCount = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors

# ==== Sampling Loop ====
while ($true) {
    $timestamp = Get-Date

    # ==== Get current snapshot ====
    $procs = Get-Process | Where-Object { $_.CPU -ne $null }
    $currSnapshot = @{}
    foreach ($proc in $procs) {
        $currSnapshot[$proc.Id] = @{
            Name = $proc.ProcessName
            CPU = $proc.CPU
        }
    }

    if ($prevCPU.Count -gt 0) {
        $cpuDeltas = @()

        foreach ($procId in $currSnapshot.Keys) {
            if ($prevCPU.ContainsKey($procId)) {
                $deltaCPU = $currSnapshot[$procId].CPU - $prevCPU[$procId].CPU
                if ($deltaCPU -gt 0) {
                    $cpuPercent = [math]::Round(($deltaCPU / $sampleInterval) * 100 / $cpuCount, 2)

                    # ==== Map process ID to service display name (if it's a service) ====
                    $svc = Get-WmiObject Win32_Service | Where-Object { $_.ProcessId -eq $procId }
                    $displayName = if ($svc) { $svc.DisplayName } else { $currSnapshot[$procId].Name }
                    $cpuDeltas += [PSCustomObject]@{
                        PID = $procId
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
                INSERT INTO cpu_processes (timestamp, pid, display_name, cpu_percent)
                VALUES (?, ?, ?, ?)
"@
            $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.DateTime]$timestamp)))
            $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Int32]$proc.PID)))
            $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.String]$proc.Name)))
            $cmd.Parameters.Add((New-Object System.Data.Odbc.OdbcParameter("", [System.Double]$proc.CPUPercent)))

            try {
                $cmd.ExecuteNonQuery()
                Write-Host "[$timestamp] PID $($proc.PID) [$($proc.Name)]: $($proc.CPUPercent)%"
            } catch {
                Write-Host "Error inserting PID $($proc.PID): $_"
            }
        }
    }

    # ==== Store snapshot for next interval ====
    $prevCPU = @{}
    foreach ($item in $currSnapshot.GetEnumerator()) {
        $prevCPU[$item.Key] = @{
            Name = $item.Value.Name
            CPU = $item.Value.CPU
        }
    }

    Start-Sleep -Seconds $sampleInterval
}
