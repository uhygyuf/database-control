# Restore database services to Automatic startup (rollback of set-db-manual.ps1).
# Run once, elevated.  Default target is mysql,oracle - PostgreSQL is left alone unless asked.
#
#   powershell -ExecutionPolicy Bypass -File restore-autostart.ps1
#   powershell -ExecutionPolicy Bypass -File restore-autostart.ps1 -Target pgsql
#   powershell -ExecutionPolicy Bypass -File restore-autostart.ps1 -Target all
[CmdletBinding()]
param(
    [ValidateSet('pgsql', 'mysql', 'oracle', 'all')]
    [string[]]$Target = @('mysql', 'oracle')
)
$ErrorActionPreference = 'Continue'

$Groups = [ordered]@{
    pgsql  = @('postgresql-x64-18')
    mysql  = @('MySQL84')
    oracle = @('OracleOraDb11g_home1TNSListener',
               'OracleServiceORCL',
               'OracleDBConsoleorcl',
               'OracleMTSRecoveryService')
}

$names = if ($Target -contains 'all') { @($Groups.Keys) } else { @($Target) }
$services = foreach ($g in $names) { $Groups[$g] }

foreach ($s in $services) {
    $r = sc.exe config $s start= auto
    Write-Host ("{0,-34} -> {1}" -f $s, ($r -join ' '))
}
Write-Host ''
Write-Host ("DONE: {0} service(s) restored to Automatic startup." -f @($services).Count)
Start-Sleep -Seconds 2
