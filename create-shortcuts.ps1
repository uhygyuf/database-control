# Create desktop shortcuts for the database start/stop scripts.
# Shortcut + folder names are built from Unicode code points so this file stays
# pure ASCII (no encoding ambiguity no matter which host runs it).
# Existing loose shortcuts on the desktop are left untouched.
$ErrorActionPreference = 'Stop'
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')

# 启(542F)动(52A8)  停(505C)止(6B62)  全(5168)部(90E8)
# 数(6570)据(636E)库(5E93)  控(63A7)制(5236)  状(72B6)态(6001)
$start  = [string][char]0x542F + [char]0x52A8
$stop   = [string][char]0x505C + [char]0x6B62
$allPre = [string][char]0x5168 + [char]0x90E8
$db     = [string][char]0x6570 + [char]0x636E + [char]0x5E93
$folder = $db + [char]0x63A7 + [char]0x5236          # 数据库控制
$status = $db + [char]0x72B6 + [char]0x6001          # 数据库状态

$dir = Join-Path $desktop $folder
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$items = @(
    @{ Lnk = "$start PostgreSQL"; Target = 'start-pgsql.bat' },
    @{ Lnk = "$stop PostgreSQL";  Target = 'stop-pgsql.bat' },
    @{ Lnk = "$start MySQL";      Target = 'start-mysql.bat' },
    @{ Lnk = "$stop MySQL";       Target = 'stop-mysql.bat' },
    @{ Lnk = "$start Oracle";     Target = 'start-oracle.bat' },
    @{ Lnk = "$stop Oracle";      Target = 'stop-oracle.bat' },
    @{ Lnk = ($allPre + $start);  Target = 'start-databases.bat' },
    @{ Lnk = ($allPre + $stop);   Target = 'stop-databases.bat' },
    @{ Lnk = $status;             Target = 'status-databases.bat' }
)

foreach ($item in $items) {
    $path = Join-Path $dir ($item.Lnk + '.lnk')
    $lnk = $ws.CreateShortcut($path)
    $lnk.TargetPath = Join-Path 'E:\Hermes\DatabaseControl' $item.Target
    $lnk.WorkingDirectory = 'E:\Hermes\DatabaseControl'
    $lnk.Description = 'Start/Stop database services (self-elevating)'
    $lnk.Save()
    Write-Host ('OK: ' + $item.Lnk + '.lnk -> ' + $lnk.TargetPath)
}
Write-Host ''
Write-Host ('Shortcuts folder: ' + $dir)
