# ==== CONFIGURATION ====
$outputDir = "C:\Metrics"
$outputFile = Join-Path $outputDir "CPU_Processes.csv"
$sampleInterval = 5  # in seconds

# ==== Ensure Output Directory Exists ====
if (!(Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# ==== Get CPU Core Count ====
$coreCount = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum

# ==== Initialize CSV Header if needed ====
if (!(Test-Path $outputFile)) {
    "Timestamp,Service Name,CPU Usage %,RAM Usage (MB)" | Out-File -FilePath $outputFile -Encoding UTF8
}

# ==== Function to resolve root ancestor ====
function Resolve-RootProcessName {
    param (
        [int]$targetPid,
        [hashtable]$pidMap
    )

    $visited = @{}
    $lastKnownName = $null

    while ($pidMap.ContainsKey($targetPid)) {
        $proc = $pidMap[$targetPid]
        if ($null -eq $proc -or $visited.ContainsKey($targetPid)) {
            break
        }

        $visited[$targetPid] = $true
        $lastKnownName = $proc.Name
        $targetPid = $proc.ParentId
    }

    return $lastKnownName
}

# ==== Main Loop ====
while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        # Build lookup table for PID -> { ParentId, Name }
        $processWmi = Get-CimInstance -Class Win32_Process | Select-Object ProcessId, ParentProcessId, Name
        $pidToParentInfo = @{}
        foreach ($proc in $processWmi) {
            $pidToParentInfo[$proc.ProcessId] = @{
                ParentId = $proc.ParentProcessId
                Name     = $proc.Name
            }
        }

        # First snapshot
        $procStats1 = @{}
        foreach ($p in Get-Process) {
            if ($p.CPU -ne $null) {
                $procStats1[$p.Id] = @{
                    Id   = $p.Id
                    CPU  = $p.CPU
                    RAM  = $p.WorkingSet64
                    Name = $p.ProcessName
                }
            }
        }

        Start-Sleep -Seconds $sampleInterval

        # Second snapshot
        $procStats2 = @{}
        foreach ($p in Get-Process) {
            if ($p.CPU -ne $null) {
                $procStats2[$p.Id] = @{
                    Id   = $p.Id
                    CPU  = $p.CPU
                    RAM  = $p.WorkingSet64
                    Name = $p.ProcessName
                }
            }
        }

        # Compute usage
        $usageData = @()
        foreach ($id in $procStats2.Keys) {
            if ($procStats1.ContainsKey($id)) {
                $cpuDelta = $procStats2[$id].CPU - $procStats1[$id].CPU
                $cpuPercent = [math]::Round(($cpuDelta / $sampleInterval) * 100 / $coreCount, 2)
                $ramMB = [math]::Round($procStats2[$id].RAM / 1MB, 2)

                $rootName = Resolve-RootProcessName -targetPid $id -pidMap $pidToParentInfo
                if (-not $rootName) {
                    $rootName = $procStats2[$id].Name
                }

                $usageData += [PSCustomObject]@{
                    'Service Name'   = $rootName
                    'CPU Usage %'    = $cpuPercent
                    'RAM Usage (MB)' = $ramMB
                }
            }
        }

        # Group by service, sum metrics, exclude CefSharp
        $grouped = $usageData |
            Where-Object { $_.'Service Name' -ne 'CefSharp.BrowserSubprocess' } |
            Group-Object 'Service Name' |
            ForEach-Object {
                $cpuSum = ($_.Group | Measure-Object 'CPU Usage %' -Sum).Sum
                $ramSum = ($_.Group | Measure-Object 'RAM Usage (MB)' -Sum).Sum
                [PSCustomObject]@{
                    'Service Name'   = $_.Name
                    'CPU Usage %'    = [math]::Round($cpuSum, 2)
                    'RAM Usage (MB)' = [math]::Round($ramSum, 2)
                }
            }

        # Top 3 by RAM usage
        $topUsage = $grouped | Sort-Object 'RAM Usage (MB)' -Descending | Select-Object -First 3

        # Write to CSV
        foreach ($entry in $topUsage) {
            "$timestamp,$($entry.'Service Name'),$($entry.'CPU Usage %'),$($entry.'RAM Usage (MB)')" |
                Out-File -Append -FilePath $outputFile -Encoding UTF8
        }

        # Status Message
        Write-Host "[$timestamp] Logged top 3 root services by CPU usage." -ForegroundColor Cyan
    }
    catch {
        Write-Warning "[$timestamp] Error during tracking: $_"
    }
}
