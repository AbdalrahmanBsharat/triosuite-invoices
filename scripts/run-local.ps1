<#
.SYNOPSIS
    Starts the local development stack: MySQL, then the API.

.DESCRIPTION
    The one command that takes a fresh clone to a running API on Windows, for anyone who cannot
    use Docker.

    On its first run it creates a MySQL instance of its own - its own port, its own data directory,
    its own credentials - so it never touches a MySQL you already have, or its data. Later runs just
    start what it created. Flyway builds and seeds the schema when the API boots.

    Neither MySQL nor the API is installed as a Windows service, so neither survives a reboot; run
    this again. The API runs in the foreground so its log is on screen and Ctrl+C stops it. MySQL is
    left running in the background, because the tests need it too.

.PARAMETER Port
    Port for the API. Default 8080. Use another if something already holds that one.

.PARAMETER SkipBuild
    Run the existing jar instead of rebuilding. Fails if there is no jar yet.

.PARAMETER DatabaseOnly
    Bring MySQL up and stop there, without building or starting the API. This is what to run before
    `./mvnw verify`, since the integration tests need the database and nothing else.

.PARAMETER Reinitialize
    Delete the development MySQL instance and build a clean one. Destroys its data; the seed is
    reapplied on the next boot, so all that is lost is invoices you created yourself.

.EXAMPLE
    .\scripts\run-local.ps1
    .\scripts\run-local.ps1 -Port 8081
    .\scripts\run-local.ps1 -SkipBuild
    .\scripts\run-local.ps1 -DatabaseOnly
    .\scripts\run-local.ps1 -Reinitialize
#>
[CmdletBinding()]
param(
    [int]$Port = 8080,
    [switch]$SkipBuild,
    [switch]$DatabaseOnly,
    [switch]$Reinitialize
)

$ErrorActionPreference = 'Stop'

$repoRoot  = Split-Path -Parent $PSScriptRoot
$instance  = Join-Path $env:LOCALAPPDATA 'triosuite-mysql'
$mysqlPort = 3307

# Development-only credentials. They are the defaults compiled into the `local` and `test` Spring
# profiles, which is what lets the project run with no configuration at all. Nothing outside those
# two profiles has a default: `prod` refuses to start without DB_URL, DB_USERNAME, DB_PASSWORD and
# JWT_SECRET.
$appUser      = 'triosuite'
$appPassword  = 'triosuite_dev_pw'
$rootPassword = 'triosuite_root_dev'

function Write-Step { param($Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok   { param($Message) Write-Host "    $Message" -ForegroundColor Green }
function Write-Note { param($Message) Write-Host "    $Message" -ForegroundColor DarkGray }

function Test-PortInUse {
    param([int]$Number)
    $null -ne (Get-NetTCPConnection -LocalPort $Number -State Listen -ErrorAction SilentlyContinue)
}

function Get-PortOwner {
    param([int]$Number)
    $connection = Get-NetTCPConnection -LocalPort $Number -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $connection) { return $null }
    $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
    $name = if ($process) { $process.ProcessName } else { 'unknown' }
    [pscustomobject]@{ Id = $connection.OwningProcess; Name = $name }
}

function Wait-ForPort {
    param([int]$Number, [int]$TimeoutSeconds, [string]$What)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-PortInUse -Number $Number) { return }
        Start-Sleep -Milliseconds 500
    }
    throw "$What never started listening on port $Number after $TimeoutSeconds seconds. See $instance\error.log."
}

# Locates an installed MySQL 8. Its path is version-stamped, so search rather than hard-code one.
function Find-MysqlHome {
    $candidates = @()
    foreach ($base in "$env:ProgramFiles\MySQL", "${env:ProgramFiles(x86)}\MySQL") {
        if (Test-Path $base) {
            $candidates += Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'MySQL Server*' } |
                Sort-Object Name -Descending |
                ForEach-Object { $_.FullName }
        }
    }
    $onPath = Get-Command mysqld.exe -ErrorAction SilentlyContinue
    if ($onPath) { $candidates += Split-Path -Parent (Split-Path -Parent $onPath.Source) }

    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate 'bin\mysqld.exe')) { return $candidate }
    }
    return $null
}

function New-MysqlInstance {
    param([string]$MysqlHome)

    Write-Note "creating a development MySQL instance in $instance"
    Write-Note 'it is separate from any MySQL already on this machine, and touches none of its data'

    if (Test-Path $instance) { Remove-Item -Recurse -Force $instance }
    New-Item -ItemType Directory -Path $instance -Force | Out-Null

    $dataDir = Join-Path $instance 'data'
    $initLog = Join-Path $instance 'init.log'

    # --log-error keeps the initialiser's chatter out of the console. Left alone, mysqld writes it
    # to stderr, which PowerShell surfaces as errors even on a clean run.
    & (Join-Path $MysqlHome 'bin\mysqld.exe') --initialize-insecure `
        --basedir="$MysqlHome" --datadir="$dataDir" --log-error="$initLog"
    if ($LASTEXITCODE -ne 0) {
        if (Test-Path $initLog) { Get-Content $initLog | Write-Host }
        throw "MySQL initialisation failed with exit code $LASTEXITCODE (log: $initLog)."
    }

    # my.ini rejects unescaped backslashes, so every path in it is written with forward slashes.
    $ini = @"
[mysqld]
basedir="$($MysqlHome.Replace('\', '/'))"
datadir="$($dataDir.Replace('\', '/'))"
log-error="$($instance.Replace('\', '/'))/error.log"
port=$mysqlPort
bind-address=127.0.0.1
mysqlx=0
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
"@
    $ini | Set-Content -Path (Join-Path $instance 'my.ini') -Encoding ascii

    Write-Ok 'initialised'
}

function Start-MysqlInstance {
    param([string]$MysqlHome)
    $defaultsFile = Join-Path $instance 'my.ini'
    Start-Process -FilePath (Join-Path $MysqlHome 'bin\mysqld.exe') `
                  -ArgumentList "--defaults-file=`"$defaultsFile`"" `
                  -WindowStyle Hidden
    Wait-ForPort -Number $mysqlPort -TimeoutSeconds 120 -What 'MySQL'
}

# Runs once, straight after initialisation, while root still has no password.
function New-DatabasesAndUser {
    param([string]$MysqlHome)

    # An option file rather than -p on the command line: it keeps the password out of the process
    # list, and stops mysql.exe writing its "using a password on the command line interface can be
    # insecure" warning to stderr, which PowerShell would report as a failure.
    $optionFile = Join-Path $instance 'init-client.cnf'
    $options = @"
[client]
host=localhost
port=$mysqlPort
protocol=TCP
user=root
"@
    $options | Set-Content -Path $optionFile -Encoding ascii

    $statements = @(
        "ALTER USER 'root'@'localhost' IDENTIFIED BY '$rootPassword';",
        "CREATE DATABASE IF NOT EXISTS triosuite CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;",
        "CREATE DATABASE IF NOT EXISTS triosuite_test CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;",
        "CREATE USER IF NOT EXISTS '$appUser'@'%' IDENTIFIED BY '$appPassword';",
        "GRANT ALL PRIVILEGES ON triosuite.* TO '$appUser'@'%';",
        "GRANT ALL PRIVILEGES ON triosuite_test.* TO '$appUser'@'%';",
        "FLUSH PRIVILEGES;"
    ) -join ' '

    try {
        & (Join-Path $MysqlHome 'bin\mysql.exe') "--defaults-file=$optionFile" "--execute=$statements"
        if ($LASTEXITCODE -ne 0) {
            throw "Creating the databases failed with exit code $LASTEXITCODE (log: $instance\error.log)."
        }
    } finally {
        Remove-Item $optionFile -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------------------
Write-Step "MySQL on port $mysqlPort"
# ---------------------------------------------------------------------------------------
if ((Test-PortInUse -Number $mysqlPort) -and -not $Reinitialize) {
    Write-Ok 'already running'
} else {
    if ($Reinitialize -and (Test-PortInUse -Number $mysqlPort)) {
        $owner = Get-PortOwner -Number $mysqlPort
        throw "MySQL is still running as PID $($owner.Id). Stop it first:  Stop-Process -Id $($owner.Id)"
    }

    $mysqlHome = Find-MysqlHome
    if (-not $mysqlHome) {
        throw @"
No MySQL 8 installation found on this machine.

Install MySQL Community Server 8 from https://dev.mysql.com/downloads/mysql/ and run this again,
or point the API at a MySQL you already have:

    `$env:DB_URL='jdbc:mysql://<host>:<port>/triosuite?sslMode=DISABLED&allowPublicKeyRetrieval=true&characterEncoding=utf8&connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true'
    `$env:DB_USERNAME='<user>'
    `$env:DB_PASSWORD='<password>'
    cd backend; .\mvnw.cmd spring-boot:run

Docker skips all of this, where it runs:  docker compose up --build
"@
    }
    Write-Note "using $mysqlHome"

    if ($Reinitialize -or -not (Test-Path (Join-Path $instance 'my.ini'))) {
        New-MysqlInstance -MysqlHome $mysqlHome
        Start-MysqlInstance -MysqlHome $mysqlHome
        New-DatabasesAndUser -MysqlHome $mysqlHome
        Write-Ok 'running, with the triosuite and triosuite_test databases created'
    } else {
        Start-MysqlInstance -MysqlHome $mysqlHome
        Write-Ok 'running'
    }
}

if ($DatabaseOnly) {
    Write-Host ''
    Write-Ok "MySQL is up on 127.0.0.1:$mysqlPort  -  $appUser / $appPassword"
    Write-Host ''
    return
}

# ---------------------------------------------------------------------------------------
Write-Step "API port $Port"
# ---------------------------------------------------------------------------------------
if (Test-PortInUse -Number $Port) {
    $owner = Get-PortOwner -Number $Port
    throw "Port $Port is taken by PID $($owner.Id) ($($owner.Name)). Pass -Port with a free one, or stop that process."
}
if (-not (Get-Command java.exe -ErrorAction SilentlyContinue)) {
    throw 'No java on PATH. Install a Java 21 JDK from https://adoptium.net and open a new terminal.'
}
Write-Ok 'free'

$backend = Join-Path $repoRoot 'backend'
$jar     = Join-Path $backend 'target\triosuite-invoices-api-1.0.0.jar'

if (-not $SkipBuild) {
    Write-Step 'Building the API'
    Write-Note 'the first build downloads Maven and every dependency, so allow a few minutes'
    Write-Note 'later runs can skip it with -SkipBuild'
    Push-Location $backend
    try {
        & .\mvnw.cmd -B -ntp package -DskipTests
        if ($LASTEXITCODE -ne 0) { throw "The build failed with exit code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }
    Write-Ok 'built'
}

if (-not (Test-Path $jar)) {
    throw "There is no jar at $jar yet. Run without -SkipBuild."
}

# ---------------------------------------------------------------------------------------
Write-Step 'Starting the API'
Write-Host ''
Write-Host "    Health    http://localhost:$Port/actuator/health" -ForegroundColor Green
Write-Host "    Swagger   http://localhost:$Port/swagger-ui.html" -ForegroundColor Green
Write-Host ''
Write-Note 'Sign in as  admin / Admin#2026  or  sales / Sales#2026'
Write-Note 'For a phone on USB, in a second terminal:'
Write-Note "    adb reverse tcp:$Port tcp:$Port"
Write-Note "    cd mobile; flutter run --dart-define=API_BASE_URL=http://localhost:$Port"
Write-Host ''
Write-Note 'Ctrl+C stops the API. MySQL keeps running.'
Write-Host ''
# ---------------------------------------------------------------------------------------

$env:PORT = "$Port"
$env:SPRING_PROFILES_ACTIVE = 'local'

# Foreground on purpose: the log stays visible and Ctrl+C is the obvious way to stop it.
& java -jar $jar
