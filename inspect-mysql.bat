@echo off
title MySQL Damage Report (read-only)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0inspect-mysql.ps1"
echo.
echo Report written to: E:\Hermes\DatabaseControl\mysql-damage-report.txt
echo Press any key to close...
pause >nul
