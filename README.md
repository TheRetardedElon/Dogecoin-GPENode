# Dogecoin GPENode

**Headless Dogecoin operator kit** for Fast Sync snapshot production and optional private settlement RPC.

> Same Dogecoin mainnet consensus. CDN is a dumb pipe. Clients fail-closed.  
> **Not** a second coin. **Not** a GUI wallet. **Not** a Rust/Go rewrite of consensus.

| Layer | Tech | Role |
|-------|------|------|
| **Node** | C++ `dogecoind` (Core Pro / AssumeUTXO DNA) | Consensus, P2P, UTXO, `dumptxoutset` |
| **Ops glue** | Go `gpenode-ops` | status · dump · publish · verify-cdn |
| **CDN** | Static HTTPS | `latest.json` + multi‑GB `.dat` only |

Public CDN example (GPE): `https://sync.doge.gopastearth.com/`

---

## Quick start

### 1. Build headless daemon (Linux)

From a full Core Pro source tree (e.g. [Dogecoin-Takeback](https://github.com/TheRetardedElon/Dogecoin-Takeback)):

```bash
# example — see deploy/build-dump-daemon.sh
./configure --without-gui --disable-tests --disable-bench --with-incompatible-bdb
make -j$(nproc) src/dogecoind src/dogecoin-cli
```

Install with `deploy/install_custom_dogecoind.sh` (bundle Boost/miniupnpc libs if you cross-distro build).

### 2. Build ops CLI

```bash
cd gpenode-ops
bash build-linux.sh          # Linux / WSL
# or: powershell -File build-windows.ps1
```

### 3. On the dump node

```bash
sudo mkdir -p /opt/gpe-deploy /opt/gpenode-ops/bin
sudo cp -a deploy/* /opt/gpe-deploy/
sudo install -m 755 gpenode-ops /opt/gpenode-ops/bin/gpenode-ops

export DOGECOIN_CLI=/opt/dogecoin-pro/bin/dogecoin-cli
export DOGECOIN_DATADIR=/path/to/datadir
export LD_LIBRARY_PATH=/opt/dogecoin-pro/lib   # if using bundled libs
export SNAP_SCRIPT=/opt/gpe-deploy/make_utxo_snapshot.sh

/opt/gpenode-ops/bin/gpenode-ops status
/opt/gpenode-ops/bin/gpenode-ops verify-cdn
# /opt/gpenode-ops/bin/gpenode-ops dump   # heavy: multi-GB
```

Conf profiles: `deploy/conf/dogecoin.dump.conf.example` (Profile A) · `dogecoin.settlement.conf.example` (Profile B).

---

## Repository layout

```text
deploy/           Operator scripts, CDN handoff, systemd timers, conf examples
gpenode-ops/      Go operator CLI (no consensus)
html/docs/        Operator documentation (open index.html)
scripts/          Optional remote helpers (need local secrets file)
GPENODE.md        What GPENode is
ARCHITECTURE.md   → deploy/ARCHITECTURE.md
SECURITY.md       Secrets policy
serverdetails.example.txt
```

---

## Architecture (locked)

```text
[gpenode-ops Go] --localhost RPC--> [dogecoind C++ headless]
        |                                    |
   dump / publish / health              dumptxoutset
        v
   HTTPS CDN (static)  -->  Core Pro clients (verify hashes + bg prove)
```

**Do not** rewrite Dogecoin consensus in another language for “speed.”  
**Do** keep the server pure CLI (`--without-gui`) and automate with Go.

Mesh stages: **M1** single public CDN · **M2** multi-URL `urls[]` failover (client + mirrors).

---

## Documentation

Open locally:

```text
html/docs/index.html
```

Key pages: GPENode overview · Multi-operator mesh · Fast Sync (client story) · Operator roadmap · Threat model.

---

## Secrets

| Commit | Never commit |
|--------|----------------|
| `serverdetails.example.txt` | `serverdetails.txt` |
| `deploy/conf/*.example` | Live `dogecoin.conf` with passwords |
| Public docs | SSH private keys, wallet.dat, cookies |

Copy `serverdetails.example.txt` → `serverdetails.txt` for local remote scripts only.

---

## Related

- **Core Pro product / clients:** [Dogecoin-Takeback](https://github.com/TheRetardedElon/Dogecoin-Takeback)  
- **This repo:** operator-side dump + CDN publish kit only  

## License

MIT — see [LICENSE](./LICENSE).
