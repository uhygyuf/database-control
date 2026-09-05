@echo off
title Stop Databases (MySQL + Oracle)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
echo === Stopping Oracle DBConsole ===
net stop OracleDBConsoleorcl
echo === Stopping OracleServiceORCL ===
net stop OracleServiceORCL
echo === Stopping Oracle TNS Listener ===
net stop OracleOraDb11g_home1TNSListener
echo === Stopping Oracle MTS Recovery ===
net stop OracleMTSRecoveryService
echo === Stopping MySQL84 ===
net stop MySQL84
echo.
echo All commands executed. Press any key to close...
pause >nul
