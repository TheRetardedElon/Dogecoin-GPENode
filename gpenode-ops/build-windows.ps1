# Build gpenode-ops for Windows (after Go is installed).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$go = Get-Command go -ErrorAction SilentlyContinue
if (-not $go) {
  # Common winget install path
  $env:Path = "C:\Program Files\Go\bin;" + $env:Path
}
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
  throw "Go not on PATH. Install GoLang.Go then re-open shell."
}

go version
Write-Host "==> build gpenode-ops.exe"
$env:CGO_ENABLED = "0"
go build -ldflags="-s -w" -o gpenode-ops.exe .
Get-Item gpenode-ops.exe | Format-List Name, Length
.\gpenode-ops.exe version
.\gpenode-ops.exe help
Write-Host "==> BUILD_OK"
