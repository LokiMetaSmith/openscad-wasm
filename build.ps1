# PowerShell script to build OpenSCAD WASM using native Docker/Podman CLI
# This is an alternative to using Make on Windows and does not require Docker Compose.

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

# Define variables
$workspacePath = (Get-Location).Path
# In PowerShell / Docker on Windows, mounting current directory is typically just $PWD, but using standard path mapping
$mountPath = $workspacePath -replace '\\', '/'

# Step 1: Download and prepare dependencies
Write-Host "`n[1/4] Preparing libraries and resources..." -ForegroundColor Yellow
& $engine run --rm -v "${mountPath}:/workspace" -w /workspace debian:bullseye-slim bash -c "apt-get update && apt-get install -y git wget tar make && make libs && make res"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to prepare libraries." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 2: Build the base Emscripten image with compiled dependencies
Write-Host "`n[2/4] Building the base Emscripten image (this will take a while)..." -ForegroundColor Yellow
& $engine build ./libs -f Dockerfile.base -t openscad/wasm-base-release --build-arg CMAKE_BUILD_TYPE=Release --build-arg MESON_BUILD_TYPE=release --build-arg 'EMSCRIPTEN_FLAGS=-fexceptions -O3' --build-arg EMSCRIPTEN_SDK_TAG=emscripten/emsdk:4.0.10
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build the base image." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 3: Build the OpenSCAD WASM image
Write-Host "`n[3/4] Building OpenSCAD WASM..." -ForegroundColor Yellow
& $engine build ./libs/openscad -f Dockerfile -t openscad/wasm-release --build-arg CMAKE_BUILD_TYPE=Release --build-arg DOCKER_TAG_BASE=openscad/wasm-base-release --build-arg 'EMSCRIPTEN_FLAGS=-fexceptions -O3'
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build the OpenSCAD WASM image." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 4: Extract the artifacts to the local build directory
Write-Host "`n[4/4] Extracting artifacts..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path .\build | Out-Null
& $engine run --rm -v "${mountPath}/build:/workspace/build" openscad/wasm-release bash -c "cp /home/build/openscad.js /workspace/build/openscad.wasm.js && cp /home/build/openscad.wasm /workspace/build/ && if [ -f /home/build/openscad.wasm.map ]; then cp /home/build/openscad.wasm.map /workspace/build/; fi"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to extract artifacts." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Build fonts JS module
Write-Host "`nBuilding fonts JS module..." -ForegroundColor Yellow
# Assuming Node/NPM is installed locally for this final wrap up step
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
