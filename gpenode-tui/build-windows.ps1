# Build gpenode-tui.exe (console TUI — keep console subsystem for terminal UI)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$env:Path = "C:\Program Files\Go\bin;" + $env:Path
if (-not (Get-Command go -ErrorAction SilentlyContinue)) { throw "Go not on PATH" }

go version
go get github.com/charmbracelet/bubbletea@v1.2.4
go get github.com/charmbracelet/lipgloss@v1.0.0
go mod tidy
$env:CGO_ENABLED = "0"
# NOTE: do NOT use -H windowsgui — this is a real terminal UI
go build -ldflags="-s -w" -o gpenode-tui.exe .
Get-Item gpenode-tui.exe | Format-List Name, Length
Write-Host "==> BUILD_OK gpenode-tui.exe"
Write-Host "Run in a real terminal (Windows Terminal / conhost): .\gpenode-tui.exe"
