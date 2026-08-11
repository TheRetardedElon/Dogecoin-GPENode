# Dogecoin GPENode

**Headless Dogecoin operator kit** for Fast Sync snapshot production, Windows service operation, and optional private settlement RPC.

> Same Dogecoin mainnet consensus. CDN is a dumb pipe. Clients fail-closed.  
> **Not** a second coin. **Not** a Qt GUI wallet. **Not** a consensus rewrite.

| Layer | Tech | Role |
|-------|------|------|
| **Node** | C++ `dogecoind` (Core Pro / AssumeUTXO DNA) | Consensus, P2P, UTXO, `dumptxoutset` |
| **Ops glue** | Go `gpenode-ops` | status · dump · publish · verify-cdn · Windows service host |
| **Windows UI** | `gpenode-tui` + `gpenode-tray` | Operator TUI + tray (localhost RPC only) |
| **CDN** | Static HTTPS | `latest.json` + multi‑GB `.dat` only |

**Latest Windows release:** [v1.14.102-gpenode3](https://github.com/TheRetardedElon/Dogecoin-GPENode/releases/tag/v1.14.102-gpenode3)  
Public UTXO CDN example: `https://sync.doge.gopastearth.com/`  
Apt origin (packages when published): `https://apt.dogecli.gopastearth.com/`

---

## Windows client (featured)

GPENode on Windows is a **headless service** plus a **gold-dark operator TUI** — not the Qt wallet. Same mainnet as [Core Pro](https://github.com/TheRetardedElon/Dogecoin-Takeback).

<p align="center">
  <img src="https://i.imgur.com/VPMlmgu.png" alt="GPENode TUI home menu" width="720" />
</p>

<p align="center">
  <img src="https://i.imgur.com/O5OJGl7.png" alt="GPENode TUI Overview — chain + service" width="720" />
</p>

<p align="center">
  <img src="https://i.imgur.com/odesIzS.png" alt="GPENode TUI UTXO Dump / Fast Sync" width="720" />
</p>

### What you get on Windows

| Piece | Role |
|-------|------|
| **Windows Service** `DogecoinGPENode` | Always-on `dogecoind` via `gpenode-ops service-run` |
| **gpenode-tui** | Keyboard/mouse operator UI (Overview, Node, Dump, CDN, Settings, …) |
| **gpenode-tray** | System tray status; open TUI / data folder / conf |
| **Unique RPC password** | Generated **per install** (no shared default) → `dogecoin.conf` + `RPC-CREDENTIALS.txt` |

### Install (recommended)

1. Download **`dogecoin-gpenode-*-win64-setup.exe`** from [Releases](https://github.com/TheRetardedElon/Dogecoin-GPENode/releases).  
2. Run as Administrator.  
3. On the **Unique RPC password** page: copy the password, check the box, continue.  
4. Optional: install as Windows Service + tray.  
5. Open **GPENode TUI** or **GPENode Status** from the Start Menu.

| Path | Default |
|------|---------|
| Install | `C:\Program Files\DogecoinGPENode` |
| Data | `C:\ProgramData\DogecoinGPENode` |
| Credentials | `%ProgramData%\DogecoinGPENode\RPC-CREDENTIALS.txt` |

```powershell
# After install — service + TUI
cd "C:\Program Files\DogecoinGPENode"
powershell -ExecutionPolicy Bypass -File .\install-service.ps1 -Profile dump
.\bin\gpenode-tui.exe
```

Portable zip is also on Releases (`*-gpenode-headless.zip`).

> **Note:** `dogecoind.exe` is **not** a native Windows SCM service. The installer registers **`gpenode-ops.exe service-run`**, which supervises the daemon (start/stop, restarts). Consensus stays in C++.

---

## What is a “dump profile”?

A **dump profile** is a **node configuration mode** for operators who **produce UTXO snapshots** for Core Pro **Fast Sync** — not a merchant wallet.

| | **Dump profile** (default for GPENode) | **Settlement profile** (optional) |
|--|----------------------------------------|-------------------------------------|
| **Job** | Stay synced, run `dumptxoutset`, publish static files to CDN | Private RPC for apps / settlement |
| **Wallet** | Usually **off** (`disablewallet=1`) | Often **on** |
| **Disk** | Often **pruned** (bounded size) | Often full / larger cache |
| **RPC** | Localhost only; for ops tools | Localhost or private network |
| **Who uses it** | Independent dump operators, GPE sync CDN producers | Backend services that need wallet/RPC |

<p align="center">
  <img src="https://i.imgur.com/lteJdAO.png" alt="Wallet optional under dump profile" width="720" />
</p>

**Why wallet is “EXPECTED” off on dump nodes**

- Snapshot production does not need keys or balances.  
- Less attack surface and less I/O.  
- Turning the wallet on is fine later (settlement profile) — it is **not** required for Fast Sync dumps.

**How Fast Sync uses dumps**

```text
[Dump node]  dogecoind  →  dumptxoutset  →  utxo-*.dat + hash_serialized
       │
       ▼  static HTTPS only
[CDN]  latest.json + multi-GB .dat
       │
       ▼  clients verify SHA-256 + mapAssumeutxo + background prove
[Core Pro GUI / other clients]
```

CDN never proxies RPC. Clients **fail closed** if hashes do not match.

Example confs: `deploy/conf/dogecoin.dump.conf.example` · `dogecoin.settlement.conf.example`  
(and on Windows: `deploy/windows/conf/`).

---

## Linux quick start

| Platform | Asset |
|----------|--------|
| **Linux x86_64** | `dogecoin-gpenode-linux-x86_64-*.tar.gz` |
| **Windows x64 setup** | `dogecoin-gpenode-*-win64-setup.exe` |
| **Windows x64 zip** | `dogecoin-gpenode-win64-*-gpenode-headless.zip` |

```bash
tar -xzf dogecoin-gpenode-linux-x86_64-*.tar.gz
cd dogecoin-gpenode-linux-x86_64-*
sudo bash install.sh
# systemd: Environment=LD_LIBRARY_PATH=/opt/dogecoin-pro/lib
export DOGECOIN_CLI=/opt/dogecoin-pro/bin/dogecoin-cli
/opt/gpenode-ops/bin/gpenode-ops status
```

Always verify `SHA256SUMS.txt` / `.sha256` files.

---

## Architecture (locked)

```text
[gpenode-tui / tray / gpenode-ops] --localhost RPC--> [dogecoind C++ headless]
              |                                              |
         dump / publish / health                      dumptxoutset
              v
         HTTPS CDN (static)  -->  Core Pro clients (hash + bg prove)
```

| Platform | Packaging |
|----------|-----------|
| **Windows** | NSIS setup + zip · Service · TUI · tray · unique RPC password |
| **Linux** | Release tarball · systemd · `gpenode-ops` · deploy scripts |

**Do not** rewrite Dogecoin consensus in another language for “speed.”  
**Do** keep the node pure headless C++ and automate with Go / scripts.

Mesh stages: **M1** single public CDN · **M2** multi-URL `urls[]` failover.

---

## Repository layout

```text
deploy/           Operator scripts, CDN handoff, systemd, Windows installer/service
deploy/windows/   NSIS, install-service, conf examples, unique-password helpers
gpenode-ops/      Go operator CLI + Windows service host (service-run)
gpenode-tui/      Windows operator TUI
gpenode-tray/     Windows system tray
html/docs/        Operator documentation (open index.html)
GPENODE.md        What GPENode is
SECURITY.md       Secrets policy
```

---

## Documentation

| Doc | Topic |
|-----|--------|
| [GPENODE.md](./GPENODE.md) | What this project is / is not |
| [deploy/windows/README.md](./deploy/windows/README.md) | Windows service + TUI |
| [deploy/INDEPENDENT_OPERATORS.md](./deploy/INDEPENDENT_OPERATORS.md) | Running a dump node without a GPE API |
| [deploy/OPERATOR_KIT.md](./deploy/OPERATOR_KIT.md) | Snapshot / publish ops |
| [SECURITY.md](./SECURITY.md) | Secrets, RPC, CDN |
| `html/docs/index.html` | Local HTML docs |

---

## Secrets

| Commit | Never commit |
|--------|----------------|
| `serverdetails.example.txt` | `serverdetails.txt` |
| `deploy/conf/*.example` | Live `dogecoin.conf` / `RPC-CREDENTIALS.txt` |
| Public docs | SSH keys, wallet.dat, cookies, real rpcpasswords |

Installer-generated passwords live only under the data directory on the operator’s machine.

---

## Related

- **Core Pro GUI / client Fast Sync:** [Dogecoin-Takeback](https://github.com/TheRetardedElon/Dogecoin-Takeback)  
- **This repo:** operator-side dump node + CDN publish + Windows headless service  

## License

MIT — see [LICENSE](./LICENSE).
