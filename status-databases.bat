@echo off
title Database Status
rem Read-only: shows status + startup type of every database service. No admin needed.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0db-service.ps1" -Action Status
echo.
echo Press any key to close...
pause >nul
