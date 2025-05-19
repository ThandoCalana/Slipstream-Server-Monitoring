# ==== CONFIGURATION ====
$collectorName = "ServerMetrics"
$outputDir = "C:\Metrics"
$sampleInterval = 10  # seconds
$outputFile = Join-Path $outputDir $collectorName

# ==== Ensure Output Directory Exists ====
if (!(Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# ==== Fetch Static System Info ====
$totalRAMBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
$totalRAMGB = [math]::Round($totalRAMBytes / 1GB, 2)

$diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
$totalDiskBytes = $diskInfo.Size
$totalDiskGB = [math]::Round($totalDiskBytes / 1GB, 2)

Write-Host "Total RAM: $totalRAMGB GB"
Write-Host "Total Disk Size (C:): $totalDiskGB GB"

# ==== Delete Existing Collector (If Exists) ====
try {
    logman stop $collectorName -ErrorAction SilentlyContinue | Out-Null
    logman delete $collectorName -ErrorAction SilentlyContinue | Out-Null
} catch {}

# ==== Create New Collector ====
$cmd = @(
    "create", "counter", "$collectorName",
    "-c",
    "`"\Processor(_Total)\% Processor Time`"",
    "`"\Memory\% Committed Bytes In Use`"",
    "`"\LogicalDisk(C:)\% Free Space`"",
    "-si", "$sampleInterval",
    "-f", "csv",
    "-o", "`"$outputFile`""
)

logman @cmd

# ==== Start Collector ====
logman start $collectorName

Write-Host "Collector '$collectorName' started."
Write-Host "Output directory: $outputDir"
Write-Host "Sampling every $sampleInterval seconds.`n"

Write-Host "Reminder:"
Write-Host "- Total RAM: $totalRAMGB GB (static)"
Write-Host "- Total Disk Size (C:): $totalDiskGB GB (static)"
Write-Host "- To get % Disk Used on C:, calculate: 100 - [% Free Space] from CSV"
