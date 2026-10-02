# db-service.ps1 - one engine for starting / stopping / checking the local database services.
# One place holds the service names of every database group; the .bat files are thin
# double-click wrappers around it (they request administrator rights for you).
#
# Manual use (already-elevated shell):
#   powershell -NoProfile -ExecutionPolicy Bypass -File db-service.ps1 -Action Status
#   powershell -NoProfile -ExecutionPolicy Bypass -File db-service.ps1 -Action Start -Target pgsql
#   powershell -NoProfile -ExecutionPolicy Bypass -File db-service.ps1 -Action Stop  -Target all
#
# Target: pgsql | mysql | oracle | all      Action: Start | Stop | Status
[CmdletBinding()]
param(
    [ValidateSet('Start', 'Stop', 'Status')]
    [string]$Action = 'Status',

    [ValidateSet('pgsql', 'mysql', 'oracle', 'all')]
    [string]$Target = 'all'
)

$ErrorActionPreference = 'Continue'

# Keep a copy of every run next to the scripts so a failure can be inspected afterwards
# (the console window closes as soon as you press a key).
$transcriptOn = $false
try {
    Start-Transcript -Path (Join-Path $PSScriptRoot 'last-run.log') -Force | Out-Null
    $transcriptOn = $true
} catch { }

function Stop-RunLog {
    if ($transcriptOn) { try { Stop-Transcript | Out-Null } catch { } }
}

# Service name -> database group. Change a service name here and every wrapper follows.
$Groups = [ordered]@{
    pgsql  = @('postgresql-x64-18')
    mysql  = @('MySQL84')
    oracle = @('OracleOraDb11g_home1TNSListener',
               'OracleServiceORCL',
               'OracleDBConsoleorcl',
               'OracleMTSRecoveryService')
}

$targets = if ($Target -eq 'all') { @($Groups.Keys) } else { @($Target) }

# Everything below talks to the SCM, so it needs an elevated shell.
$isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and $Action -ne 'Status') {
    Write-Host 'This action needs administrator rights.' -ForegroundColor Red
    Write-Host 'Use the matching .bat file (it asks for elevation automatically), or open an elevated PowerShell.'
    Stop-RunLog
    exit 5
}

$problems = 0

# A failed Start only gives the SCM's generic message ("Failed to start service ...").
# Dig out the application's own reason: its newest .err log plus what it wrote to the
# Application event log in the last ten minutes.
function Show-FailureHint {
    param([string]$ServiceName)

    if ($ServiceName -like 'MySQL*') {
        $dataDir = 'C:\ProgramData\MySQL\MySQL Server 8.4\Data'
        $errLog = Get-ChildItem -Path $dataDir -Filter '*.err' -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($errLog) {
            Write-Host ("  --- last lines of {0} ---" -f $errLog.FullName) -ForegroundColor Yellow
            Get-Content -Path $errLog.FullName -Tail 15 -ErrorAction SilentlyContinue |
                ForEach-Object { Write-Host ('      ' + $_) }
        } else {
            Write-Host ("  (no readable .err log in {0} - the server may have died before opening it)" -f $dataDir) -ForegroundColor DarkYellow
        }
    }

    $ev = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddMinutes(-10) } -ErrorAction SilentlyContinue |
          Where-Object { $_.Message -match 'mysqld|MySQL|Oracle' } |
          Select-Object -First 3
    if ($ev) {
        Write-Host '  --- recent Application event log entries ---' -ForegroundColor Yellow
        foreach ($e in $ev) {
            Write-Host ("      {0} : {1}" -f $e.TimeCreated.ToString('HH:mm:ss'), ($e.Message -replace '\s+', ' '))
        }
    }
}

foreach ($group in $targets) {
    Write-Host ''
    Write-Host ("=== {0} ===" -f $group.ToUpper())
    foreach ($svc in $Groups[$group]) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if (-not $s) {
            Write-Host ("  [MISSING]   {0}" -f $svc) -ForegroundColor Yellow
            $problems++
            continue
        }
        switch ($Action) {
            'Status' {
                $colour = if ($s.Status -eq 'Running') { 'Green' } else { 'Gray' }
                Write-Host ("  {0,-34} {1,-8} startup: {2}" -f $svc, $s.Status, $s.StartType) -ForegroundColor $colour
            }
            'Start' {
                if ($s.Status -eq 'Running') {
                    Write-Host ("  [skip]      {0} - already running" -f $svc)
                } else {
                    try {
                        Start-Service -Name $svc -ErrorAction Stop
                        Write-Host ("  [started]   {0}" -f $svc) -ForegroundColor Green
                    } catch {
                        Write-Host ("  [FAILED]    {0} - {1}" -f $svc, $_.Exception.Message) -ForegroundColor Red
                        Show-FailureHint -ServiceName $svc
                        $problems++
                    }
                }
            }
            'Stop' {
                if ($s.Status -eq 'Stopped') {
                    Write-Host ("  [skip]      {0} - already stopped" -f $svc)
                } else {
                    try {
                        Stop-Service -Name $svc -Force -ErrorAction Stop
                        Write-Host ("  [stopped]   {0}" -f $svc) -ForegroundColor Green
                    } catch {
                        Write-Host ("  [FAILED]    {0} - {1}" -f $svc, $_.Exception.Message) -ForegroundColor Red
                        $problems++
                    }
                }
            }
        }
    }
}

Write-Host ''
if ($problems -gt 0) {
    Write-Host ("Finished with {0} problem(s) - see the lines marked [FAILED] / [MISSING]." -f $problems) -ForegroundColor Red
    Stop-RunLog
    exit 1
}
Write-Host 'OK.' -ForegroundColor Green
Stop-RunLog
exit 0
