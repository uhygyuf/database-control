# Set MySQL + Oracle services to Manual startup (no longer auto-start at boot)
# Run this once as Administrator (this file is launched elevated).
$ErrorActionPreference = 'Continue'
$services = 'MySQL84','OracleServiceORCL','OracleOraDb11g_home1TNSListener','OracleDBConsoleorcl','OracleMTSRecoveryService'
foreach ($s in $services) {
    $r = sc.exe config $s start= demand
    Write-Host ("{0,-42} -> {1}" -f $s, ($r -join ' '))
}
Write-Host ''
Write-Host 'DONE: services above are now set to Manual. Already-running services keep running; change takes effect after reboot.'
Start-Sleep -Seconds 2
