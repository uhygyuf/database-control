# inspect-mysql.ps1 - READ-ONLY damage assessment for the MySQL 8.4 data directory.
# Changes nothing: no deletes, no writes outside its own report file.
# Produces E:\Hermes\DatabaseControl\mysql-damage-report.txt
$ErrorActionPreference = 'Continue'
$report = 'E:\Hermes\DatabaseControl\mysql-damage-report.txt'
$dataDir = 'C:\ProgramData\MySQL\MySQL Server 8.4\Data'

function Say($t) { Write-Host $t; Add-Content -Path $report -Value $t -Encoding UTF8 }

Set-Content -Path $report -Value ("MySQL damage report - " + (Get-Date) + "`r`n" + ("=" * 60)) -Encoding UTF8

Say ''
Say '### 1. What is left in the data directory ###'
if (Test-Path $dataDir) {
    $items = Get-ChildItem -LiteralPath $dataDir -Force -Recurse -ErrorAction SilentlyContinue
    Say ("items found: " + @($items).Count)
    foreach ($i in $items | Sort-Object FullName) {
        $kind = if ($i.PSIsContainer) { 'DIR ' } else { 'FILE' }
        Say ("  {0}  {1,12} bytes  {2:yyyy-MM-dd HH:mm}  {3}" -f $kind, $i.Length, $i.LastWriteTime, $i.FullName.Replace($dataDir, ''))
    }
    foreach ($must in 'auto.cnf', 'mysql.ibd', 'ibdata1', '#ib_16384_0.dblwr') {
        Say ("  present check: {0,-20} {1}" -f $must, (Test-Path (Join-Path $dataDir $must)))
    }
    Say ("  present check: {0,-20} {1}" -f 'mysql\ (system schema)', (Test-Path (Join-Path $dataDir 'mysql')))
} else {
    Say '  data directory does not exist at all'
}

Say ''
Say '### 2. Shadow copies (a snapshot from before the loss would be recoverable) ###'
$sh = & vssadmin.exe list shadows 2>&1
if ($sh) { $sh | ForEach-Object { Say ('  ' + $_) } } else { Say '  vssadmin returned nothing' }

Say ''
Say '### 3. System Restore points ###'
$rp = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
if ($rp) { $rp | ForEach-Object { Say ('  ' + $_.CreationTime + '  ' + $_.Description + '  seq=' + $_.SequenceNumber) } }
else { Say '  none (Get-ComputerRestorePoint gave nothing)' }

Say ''
Say '### 4. Stray copies of InnoDB files elsewhere (D:/E: only) ###'
foreach ($root in 'D:\', 'E:\') {
    $hits = Get-ChildItem -LiteralPath $root -Force -Recurse -Include '*.ibd', 'ibdata1', 'auto.cnf' -ErrorAction SilentlyContinue |
            Select-Object -First 25
    foreach ($h in $hits) { Say ("  {0}  {1:yyyy-MM-dd HH:mm}  {2}" -f $h.Length, $h.LastWriteTime, $h.FullName) }
}
Say '  (end of stray search)'

Say ''
Say '### 5. my.ini / installer leftovers ###'
foreach ($p in 'C:\ProgramData\MySQL\MySQL Server 8.4\my.ini', 'C:\ProgramData\MySQL Installer for Windows', 'C:\Windows.old') {
    Say ("  {0,-55} {1}" -f $p, (Test-Path $p))
}

Say ''
Say '### 6. Service account + ACL of the data directory ###'
Say ((& sc.exe qc MySQL84 2>&1) -join "`r`n")
try { Say ((Get-Acl -LiteralPath $dataDir).AccessToString) } catch { Say ('  ACL read failed: ' + $_.Exception.Message) }
Say ((& icacls.exe $dataDir 2>&1) -join "`r`n")

Say ''
Say 'DONE - nothing was modified.'
