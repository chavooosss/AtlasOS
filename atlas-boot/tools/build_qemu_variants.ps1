$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$output = Join-Path $root '..\dist\validation\atlas-boot\phase6\finalvisual\qemu'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$targets = @('1920x1080', '1368x768', '1280x720')
foreach ($target in $targets) {
    $env:ATLAS_BOOT_TARGET = $target
    cargo build --release --no-default-features --features uefi-app --target x86_64-unknown-uefi --bin AtlasBootManager --manifest-path (Join-Path $root 'Cargo.toml')
    if ($LASTEXITCODE -ne 0) { throw "UEFI build failed for $target" }
    $artifactTarget = $target
    if ($target -eq '1368x768') { $artifactTarget = '1366x768' }
    $dest = Join-Path $output "AtlasBootManager-$artifactTarget.efi"
    Copy-Item -LiteralPath (Join-Path $root 'target\x86_64-unknown-uefi\release\AtlasBootManager.efi') -Destination $dest -Force
    Write-Output "$dest"
}
Remove-Item Env:\ATLAS_BOOT_TARGET -ErrorAction SilentlyContinue
