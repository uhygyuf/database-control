@echo off
title Install MySQL 8.4.11 LTS (v2: MSI, ZIP fallback)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-mysql-8.4.11-v2.ps1"
echo.
echo Report: E:\Hermes\DatabaseControl\mysql-reinstall-report.txt
echo Press any key to close...
pause >nul
