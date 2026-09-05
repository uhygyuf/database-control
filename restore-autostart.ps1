# Restore MySQL + Oracle services to Automatic startup (rollback of set-db-manual.ps1)
# Run this once as Administrator.
$ErrorActionPreference = 'Continue'
$services = 'MySQL84','OracleServiceORCL','OracleOraDb11g_home1TNSListener','OracleDBConsoleorcl','OracleMTSRecoveryService'
foreach ($s in $services) {
    $r = sc.exe config $s start= auto
    Write-Host ("{0,-42} -> {1}" -f $s, ($r -join ' '))
}
Write-Host ''
Write-Host 'DONE: services restored to Automatic startup.'
Start-Sleep -Seconds 2
