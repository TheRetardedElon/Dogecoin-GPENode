#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install Dogecoin GPENode / Core Pro Headless as a Windows Service.

.DESCRIPTION
  dogecoind.exe is NOT a native Windows service. This installer registers
  gpenode-ops.exe service-run as the SCM entrypoint; that wrapper starts and
  stops dogecoind cleanly (RPC stop preferred).

  Same mainnet consensus — wrapper is process supervision only.
#>
param(
    [string]$BinDir = "",
    [string]$DataDir = "",
    [string]$ConfFile = "",
    [string]$ServiceName = "DogecoinGPENode",
    [string]$DisplayName = "Dogecoin GPENode (Core Pro Headless)",
    [ValidateSet("dump", "settlement")]
    [string]$Profile = "dump"
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$m) { Write-Host "[GPENode] $m" -ForegroundColor Cyan }

# Resolve BinDir: param, then script\bin, then install root\bin
if (-not $BinDir) {
    $BinDir = Join-Path $PSScriptRoot "bin"
}
if (-not (Test-Path (Join-Path $BinDir "dogecoind.exe"))) {
    $cand = Join-Path (Split-Path $PSScriptRoot -Parent) "bin"
    if (Test-Path (Join-Path $cand "dogecoind.exe")) { $BinDir = $cand }
}
$BinDir = [System.IO.Path]::GetFullPath($BinDir)

if (-not $DataDir) {
    $DataDir = Join-Path $env:ProgramData "DogecoinGPENode"
}
$DataDir = [System.IO.Path]::GetFullPath($DataDir)

$dogecoind = Join-Path $BinDir "dogecoind.exe"
$cli = Join-Path $BinDir "dogecoin-cli.exe"
$ops = Join-Path $BinDir "gpenode-ops.exe"

Write-Info "BinDir  = $BinDir"
Write-Info "DataDir = $DataDir"

if (-not (Test-Path $dogecoind)) {
    throw "Missing dogecoind.exe in $BinDir - place headless build binaries here first."
}
if (-not (Test-Path $cli)) {
    Write-Host "WARNING: dogecoin-cli.exe not found in $BinDir" -ForegroundColor Yellow
}
if (-not (Test-Path $ops)) {
    throw @"
Missing gpenode-ops.exe in $BinDir

dogecoind is not a native Windows service. The GPENode package includes
gpenode-ops.exe which implements the SCM service host (service-run).

Copy gpenode-ops.exe next to dogecoind.exe, reinstall, or use the official
win64 setup / zip from https://github.com/TheRetardedElon/Dogecoin-GPENode
"@
}

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $DataDir "snapshots") | Out-Null

if (-not $ConfFile) {
    $ConfFile = Join-Path $DataDir "dogecoin.conf"
}
$ConfFile = [System.IO.Path]::GetFullPath($ConfFile)

if (-not (Test-Path $ConfFile)) {
    $example = Join-Path $PSScriptRoot "conf\dogecoin.$Profile.conf.example"
    if (-not (Test-Path $example)) {
        $example = Join-Path $PSScriptRoot "conf\dogecoin.dump.conf.example"
    }
    if (Test-Path $example) {
        Copy-Item $example $ConfFile -Force
        Write-Info "Wrote conf from $example"
        Write-Host "  EDIT $ConfFile - set a strong rpcpassword before mainnet funds." -ForegroundColor Yellow
    } else {
        @(
            "# Dogecoin GPENode headless - EDIT ME"
            "server=1"
            "listen=1"
            "txindex=0"
            "prune=5500"
            "rpcbind=127.0.0.1"
            "rpcallowip=127.0.0.1"
            "rpcuser=gpenode"
            "rpcpassword=CHANGE_ME_LONG_RANDOM"
            "printtoconsole=0"
        ) | Set-Content -Path $ConfFile -Encoding ASCII
        Write-Info "Wrote minimal conf at $ConfFile - EDIT rpcpassword"
    }
}

# Stop / remove existing service (New-Service cannot overwrite)
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Info "Stopping existing service $ServiceName"
    if ($existing.Status -eq "Running") {
        Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
    & sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
    # Wait until SCM forgets the name
    for ($i = 0; $i -lt 15; $i++) {
        if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Seconds 1
    }
}

# ImagePath: gpenode-ops service-run supervises dogecoind (SCM protocol).
# New-Service BinaryPathName preserves embedded quotes for paths with spaces.
$binPathName = '"{0}" service-run -dogecoind="{1}" -datadir="{2}" -conf="{3}"' -f $ops, $dogecoind, $DataDir, $ConfFile
if (Test-Path $cli) {
    $binPathName += ' -cli="{0}"' -f $cli
}

Write-Info "Creating service $ServiceName"
Write-Info "ImagePath = $binPathName"

try {
    New-Service `
        -Name $ServiceName `
        -BinaryPathName $binPathName `
        -DisplayName $DisplayName `
        -StartupType Automatic `
        -Description "Dogecoin Core Pro headless node (GPENode). Same mainnet consensus; no Qt GUI. Wrapper: gpenode-ops service-run." `
        | Out-Null
} catch {
    throw "New-Service failed: $_"
}

# Restart on failure (SCM recovery)
& sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
& sc.exe failureflag $ServiceName 1 | Out-Null

# Registry for status-service.ps1
New-Item -Path "HKLM:\Software\DogecoinGPENode" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -Name "InstallPath" -Value (Split-Path $BinDir -Parent)
Set-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -Name "DataDir" -Value $DataDir
Set-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -Name "ServiceInstalled" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -Name "ServiceBinary" -Value $ops

Write-Info "Starting $ServiceName"
try {
    Start-Service $ServiceName
} catch {
    Write-Host "Start-Service failed: $_" -ForegroundColor Yellow
    Write-Host "Check Event Viewer (Application / DogecoinGPENode) or:" -ForegroundColor Yellow
    Write-Host "  & `"$ops`" service-run -dogecoind=`"$dogecoind`" -datadir=`"$DataDir`" -conf=`"$ConfFile`"" -ForegroundColor Yellow
}
Start-Sleep -Seconds 4
Get-Service $ServiceName -ErrorAction SilentlyContinue | Format-List Name, Status, StartType

Write-Host ""
Write-Info "Installed."
Write-Host "  DataDir:  $DataDir"
Write-Host "  Conf:     $ConfFile"
Write-Host "  Daemon:   $dogecoind"
Write-Host "  Wrapper:  $ops"
Write-Host "  Status:   .\status-service.ps1 -BinDir `"$BinDir`""
Write-Host ""
Write-Host "First start loads the block index (like the GUI splash). Wait a few minutes, then run status." -ForegroundColor Cyan
Write-Host "RPC is 127.0.0.1 only. Do not expose port 22555." -ForegroundColor Yellow
