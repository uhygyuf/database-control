# Set database services to Manual startup (they no longer start at boot).
# Run once, elevated.  Default target is mysql,oracle - PostgreSQL is left alone unless asked.
#
#   powershell -ExecutionPolicy Bypass -File set-db-manual.ps1                    # mysql + oracle
#   powershell -ExecutionPolicy Bypass -File set-db-manual.ps1 -Target pgsql      # postgresql only
#   powershell -ExecutionPolicy Bypass -File set-db-manual.ps1 -Target all        # all three
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
    $r = sc.exe config $s start= demand
    Write-Host ("{0,-34} -> {1}" -f $s, ($r -join ' '))
}
Write-Host ''
Write-Host ("DONE: {0} service(s) are now set to Manual startup." -f @($services).Count)
Write-Host 'Already-running services keep running; the change takes effect after the next reboot.'
Start-Sleep -Seconds 2
