$systemMetricsScript = "C:\Users\ThandoCalana\Downloads\Powershell_Script\Master_script\system.ps1"
$cpuScript = "C:\Users\ThandoCalana\Downloads\Powershell_Script\Master_script\cpu.ps1"
$ramScript = "C:\Users\ThandoCalana\Downloads\Powershell_Script\Master_script\ram.ps1"
$diskScript = "C:\Users\ThandoCalana\Downloads\Powershell_Script\Master_script\disk.ps1"

while ($true) {
    Write-Host "Starting metrics collection cycle at $(Get-Date -Format 'HH:mm:ss')..."

    # Run system metrics script and capture the inserted system_metrics.id
    $systemMetricsId = & powershell -NoProfile -File $systemMetricsScript

    if (-not [int]::TryParse($systemMetricsId, [ref]$null)) {
        Write-Error "Failed to get valid system_metrics.id from system script. Output was: $systemMetricsId"
    
        Start-Sleep -Seconds 15
        continue
    }

    Write-Host "System metrics ID: $systemMetricsId"

    # Run other scripts with the captured ID
    Write-Host "Running CPU processes script..."
    & powershell -NoProfile -File $cpuScript -SystemMetricsId $systemMetricsId

    Write-Host "Running RAM processes script..."
    & powershell -NoProfile -File $ramScript -SystemMetricsId $systemMetricsId

    Write-Host "Running Disk processes script..."
    & powershell -NoProfile -File $diskScript -SystemMetricsId $systemMetricsId

    Write-Host "Cycle complete. Waiting 15 seconds before next run..."
    Start-Sleep -Seconds 15
}
