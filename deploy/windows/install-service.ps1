#Requires -RunAsAdministrator
# Install Dogecoin GPENode / Core Pro Headless as a Windows Service.
# dogecoind is NOT a native SCM service; gpenode-ops service-run is the entrypoint.
# ASCII-only script for max Windows PowerShell compatibility.
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

function Write-InstallLog([string]$DataDir, [string]$Msg) {
    try {
        $logDir = Join-Path $DataDir "logs"
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        $log = Join-Path $logDir ("install-{0}.log" -f (Get-Date -Format "yyyyMMdd"))
        $line = "{0}Z {1}" -f (Get-Date).ToUniversalTime().ToString("s"), $Msg
        Add-Content -Path $log -Value $line -Encoding ASCII
    } catch { }
}

function Show-UserError([string]$DataDir, [string]$Title, [string]$Detail) {
    Write-InstallLog $DataDir $Detail
    $logDir = Join-Path $DataDir "logs"
    Write-Host ""
    Write-Host "ERROR: $Title" -ForegroundColor Red
    Write-Host $Detail -ForegroundColor Yellow
    Write-Host "Log folder: $logDir" -ForegroundColor Cyan
    Write-Host ""
}

try {
    # Resolve BinDir
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
    Write-InstallLog $DataDir "install-service start BinDir=$BinDir"

    if (-not (Test-Path $dogecoind)) {
        throw "Missing dogecoind.exe in $BinDir"
    }
    if (-not (Test-Path $cli)) {
        Write-Host "WARNING: dogecoin-cli.exe not found in $BinDir" -ForegroundColor Yellow
    }
    if (-not (Test-Path $ops)) {
        throw "Missing gpenode-ops.exe in $BinDir (required Windows service host)"
    }

    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $DataDir "snapshots") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $DataDir "logs") | Out-Null

    if (-not $ConfFile) {
        $ConfFile = Join-Path $DataDir "dogecoin.conf"
    }
    $ConfFile = [System.IO.Path]::GetFullPath($ConfFile)

    if (-not (Test-Path $ConfFile)) {
        # Unique password - never a shared default
        $writer = Join-Path $PSScriptRoot "write-install-conf.ps1"
        $gen = Join-Path $PSScriptRoot "gen-rpc-password.ps1"
        $example = Join-Path $PSScriptRoot "conf\dogecoin.$Profile.conf.example"
        if (-not (Test-Path $example)) {
            $example = Join-Path $PSScriptRoot "conf\dogecoin.dump.conf.example"
        }
        $pass = $null
        if (Test-Path $gen) {
            $pass = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gen | Out-String).Trim()
        }
        if (-not $pass) {
            $bytes = New-Object byte[] 28
            [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
            $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            $pass = -join ($bytes | ForEach-Object { $chars[$_ % 62] })
        }
        if (Test-Path $writer) {
            $argsList = @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $writer,
                "-DataDir", $DataDir, "-RpcPassword", $pass, "-RpcUser", "gpenode", "-Profile", $Profile
            )
            if (Test-Path $example) {
                $argsList += @("-ExampleConf", $example)
            }
            $p = Start-Process -FilePath "powershell.exe" -ArgumentList $argsList -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -ne 0) { throw "write-install-conf.ps1 failed exit=$($p.ExitCode)" }
            Write-Info "Wrote conf with unique rpcpassword"
            Write-Host "  Credentials: $(Join-Path $DataDir 'RPC-CREDENTIALS.txt')" -ForegroundColor Yellow
        } else {
            # Minimal ASCII conf, UTF-8 no BOM
            $lines = @(
                "# Dogecoin GPENode headless - unique credentials"
                "server=1"
                "listen=1"
                "txindex=0"
                "prune=5500"
                "rpcbind=127.0.0.1"
                "rpcallowip=127.0.0.1"
                "rpcuser=gpenode"
                "rpcpassword=$pass"
                "printtoconsole=0"
                "disablewallet=1"
            )
            $enc = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllLines($ConfFile, $lines, $enc)
            Write-Info "Wrote minimal conf with unique rpcpassword"
        }
    } else {
        # Strip BOM if present (fixes prior installs)
        $bytes = [System.IO.File]::ReadAllBytes($ConfFile)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $text = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
            $enc = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($ConfFile, $text, $enc)
            Write-Info "Stripped UTF-8 BOM from existing dogecoin.conf"
            Write-InstallLog $DataDir "Stripped BOM from $ConfFile"
        }
    }

    # Stop / remove existing service
    $existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Info "Stopping existing service $ServiceName"
        if ($existing.Status -eq "Running") {
            Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        & sc.exe delete $ServiceName | Out-Null
        Start-Sleep -Seconds 2
        for ($i = 0; $i -lt 15; $i++) {
            if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) { break }
            Start-Sleep -Seconds 1
        }
    }

    $binPathName = '"{0}" service-run -dogecoind="{1}" -datadir="{2}" -conf="{3}"' -f $ops, $dogecoind, $DataDir, $ConfFile
    if (Test-Path $cli) {
        $binPathName += ' -cli="{0}"' -f $cli
    }

    Write-Info "Creating service $ServiceName"
    Write-Info "ImagePath = $binPathName"
    Write-InstallLog $DataDir "Creating service ImagePath=$binPathName"

    New-Service `
        -Name $ServiceName `
        -BinaryPathName $binPathName `
        -DisplayName $DisplayName `
        -StartupType Automatic `
        -Description "Dogecoin Core Pro headless node (GPENode). Same mainnet consensus; no Qt GUI." `
        | Out-Null

    & sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
    & sc.exe failureflag $ServiceName 1 | Out-Null

    New-Item -Path "HKLM:\Software\DogecoinGPENode" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -Name "InstallPath" -Value (Split-Path $BinDir -Parent)
    Set-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -Name "DataDir" -Value $DataDir
    Set-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -Name "ServiceInstalled" -Value 1 -Type DWord
    Set-ItemProperty -Path "HKLM:\Software\DogecoinGPENode" -Name "ServiceBinary" -Value $ops

    Write-Info "Starting $ServiceName"
    try {
        Start-Service $ServiceName
        Write-InstallLog $DataDir "Start-Service OK"
    } catch {
        Write-Host "Start-Service failed: $_" -ForegroundColor Yellow
        Write-InstallLog $DataDir "Start-Service failed: $_"
        Write-Host "Check Event Viewer or logs under $DataDir\logs" -ForegroundColor Yellow
        Write-Host "Manual: $ops service-run -dogecoind=$dogecoind -datadir=$DataDir -conf=$ConfFile" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 4
    Get-Service $ServiceName -ErrorAction SilentlyContinue | Format-List Name, Status, StartType

    Write-Host ""
    Write-Info "Installed."
    Write-Host "  DataDir:  $DataDir"
    Write-Host "  Conf:     $ConfFile"
    Write-Host "  Daemon:   $dogecoind"
    Write-Host "  Wrapper:  $ops"
    Write-Host "  Logs:     $(Join-Path $DataDir 'logs')"
    Write-Host "  Status:   status-service.ps1 or gpenode-tui.exe"
    Write-Host ""
    Write-Host "First start loads the block index. Wait a few minutes, then check status." -ForegroundColor Cyan
    Write-Host "RPC is 127.0.0.1 only. Do not expose port 22555." -ForegroundColor Yellow
    Write-InstallLog $DataDir "install-service COMPLETE"
    exit 0
} catch {
    $dd = $DataDir
    if (-not $dd) { $dd = Join-Path $env:ProgramData "DogecoinGPENode" }
    Show-UserError $dd "Service install failed" $_.Exception.Message
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
