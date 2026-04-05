# PowerShell script to build OpenSCAD WASM using Docker Compose
# This is an alternative to using Make on Windows.

Write-Host "Starting OpenSCAD WASM build process for Windows..." -ForegroundColor Cyan

# Check for Podman first, fallback to Docker
$engine = ""
if (Get-Command "podman" -ErrorAction SilentlyContinue) {
    $engine = "podman"
    Write-Host "Using podman as the container engine." -ForegroundColor Green
} elseif (Get-Command "docker" -ErrorAction SilentlyContinue) {
    $engine = "docker"
    Write-Host "Using docker as the container engine." -ForegroundColor Green
} else {
    Write-Host "Error: Neither podman nor docker is installed or in PATH." -ForegroundColor Red
    exit 1
}

# Step 1: Download and prepare dependencies
Write-Host "`n[1/4] Preparing libraries and resources..." -ForegroundColor Yellow
& $engine compose run --rm prepare
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to prepare libraries." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 2: Build the base Emscripten image with compiled dependencies
Write-Host "`n[2/4] Building the base Emscripten image (this will take a while)..." -ForegroundColor Yellow
& $engine compose build base-build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build the base image." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 3: Build the OpenSCAD WASM image
Write-Host "`n[3/4] Building OpenSCAD WASM..." -ForegroundColor Yellow
& $engine compose build wasm-build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build the OpenSCAD WASM image." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 4: Extract the artifacts to the local build directory
Write-Host "`n[4/4] Extracting artifacts..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path .\build | Out-Null
& $engine compose run --rm extract
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to extract artifacts." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Build fonts JS module
Write-Host "`nBuilding fonts JS module..." -ForegroundColor Yellow
# Assuming Node/NPM is installed locally for this final wrap up step (or we could run it in docker too)
if (Get-Command "npm" -ErrorAction SilentlyContinue) {
    Push-Location .\runtime
    npm install
    npm run build
    Pop-Location
    Copy-Item .\runtime\dist\* .\build\
} else {
    Write-Host "npm not found. Skipping runtime build." -ForegroundColor DarkYellow
}

Write-Host "`nBuild completed successfully! Artifacts are in the 'build' directory." -ForegroundColor Green
