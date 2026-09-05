# Database Control Scripts (Windows)

Manage MySQL (MySQL84) and Oracle 11g (ORCL) services on Windows:
switch them from auto-start to manual startup, then start/stop them on demand.

## Files

| File | Purpose |
|------|---------|
| `set-db-manual.ps1` | One-time setup: set 5 services to Manual startup (run as Administrator) |
| `restore-autostart.ps1` | Rollback: restore Automatic startup |
| `start-databases.bat` | Start all DB services (self-elevating, UAC prompt) |
| `stop-databases.bat` | Stop all DB services (self-elevating, UAC prompt) |
| `create-shortcuts.ps1` | (Optional) create desktop shortcuts using Unicode code points to avoid encoding issues |
| `使用说明.txt` | Chinese usage guide |

## Affected services

- `MySQL84` — MySQL 8.4
- `OracleServiceORCL` — Oracle 11g database instance (core)
- `OracleOraDb11g_home1TNSListener` — SQL*Net listener
- `OracleDBConsoleorcl` — Enterprise Manager web console
- `OracleMTSRecoveryService` — MS DTC distributed transaction recovery

## Usage

1. Run `set-db-manual.ps1` once as Administrator (services stop auto-starting at boot;
   running services are unaffected until reboot).
2. Double-click `start-databases.bat` / `stop-databases.bat` to start/stop everything
   (accept the UAC prompt). Service names are machine-specific — adjust before reuse.
