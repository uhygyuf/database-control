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
