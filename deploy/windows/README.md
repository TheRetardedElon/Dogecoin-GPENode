# Windows — Dogecoin GPENode / Core Pro Headless

## Is this where we want to go?

**Yes.** Next product cut after Linux headless:

| Product | Package |
|---------|---------|
| Core Pro GUI | `dogecoin-qt` Windows installer (Dogecoin-Takeback) |
| **GPENode / Core Pro Headless** | **`dogecoind` as Windows Service** (this folder) |

Same consensus, coins, wallet rules, network. **No Qt product surface** in this package.

## Phase W0 (here now)

Scripts that register an existing `dogecoind.exe` as a Windows Service:

| Script | Role |
|--------|------|
| `install-service.ps1` | Admin install + auto-start + restart recovery |
| `uninstall-service.ps1` | Remove service (optional datadir wipe) |
| `status-service.ps1` | SCM + RPC smoke |
| `conf/*.example` | Dump vs settlement profiles |

## What you need first

A **headless** Windows build of Core Pro DNA:

```text
dogecoind.exe
dogecoin-cli.exe
```

Built from dogedev with GUI product not required for this package (`--without-gui` / winbuild without shipping qt).  
Place them in `deploy/windows/bin/` next to these scripts (or pass `-BinDir`).

## Install (elevated PowerShell)

```powershell
cd deploy\windows
# copy binaries into .\bin\
mkdir bin
copy path\to\dogecoind.exe bin\
copy path\to\dogecoin-cli.exe bin\

# edit conf after first install if needed
powershell -ExecutionPolicy Bypass -File .\install-service.ps1 -Profile dump

.\status-service.ps1
```

Default datadir: `%ProgramData%\DogecoinGPENode`

## Safety

- Default conf binds RPC to **127.0.0.1** only  
- Change `rpcpassword` before any real funds  
- Service restart does not rewrite the chain — datadir is the source of truth  
- Uninstall without `-RemoveDataDir` keeps wallets/chainstate  

## Operator CLI + tray (W3)

```powershell
# Phases: OFFLINE | INIT | IBD | SYNCED
& "C:\Program Files\DogecoinGPENode\bin\gpenode-ops.exe" status
& "C:\Program Files\DogecoinGPENode\bin\gpenode-ops.exe" service status

# Session tray (does not stop the service when quit)
& "C:\Program Files\DogecoinGPENode\bin\gpenode-tray.exe"
```

## Later phases

- **W2** — Task Scheduler dump job (like Linux systemd timer)  
- **W3c** — Richer operator TUI (localhost RPC only; never consensus)  

## Non-goals

- Breaking clients / network / consensus / coins  
- Replacing Core Pro GUI for merchants  
- Public RPC  
- GPE API requirement  
