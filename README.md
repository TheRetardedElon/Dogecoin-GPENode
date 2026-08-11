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

**Install**

| Platform | How |
|----------|-----|
| **Linux (Debian/Ubuntu)** | `apt install dogecoin-gpenode` from [apt.dogecli.gopastearth.com](https://apt.dogecli.gopastearth.com/) (live, signed) |
| **Windows** | [v1.14.102-gpenode3 setup.exe](https://github.com/TheRetardedElon/Dogecoin-GPENode/releases/tag/v1.14.102-gpenode3) |

Public UTXO CDN example: `https://sync.doge.gopastearth.com/`

---

## Quick start (Linux — recommended)

Debian/Ubuntu (and WSL):

```bash
# 1) Trust the apt key + add the repo
curl -fsSL https://apt.dogecli.gopastearth.com/pubkey.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/gpenode.gpg

echo "deb [signed-by=/usr/share/keyrings/gpenode.gpg] https://apt.dogecli.gopastearth.com stable main" \
  | sudo tee /etc/apt/sources.list.d/gpenode.list

# 2) Install
sudo apt update
sudo apt install dogecoin-gpenode

# 3) Check
systemctl status dogecoin-gpenode --no-pager
sudo cat /var/lib/dogecoin-gpenode/RPC-CREDENTIALS.txt   # unique password for THIS machine
gpenode-ops status
gpenode-tui   # gold operator TUI when your terminal supports color
```

Human install page: https://apt.dogecli.gopastearth.com/  
Signing key fingerprint: `191C 47CA DF15 5395 CF83  0057 99B1 7249 3442 438C`

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

## Linux install (details)

Same headless node + operator tools as Windows. **No Qt GUI.**

| Method | When to use |
|--------|-------------|
| **`apt` (recommended)** | Debian/Ubuntu — [apt.dogecli.gopastearth.com](https://apt.dogecli.gopastearth.com/) is **live and signed** |
| **Local `.deb`** | Offline install / CI / air-gapped |
| **Tarball** | Portable / non-Debian hosts |

### Apt (copy-paste)

```bash
curl -fsSL https://apt.dogecli.gopastearth.com/pubkey.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/gpenode.gpg

echo "deb [signed-by=/usr/share/keyrings/gpenode.gpg] https://apt.dogecli.gopastearth.com stable main" \
  | sudo tee /etc/apt/sources.list.d/gpenode.list

sudo apt update
sudo apt install dogecoin-gpenode
```

If you see `Unable to locate package dogecoin-gpenode`, you usually forgot the `sources.list.d` lines or `apt update` above.

**After install**

```bash
systemctl status dogecoin-gpenode --no-pager
sudo cat /var/lib/dogecoin-gpenode/RPC-CREDENTIALS.txt
gpenode-ops status
gpenode-tui
sudo journalctl -u dogecoin-gpenode -f
```

First install generates a **unique** localhost RPC password (no shared default).  
systemd unit `dogecoin-gpenode` is enabled and started automatically.

Origin / security notes: [deploy/debian/APT-ORIGIN.md](./deploy/debian/APT-ORIGIN.md)  
(static HTTPS only — no Dogecoin RPC on the apt host)

### Linux paths (package)

| Path | Purpose |
|------|---------|
| `/usr/bin/dogecoind` | Daemon |
| `/usr/bin/dogecoin-cli` | CLI |
| `/usr/bin/gpenode-ops` | Operator glue |
| `/usr/bin/gpenode-tui` | Operator TUI (color when terminal supports it) |
| `/etc/dogecoin-gpenode/dogecoin.conf` | Config |
| `/var/lib/dogecoin-gpenode/` | Datadir + `RPC-CREDENTIALS.txt` |
| `dogecoin-gpenode.service` | systemd unit |

### Local `.deb` (offline)

```bash
# download from the apt pool, or use a built file:
#   https://apt.dogecli.gopastearth.com/pool/main/dogecoin-gpenode_1.14.102-1_amd64.deb
sudo apt-get install -y ./dogecoin-gpenode_1.14.102-1_amd64.deb
```

Build from this repo (maintainers): [deploy/debian/README.md](./deploy/debian/README.md)

### Linux tarball (portable)

| Platform | Asset |
|----------|--------|
| **Linux x86_64** | `dogecoin-gpenode-linux-x86_64-*.tar.gz` ([Releases](https://github.com/TheRetardedElon/Dogecoin-GPENode/releases)) |
| **Windows x64 setup** | `dogecoin-gpenode-*-win64-setup.exe` |
| **Windows x64 zip** | `dogecoin-gpenode-win64-*-gpenode-headless.zip` |

```bash
tar -xzf dogecoin-gpenode-linux-x86_64-*.tar.gz
cd dogecoin-gpenode-linux-x86_64-*
sudo bash install.sh
export LD_LIBRARY_PATH=/opt/dogecoin-pro/lib
export DOGECOIN_CLI=/opt/dogecoin-pro/bin/dogecoin-cli
/opt/gpenode-ops/bin/gpenode-ops status
```

Always verify `SHA256SUMS.txt` / `.sha256` files when using GitHub Release assets.

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
| **Linux** | `.deb` + apt origin · tarball · systemd · `gpenode-ops` · TUI |

**Do not** rewrite Dogecoin consensus in another language for “speed.”  
**Do** keep the node pure headless C++ and automate with Go / scripts.

Mesh stages: **M1** single public CDN · **M2** multi-URL `urls[]` failover.

---

## Repository layout

```text
deploy/           Operator scripts, CDN handoff, systemd, Windows installer/service
deploy/windows/   NSIS, install-service, conf examples, unique-password helpers
deploy/debian/    .deb build, apt publish, APT-ORIGIN (apt.dogecli.gopastearth.com)
gpenode-ops/      Go operator CLI + Windows service host (service-run)
gpenode-tui/      Operator TUI (Windows + Linux)
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
| [deploy/debian/README.md](./deploy/debian/README.md) | Build/install `.deb` |
| [deploy/debian/APT-ORIGIN.md](./deploy/debian/APT-ORIGIN.md) | Public apt CDN |
| [deploy/INDEPENDENT_OPERATORS.md](./deploy/INDEPENDENT_OPERATORS.md) | Running a dump node without a GPE API |
| [deploy/OPERATOR_KIT.md](./deploy/OPERATOR_KIT.md) | Snapshot / publish ops |
| [SECURITY.md](./SECURITY.md) | Secrets, RPC, CDN |
| [PRIVACY.md](./PRIVACY.md) | Privacy policy (canonical URL below) |
| `html/docs/index.html` | Local HTML docs |

**Privacy policy URL:** https://github.com/TheRetardedElon/Dogecoin-GPENode/blob/main/PRIVACY.md

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

## Privacy

[Privacy Policy](./PRIVACY.md) — https://github.com/TheRetardedElon/Dogecoin-GPENode/blob/main/PRIVACY.md
