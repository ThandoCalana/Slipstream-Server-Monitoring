# === Define Script Paths ===
$metricsScript = "C:\Users\ThandoCalana\Downloads\Powershell_Script\Collector_Script.ps1"
$cpuScript = "C:\Users\ThandoCalana\Downloads\Powershell_Script\CPU_Processes.ps1"
$ramScript = "C:\Users\ThandoCalana\Downloads\Powershell_Script\RAM_Processes.ps1"

# === Launch as Background Jobs ===
Start-Job -FilePath $metricsScript
Start-Job -FilePath $cpuScript
Start-Job -FilePath $ramScript

Write-Host "All monitoring scripts launched as background jobs."
