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

### Easiest: download a headless release (recommended)

Prebuilt **Linux x86_64** packages ship on GitHub Releases:

**https://github.com/TheRetardedElon/Dogecoin-GPENode/releases**

```bash
# example asset name
tar -xzf dogecoin-gpenode-linux-x86_64-*.tar.gz
cd dogecoin-gpenode-linux-x86_64-*
sudo bash install.sh
# systemd unit should set Environment=LD_LIBRARY_PATH=/opt/dogecoin-pro/lib
```

Contents: `dogecoind` + `dogecoin-cli` (no Qt, dump RPCs) · `gpenode-ops` · bundled libs · `deploy/` scripts.

Always verify the published `.sha256` file.

### Or build from source

From a full Core Pro tree (e.g. [Dogecoin-Takeback](https://github.com/TheRetardedElon/Dogecoin-Takeback)):

```bash
# see deploy/build-dump-daemon.sh
./configure --without-gui --disable-tests --disable-bench --with-incompatible-bdb
make -j$(nproc) src/dogecoind src/dogecoin-cli
```

Ops CLI only:

```bash
cd gpenode-ops && bash build-linux.sh
```

### On the dump node (after install)

```bash
export DOGECOIN_CLI=/opt/dogecoin-pro/bin/dogecoin-cli
export DOGECOIN_DATADIR=/path/to/datadir
export LD_LIBRARY_PATH=/opt/dogecoin-pro/lib
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
**Do** keep the node pure headless C++ and automate with Go / scripts.

| Platform | Headless packaging |
|----------|-------------------|
| **Linux** | GitHub Release tarball + systemd |
| **Windows** | Service scripts in `deploy/windows/` (W0); win64 zip next (W1) |

Mesh stages: **M1** single public CDN · **M2** multi-URL `urls[]` failover (client + mirrors).

### Windows Service (W0)

```powershell
cd deploy\windows
# place dogecoind.exe + dogecoin-cli.exe in .\bin\
powershell -ExecutionPolicy Bypass -File .\install-service.ps1 -Profile dump
.\status-service.ps1
```

See `deploy/windows/README.md` and `deploy/windows/ARCHITECTURE-WINDOWS-HEADLESS.md`.

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
