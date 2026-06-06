$ErrorActionPreference = "Stop"

Write-Host "================================="
Write-Host "HardwareMon Installer Builder"
Write-Host "================================="

# Move to installer directory
Set-Location $PSScriptRoot

# Clean staging
Write-Host "Cleaning staging folder..."

if (Test-Path "staging") {
    Remove-Item "staging" -Recurse -Force
}

New-Item -ItemType Directory -Path "staging" | Out-Null

# ─────────────────────────────────────────────────────
# Build backend executable
# ─────────────────────────────────────────────────────

Write-Host "Building backend..."

Set-Location "../flutter_gui/backend_fastapi"

pyinstaller backend.spec --clean -y
Write-Host "Backend dist contents:"
Get-ChildItem dist -Recurse

# ─────────────────────────────────────────────────────
# Build Flutter Windows release
# ─────────────────────────────────────────────────────

Write-Host "Building Flutter Windows release..."

Set-Location ".."

flutter build windows --release

# Return to installer folder
Set-Location "../installer"

# ─────────────────────────────────────────────────────
# Copy Flutter release files
# ─────────────────────────────────────────────────────

Write-Host "Copying Flutter release files..."

Copy-Item `
    "../flutter_gui/build/windows/x64/runner/Release/*" `
    "staging/" `
    -Recurse `
    -Force

# ─────────────────────────────────────────────────────
# Copy backend executable
# ─────────────────────────────────────────────────────

Write-Host "Copying backend executable..."

Copy-Item `
    "../flutter_gui/backend_fastapi/dist/backend/backend.exe" `
    "staging/backend.exe" `
    -Force

# ─────────────────────────────────────────────────────
# Set installer version
# ─────────────────────────────────────────────────────

if (-not $env:APP_VERSION) {
    $env:APP_VERSION = "dev-build"
}

Write-Host "Installer version: $env:APP_VERSION"

# ─────────────────────────────────────────────────────
# Compile installer
# ─────────────────────────────────────────────────────

Write-Host "Compiling installer..."

$inno = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
$issFile = Join-Path $PSScriptRoot "installer.iss"

if (-not (Test-Path $inno)) {
    throw "ISCC.exe not found."
}

if (-not (Test-Path $issFile)) {
    throw "installer.iss not found."
}

& $inno $issFile

if ($LASTEXITCODE -ne 0) {
    throw "Installer compilation failed."
}

Write-Host "================================="
Write-Host "BUILD COMPLETE"
Write-Host "================================="