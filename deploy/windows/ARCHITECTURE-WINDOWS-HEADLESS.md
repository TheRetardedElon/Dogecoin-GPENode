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

## Architecture (v1)

```text
Windows Service: "DogecoinGPENode"
  ImagePath → dogecoind.exe -datadir=... -conf=...
  Restart on failure
  Runs as LocalService or dedicated user (configurable)

Local only:
  RPC 127.0.0.1
  Optional P2P listen for full node duty

Operator:
  dogecoin-cli.exe  OR  gpenode-ops.exe (when ported)
  PowerShell install/uninstall/status scripts
```

## Architecture (v2 — optional sugar)

```text
Service: dogecoind (unchanged)
Tray:    gpenode-tray.exe  (session process)
TUI:     gpenode-tui.exe   (localhost RPC, Grok-Build-like UX)
```

Tray/TUI **never** contain consensus logic.

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
| **W0** | Plan + scripts (service install around existing `dogecoind.exe`) | **Now** |
| **W1** | Package zip from win64 headless build; smoke install on a Windows box | Next |
| **W2** | Scheduled dump task (Windows Task Scheduler) + optional publish | Later |
| **W3** | Tray + operator TUI (localhost RPC only) | Later |

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
