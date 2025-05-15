# Variables
$setName = "Server_Metrics_PoC"
$logPath = "C:\PerfmonLogs\$setName"
$sampleInterval = 15  # seconds
$csvFile = "$logPath\$setName.blg"

# Create log directory if it doesn't exist
if (!(Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory | Out-Null
}

# Create a new Data Collector Set
$counterSet = New-Object -ComObject Pla.DataCollectorSet
$counterSet.DisplayName = $setName
$counterSet.RootPath = $logPath

# Define Performance Counters
$counters = @(
    "\Processor(_Total)\% Processor Time",
    "\Memory\Available MBytes",
    "\LogicalDisk(C:)\% Free Space",
    "\LogicalDisk(C:)\Disk Transfers/sec"
)

# Add Performance Counter Data Collector
$collector = $counterSet.DataCollectors.CreateDataCollector(0)  # 0 = plaPerformanceCounter
$collector.Name = "$setName-Collector"
$collector.FileName = $setName
$collector.FileNameFormat = 3  # CSV
$collector.LogAppend = $true
$collector.SampleInterval = $sampleInterval
$collector.LogFileFormat = 2  # CSV

# Set the counters
$collector.PerformanceCounters = $counters
$collector.SetFileName($setName)

# Add the collector to the set
$counterSet.DataCollectors.Add($collector)

# Save the Data Collector Set
$counterSet.Commit("$env:COMPUTERNAME\$setName", "", 0)

# Start the Data Collector Set
$counterSet.Start($true)
Write-Output "Data Collector Set '$setName' started. Logging every $sampleInterval seconds to $logPath"
