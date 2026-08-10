# Build gpenode-tray.exe (Windows systray).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:Path = "C:\Program Files\Go\bin;" + $env:Path
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
  throw "Go not on PATH"
}

$assets = Join-Path $PSScriptRoot "assets"
New-Item -ItemType Directory -Force -Path $assets | Out-Null
$icoSrc = @(
  "C:\dogedev\share\pixmaps\dogecoin.ico",
  "C:\dogedev\src\qt\res\icons\dogecoin.ico",
  "C:\dogedevGPEnode\share\pixmaps\dogecoin.ico"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $icoSrc) { throw "dogecoin.ico not found" }
Copy-Item $icoSrc (Join-Path $assets "dogecoin.ico") -Force
Write-Host "icon: $icoSrc"

go version
go get github.com/energye/systray@latest
go mod tidy
$env:CGO_ENABLED = "0"
go build -ldflags="-s -w -H windowsgui" -o gpenode-tray.exe .
Get-Item gpenode-tray.exe | Format-List Name, Length
Write-Host "==> BUILD_OK gpenode-tray.exe"
