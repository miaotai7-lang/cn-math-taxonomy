@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Backup-CNM.ps1" -Mode Backup
if errorlevel 1 (
  echo.
  echo BACKUP FAILED - preserve this window and send the error details for review.
) else (
  echo.
  echo Backup complete. Keep another copy outside this PC.
)
pause
