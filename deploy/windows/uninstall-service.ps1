#Requires -RunAsAdministrator
param(
    [string]$ServiceName = "DogecoinGPENode",
    [switch]$RemoveDataDir,
    [string]$DataDir = (Join-Path $env:ProgramData "DogecoinGPENode")
)
$ErrorActionPreference = "Stop"
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -eq "Running") {
        Write-Host "Stopping $ServiceName..."
        Stop-Service $ServiceName -Force
        Start-Sleep -Seconds 3
    }
    & sc.exe delete $ServiceName | Out-Null
    Write-Host "Service $ServiceName removed."
} else {
    Write-Host "Service $ServiceName not found."
}
if ($RemoveDataDir) {
    if (Test-Path $DataDir) {
        Write-Host "Removing $DataDir (wallets/chainstate) — irreversible for this path"
        Remove-Item -Recurse -Force $DataDir
    }
} else {
    Write-Host "Datadir kept at $DataDir (pass -RemoveDataDir to delete)."
}
