# Dogecoin GPENode / Core Pro Headless — Windows

## Goal

Ship a **Windows product line** of Core Pro DNA that:

- Runs **`dogecoind` only** (no Qt / no Core Pro desktop shell)
- Installs as a **Windows Service** (always-on, restartable)
- Speaks **same mainnet consensus**, same wallet/RPC semantics, same dump path
- Never invents a second ledger or trust model

Optional later: tray icon + operator TUI over localhost RPC (sugar). **Not** required for v1.

## Non-negotiables (do not break)

| Surface | Rule |
|---------|------|
| Consensus | Unchanged C++ validation (AuxPoW, DigiShield, subsidy, scripts) |
| Network | Same P2P mainnet |
| Coins / wallet | Same keys, addresses, RPC wallet behavior |
| Fast Sync clients | Same dump format + hash fail-closed |
| Ecosystem | Interops with Core Pro GUI packages and other operators |

Headless = **packaging + process model**, not a protocol fork.

## Architecture (v1 — shipping)

```text
Windows Service: "DogecoinGPENode"
  ImagePath → gpenode-ops.exe service-run -dogecoind=... -datadir=... -conf=...
  (dogecoind is NOT a native SCM service; wrapper supervises it)
  Restart on failure (SCM recovery)

Local only:
  RPC 127.0.0.1
  Optional P2P listen for full node duty

Operator CLI:
  gpenode-ops.exe status | service | dump | verify-cdn
  dogecoin-cli.exe
  PowerShell install/uninstall/status scripts
```

## Architecture (v2 / W3 — tray + TUI)

```text
Service: gpenode-ops service-run → dogecoind  (unchanged)
Tray:    gpenode-tray.exe  (session process, dogecoin.ico)
TUI:     later — richer console UX over localhost RPC
```

Tray/TUI **never** contain consensus logic.

### Tray menu (now)

- Tooltip phases: OFFLINE / INIT / IBD / SYNCED  
- Refresh status · open status window · data folder · conf  
- Start/stop service (may need Admin) · Quit tray (service keeps running)

## Build source

| Artifact | Source |
|----------|--------|
| `dogecoind.exe`, `dogecoin-cli.exe` | dogedev MinGW/depends **or** CI, configured **without GUI product** (`--without-gui` / no qt package) |
| Install scripts | this kit `deploy/windows/` |
| Conf examples | Profile A dump / Profile B settlement |

## Release layout (target)

```text
dogecoin-gpenode-win64-<ver>.zip
  bin/dogecoind.exe
  bin/dogecoin-cli.exe
  conf/dogecoin.dump.conf.example
  conf/dogecoin.settlement.conf.example
  install-service.ps1
  uninstall-service.ps1
  status-service.ps1
  README.txt
  SHA256SUMS.txt
```

## Phases

| Phase | Deliverable | Status |
|-------|-------------|--------|
| **W0** | Plan + scripts (service install) | **Done** |
| **W1** | win64 zip + NSIS setup on GitHub Releases; service smoke | **Done** |
| **W2** | Scheduled dump task (Windows Task Scheduler) + optional publish | Later |
| **W3a** | Operator CLI phases + `gpenode-ops service` | **Now** |
| **W3b** | Tray icon (`gpenode-tray`) + product icon | **Now** |
| **W3c** | Richer TUI (optional) | Later |

## Failure / recovery (“never die” ops)

- Service **Restart** on failure (SCM recovery)
- Datadir survives process death — restart same binary family
- No consensus change if service wrapper is replaced
- Operators can always fall back to manual `dogecoind.exe -datadir=...`

## Explicit non-goals (v1)

- Full Core Pro Qt in this package  
- Rewriting dogecoind in Go/Rust  
- Public RPC by default  
- GPE API dependency  
