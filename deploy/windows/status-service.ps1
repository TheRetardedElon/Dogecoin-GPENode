param(
    [string]$ServiceName = "DogecoinGPENode",
    [string]$BinDir = "",
    [string]$DataDir = ""
)
$ErrorActionPreference = "Continue"

# Resolve install paths robustly (installer shortcuts must not pass unexpanded NSIS vars)
if (-not $BinDir -or $BinDir -match '\$' -or -not (Test-Path (Join-Path $BinDir "dogecoin-cli.exe"))) {
    $reg = Get-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -ErrorAction SilentlyContinue
    if ($reg -and $reg.InstallPath) {
        $BinDir = Join-Path $reg.InstallPath "bin"
    } else {
        $BinDir = Join-Path ${env:ProgramFiles} "DogecoinGPENode\bin"
    }
}

if (-not $DataDir -or $DataDir -match '\$' -or $DataDir -eq '$DataDir') {
    $reg = Get-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -ErrorAction SilentlyContinue
    if ($reg -and $reg.DataDir) {
        $DataDir = $reg.DataDir
    } else {
        $DataDir = Join-Path $env:ProgramData "DogecoinGPENode"
    }
}

# Normalize
$BinDir = [System.IO.Path]::GetFullPath($BinDir)
$DataDir = [System.IO.Path]::GetFullPath($DataDir)

Write-Host "=== Paths ===" -ForegroundColor Cyan
Write-Host "BinDir:  $BinDir"
Write-Host "DataDir: $DataDir"

if (-not (Test-Path $DataDir)) {
    Write-Host "Creating data directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $DataDir "snapshots") -ErrorAction SilentlyContinue | Out-Null
}

Write-Host "=== Service ===" -ForegroundColor Cyan
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc) {
    $svc | Format-List Name, Status, StartType, DisplayName
} else {
    Write-Host "Service '$ServiceName' is not installed." -ForegroundColor Yellow
    Write-Host "Run install-service.ps1 as Administrator, or re-run setup and check 'Install as Windows Service'."
}

Write-Host "=== Process ===" -ForegroundColor Cyan
$procs = Get-Process -Name dogecoind -ErrorAction SilentlyContinue
if ($procs) {
    $procs | Format-Table Id, CPU, @{N='WorkingSetMB';E={[math]::Round($_.WorkingSet64/1MB,1)}}, Path -AutoSize
} else {
    Write-Host "No dogecoind.exe process running." -ForegroundColor Yellow
}

$cli = Join-Path $BinDir "dogecoin-cli.exe"
$daemon = Join-Path $BinDir "dogecoind.exe"
if (-not (Test-Path $cli)) {
    Write-Host "ERROR: dogecoin-cli.exe not found at $cli" -ForegroundColor Red
    exit 1
}

Write-Host "=== RPC getblockchaininfo ===" -ForegroundColor Cyan
& $cli -datadir="$DataDir" getblockchaininfo 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "RPC failed. Common causes:" -ForegroundColor Yellow
    Write-Host "  - Service not running yet (still loading block index)"
    Write-Host "  - Wrong datadir / conf"
    Write-Host "  - rpcpassword in conf does not match"
    if (Test-Path $daemon) {
        Write-Host ""
        Write-Host "Try: Start-Service $ServiceName" -ForegroundColor Cyan
        Write-Host "  or: & `"$daemon`" -datadir=`"$DataDir`"  (foreground smoke test)"
    }
}

Write-Host "=== dumptxoutset help (first lines) ===" -ForegroundColor Cyan
& $cli -datadir="$DataDir" help dumptxoutset 2>&1 | Select-Object -First 10

Write-Host ""
Write-Host "Done. Press Enter to close..." -ForegroundColor DarkGray
[void][System.Console]::ReadLine()
