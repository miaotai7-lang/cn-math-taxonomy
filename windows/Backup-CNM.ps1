# Windows PowerShell 5.1+, requires Git for Windows. No GitHub token needed for public fork.
# This backs up SOURCE and GIT HISTORY, NOT browser localStorage or Firebase data.
param(
  [ValidateSet('Backup','VerifyLatest')]
  [string]$Mode = 'Backup',
  [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CNM_Source_Backups')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = 'https://github.com/miaotai7-lang/cn-math-taxonomy.git'
$required = @('index.html','LICENSE','.nojekyll','manifest.webmanifest','sw.js',
              'data/topics.json','data/questions.json','data/dependencies.json',
              'data/cn-curriculum-standards.json','data/id-aliases.json',
              'explore/index.html','diagnose/index.html','children/index.html')

function Invoke-GitChecked([string[]]$GitArgs) {
  & git.exe @GitArgs
  if ($LASTEXITCODE -ne 0) { throw ('Git command failed with exit code ' + $LASTEXITCODE + ': git ' + ($GitArgs -join ' ')) }
}

function CheckZip([string]$ZipPath) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $paths = @{}
    foreach ($entry in $archive.Entries) { $paths[$entry.FullName] = $true }
    foreach ($item in $required) {
      if (-not $paths.ContainsKey($item)) { throw ('ZIP is missing required site file: ' + $item) }
    }
    foreach ($item in @('data/topics.json','data/questions.json','data/dependencies.json','data/cn-curriculum-standards.json','data/id-aliases.json')) {
      $entry = $archive.GetEntry($item)
      if ($entry.Length -le 0) { throw ('Empty dataset in ZIP: ' + $item) }
      $stream = $entry.Open()
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
      try { $null = ConvertFrom-Json -InputObject $reader.ReadToEnd() }
      finally { $reader.Dispose() }
    }
  }
  finally { $archive.Dispose() }
}

function VerifyFolder([string]$Folder) {
  $manifestPath = Join-Path $Folder 'manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Missing manifest.json' }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $zipPath = Join-Path $Folder $manifest.snapshot_file
  $bundlePath = Join-Path $Folder $manifest.bundle_file
  $filesToVerify = @(
    [pscustomobject]@{ Path = $zipPath; ExpectedHash = $manifest.snapshot_sha256 },
    [pscustomobject]@{ Path = $bundlePath; ExpectedHash = $manifest.bundle_sha256 }
  )
  foreach ($info in $filesToVerify) {
    if (-not (Test-Path -LiteralPath $info.Path)) { throw ('Missing backup file: ' + $info.Path) }
    $actual = (Get-FileHash -LiteralPath $info.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $info.ExpectedHash.ToLowerInvariant()) { throw ('SHA256 mismatch: ' + $info.Path) }
  }
  CheckZip $zipPath
  $temp = Join-Path $env:TEMP ('CNM-Verify-' + [guid]::NewGuid().ToString('N'))
  try {
    Invoke-GitChecked -GitArgs @('clone','--quiet','--branch','main',$bundlePath,$temp)
    $restoreSha = (& git -C $temp rev-parse refs/heads/main).Trim()
    if ($LASTEXITCODE -ne 0 -or $restoreSha -ne $manifest.main_commit) {
      throw ('Recovered Git bundle has incorrect main SHA: ' + $restoreSha)
    }
  }
  finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
  Write-Host ('PASS: ZIP and Git history restored successfully. Stable SHA: ' + $manifest.main_commit) -ForegroundColor Green
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'Git for Windows was not found. Install Git and open a NEW CMD window.'
}
if (-not (Test-Path -LiteralPath $BackupRoot)) {
  New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
}
$BackupRoot = (Resolve-Path -LiteralPath $BackupRoot).Path

if ($Mode -eq 'VerifyLatest') {
  $candidate = Get-ChildItem -LiteralPath $BackupRoot -Directory |
    Where-Object { $_.Name -like 'cnm-*' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'manifest.json')) } |
    Sort-Object Name -Descending | Select-Object -First 1
  if ($null -eq $candidate) { throw ('No backup was found under ' + $BackupRoot) }
  Write-Host ('Verifying: ' + $candidate.FullName)
  VerifyFolder $candidate.FullName
  exit 0
}

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$folder = Join-Path $BackupRoot ('cnm-' + $stamp)
$tempMirror = Join-Path $env:TEMP ('CNM-Mirror-' + [guid]::NewGuid().ToString('N'))
$completed = $false
try {
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
  Write-Host 'Cloning only your OWN public GitHub fork...'
  Invoke-GitChecked -GitArgs @('clone','--quiet','--mirror',$repo,$tempMirror)
  $sha = (& git -C $tempMirror rev-parse refs/heads/main).Trim()
  if ($LASTEXITCODE -ne 0 -or $sha -notmatch '^[0-9a-f]{40}$') { throw 'Could not identify stable main SHA' }
  $short = $sha.Substring(0,12)
  $zipName = 'cnm-main-' + $short + '.zip'
  $bundleName = 'cnm-history-' + $short + '.bundle'
  $zipPath = Join-Path $folder $zipName
  $bundlePath = Join-Path $folder $bundleName
  Invoke-GitChecked -GitArgs @('-C',$tempMirror,'archive','--format=zip',('--output=' + $zipPath),'refs/heads/main')
  Invoke-GitChecked -GitArgs @('-C',$tempMirror,'bundle','create',$bundlePath,'--all')
  Invoke-GitChecked -GitArgs @('-C',$tempMirror,'bundle','verify',$bundlePath)
  CheckZip $zipPath

  $manifest = [ordered]@{
    repository = $repo
    stable_branch = 'main'
    main_commit = $sha
    created_utc = ([DateTime]::UtcNow.ToString('o'))
    snapshot_file = $zipName
    snapshot_sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    bundle_file = $bundleName
    bundle_sha256 = (Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
    note = 'Source and Git history only; localStorage, child profiles and Firebase data not included.'
  }
  $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $folder 'manifest.json') -Encoding UTF8
  VerifyFolder $folder
  $completed = $true
  Write-Host ('COMPLETE: backup folder ' + $folder) -ForegroundColor Green
  Write-Host 'Copy the ENTIRE backup folder to an external disk or independent cloud account.'
}
finally {
  if (Test-Path -LiteralPath $tempMirror) { Remove-Item -LiteralPath $tempMirror -Recurse -Force }
  if (-not $completed -and (Test-Path -LiteralPath $folder)) {
    Write-Warning 'Incomplete backup was not accepted; deleting partial output folder.'
    Remove-Item -LiteralPath $folder -Recurse -Force
  }
}
