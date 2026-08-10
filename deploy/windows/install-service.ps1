#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install Dogecoin GPENode / Core Pro Headless as a Windows Service.

.DESCRIPTION
  Registers dogecoind.exe with the Service Control Manager.
  Does NOT alter consensus, wallet format, or network magic.
  RPC should remain localhost (see conf examples).

.PARAMETER BinDir
  Directory containing dogecoind.exe and dogecoin-cli.exe

.PARAMETER DataDir
  Dogecoin datadir (created if missing)

.PARAMETER ConfFile
  Path to dogecoin.conf (copied from example if missing)

.PARAMETER ServiceName
  SCM service name (default DogecoinGPENode)

.PARAMETER DisplayName
  SCM display name
#>
param(
    [string]$BinDir = (Join-Path $PSScriptRoot "bin"),
    [string]$DataDir = (Join-Path $env:ProgramData "DogecoinGPENode"),
    [string]$ConfFile = "",
    [string]$ServiceName = "DogecoinGPENode",
    [string]$DisplayName = "Dogecoin GPENode (Core Pro Headless)",
    [ValidateSet("dump", "settlement")]
    [string]$Profile = "dump"
)

$ErrorActionPreference = "Stop"

function Write-Info($m) { Write-Host "[GPENode] $m" -ForegroundColor Cyan }

$dogecoind = Join-Path $BinDir "dogecoind.exe"
$cli = Join-Path $BinDir "dogecoin-cli.exe"
if (-not (Test-Path $dogecoind)) {
    throw "Missing dogecoind.exe in $BinDir — place headless build binaries here first."
}

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $DataDir "snapshots") | Out-Null

if (-not $ConfFile) {
    $ConfFile = Join-Path $DataDir "dogecoin.conf"
}
if (-not (Test-Path $ConfFile)) {
    $example = Join-Path $PSScriptRoot "conf\dogecoin.$Profile.conf.example"
    if (-not (Test-Path $example)) {
        $example = Join-Path $PSScriptRoot "..\conf\dogecoin.$Profile.conf.example"
    }
    if (Test-Path $example) {
        Copy-Item $example $ConfFile
        Write-Info "Wrote conf from $example"
        Write-Host "  EDIT $ConfFile — set a strong rpcpassword (or use cookie auth) before mainnet funds." -ForegroundColor Yellow
    } else {
        @"
# Dogecoin GPENode headless — EDIT ME
server=1
listen=1
txindex=0
prune=5500
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcuser=gpenode
rpcpassword=CHANGE_ME_LONG_RANDOM
printtoconsole=0
"@ | Set-Content -Path $ConfFile -Encoding UTF8
        Write-Info "Wrote minimal conf at $ConfFile — EDIT rpcpassword"
    }
}

# Stop existing
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Info "Stopping existing service $ServiceName"
    if ($existing.Status -eq "Running") { Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    & sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

# binPath: dogecoind with datadir + conf (absolute paths)
$binPath = "`"$dogecoind`" -datadir=`"$DataDir`" -conf=`"$ConfFile`""
Write-Info "Creating service $ServiceName"
& sc.exe create $ServiceName binPath= $binPath start= auto DisplayName= $DisplayName obj= "LocalSystem"
if ($LASTEXITCODE -ne 0) { throw "sc create failed exit=$LASTEXITCODE" }

# Recovery: restart after 5s, 10s, 30s
& sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
& sc.exe description $ServiceName "Dogecoin Core Pro headless node (GPENode). Same mainnet consensus; no Qt GUI." | Out-Null

Write-Info "Starting $ServiceName"
Start-Service $ServiceName
Start-Sleep -Seconds 3
Get-Service $ServiceName | Format-List Name, Status, StartType

Write-Host ""
Write-Info "Installed."
Write-Host "  DataDir:  $DataDir"
Write-Host "  Conf:     $ConfFile"
Write-Host "  Binary:   $dogecoind"
Write-Host "  Status:   .\status-service.ps1"
Write-Host "  CLI:      & `"$cli`" -datadir=`"$DataDir`" getblockchaininfo"
Write-Host ""
Write-Host "RPC is intended for 127.0.0.1 only. Do not expose 22555 to the internet." -ForegroundColor Yellow
