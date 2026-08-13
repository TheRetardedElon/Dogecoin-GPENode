# Dogecoin GPENode

**Operator kit for Dogecoin Core Pro.** Same mainnet, same `dogecoind`. This repo is the Server / Hybrid / dump-node line.

> Core Pro **replaces** the old GPENode product name on disk.  
> **Not** a second coin. **Not** Qt. **Not** a consensus rewrite.

| Layer | Tech | Role |
|-------|------|------|
| **Node** | C++ `dogecoind` (Core Pro / 1.14 DNA) | Consensus, P2P, UTXO, `dumptxoutset` |
| **Desktop** | ImGui `dogecoin-pro-gui` | Hybrid / Client wallet UI (localhost RPC) |
| **Ops glue** | Go `gpenode-ops` | status · dump · publish · Windows service host |
| **Windows UI** | `corepro-launch` + `gpenode-tui` + `gpenode-tray` | Native picker (no console) · TUI · tray |
| **CDN** | Static HTTPS | `latest.json` + multi‑GB `.dat` only |

**Latest:** [v1.14.104-gpenode](https://github.com/TheRetardedElon/Dogecoin-GPENode/releases/tag/v1.14.104-gpenode)  
Same files as [Core Pro v1.14.104](https://github.com/TheRetardedElon/Dogecoin-Takeback/releases/tag/v1.14.104) — pick **Server** or **Hybrid**.  
Desktop screenshots live on the [Takeback README](https://github.com/TheRetardedElon/Dogecoin-Takeback#screenshots).  
Public CDN: `https://sync.doge.gopastearth.com/`

<p align="center">
  <img src="https://i.imgur.com/btEJ7k3.png" alt="Client / Server / Hybrid" width="720" />
</p>

<p align="center">
  <img src="https://i.imgur.com/OJMui2T.png" alt="Core Pro Home (Hybrid desktop)" width="860" />
</p>

---

## Windows (Server / Hybrid)

1. Download **`dogecoin-1.14.104-win64-setup-rpcsecure.exe`** from [Releases](https://github.com/TheRetardedElon/Dogecoin-GPENode/releases/tag/v1.14.104-gpenode).  
2. Run as Administrator. Choose **Server** (TUI only) or **Hybrid** (ImGui + TUI, **one** node).  
3. Unique RPC password page: copy it, check the box, continue.  
4. Server/Hybrid register the Windows service (display name **Dogecoin Core Pro**).  
5. Hybrid Start Menu is **`corepro-launch.exe`** — a native picker, **no PowerShell/cmd window**. Remember is opt-in.

| Path | Default (Hybrid / Client desktop) |
|------|---------|
| Install | `C:\Program Files\Dogecoin` |
| Data | `%APPDATA%\Dogecoin` |
| Credentials | `%APPDATA%\Dogecoin\RPC-CREDENTIALS.txt` |

X sends the UI to the tray; the node stays up. Hybrid tray can reopen Desktop GUI or Operator TUI.

> `dogecoind.exe` is **not** a native SCM service. The installer registers **`gpenode-ops.exe service-run`**. Consensus stays in C++.

---

## Linux (apt)

```bash
curl -fsSL https://apt.dogecli.gopastearth.com/pubkey.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/gpenode.gpg
echo "deb [signed-by=/usr/share/keyrings/gpenode.gpg] https://apt.dogecli.gopastearth.com stable main" \
  | sudo tee /etc/apt/sources.list.d/gpenode.list
sudo apt update
sudo apt install dogecoin-core-pro
# or: sudo apt install dogecoin-gpenode   # transitional package
sudo systemctl status dogecoin-core-pro --no-pager
```

Debian package on the release: `dogecoin-core-pro_1.14.104-1_amd64.deb`. Same consensus binary. Qt is not shipped.

---

## What you get

| Piece | Role |
|-------|------|
| **`dogecoind`** | The node |
| **`dogecoin-pro-gui`** | ImGui desktop (Client / Hybrid) |
| **`corepro-launch`** | Windows launcher / Hybrid picker (no console) |
| **`gpenode-tui`** | Operator TUI |
| **`gpenode-tray`** | Tray: reopen GUI or TUI |
| **`gpenode-ops`** | Service host + dump/CDN glue |
| **Unique RPC password** | Per install, localhost only |

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

## Linux tarball (optional)

Prefer apt / the `.deb` above. Older tarball names:

| Platform | Asset |
|----------|--------|
| **Linux x86_64** | `dogecoin-gpenode-linux-x86_64-*.tar.gz` |
| **Windows** | Use `dogecoin-1.14.104-win64-setup-rpcsecure.exe` |

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
