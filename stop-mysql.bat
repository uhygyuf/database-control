@echo off
title Stop MySQL
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0db-service.ps1" -Action Stop -Target mysql
echo.
echo Press any key to close...
pause >nul
