# Windows — Dogecoin GPENode / Core Pro Headless

Headless **Windows Service** + operator **TUI/tray** for the same mainnet consensus as Core Pro.

| Product | Package |
|---------|---------|
| Core Pro GUI | `dogecoin-qt` (Dogecoin-Takeback) |
| **GPENode Headless** | **`dogecoind` + service + TUI** (this folder / GitHub Releases) |

## Screenshots

See the [root README](../../README.md) for TUI screenshots (home, overview, dump, dump-profile wallet note).

## Install (release)

Download from [Releases](https://github.com/TheRetardedElon/Dogecoin-GPENode/releases):

- **`dogecoin-gpenode-*-win64-setup.exe`** — recommended  
- or **`dogecoin-gpenode-win64-*-gpenode-headless.zip`**

### Unique RPC password

Every **new** install generates a **cryptographically random** `rpcpassword` (no shared default).

1. Wizard shows user + password  
2. You must check “I have saved this password…”  
3. Written to:

```text
%ProgramData%\DogecoinGPENode\dogecoin.conf
%ProgramData%\DogecoinGPENode\RPC-CREDENTIALS.txt
```

Existing conf is **not** overwritten on reinstall.

## Dump profile (default)

Windows install uses **Profile dump** by default:

- Optimized for **Fast Sync snapshot production** (`dumptxoutset`)  
- Wallet usually **disabled** (`disablewallet=1`) — expected  
- Pruned / bounded disk is common  
- RPC localhost-only for TUI / ops  

**Settlement profile** (optional): enable wallet + different conf for private app RPC.  
Examples: `conf/dogecoin.dump.conf.example` · `conf/dogecoin.settlement.conf.example`

## Service model

`dogecoind.exe` is **not** a native Windows service.

| Process | Role |
|---------|------|
| Service `DogecoinGPENode` | SCM entry: `gpenode-ops.exe service-run …` |
| `dogecoind.exe` | Real node (child of the wrapper) |
| `gpenode-tui.exe` | Operator UI (optional, session) |
| `gpenode-tray.exe` | Tray icon (optional, session) |

```powershell
cd "C:\Program Files\DogecoinGPENode"
powershell -ExecutionPolicy Bypass -File .\install-service.ps1 -Profile dump
.\status-service.ps1
.\bin\gpenode-tui.exe
```

## Portable / dev layout

```text
deploy/windows/
  bin/                 dogecoind, cli, gpenode-ops, tray, tui
  conf/*.example
  install-service.ps1
  status-service.ps1
  uninstall-service.ps1
  write-install-conf.ps1
  gen-rpc-password.ps1
  setup-gpenode-headless.nsi
```

```powershell
cd deploy\windows
powershell -ExecutionPolicy Bypass -File .\install-service.ps1 -Profile dump -BinDir .\bin
```

## Safety

- Default conf binds RPC to **127.0.0.1** only  
- Unique password per install — still do not expose RPC publicly  
- Service restart does not rewrite the chain — datadir is source of truth  
- Uninstall without `-RemoveDataDir` keeps wallets/chainstate  

## Build installer (maintainers)

```bash
# WSL — after bins are in deploy/windows/bin/
bash deploy/windows/build-installer.sh
# → out/windows-headless/dogecoin-gpenode-*-win64-setup.exe
```
