# install-mysql-8.4.11.ps1 - replace the running MySQL 8.4.8 install with the current
# 8.4 LTS package (8.4.11) and configure a fresh instance with a known root password.
#
# Nothing is deleted outright:
#   * the old 8.4.8 program files are removed through their own MSI uninstaller
#   * C:\ProgramData\MySQL\MySQL Server 8.4 is RENAMED (kept) as 8.4.8-old-<date>
# Every step is logged to E:\Hermes\DatabaseControl\mysql-reinstall-report.txt
$ErrorActionPreference = 'Continue'

$msi        = 'D:\Loaddown\mysql-8.4.11-winx64.msi'
$report     = 'E:\Hermes\DatabaseControl\mysql-reinstall-report.txt'
$oldProduct = '{692DCAD6-AE04-4A42-8ED5-12A35F5F9910}'      # MySQL Server 8.4.8
$installDir = 'C:\Program Files\MySQL\MySQL Server 8.4'
$dataRoot   = 'C:\ProgramData\MySQL\MySQL Server 8.4'
$dataDir    = Join-Path $dataRoot 'Data'
$iniPath    = Join-Path $dataRoot 'my.ini'
$rootPwd    = '123456'
$stage      = Join-Path $env:TEMP 'mysql-install'
$stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'

New-Item -ItemType Directory -Force -Path $stage | Out-Null
Set-Content -Path $report -Value ("MySQL reinstall report - " + (Get-Date) + "`r`n" + ("=" * 60)) -Encoding UTF8

function Say($t) { Write-Host $t; Add-Content -Path $report -Value $t -Encoding UTF8 }
function Run($exe, [string[]]$argList) {
    Say ("$ " + $exe + " " + ($argList -join ' '))
    $out = & $exe @argList 2>&1
    if ($out) { $out | ForEach-Object { Say ('   ' + $_) } }
    $rc = $LASTEXITCODE
    Say ("   -> exit code " + $rc)
    return $rc
}
function Sv($name) {
    $s = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($s) { return "$($s.Status)/$($s.StartType)" } else { return 'MISSING' }
}

# ---------------------------------------------------------------- 0. preflight
Say "`n=== 0. preflight ==="
Say ("MSI present : " + (Test-Path $msi) + "  (" + (Get-Item $msi -ErrorAction SilentlyContinue).Length + " bytes)")
$sig = Get-AuthenticodeSignature $msi
Say ("MSI signature: " + $sig.Status + " | signer: " + $sig.SignerCertificate.Subject)
Say ("admin        : " + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
Say ("old service  : MySQL84 = " + (Sv 'MySQL84') + "   (old version " + (Get-Item "$installDir\bin\mysqld.exe" -ErrorAction SilentlyContinue).VersionInfo.ProductVersion + ")")

# ------------------------------------------------- 1. stop + remove old service
Say "`n=== 1. stop and remove the old service ==="
if (Get-Service -Name MySQL84 -ErrorAction SilentlyContinue) {
    Run 'sc.exe' @('stop', 'MySQL84')
    Start-Sleep -Seconds 3
    Run 'sc.exe' @('delete', 'MySQL84')
    Start-Sleep -Seconds 2
}
Say ("MySQL84 now: " + (Sv 'MySQL84'))

# ------------------------------------------------------- 2. uninstall old MSI
Say "`n=== 2. remove the old program files (MSI uninstall) ==="
$uninstLog = Join-Path $stage 'uninstall-old.log'
Run 'msiexec.exe' @('/x', $oldProduct, '/qn', '/norestart', '/l*v', $uninstLog)
Say ("old product still registered? " + [bool](Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq 'MySQL Server 8.4' }))
if (Test-Path $installDir) {
    $left = @(Get-ChildItem $installDir -Force -Recurse -ErrorAction SilentlyContinue).Count
    Say ("files left in install dir: " + $left)
    if ($left -gt 0) {
        $stale = "$installDir.8.4.8-old-$stamp"
        Say ("renaming leftover install dir to: " + $stale)
        Move-Item -LiteralPath $installDir -Destination $stale -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------- 3. keep old data aside
Say "`n=== 3. keep the old data directory (rename, not delete) ==="
if (Test-Path $dataRoot) {
    $keep = Join-Path 'C:\ProgramData\MySQL' ("8.4.8-old-" + $stamp)
    Say ("renaming " + $dataRoot + "  ->  " + $keep)
    Move-Item -LiteralPath $dataRoot -Destination $keep -Force -ErrorAction SilentlyContinue
    Say ("renamed: " + (Test-Path $keep) + "   old path still there: " + (Test-Path $dataRoot))
} else {
    Say 'nothing to rename'
}

# ------------------------------------------------------------ 4. install MSI
Say "`n=== 4. install MySQL 8.4.11 (silent) ==="
New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
$msiLog = Join-Path $stage 'install-8.4.11.log'
$rc = Run 'msiexec.exe' @('/i', $msi, '/qn', '/norestart', '/l*v', $msiLog, "INSTALLDIR=$installDir")
Say ("msiexec exit: " + $rc + " (0 = ok, 3010 = ok but wants a reboot)")
$mysqld = Join-Path $installDir 'bin\mysqld.exe'
Say ("mysqld present: " + (Test-Path $mysqld) + "  version: " + (Get-Item $mysqld -ErrorAction SilentlyContinue).VersionInfo.ProductVersion)
if (-not (Test-Path $mysqld)) {
    Say "ABORT: mysqld.exe is not there - the install did not land. See $msiLog"
    Say 'DONE (with errors)'
    exit 1
}

# ------------------------------------------------------------- 5. write my.ini
Say "`n=== 5. write my.ini ==="
$ini = @"
# MySQL 8.4 configuration - written by the DatabaseControl reinstall script.
# The MySQL84 service command line passes this file via --defaults-file, so it must stay here.
[mysqld]
basedir="$($installDir -replace '\\','/')"
datadir="$($dataDir -replace '\\','/')"
port=3306

[client]
port=3306
"@
Set-Content -Path $iniPath -Value $ini -Encoding ASCII
Get-Content $iniPath | ForEach-Object { Say ('   ' + $_) }

# --------------------------------------------------------- 6. initialize datadir
Say "`n=== 6. initialize a fresh data directory (root gets an empty password for now) ==="
$initLog = Join-Path $stage 'initialize.log'
$out = & $mysqld "--defaults-file=$iniPath" '--initialize-insecure' '--console' 2>&1
$out | ForEach-Object { Say ('   ' + $_) }
Say ("data dir contents: " + @(Get-ChildItem $dataDir -Force -ErrorAction SilentlyContinue).Count + " entries")
Say ("mysql system schema present: " + (Test-Path (Join-Path $dataDir 'mysql')))

# --------------------------------------------------------- 7. register + start
Say "`n=== 7. register the Windows service ==="
Run $mysqld @('--install', 'MySQL84', "--defaults-file=$iniPath")
if (-not (Get-Service -Name MySQL84 -ErrorAction SilentlyContinue)) {
    Say 'mysqld --install did not create the service - falling back to sc.exe create'
    $bin = '"' + $mysqld + '" --defaults-file="' + $iniPath + '" MySQL84'
    Run 'sc.exe' @('create', 'MySQL84', 'binPath=', $bin, 'start=', 'demand', 'DisplayName=', 'MySQL84')
    Start-Sleep -Seconds 2
}
Run 'sc.exe' @('config', 'MySQL84', 'start=', 'demand')
Say ("service: " + (Sv 'MySQL84'))
Say ('service command line: ' + ((Get-CimInstance Win32_Service -Filter "Name='MySQL84'").PathName))

Run 'net.exe' @('start', 'MySQL84')

# ---------------------------------------------------- 8. wait until it answers
Say "`n=== 8. wait for the server to accept connections (max 60s) ==="
$mysql = Join-Path $installDir 'bin\mysql.exe'
$mysqladmin = Join-Path $installDir 'bin\mysqladmin.exe'
$up = $false
for ($i = 1; $i -le 12; $i++) {
    $ping = & $mysqladmin "--defaults-file=$iniPath" '-u' 'root' '--skip-password' 'ping' 2>&1
    Say ("   try $i : " + ($ping -join ' '))
    if (($ping -join ' ') -match 'mysqld is alive') { $up = $true; break }
    Start-Sleep -Seconds 5
}
Say ("server up: " + $up)

# ------------------------------------------------------- 9. set root password
Say "`n=== 9. set the root password ==="
if ($up) {
    $sql = "ALTER USER 'root'@'localhost' IDENTIFIED BY '$rootPwd'; FLUSH PRIVILEGES;"
    Run $mysql @("--defaults-file=$iniPath", '-u', 'root', '--skip-password', '-e', $sql)

    Say '-- verify with the password over TCP 127.0.0.1 --'
    $verify = & $mysql '-h' '127.0.0.1' '-P' '3306' '-u' 'root' "-p$rootPwd" '-e' 'SELECT VERSION() AS version; SHOW DATABASES;' 2>&1
    $verify | ForEach-Object { Say ('   ' + $_) }
    Say "-- verify socket/localhost --"
    $verify2 = & $mysql "-p$rootPwd" '-u' 'root' '-e' 'SELECT CURRENT_USER() AS whoami;' 2>&1
    $verify2 | ForEach-Object { Say ('   ' + $_) }
    Say "-- port 3306 listening? --"
    Say ((netstat -ano | Select-String ':3306\s' | Select-Object -First 3) -join "`r`n")
}

Say "`n=== 10. final state ==="
Say ("MySQL84 service : " + (Sv 'MySQL84'))
Say ("mysqld version  : " + (Get-Item $mysqld).VersionInfo.ProductVersion)
Say ("datadir         : " + $dataDir)
Say ("my.ini          : " + $iniPath)
Say ("old everything  : " + (Get-ChildItem 'C:\ProgramData\MySQL' -Directory -Filter '8.4.8-old-*' -ErrorAction SilentlyContinue).FullName)
Say "root password   : 123456"
Say 'DONE'
