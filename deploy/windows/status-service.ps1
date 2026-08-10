param(
    [string]$ServiceName = "DogecoinGPENode",
    [string]$BinDir = "",
    [string]$DataDir = "",
    [switch]$NoWait
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
$procs = Get-Process -Name dogecoind, gpenode-ops, gpenode-tray -ErrorAction SilentlyContinue
if ($procs) {
    $procs | Format-Table Id, ProcessName, @{N='WorkingSetMB';E={[math]::Round($_.WorkingSet64/1MB,1)}}, Path -AutoSize
} else {
    Write-Host "No dogecoind / gpenode-ops process running." -ForegroundColor Yellow
}

$cli = Join-Path $BinDir "dogecoin-cli.exe"
$daemon = Join-Path $BinDir "dogecoind.exe"
$ops = Join-Path $BinDir "gpenode-ops.exe"
if (-not (Test-Path $cli)) {
    Write-Host "ERROR: dogecoin-cli.exe not found at $cli" -ForegroundColor Red
    if (-not $NoWait) {
        Write-Host "Press Enter to close..." -ForegroundColor DarkGray
        [void][System.Console]::ReadLine()
    }
    exit 1
}

# Prefer operator CLI when present (cleaner phases)
if (Test-Path $ops) {
    Write-Host "=== gpenode-ops status ===" -ForegroundColor Cyan
    $env:DOGECOIN_CLI = $cli
    $env:DOGECOIN_DATADIR = $DataDir
    & $ops status 2>&1
    Write-Host ""
}

Write-Host "=== RPC getblockchaininfo ===" -ForegroundColor Cyan
$rpcOut = & $cli -datadir="$DataDir" getblockchaininfo 2>&1 | Out-String
$rpcCode = $LASTEXITCODE
Write-Host $rpcOut

if ($rpcCode -ne 0) {
    $warm = $rpcOut -match 'error code: -28|Loading block index|Verifying blocks|Loading wallet'
    Write-Host ""
    if ($warm) {
        Write-Host "PHASE: INIT (warmup)" -ForegroundColor Yellow
        Write-Host "Node is loading the block index (same as GUI splash)." -ForegroundColor Yellow
        Write-Host "Service/process can be Running while RPC returns -28. Wait 1-2 min and re-run." -ForegroundColor Yellow
    } else {
        Write-Host "PHASE: OFFLINE / RPC failed" -ForegroundColor Red
        Write-Host "Common causes:" -ForegroundColor Yellow
        Write-Host "  - Service not installed or not running"
        Write-Host "  - Wrong datadir / conf"
        Write-Host "  - rpcpassword in conf does not match"
        if (Test-Path $daemon) {
            Write-Host ""
            Write-Host "Try: Start-Service $ServiceName" -ForegroundColor Cyan
            if (Test-Path $ops) {
                Write-Host "  or: & `"$ops`" service start" -ForegroundColor Cyan
            }
        }
    }
} else {
    if ($rpcOut -match '"initialblockdownload"\s*:\s*true') {
        Write-Host "PHASE: IBD (syncing mainnet)" -ForegroundColor Cyan
    } else {
        Write-Host "PHASE: SYNCED (or nearly)" -ForegroundColor Green
    }
}

Write-Host "=== dumptxoutset help (first lines) ===" -ForegroundColor Cyan
& $cli -datadir="$DataDir" help dumptxoutset 2>&1 | Select-Object -First 8

Write-Host ""
if (-not $NoWait) {
    Write-Host "Done. Press Enter to close..." -ForegroundColor DarkGray
    [void][System.Console]::ReadLine()
}
