param(
    [string]$ServiceName = "DogecoinGPENode",
    [string]$BinDir = (Join-Path $PSScriptRoot "bin"),
    [string]$DataDir = (Join-Path $env:ProgramData "DogecoinGPENode")
)
$ErrorActionPreference = "Continue"
Write-Host "=== Service ===" -ForegroundColor Cyan
Get-Service -Name $ServiceName -ErrorAction SilentlyContinue | Format-List *
Write-Host "=== Process ===" -ForegroundColor Cyan
Get-Process -Name dogecoind -ErrorAction SilentlyContinue | Format-Table Id, CPU, WorkingSet64, Path -AutoSize
$cli = Join-Path $BinDir "dogecoin-cli.exe"
if (Test-Path $cli) {
    Write-Host "=== RPC getblockchaininfo ===" -ForegroundColor Cyan
    & $cli -datadir=$DataDir getblockchaininfo 2>&1
    Write-Host "=== dumptxoutset help (first lines) ===" -ForegroundColor Cyan
    & $cli -datadir=$DataDir help dumptxoutset 2>&1 | Select-Object -First 8
} else {
    Write-Host "dogecoin-cli.exe not in $BinDir"
}
