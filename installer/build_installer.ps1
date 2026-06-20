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

Set-Location "../hardwaremon_app/backend_fastapi"

pyinstaller backend.spec --clean -y
Write-Host "Backend dist contents:"
Get-ChildItem dist -Recurse

# ─────────────────────────────────────────────────────
# Build Flutter Windows release
# ─────────────────────────────────────────────────────

Write-Host "Building Flutter Windows release..."

Set-Location ".."

$flutterVersion = if ($env:APP_VERSION) {
    $env:APP_VERSION.TrimStart("v")
}
else {
    "18.0.0-dev"
}

flutter build windows --release `
    --build-name="$flutterVersion" `
    --dart-define="APP_VERSION=$flutterVersion"

# Return to installer folder
Set-Location "../installer"

# ─────────────────────────────────────────────────────
# Copy Flutter release files
# ─────────────────────────────────────────────────────

Write-Host "Copying Flutter release files..."

Copy-Item `
    "../hardwaremon_app/build/windows/x64/runner/Release/*" `
    "staging/" `
    -Recurse `
    -Force

# ─────────────────────────────────────────────────────
# Copy backend executable
# ─────────────────────────────────────────────────────

Write-Host "Copying backend executable..."

Copy-Item `
    "../hardwaremon_app/backend_fastapi/dist/backend/*" `
    "staging/" `
    -Recurse `
    -Force

# ─────────────────────────────────────────────────────
# Verify the exact staged backend layout
# ─────────────────────────────────────────────────────

Write-Host "Smoke testing staged backend..."

$backendExe = Join-Path $PSScriptRoot "staging/backend.exe"
$lhmExe = Join-Path $PSScriptRoot "staging/_internal/third_party/LibreHardwareMonitor/LibreHardwareMonitor.exe"
$stdoutLog = Join-Path $PSScriptRoot "staging-backend.stdout.log"
$stderrLog = Join-Path $PSScriptRoot "staging-backend.stderr.log"
$smokeTestPort = 18000

if (-not (Test-Path $backendExe)) {
    throw "Staged backend.exe was not found."
}

if (-not (Test-Path $lhmExe)) {
    throw "Staged LibreHardwareMonitor files were not found."
}

Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

$previousDisableLhm = $env:HARDWAREMON_DISABLE_LHM
$previousBackendPort = $env:HARDWAREMON_BACKEND_PORT
$env:HARDWAREMON_DISABLE_LHM = "1"
$env:HARDWAREMON_BACKEND_PORT = "$smokeTestPort"
$backendProcess = $null
$backendReady = $false

try {
    $backendProcess = Start-Process `
        -FilePath $backendExe `
        -WorkingDirectory (Split-Path $backendExe) `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -PassThru `
        -WindowStyle Hidden

    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        if ($backendProcess.HasExited) {
            break
        }

        try {
            $response = Invoke-WebRequest `
                -Uri "http://127.0.0.1:$smokeTestPort/" `
                -UseBasicParsing `
                -TimeoutSec 1

            if ($response.StatusCode -eq 200) {
                $backendReady = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 250
        }
    }

    if (-not $backendReady) {
        $stdout = if (Test-Path $stdoutLog) { Get-Content $stdoutLog -Raw } else { "" }
        $stderr = if (Test-Path $stderrLog) { Get-Content $stderrLog -Raw } else { "" }
        throw "Staged backend failed its health check.`nSTDOUT:`n$stdout`nSTDERR:`n$stderr"
    }
}
finally {
    if ($backendProcess -and -not $backendProcess.HasExited) {
        Stop-Process -Id $backendProcess.Id -Force
        $backendProcess.WaitForExit()
    }

    if ($null -eq $previousDisableLhm) {
        Remove-Item Env:HARDWAREMON_DISABLE_LHM -ErrorAction SilentlyContinue
    }
    else {
        $env:HARDWAREMON_DISABLE_LHM = $previousDisableLhm
    }

    if ($null -eq $previousBackendPort) {
        Remove-Item Env:HARDWAREMON_BACKEND_PORT -ErrorAction SilentlyContinue
    }
    else {
        $env:HARDWAREMON_BACKEND_PORT = $previousBackendPort
    }
}

Write-Host "Staged backend health check passed."

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
