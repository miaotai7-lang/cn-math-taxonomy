@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Backup-CNM.ps1" -Mode VerifyLatest
if errorlevel 1 (
  echo.
  echo VERIFICATION FAILED. Do not use this backup for restoration.
) else (
  echo.
  echo Verification passed.
)
pause
