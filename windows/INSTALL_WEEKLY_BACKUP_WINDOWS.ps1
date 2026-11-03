# Optional, requires Windows Task Scheduler; installs a permanent copy of the script.
# No elevation is requested. Runs on Sunday 10:15 local time when the user logs on.
$ErrorActionPreference = 'Stop'
$taskName = 'CNM-Weekly-Source-Backup'
$directory = Join-Path $env:LOCALAPPDATA 'CNMSourceBackup'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$target = Join-Path $directory 'Backup-CNM.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Backup-CNM.ps1') -Destination $target -Force
$exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$args = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $target + '" -Mode Backup'
$action = New-ScheduledTaskAction -Execute $exe -Argument $args
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '10:15'
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 50)
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Weekly backup of public eight-subject GitHub fork to Documents' -Force | Out-Null
Write-Host ('Weekly task installed: ' + $taskName) -ForegroundColor Green
Write-Host 'It runs only when your Windows user session is signed in. Missed runs start when available.'
Write-Host 'It does not copy files outside the computer: please also sync backup folder to an external location.'
