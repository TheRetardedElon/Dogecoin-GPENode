# GPENode — what this project is

**Dogecoin GPENode** is a **headless operator stack** for:

1. Running an honest Dogecoin full node (or carefully pruned node)  
2. Producing UTXO snapshots (`dumptxoutset`) for Core Pro **Fast Sync**  
3. Publishing static artifacts to an HTTPS CDN  
4. Optionally serving **private** RPC for merchant settlement (GPE or others)  

It is **not** Core Pro desktop, not a second ledger, and not a consensus rewrite.

## Relationship to Core Pro

| Project | Owns |
|---------|------|
| **Dogecoin-Takeback** (Core Pro) | GUI, client Fast Sync, Windows packages, `mapAssumeutxo` in releases |
| **Dogecoin-GPENode** (this repo) | Dump node ops, CDN publish, Go glue, operator docs |

Daemon features (`dumptxoutset`, dual chainstate) live in Core Pro DNA. Build `dogecoind` from that source (or a compatible fork), then operate it with this kit.

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

## Language split

| Layer | Language | Rewrite for speed? |
|-------|----------|--------------------|
| Consensus / P2P / dump RPC | **C++ `dogecoind`** | **No** |
| Operator glue | **Go `gpenode-ops`** | Yes |

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
4. Clients verify file SHA-256 + attestation + background prove  
5. Live chainstate only on real block storage (NVMe), never FUSE LevelDB  

## Docs

```text
html/docs/index.html
deploy/ARCHITECTURE.md
deploy/OPERATOR_KIT.md
SECURITY.md
```
