# Define DCS Name and Output Path
$DcsName = "Server_Metrics_PoC"
$OutputPath = "C:\PerfmonLogs\Server_Metrics_PoC"

# Create output directory if it doesn't exist
if (-Not (Test-Path -Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath
}

# Define counters to monitor
$counters = @(
    "\Processor(_Total)\% Processor Time",
    "\Memory\Available MBytes",
    "\LogicalDisk(C:)\% Free Space",
    "\PhysicalDisk(_Total)\Disk Transfers/sec"
)

# Remove existing DCS if it exists
if (Get-CounterSet -ListSet $DcsName -ErrorAction SilentlyContinue) {
    logman delete $DcsName
}

# Create the Data Collector Set
logman create counter $DcsName -f csv -o "$OutputPath\$DcsName" -si 00:00:15

# Add counters to it
foreach ($counter in $counters) {
    logman update $DcsName -c $counter
}

# Start the DCS
logman start $DcsName

Write-Host "Data Collector Set '$DcsName' created and started. Logging every 15 seconds to $OutputPath"
