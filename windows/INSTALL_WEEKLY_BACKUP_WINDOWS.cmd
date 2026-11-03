@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL_WEEKLY_BACKUP_WINDOWS.ps1"
if errorlevel 1 (
  echo.
  echo SCHEDULE FAILED. Keep using BACKUP_NOW_WINDOWS.cmd manually.
) else (
  echo.
  echo Weekly schedule configured. Test a manual backup next.
)
pause
