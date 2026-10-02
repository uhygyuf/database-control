# Database Control Scripts (Windows)

Start/stop the local database services **per database** — PostgreSQL, MySQL and Oracle
are independent, so you only launch what you need.

## Layout

| File | Purpose |
|------|---------|
| `db-service.ps1` | The engine: holds the service names per database and does Start / Stop / Status. The `.bat` files are thin wrappers around it. |
| `start-pgsql.bat` / `stop-pgsql.bat` | PostgreSQL only |
| `start-mysql.bat` / `stop-mysql.bat` | MySQL only |
| `start-oracle.bat` / `stop-oracle.bat` | Oracle only (4 services as one group) |
| `start-databases.bat` / `stop-databases.bat` | All three at once |
| `status-databases.bat` | Read-only status + startup type of every service (no UAC) |
| `set-db-manual.ps1` | One-time setup: set services to Manual startup (default `-Target mysql,oracle`) |
| `restore-autostart.ps1` | Rollback: set services back to Automatic (same `-Target` options) |
| `create-shortcuts.ps1` | (Re)build the desktop shortcuts folder |
| `使用说明.txt` | Chinese usage guide |

## Services

| Database | Service name | Startup |
|----------|--------------|---------|
| PostgreSQL 18 | `postgresql-x64-18` | Automatic (left as-is) |
| MySQL 8.4 | `MySQL84` | Manual |
| Oracle 11g (ORCL) | `OracleServiceORCL` | Manual |
| Oracle 11g | `OracleOraDb11g_home1TNSListener` | Manual |
| Oracle 11g | `OracleDBConsoleorcl` | Manual |
| Oracle 11g | `OracleMTSRecoveryService` | Manual |

## Usage

Double-click the `.bat` for the database you want (accept the UAC prompt — starting a
service without administrator rights fails with `error 5`). `status-databases.bat` needs
no elevation.

From an elevated shell:

```powershell
powershell -ExecutionPolicy Bypass -File db-service.ps1 -Action Start  -Target pgsql
powershell -ExecutionPolicy Bypass -File db-service.ps1 -Action Status -Target all
```

`-Action` = `Start` | `Stop` | `Status`, `-Target` = `pgsql` | `mysql` | `oracle` | `all`.

To make PostgreSQL manual as well:

```powershell
powershell -ExecutionPolicy Bypass -File set-db-manual.ps1 -Target pgsql
```

Service names are machine-specific: edit the `$Groups` table at the top of
`db-service.ps1` (and in the two startup-type scripts) before reusing this elsewhere.

## Logs

Every run overwrites `last-run.log` in this folder, so a failed run can be inspected
after the console window is closed. On a failed start the engine also prints the tail of
MySQL's `.err` log and the recent Application event-log entries — the SCM's own message
("Failed to start service") never contains the real reason.

## MySQL gotcha

`MySQL84`'s command line passes an absolute `--defaults-file="C:\ProgramData\MySQL\MySQL Server 8.4\my.ini"`.
If that file is ever removed, mysqld exits immediately and the service reports only
"Failed to start service". Keep it in place (it holds `basedir`, `datadir`, `port`).

## Installing / upgrading the server

`install-mysql-8.4.11-v2.bat` (double-click, self-elevating) replaces the server with the
current 8.4 LTS package and configures a fresh instance end to end:

1. kill stale `msiexec.exe`, remove the old service
2. silent MSI install (falls back to the official ZIP archive if the MSI does not land)
3. rename the old `C:\ProgramData\MySQL\MySQL Server 8.4` aside (never deletes it)
4. write `my.ini`, `mysqld --initialize-insecure`, register `MySQL84` as Manual, start it
5. set the root password and verify it over TCP, then print a PASS/FAIL report to
   `mysql-reinstall-report.txt`

### Pitfall: a silent MSI install that "succeeds" but installs nothing

If a `msiexec.exe` from an earlier run is still alive it holds the Windows Installer
mutex: the next `msiexec /i ... /qn` returns exit code 0, writes **no log at all**, and
installs nothing. Always kill leftover `msiexec.exe` processes before a silent install
and treat "no log file" as the symptom. Related: give `/l*v` a space-free path — an
8.3-style path such as `C:\Users\LEOWAN~1\...` can make the log fail to open.

## Inspecting a damaged data directory

`inspect-mysql.bat` is read-only: it lists what is left in the data directory, any shadow
copies, System Restore points, stray InnoDB files, and the service ACL — the checks that
decide whether an old instance can still be recovered or only rebuilt.

