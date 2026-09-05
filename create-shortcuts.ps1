# Create desktop shortcuts for database start/stop scripts.
# Filenames built from Unicode code points (ASCII-safe script, no encoding ambiguity).
$ErrorActionPreference = 'Stop'
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')

# 启(542F) 动(52A8) 数(6570) 据(636E) 库(5E93)  -> "启动数据库"
$name1 = [string][char]0x542F + [char]0x52A8 + [char]0x6570 + [char]0x636E + [char]0x5E93
# 停(505C) 止(6B62) ... -> "停止数据库"
$name2 = [string][char]0x505C + [char]0x6B62 + [char]0x6570 + [char]0x636E + [char]0x5E93

foreach ($pair in @(
    @{ Lnk = $name1; Target = 'start-databases.bat' },
    @{ Lnk = $name2; Target = 'stop-databases.bat' }
)) {
    $path = Join-Path $desktop ($pair.Lnk + '.lnk')
    $lnk = $ws.CreateShortcut($path)
    $lnk.TargetPath = 'E:\Hermes\DatabaseControl\' + $pair.Target
    $lnk.WorkingDirectory = 'E:\Hermes\DatabaseControl'
    $lnk.Description = 'Start/Stop MySQL + Oracle services (self-elevating)'
    $lnk.Save()
    Write-Host ('OK: ' + $pair.Lnk + '.lnk -> ' + $lnk.TargetPath)
}
