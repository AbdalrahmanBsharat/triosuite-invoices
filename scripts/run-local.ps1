<#
.SYNOPSIS
    Starts the local development stack: MySQL, then the API.

.DESCRIPTION
    Neither piece is a Windows service, so neither survives a reboot. This script brings both up
    in the right order and waits for each, so getting back to a working system after restarting
    the machine is one command rather than several remembered ones.

    The API runs in the foreground: its log is on screen and Ctrl+C stops it. The MySQL instance
    is left running in the background, because the tests need it too.

.PARAMETER Port
    Port for the API. Default 8080. Use another if something already has that one.

.PARAMETER SkipBuild
    Skip the Maven build and run the existing jar. Fails if there is no jar yet.

.EXAMPLE
    .\scripts\run-local.ps1
    .\scripts\run-local.ps1 -Port 8081
    .\scripts\run-local.ps1 -Port 8081 -SkipBuild
#>
[CmdletBinding()]
param(
    [int]$Port = 8080,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $PSScriptRoot
$mysqlHome  = 'C:\Program Files\MySQL\MySQL Server 8.4'
$instance   = Join-Path $env:LOCALAPPDATA 'triosuite-mysql'
$mysqlPort  = 3307

function Write-Step  { param($m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "    $m" -ForegroundColor Green }
function Write-Info  { param($m) Write-Host "    $m" -ForegroundColor DarkGray }

function Test-Port {
    param([int]$Number)
    $null -ne (Get-NetTCPConnection -LocalPort $Number -State Listen -ErrorAction SilentlyContinue)
}

function Wait-ForPort {
    param([int]$Number, [int]$TimeoutSeconds = 60, [string]$What)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Port -Number $Number) { return $true }
        Start-Sleep -Milliseconds 500
    }
    throw "$What did not start listening on port $Number within $TimeoutSeconds seconds."
}

# ---------------------------------------------------------------------------------------
Write-Step "MySQL on port $mysqlPort"
# ---------------------------------------------------------------------------------------
if (Test-Port -Number $mysqlPort) {
    Write-Ok "already running"
} else {
    $config = Join-Path $instance 'my.ini'
    if (-not (Test-Path $config)) {
        throw @"
No development MySQL instance found at $instance.

Either create it (see database/README.md), or point the API at your own MySQL:

    `$env:DB_URL='jdbc:mysql://127.0.0.1:3306/triosuite?sslMode=DISABLED&allowPublicKeyRetrieval=true&characterEncoding=utf8&connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true'
    `$env:DB_USERNAME='root'; `$env:DB_PASSWORD='<your password>'
"@
    }

    Write-Info "starting mysqld with $config"
    Start-Process -FilePath (Join-Path $mysqlHome 'bin\mysqld.exe') `
                  -ArgumentList "--defaults-file=`"$config`"" `
                  -WindowStyle Hidden
    Wait-ForPort -Number $mysqlPort -TimeoutSeconds 60 -What 'MySQL' | Out-Null
    Write-Ok "started"
}

# ---------------------------------------------------------------------------------------
Write-Step "API port $Port"
# ---------------------------------------------------------------------------------------
if (Test-Port -Number $Port) {
    $owner = Get-NetTCPConnection -LocalPort $Port -State Listen | Select-Object -First 1
    $proc  = Get-Process -Id $owner.OwningProcess -ErrorAction SilentlyContinue
    throw "Port $Port is already taken by PID $($owner.OwningProcess) ($($proc.ProcessName)). Pass -Port with a free one, or stop that process."
}
Write-Ok "free"

# ---------------------------------------------------------------------------------------
$backend = Join-Path $repoRoot 'backend'
$jar     = Join-Path $backend 'target\triosuite-invoices-api-1.0.0.jar'

if (-not $SkipBuild) {
    Write-Step 'Building'
    Write-Info 'skip with -SkipBuild once you have a jar'
    Push-Location $backend
    try {
        & .\mvnw.cmd -B -ntp -q package -DskipTests
        if ($LASTEXITCODE -ne 0) { throw "The build failed with exit code $LASTEXITCODE." }
    } finally { Pop-Location }
    Write-Ok 'built'
}

if (-not (Test-Path $jar)) {
    throw "No jar at $jar. Run without -SkipBuild."
}

# ---------------------------------------------------------------------------------------
Write-Step 'Starting the API'
Write-Host ''
Write-Host "    Health     http://localhost:$Port/actuator/health" -ForegroundColor Green
Write-Host "    Swagger    http://localhost:$Port/swagger-ui.html" -ForegroundColor Green
Write-Host ''
Write-Host "    Sign in with  admin / Admin#2026   or   sales / Sales#2026" -ForegroundColor DarkGray
Write-Host "    For a USB phone, in another terminal:" -ForegroundColor DarkGray
Write-Host "        adb reverse tcp:$Port tcp:$Port" -ForegroundColor DarkGray
Write-Host "        cd mobile; flutter run --dart-define=API_BASE_URL=http://localhost:$Port" -ForegroundColor DarkGray
Write-Host ''
Write-Host '    Ctrl+C stops the API. MySQL keeps running.' -ForegroundColor DarkGray
Write-Host ''
# ---------------------------------------------------------------------------------------

$env:PORT = "$Port"
$env:SPRING_PROFILES_ACTIVE = 'local'

# Foreground on purpose: the log is visible and Ctrl+C is the obvious way to stop it.
& java -jar $jar
