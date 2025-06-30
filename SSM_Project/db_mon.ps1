# ===== Configuration =====
$server = "34.250.17.80"
$database = "Metric_DB"

# ===== DB Login =====
$dbUser = "Slipstream_adm"
$dbPass = "Slip2020!"

# ===== Gmail SMTP Settings =====
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$smtpUser = "tableau@slipstreamdata.co.za"
$smtpPass = "TbU@987!"
$emailFrom = $smtpUser
$emailTo = "support@slipstreamdata.co.za"

# ===== Alert Thresholds =====
$cpuThreshold = 90
$ramThreshold = 80
$diskUsageThresholdPercent = 70

# ===== Alert Reset Settings =====
$alertResetIntervalHours = 3
$lastAlertTime = Get-Date

# ===== SQL Connection String =====
$connectionString = "Server=$server;Database=$database;User ID=$dbUser;Password=$dbPass;"

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
    }
}

# ===== Email Helper =====
function Send-AlertEmail {
    param (
        [string]$subject,
        [string]$body
    )
    try {
        $message = New-Object System.Net.Mail.MailMessage
        $message.From = $emailFrom
        $message.To.Add($emailTo)
        $message.Subject = $subject
        $message.Body = $body
        $message.IsBodyHtml = $false

        $smtp = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $smtp.EnableSsl = $true
        $smtp.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPass)
        $smtp.Send($message)

        Write-Host "Alert email sent: $subject"
    } catch {
        Write-Host "Failed to send alert email: $($_.Exception.Message)"
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

# ===== Alert State =====
$alertSent = $false

# ===== Main Loop =====
$runCounter = 0
$startTime = Get-Date
Write-Host "Monitoring started at: $startTime"

while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $runCounter++
    Write-Host "Run $runCounter at $timestamp"

    if ((New-TimeSpan -Start $lastTruncateTime -End (Get-Date)).TotalHours -ge 3) {
        Write-Host "Truncating tables..."
        Execute-SqlNonQuery "TRUNCATE TABLE $cpuTable"
        Execute-SqlNonQuery "TRUNCATE TABLE $ramTable"
        Execute-SqlNonQuery "TRUNCATE TABLE $diskTable"
        $lastTruncateTime = Get-Date
    }

    $cpuBuffer = @()
    $ramBuffer = @()
    $diskBuffer = @()

    $diskAlertTriggered = $false
    $cpuAlertTriggered = $false
    $ramAlertTriggered = $false

    # === CPU Total ===
    $totalCpu = 0
    try {
        $cpuSample = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1
        $totalCpu = [math]::Round($cpuSample.CounterSamples.CookedValue, 2)
        if ($totalCpu -ge $cpuThreshold) {
            $cpuAlertTriggered = $true
        }
    } catch {
        Write-Host "CPU Error: $($_.Exception.Message)"
    }

    # === RAM Total ===
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $freeRam = $os.FreePhysicalMemory * 1KB
        $usedRam = $totalRAM - $freeRam
        $usedRamGB = [math]::Round($usedRam / 1GB, 2)
        $totalRamGB = [math]::Round($totalRAM / 1GB, 2)
        $ramPct = if ($totalRAM -gt 0) {
            [math]::Round(($usedRam / $totalRAM) * 100, 2)
        } else { 0 }

        if ($ramPct -ge $ramThreshold) {
            $ramAlertTriggered = $true
        }
    } catch {
        Write-Host "RAM Error: $($_.Exception.Message)"
    }

    # === Disk ===
    try {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = 'C:'"
        if ($disk) {
            $totalDisk = [math]::Round($disk.Size / 1GB, 2)
            $freeDisk = [math]::Round($disk.FreeSpace / 1GB, 2)
            $usedDisk = [math]::Round($totalDisk - $freeDisk, 2)
            $diskUsedPercent = if ($totalDisk -gt 0) {
                [math]::Round(($usedDisk / $totalDisk) * 100, 2)
            } else { 0 }

            $diskBuffer += "('$timestamp', $usedDisk, $freeDisk, $totalDisk)"

            if ($diskUsedPercent -ge $diskUsageThresholdPercent) {
                $diskAlertTriggered = $true
            }
        }
    } catch {
        Write-Host "Disk Error: $($_.Exception.Message)"
    }

    # ===== Perform Alerts if Not Already Sent =====
    if (-not $alertSent) {
        if ($cpuAlertTriggered) {
            $body = "High CPU usage detected at $timestamp.`n`nTotal CPU Usage: $totalCpu%"
            Send-AlertEmail -subject "CPU Alert at $timestamp" -body $body
            $alertSent = $true
            $lastAlertTime = Get-Date
        }
        elseif ($ramAlertTriggered) {
            $body = "High RAM usage detected at $timestamp.`n`nRAM Usage: $usedRamGB GB / $totalRamGB GB ($ramPct%)"
            Send-AlertEmail -subject "RAM Alert at $timestamp" -body $body
            $alertSent = $true
            $lastAlertTime = Get-Date
        }
        elseif ($diskAlertTriggered) {
            $body = "High Disk usage detected at $timestamp.`n`nDisk Usage: $usedDisk GB / $totalDisk GB ($diskUsedPercent%)"
            Send-AlertEmail -subject "Disk Space Alert at $timestamp" -body $body
            $alertSent = $true
            $lastAlertTime = Get-Date
        }
    }

    # ===== CPU Process-Level Logging =====
    try {
        $cpuData = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process | Where-Object { $_.Name -notmatch '^Idle$|^_Total$' }
        foreach ($proc in $cpuData) {
            $cpuPct = [math]::Round($proc.PercentProcessorTime / $logicalCores, 2)
            $sql = "('$timestamp', '$($proc.Name.Replace("'", "''"))', $cpuPct)"
            $cpuBuffer += $sql
        }
    } catch {
        Write-Host "CPU Process Error: $($_.Exception.Message)"
    }

    # ===== RAM Process-Level Logging =====
    try {
        $procs = Get-Process
        foreach ($proc in $procs) {
            $ramMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            $ramPct = if ($totalRAM -gt 0) {
                [math]::Round(($proc.WorkingSet64 / $totalRAM) * 100, 2)
            } else { 0 }
            $procName = $proc.ProcessName.Replace("'", "''")
            $ramBuffer += "('$timestamp', '$procName', $ramMB, $ramPct)"
        }
    } catch {
        Write-Host "RAM Process Error: $($_.Exception.Message)"
    }

    # ===== SQL Loads =====
    if ($cpuBuffer.Count -gt 0) {
        $cpuSql = "INSERT INTO $cpuTable (Timestamp, ProcessName, CPU_Usage_Percent) VALUES " + ($cpuBuffer -join ",")
        Execute-SqlNonQuery $cpuSql
    }

    if ($ramBuffer.Count -gt 0) {
        $ramSql = "INSERT INTO $ramTable (Timestamp, ProcessName, RAM_Used_MB, RAM_Used_Percent) VALUES " + ($ramBuffer -join ",")
        Execute-SqlNonQuery $ramSql
    }

    if ($diskBuffer.Count -gt 0) {
        $diskSql = "INSERT INTO $diskTable (Timestamp, UsedSpace_GB, FreeSpace_GB, TotalSpace_GB) VALUES " + ($diskBuffer -join ",")
        Execute-SqlNonQuery $diskSql
    }

    # ===== Alert Reset Based on Time =====
    if ((New-TimeSpan -Start $lastAlertTime -End (Get-Date)).TotalHours -ge $alertResetIntervalHours) {
        Write-Host "Resetting alert flag due to time interval."
        $alertSent = $false
        $lastAlertTime = Get-Date
    }

    # ===== Alert Reset Based on Recovery =====
    $systemHealthy = ($ramPct -lt $ramThreshold) -and ($diskUsedPercent -lt $diskUsageThresholdPercent)

    if ($alertSent -and $systemHealthy) {
        Write-Host "System recovered. Resetting alert flag."
        $alertSent = $false
        $lastAlertTime = Get-Date
    }

    Start-Sleep -Seconds 5
}