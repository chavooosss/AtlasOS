param([switch]$CopyToDesktop, [switch]$SkipBuild)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")
$Version = (Get-Content -LiteralPath (Join-Path $ProjectRoot "VERSION") -Raw).Trim()
if ($Version -notmatch '^\d+\.\d+\.\d+([.-][A-Za-z0-9.-]+)?$') {
  throw "Invalid project VERSION value: $Version"
}

if (-not $SkipBuild) {
  Write-Host "Starting AtlasOS build in WSL..."
  Write-Host "Project: $ProjectRoot"
  wsl.exe --cd "$ProjectRoot" bash -lc "bash iso/build-atlasos.sh"
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

$IsoPath = Join-Path $ProjectRoot "dist\AtlasOS-$Version\AtlasOS-$Version-live-amd64.iso"
if (-not (Test-Path -LiteralPath $IsoPath)) {
  throw "Build finished without creating the ISO: $IsoPath"
}

if (-not $CopyToDesktop) {
  Write-Host "Build complete: $IsoPath"
  Write-Host "After VM verification, run this script with -SkipBuild -CopyToDesktop."
  exit 0
}

$DesktopLatestDir = Join-Path $env:USERPROFILE "Desktop\AtlasOS\en son"
New-Item -ItemType Directory -Path $DesktopLatestDir -Force | Out-Null
$DesktopIsoPath = Join-Path $DesktopLatestDir "AtlasOS-$Version-live-amd64.iso"

foreach ($PreviousIso in Get-ChildItem -LiteralPath $DesktopLatestDir -File -Filter '*.iso') {
  $VersionMatch = [regex]::Match($PreviousIso.Name, '^AtlasOS-(0\.\d+\.\d+)')
  if (-not $VersionMatch.Success) {
    throw "Cannot archive unrecognized ISO name: $($PreviousIso.Name)"
  }
  $ArchiveDir = Join-Path (Join-Path (Split-Path -Parent $DesktopLatestDir) 'Sürümler') $VersionMatch.Groups[1].Value
  New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null
  $ArchiveIso = Join-Path $ArchiveDir $PreviousIso.Name
  if (Test-Path -LiteralPath $ArchiveIso) {
    $LatestHash = (Get-FileHash -LiteralPath $PreviousIso.FullName -Algorithm SHA256).Hash
    $ArchiveHash = (Get-FileHash -LiteralPath $ArchiveIso -Algorithm SHA256).Hash
    if ($LatestHash -eq $ArchiveHash) {
      Remove-Item -LiteralPath $PreviousIso.FullName
      $DuplicateChecksum = "$($PreviousIso.FullName).sha256"
      if (Test-Path -LiteralPath $DuplicateChecksum) { Remove-Item -LiteralPath $DuplicateChecksum }
      continue
    }
    $CopyTag = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmss')
    $ArchiveIso = Join-Path $ArchiveDir ($PreviousIso.BaseName + "-copy-$CopyTag.iso")
    if (Test-Path -LiteralPath $ArchiveIso) { throw "Refusing to overwrite archived ISO: $ArchiveIso" }
  }
  Move-Item -LiteralPath $PreviousIso.FullName -Destination $ArchiveIso
  $PreviousChecksum = "$($PreviousIso.FullName).sha256"
  if (Test-Path -LiteralPath $PreviousChecksum) {
    Move-Item -LiteralPath $PreviousChecksum -Destination "$ArchiveIso.sha256"
    $PreviousDigest = ((Get-Content -LiteralPath "$ArchiveIso.sha256" -Raw) -split '\s+')[0]
    if ($PreviousDigest -notmatch '^[0-9a-fA-F]{64}$') {
      throw "Invalid SHA-256 sidecar for archived ISO: $ArchiveIso"
    }
    $ArchivedName = [System.IO.Path]::GetFileName($ArchiveIso)
    Set-Content -LiteralPath "$ArchiveIso.sha256" -Value "$PreviousDigest  $ArchivedName" -NoNewline -Encoding ascii
  }
}

Copy-Item -LiteralPath $IsoPath -Destination $DesktopIsoPath -Force

$IsoChecksumPath = "$IsoPath.sha256"
if (-not (Test-Path -LiteralPath $IsoChecksumPath)) {
  throw "Build finished without the SHA-256 file: $IsoChecksumPath"
}
Copy-Item -LiteralPath $IsoChecksumPath -Destination "$DesktopIsoPath.sha256" -Force

$BuildHash = (Get-FileHash -LiteralPath $IsoPath -Algorithm SHA256).Hash
$DesktopHash = (Get-FileHash -LiteralPath $DesktopIsoPath -Algorithm SHA256).Hash
if ($BuildHash -ne $DesktopHash) {
  throw "The desktop ISO copy failed SHA-256 verification."
}

Write-Host "Verified ISO copied to: $DesktopIsoPath"
