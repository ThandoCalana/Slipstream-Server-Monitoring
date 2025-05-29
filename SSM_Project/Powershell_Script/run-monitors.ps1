$scriptDir = "C:\Users\Tcala\OneDrive\Documents\Slipstream\Slipstream-Server-Monitoring\SSM_Project\Powershell_Script"

# List of scripts to run
$scripts = @(
    "cpu.ps1",
    "ram.ps1",
    "disk.ps1",
    "system.ps1"
)

foreach ($script in $scripts) {
    $scriptPath = Join-Path $scriptDir $script
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    Write-Host "Started $script"
}
