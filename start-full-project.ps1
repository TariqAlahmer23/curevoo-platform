<#
.SYNOPSIS
  Starts the whole CureVoo stack: PostgreSQL, the FastAPI AI service, the Node
  backend, and the built Flutter web frontend.

.DESCRIPTION
  Each tier is started in its own window so logs stay visible during a demo.
  Ports already in use are left alone, so re-running this is safe.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File start-full-project.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File start-full-project.ps1 -SkipFrontend
#>
param(
  [switch]$SkipDatabase,
  [switch]$SkipAiService,
  [switch]$SkipBackend,
  [switch]$SkipFrontend
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$postgresContainer = "curevoo-postgres"

function Test-PortOpen {
  param([int]$Port)

  $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  return $null -ne $connection
}

function Start-Tier {
  param(
    [string]$Name,
    [int]$Port,
    [string]$WorkingDirectory,
    [string]$Command
  )

  if (Test-PortOpen -Port $Port) {
    Write-Host "  [skip]  $Name already listening on $Port" -ForegroundColor DarkGray
    return
  }

  Start-Process -FilePath "powershell" `
    -ArgumentList "-NoExit", "-Command", "Set-Location '$WorkingDirectory'; $Command" `
    -WorkingDirectory $WorkingDirectory | Out-Null

  Write-Host "  [start] $Name on $Port" -ForegroundColor Green
}

function Wait-ForPort {
  param([string]$Name, [int]$Port, [int]$TimeoutSeconds = 90)

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-PortOpen -Port $Port) { return $true }
    Start-Sleep -Milliseconds 700
  }

  Write-Host "  [warn]  $Name did not open port $Port within ${TimeoutSeconds}s" -ForegroundColor Yellow
  return $false
}

Write-Host ""
Write-Host "Starting CureVoo" -ForegroundColor Cyan
Write-Host "----------------"

# 1. PostgreSQL -------------------------------------------------------------
if (-not $SkipDatabase) {
  if (Test-PortOpen -Port 5432) {
    Write-Host "  [skip]  PostgreSQL already listening on 5432" -ForegroundColor DarkGray
  } else {
    $existing = (docker ps -a --filter "name=$postgresContainer" --format "{{.Names}}" 2>$null)
    if ($existing -eq $postgresContainer) {
      docker start $postgresContainer | Out-Null
      Write-Host "  [start] PostgreSQL container resumed" -ForegroundColor Green
    } else {
      docker run -d --name $postgresContainer `
        -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres123 -e POSTGRES_DB=curevoo `
        -p 5432:5432 postgres:16 | Out-Null
      Write-Host "  [start] PostgreSQL container created" -ForegroundColor Green
      Write-Host "  [note]  new database - run 'npm run prisma:push' in Backend/" -ForegroundColor Yellow
    }
    Wait-ForPort -Name "PostgreSQL" -Port 5432 | Out-Null
  }
}

# 2. FastAPI AI service -----------------------------------------------------
if (-not $SkipAiService) {
  Start-Tier -Name "FastAPI AI service" -Port 8001 `
    -WorkingDirectory (Join-Path $root "dip-ai-service") `
    -Command "python -m uvicorn app.api.app:app --host 127.0.0.1 --port 8001"
  Wait-ForPort -Name "FastAPI AI service" -Port 8001 | Out-Null
}

# 3. Node backend -----------------------------------------------------------
if (-not $SkipBackend) {
  Start-Tier -Name "Node backend" -Port 3000 `
    -WorkingDirectory (Join-Path $root "Backend") `
    -Command "npm start"
  Wait-ForPort -Name "Node backend" -Port 3000 | Out-Null
}

# 4. Flutter web ------------------------------------------------------------
if (-not $SkipFrontend) {
  $webRoot = Join-Path $root "Frontend\build\web"
  if (-not (Test-Path -LiteralPath $webRoot)) {
    Write-Host "  [warn]  No web build found. Run this in Frontend/ first:" -ForegroundColor Yellow
    Write-Host "          flutter build web --dart-define=API_BASE_URL=http://localhost:3000/api" -ForegroundColor Yellow
  } else {
    Start-Tier -Name "Flutter web" -Port 5173 `
      -WorkingDirectory $webRoot `
      -Command "python -m http.server 5173 --bind 127.0.0.1"
    Wait-ForPort -Name "Flutter web" -Port 5173 | Out-Null
  }
}

Write-Host ""
Write-Host "Ready" -ForegroundColor Cyan
Write-Host "-----"
Write-Host "  Frontend    http://127.0.0.1:5173"
Write-Host "  Backend     http://127.0.0.1:3000/health"
Write-Host "  AI service  http://127.0.0.1:8001/docs"
Write-Host ""
Write-Host "  Sign in     doctor@curevoo.local / Doctor@12345"
Write-Host ""
Write-Host "  Stop a tier by closing its window; stop the database with:"
Write-Host "    docker stop $postgresContainer"
Write-Host ""
