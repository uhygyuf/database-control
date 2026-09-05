@echo off
title Start Databases (MySQL + Oracle)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
echo === Starting MySQL84 ===
net start MySQL84
echo === Starting OracleServiceORCL ===
net start OracleServiceORCL
echo === Starting Oracle TNS Listener ===
net start OracleOraDb11g_home1TNSListener
echo === Starting Oracle DBConsole ===
net start OracleDBConsoleorcl
echo === Starting Oracle MTS Recovery ===
net start OracleMTSRecoveryService
echo.
echo All commands executed. Press any key to close...
pause >nul
