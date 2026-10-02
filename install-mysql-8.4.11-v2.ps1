# install-mysql-8.4.11-v2.ps1 - install the current 8.4 LTS server and configure it.
#
# Path A: the official MSI already downloaded to D:\Loaddown (silent install)
# Path B: if the MSI does not land, download the official ZIP and unpack it instead
# Both paths end at the same place: C:\Program Files\MySQL\MySQL Server 8.4 + a fresh
# data directory + service MySQL84 + root password 123456.
#
# Nothing is deleted: the previous 8.4.8 install and its data directory were already
# renamed aside (see the earlier report) before this script runs.
$ErrorActionPreference = 'Continue'

$msi        = 'D:\Loaddown\mysql-8.4.11-winx64.msi'
$zip        = 'D:\Loaddown\mysql-8.4.11-winx64.zip'
$zipUrl     = 'https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11-winx64.zip'
$report     = 'E:\Hermes\DatabaseControl\mysql-reinstall-report.txt'
$msiLog     = 'C:\ProgramData\mysql8-msi-install.log'
$installDir = 'C:\Program Files\MySQL\MySQL Server 8.4'
$dataRoot   = 'C:\ProgramData\MySQL\MySQL Server 8.4'
$dataDir    = Join-Path $dataRoot 'Data'
$iniPath    = Join-Path $dataRoot 'my.ini'
$rootPwd    = '123456'
$mysqld     = Join-Path $installDir 'bin\mysqld.exe'

Set-Content -Path $report -Value ("MySQL reinstall report v2 - " + (Get-Date) + "`r`n" + ("=" * 60)) -Encoding UTF8
function Say($t) { Write-Host $t; Add-Content -Path $report -Value $t -Encoding UTF8 }
function Verdict($label, $ok) {
    $tag = 'FAIL'
    if ($ok) { $tag = 'PASS' }
    Say ("  [" + $tag + "] " + $label)
}
function Vers { if (Test-Path $mysqld) { (Get-Item $mysqld).VersionInfo.ProductVersion } else { 'not installed' } }

# --------------------------------------------------------------- 0. clear the way
Say "`n=== 0. clear stale installer processes ==="
Get-Process msiexec -ErrorAction SilentlyContinue | ForEach-Object { Say ("  killing stale msiexec pid " + $_.Id); $_ | Stop-Process -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2
Say ("  msiexec left: " + @(Get-Process msiexec -ErrorAction SilentlyContinue).Count)

# ---------------------------------------------------- 1. try the MSI (path A)
Say "`n=== 1. MSI install (path A) ==="
Remove-Item $msiLog -Force -ErrorAction SilentlyContinue
$argLine = '/i "' + $msi + '" /qn /norestart /l*v "' + $msiLog + '" INSTALLDIR="' + $installDir + '"'
Say ("  $ msiexec " + $argLine)
$p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argLine -Wait -PassThru -NoNewWindow
Say ("  msiexec exit code: " + $p.ExitCode)
if (Test-Path $msiLog) {
    Select-String -Path $msiLog -Pattern 'Installation success or error status|MainEngineThread is returning|Windows Installer installed the product|could not be opened|1603|1622|1925' -ErrorAction SilentlyContinue |
        Select-Object -Last 6 | ForEach-Object { Say ('  log: ' + $_.Line.Trim()) }
} else { Say '  no MSI log was written' }
Verdict ('mysqld.exe present after MSI (' + (Vers) + ')') (Test-Path $mysqld)

# ---------------------------------------------------- 2. fall back to the ZIP
if (-not (Test-Path $mysqld)) {
    Say "`n=== 2. ZIP install (path B, fallback) ==="
    if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 280000000) {
        Say ("  downloading " + $zipUrl)
        & 'C:\Windows\System32\curl.exe' '-L' '--fail' '--retry' '3' '--retry-delay' '3' '-o' $zip $zipUrl 2>&1 |
            Select-Object -Last 3 | ForEach-Object { Say ('  curl: ' + $_) }
    }
    Say ("  zip size: " + (Get-Item $zip -ErrorAction SilentlyContinue).Length + " bytes")
    $extract = 'C:\Program Files\MySQL'
    Say ("  extracting to " + $extract)
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $inner = Join-Path $extract 'mysql-8.4.11-winx64'
    if (Test-Path $inner) {
        if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue }
        Move-Item -LiteralPath $inner -Destination $installDir -Force
    }
    Verdict ('mysqld.exe present after ZIP (' + (Vers) + ')') (Test-Path $mysqld)
}

if (-not (Test-Path $mysqld)) {
    Say "`nABORT: no server binaries. Nothing else was changed."
    Say 'DONE (with errors)'
    exit 1
}

# ------------------------------------------------------------- 3. write my.ini
Say "`n=== 3. write my.ini ==="
New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
$ini = @"
# MySQL 8.4 configuration - written by the DatabaseControl install script.
# The MySQL84 service command line passes this file via --defaults-file, so keep it here.
[mysqld]
basedir="$($installDir -replace '\\','/')"
datadir="$($dataDir -replace '\\','/')"
port=3306

[client]
port=3306
"@
Set-Content -Path $iniPath -Value $ini -Encoding ASCII
Get-Content $iniPath | ForEach-Object { Say ('   ' + $_) }

# --------------------------------------------------------- 4. initialize datadir
Say "`n=== 4. initialize a fresh data directory ==="
if (Test-Path (Join-Path $dataDir 'mysql')) {
    Say '  data directory already initialized - leaving it alone'
} else {
    $out = & $mysqld "--defaults-file=$iniPath" '--initialize-insecure' '--console' 2>&1
    $out | ForEach-Object { Say ('   ' + $_) }
}
Verdict 'mysql system schema exists' (Test-Path (Join-Path $dataDir 'mysql'))

# --------------------------------------------------------- 5. register + start
Say "`n=== 5. register and start the service ==="
if (Get-Service -Name MySQL84 -ErrorAction SilentlyContinue) {
    Say '  removing the old service entry first'
    & sc.exe delete MySQL84 | ForEach-Object { Say ('   ' + $_) }
    Start-Sleep -Seconds 2
}
& $mysqld '--install' 'MySQL84' "--defaults-file=$iniPath" 2>&1 | ForEach-Object { Say ('  ' + $_) }
if (-not (Get-Service -Name MySQL84 -ErrorAction SilentlyContinue)) {
    Say '  mysqld --install did not register it - using sc.exe create'
    $bin = '"' + $mysqld + '" --defaults-file="' + $iniPath + '" MySQL84'
    & sc.exe create MySQL84 binPath= $bin start= demand DisplayName= MySQL84 | ForEach-Object { Say ('  ' + $_) }
    Start-Sleep -Seconds 2
}
& sc.exe config MySQL84 start= demand | ForEach-Object { Say ('  ' + $_) }
Say ('  service now: ' + (Get-Service MySQL84 -ErrorAction SilentlyContinue).Status + ' / ' + (Get-Service MySQL84 -ErrorAction SilentlyContinue).StartType)
Say ('  service command line: ' + (Get-CimInstance Win32_Service -Filter "Name='MySQL84'").PathName)
& net.exe start MySQL84 2>&1 | ForEach-Object { Say ('  ' + $_) }

# ---------------------------------------------------- 6. wait until it answers
Say "`n=== 6. wait for the server (max 60s) ==="
$mysql = Join-Path $installDir 'bin\mysql.exe'
$mysqladmin = Join-Path $installDir 'bin\mysqladmin.exe'
$up = $false
for ($i = 1; $i -le 12; $i++) {
    $ping = & $mysqladmin '-u' 'root' '--skip-password' 'ping' 2>&1
    Say ("   try $i : " + (($ping | Out-String).Trim()))
    if (($ping | Out-String) -match 'mysqld is alive') { $up = $true; break }
    Start-Sleep -Seconds 5
}
Verdict 'server answers mysqladmin ping' $up

# ------------------------------------------------------- 7. set root password
Say "`n=== 7. set the root password ==="
if ($up) {
    & $mysql '-u' 'root' '--skip-password' '-e' "ALTER USER 'root'@'localhost' IDENTIFIED BY '$rootPwd'; FLUSH PRIVILEGES;" 2>&1 |
        ForEach-Object { Say ('  ' + $_) }
    Say '  -- verify with the password over TCP 127.0.0.1 --'
    & $mysql '-h' '127.0.0.1' '-P' '3306' '-u' 'root' "-p$rootPwd" '-e' 'SELECT VERSION() AS version; SELECT CURRENT_USER() AS whoami; SHOW DATABASES;' 2>&1 |
        ForEach-Object { Say ('  ' + $_) }
    Say '  -- port 3306 listening --'
    (netstat -ano | Select-String ':3306\s' | Select-Object -First 3) | ForEach-Object { Say ('  ' + $_) }
}

# ------------------------------------------------------------- 8. final state
Say "`n=== 8. final state ==="
Say ('  MySQL84 service : ' + (Get-Service MySQL84 -ErrorAction SilentlyContinue).Status + ' / ' + (Get-Service MySQL84 -ErrorAction SilentlyContinue).StartType)
Say ('  mysqld version  : ' + (Vers))
Say ('  datadir         : ' + $dataDir)
Say ('  my.ini          : ' + $iniPath)
Say ('  root password   : ' + $rootPwd)
Say ('  old 8.4.8 kept  : ' + ((Get-ChildItem 'C:\ProgramData\MySQL' -Directory -Filter '8.4.8-old-*' -ErrorAction SilentlyContinue).FullName -join ', '))
Say 'DONE'
