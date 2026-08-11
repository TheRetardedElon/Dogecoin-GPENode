@echo off
REM Launch GPENode status maximized. Prefer PowerShell; fall back to gpenode-ops / TUI.
setlocal
set "INST=%~dp0"
set "BIN=%INST%bin"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "STATUS=%INST%status-service.ps1"
set "TUI=%BIN%\gpenode-tui.exe"
set "OPS=%BIN%\gpenode-ops.exe"
set "LOGDIR=%ProgramData%\DogecoinGPENode\logs"

if not exist "%LOGDIR%" mkdir "%LOGDIR%" 2>nul

if exist "%PS%" if exist "%STATUS%" (
  start "GPENode Status" /MAX "%PS%" -NoExit -NoProfile -ExecutionPolicy Bypass -WindowStyle Maximized -File "%STATUS%" -BinDir "%BIN%"
  exit /b 0
)

REM PowerShell missing or blocked - open TUI if present
if exist "%TUI%" (
  start "GPENode TUI" /MAX "%TUI%"
  exit /b 0
)

REM Last resort: ops status in cmd
if exist "%OPS%" (
  start "GPENode Status" /MAX cmd.exe /k "cd /d "%BIN%" && gpenode-ops.exe status && echo. && echo Press any key to close... && pause >nul"
  exit /b 0
)

echo GPENode: could not find PowerShell status script or TUI. >> "%LOGDIR%\launch-errors.log"
echo GPENode launch failed. See %LOGDIR%\launch-errors.log
notepad "%LOGDIR%\launch-errors.log"
exit /b 1
