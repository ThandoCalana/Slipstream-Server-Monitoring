# ===== Configuration =====
$server = "XAN"
$database = "Metric_DB"
$connectionString = "Server=$server;Database=$database;Integrated Security=SSPI;"

# ===== Email Config =====
$emailFrom = "monitor@yourdomain.com"
$emailTo   = "you@yourdomain.com"
$smtpServer = "smtp.yourdomain.com"
$smtpPort   = 587
$smtpUser   = "monitor@yourdomain.com"
$smtpPass   = "yourpassword"

# ===== Email Body Templates =====
$cpuAlertBodyTemplate  = "⚠️ CPU Alert:`nAverage CPU over the past hour is {CPU}%."
$ramAlertBodyTemplate  = "⚠️ RAM Alert:`nTotal RAM usage is {RAM}%."
$diskAlertBodyTemplate = "⚠️ Disk Space Alert:`nDisk C: free space remaining is {FREE} GB."

# ===== SQL Tables =====
$cpuTable = "cpu_metrics"
$ramTable = "ram_metrics"
$diskTable = "disk_metrics"

# ===== Helper Functions =====
function Execute-SqlNonQuery {
    param ([string]$query)
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

function Send-AlertEmail {
    param (
        [string]$Subject,
        [string]$Body
    )
    try {
        Send-MailMessage -From $emailFrom -To $emailTo -Subject $Subject -Body $Body `
            -SmtpServer $smtpServer -Port $smtpPort -Credential (New-Object System.Management.Automation.PSCredential($smtpUser, (ConvertTo-SecureString $smtpPass -AsPlainText -Force))) `
            -UseSsl -ErrorAction Stop
    } catch {
        Write-Host "Email Error: $($_.Exception.Message)"
    }
}

# ===== System Info =====
$systemInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$totalRAM = $systemInfo.TotalPhysicalMemory
$logicalCores = $systemInfo.NumberOfLogicalProcessors
$systemInfo.Dispose()

# ===== CPU History for Rolling Average =====
$cpuUsageHistory = @()

# ===== Truncate Timer Setup =====
$lastTruncateTime = Get-Date

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

        $totalCpuPercent = 0
        $procCount = 0

        foreach ($proc in $cpuData) {
            $cpuPct = [math]::Round($proc.PercentProcessorTime / $logicalCores, 2)
            $sql = "INSERT INTO $cpuTable (Timestamp, ProcessName, CPU_Usage_Percent) VALUES ('$timestamp', '$($proc.Name.Replace("'", "''"))', $cpuPct)"
            Execute-SqlNonQuery $sql

            $totalCpuPercent += $cpuPct
            $procCount++
        }
        $cpuData.Dispose()

        if ($procCount -gt 0) {
            $avgCpu = $totalCpuPercent / $procCount
            $cpuUsageHistory += [PSCustomObject]@{Timestamp=Get-Date(); CPU=$avgCpu}
        }

        # Maintain only last 1 hour of CPU history
        $cpuUsageHistory = $cpuUsageHistory | Where-Object { (New-TimeSpan -Start $_.Timestamp -End (Get-Date)).TotalHours -le 1 }
        $cpuHourAvg = ($cpuUsageHistory | Measure-Object -Property CPU -Average).Average

        if ($cpuHourAvg -gt 80) {
            $body = $cpuAlertBodyTemplate -replace "{CPU}", ([math]::Round($cpuHourAvg, 2))
            Send-AlertEmail -Subject "High CPU Alert" -Body $body
        }

    } catch {
        Write-Host "CPU Error: $($_.Exception.Message)"
    }

    # === RAM ===
    try {
        $procs = Get-Process
        $totalUsedRAM = ($procs | Measure-Object -Property WorkingSet64 -Sum).Sum
        $ramUsagePercent = [math]::Round(($totalUsedRAM / $totalRAM) * 100, 2)

        foreach ($proc in $procs) {
            $ramMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            $ramPct = if ($totalRAM -gt 0) {
                [math]::Round(($proc.WorkingSet64 / $totalRAM) * 100, 2)
            } else { 0 }
            $sql = "INSERT INTO $ramTable (Timestamp, ProcessName, RAM_Used_MB, RAM_Used_Percent) VALUES ('$timestamp', '$($proc.ProcessName.Replace("'", "''"))', $ramMB, $ramPct)"
            Execute-SqlNonQuery $sql
        }
        $procs | ForEach-Object { $_.Dispose() }

        if ($ramUsagePercent -gt 90) {
            $body = $ramAlertBodyTemplate -replace "{RAM}", $ramUsagePercent
            Send-AlertEmail -Subject "High RAM Usage Alert" -Body $body
        }

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

            if ($free -lt 10) {
                $body = $diskAlertBodyTemplate -replace "{FREE}", $free
                Send-AlertEmail -Subject "Low Disk Space Alert" -Body $body
            }

            $disk.Dispose()
        }
    } catch {
        Write-Host "Disk Error: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 5
}
