# gpenode-ops

**Operator glue only.** Single static Go binary next to headless `dogecoind`.

- Does **not** validate blocks or implement Dogecoin consensus  
- Speaks **localhost RPC** / `dogecoin-cli` and wraps `deploy/*.sh`  
- Architecture: `../deploy/ARCHITECTURE.md`

## Build

```bash
# Linux (WSL/node)
bash build-linux.sh

# Windows
powershell -ExecutionPolicy Bypass -File build-windows.ps1
```

Staged package (both OS binaries + deploy scripts):

```bash
bash ../deploy/stage-ops-binaries.sh
# → out/gpenode-ops/
```

Live check (no node required):

```bash
./gpenode-ops verify-cdn
# → blocks / sha256 / url from sync.doge.gopastearth.com
```

## Commands

```bash
export DOGECOIN_DATADIR=/mnt/gpedogecloud/dogecoin
export DOGECOIN_CLI=/opt/dogecoin-pro/bin/dogecoin-cli

./gpenode-ops status      # tip + dumptxoutset present?
./gpenode-ops dump        # make_utxo_snapshot.sh
./gpenode-ops publish     # needs CDN_TARGET for push
./gpenode-ops verify-cdn  # GET latest.json
```

## Pairing

| Piece | Role |
|-------|------|
| `dogecoind` (C++, `--without-gui`) | Consensus / UTXO / dump RPC |
| `gpenode-ops` (Go) | Schedule triggers, publish, health |
| CDN | Static files only |

Profile A/B conf: `../deploy/conf/`.
