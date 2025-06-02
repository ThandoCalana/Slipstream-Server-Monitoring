$scripts = @(
    "C:\Users\Tcala\OneDrive\Documents\Slipstream\Slipstream-Server-Monitoring\SSM_Project\Powershell_Script\CSV\system.ps1",
    "C:\Users\Tcala\OneDrive\Documents\Slipstream\Slipstream-Server-Monitoring\SSM_Project\Powershell_Script\CSV\ram.ps1",
    "C:\Users\Tcala\OneDrive\Documents\Slipstream\Slipstream-Server-Monitoring\SSM_Project\Powershell_Script\CSV\cpu.ps1",
    "C:\Users\Tcala\OneDrive\Documents\Slipstream\Slipstream-Server-Monitoring\SSM_Project\Powershell_Script\CSV\disk.ps1"
)

# ==== Start each script as a background job ====
$jobs = @()
foreach ($script in $scripts) {
    if (Test-Path $script) {
        $jobs += Start-Job -ScriptBlock {
            param($path)
            & $path
        } -ArgumentList $script
    } else {
        Write-Host "Script not found: $script"
    }
}

Write-Host "Started all monitoring scripts as background jobs."

# ==== Optionally monitor jobs and wait indefinitely ====
while ($true) {
    foreach ($job in $jobs) {
        if ($job.State -ne 'Running') {
            Write-Host "Job $($job.Id) stopped unexpectedly. Restarting..."
            # Restart the job
            $scriptPath = $job.ChildJobs[0].Command
            $jobs = $jobs | Where-Object { $_.Id -ne $job.Id }
            $jobs += Start-Job -ScriptBlock {
                param($path)
                & $path
            } -ArgumentList $scriptPath
        }
    }
    Start-Sleep -Seconds 60
}
