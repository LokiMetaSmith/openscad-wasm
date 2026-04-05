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

# Step 1: Build the multi-stage image
Write-Host "`n[1/2] Building the OpenSCAD WASM image (this will take a while)..." -ForegroundColor Yellow
& $engine build . -f Dockerfile.windows -t openscad/wasm-release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build the image." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 2: Extract the artifacts to the local build directory
Write-Host "`n[2/2] Extracting artifacts..." -ForegroundColor Yellow

$workspacePath = (Get-Location).Path
$mountPath = $workspacePath -replace '\\', '/'
New-Item -ItemType Directory -Force -Path .\build | Out-Null

& $engine run --rm -v "${mountPath}/build:/workspace/build" openscad/wasm-release bash -c "cp /home/build/build/openscad.js /workspace/build/openscad.js && cp /home/build/build/openscad.wasm /workspace/build/ && if [ -f /home/build/build/openscad.wasm.map ]; then cp /home/build/build/openscad.wasm.map /workspace/build/; fi"
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
