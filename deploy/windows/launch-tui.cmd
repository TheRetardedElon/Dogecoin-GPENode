@echo off
REM Launch GPENode TUI maximized (works without PowerShell).
setlocal
set "TUI=%~dp0bin\gpenode-tui.exe"
set "LOGDIR=%ProgramData%\DogecoinGPENode\logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" 2>nul

if exist "%TUI%" (
  start "GPENode" /MAX "%TUI%"
  exit /b 0
)

echo gpenode-tui.exe not found at %TUI% >> "%LOGDIR%\launch-errors.log"
echo GPENode TUI missing. See %LOGDIR%\launch-errors.log
if exist "%SystemRoot%\System32\notepad.exe" notepad "%LOGDIR%\launch-errors.log"
exit /b 1
