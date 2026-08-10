# GPENode — what this project is

**Dogecoin GPENode** is a **headless operator stack** for:

1. Running an honest Dogecoin full node (or carefully pruned node)  
2. Producing UTXO snapshots (`dumptxoutset`) for Core Pro **Fast Sync**  
3. Publishing static artifacts to an HTTPS CDN  
4. Operating that node as a **Windows Service** (or Linux systemd) with operator tools  
5. Optionally serving **private** RPC for merchant settlement (GPE or others)  

It is **not** Core Pro desktop, not a second ledger, and not a consensus rewrite.

## Relationship to Core Pro

| Project | Owns |
|---------|------|
| **Dogecoin-Takeback** (Core Pro) | GUI, client Fast Sync, Windows GUI packages, `mapAssumeutxo` in client releases |
| **Dogecoin-GPENode** (this repo) | Dump node ops, CDN publish, Go glue, Windows headless service + TUI/tray, operator docs |

Daemon features (`dumptxoutset`, dual chainstate) live in Core Pro DNA. Build `dogecoind` from that source (or a compatible fork), then operate it with this kit.

## Dump profile vs settlement profile

### Dump profile (default)

**Purpose:** Produce trustworthy UTXO dumps for Fast Sync clients.

Typical conf traits:

- `disablewallet=1` — no keys needed to dump the UTXO set  
- Bounded disk (`prune=…`) is common for operators  
- RPC on `127.0.0.1` for `gpenode-ops` / TUI / `dogecoin-cli` only  
- Job: sync → `dumptxoutset` → publish `.dat` + `latest.json` to CDN  

Wallet UI showing “EXPECTED for dump profile” is **correct**, not a failure.

### Settlement profile (optional)

**Purpose:** Private JSON-RPC for applications (orders, payouts, monitoring).

Typical traits:

- Wallet enabled when the app needs addresses / send  
- Larger `dbcache` / less aggressive prune  
- Still **never** expose RPC to the public internet  

See `deploy/conf/dogecoin.dump.conf.example` and `dogecoin.settlement.conf.example`.

## Two hosts

```text
[Dump node]  dogecoind + dumptxoutset + NVMe
      │ rsync / pull
      ▼
[CDN host]  static HTTPS  →  latest.json + utxo-*.dat
      │
      ▼
[Core Pro clients]  stream-hash + mapAssumeutxo + background prove
```

| Host | Public | Private |
|------|--------|---------|
| Dump node | P2P optional | RPC `127.0.0.1`, SSH, snapshot export |
| CDN | static files only | deploy key / rsync |

## Language / process split

| Layer | Language | Rewrite for speed? |
|-------|----------|--------------------|
| Consensus / P2P / dump RPC | **C++ `dogecoind`** | **No** |
| Operator glue | **Go `gpenode-ops`** | Yes (status, dump, publish, Windows SCM host) |
| Operator UX (Windows) | **Go TUI / tray** | Yes — RPC only, no consensus |

## Mesh

| Stage | Meaning |
|-------|---------|
| M0 | Private dump/load |
| M1 | First public CDN + client Fast Sync |
| M2 | Multi-URL `urls[]` + client failover |
| M3 | Multi-dumper |
| M4 | Optional cold `blk` objects |

## Security non-negotiables

1. RPC bind **127.0.0.1** only (or private network)  
2. CDN = **static files only** — never proxy RPC  
3. No secrets in git  
4. **No shared default rpcpassword** — installers generate unique credentials per machine  
5. Clients verify file SHA-256 + attestation + background prove  
6. Live chainstate only on real block storage (NVMe), never FUSE LevelDB  

## Docs

```text
README.md                 Project front door (Windows featured)
html/docs/index.html
deploy/ARCHITECTURE.md
deploy/OPERATOR_KIT.md
deploy/INDEPENDENT_OPERATORS.md
deploy/windows/README.md
SECURITY.md
```
