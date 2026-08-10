# GPENode architecture (locked)

**Date:** 2026-08-10  
**Status:** agreed (Core Pro / GPE operator path)

## Non-negotiable

| Layer | Language / binary | May rewrite? |
|-------|-------------------|--------------|
| **Consensus + P2P + UTXO + `dumptxoutset`** | C++ **`dogecoind`** (Core Pro DNA) | **No** — L1 compatibility by definition |
| **Operator glue** | Go (preferred) / Rust / shell | **Yes** — RPC only, no consensus |

One edge-case drift in AuxPoW, DigiShield, script, or dump/`hash_serialized` serialization = silent split or rejected snapshots. Do not reimplement the node for “speed.”

## Pure headless CLI

Server builds never link Qt / Arcade / Meme Stream / themes.

```bash
# see build-dump-daemon.sh
./configure --prefix=... --without-gui --disable-tests --disable-bench
make -j$(nproc) dogecoind dogecoin-cli
```

Result: UNIX daemon focused on validation, LevelDB/UTXO cache, P2P, dump RPCs.

## Split of responsibility

```text
┌─────────────────────────────────────────┐
│  gpenode-ops  (Go static binary)        │
│  status · dump · publish · verify ·     │
│  schedule hooks · CDN health            │
└──────────────────┬──────────────────────┘
                   │ localhost JSON-RPC only
┌──────────────────▼──────────────────────┐
│  dogecoind  (C++ Core Pro, no GUI)      │
│  consensus · P2P · coins · dumptxoutset │
└─────────────────────────────────────────┘
                   │ artifacts
┌──────────────────▼──────────────────────┐
│  CDN static HTTPS                       │
│  latest.json + utxo-*.dat               │
└─────────────────────────────────────────┘
```

## Server profiles

| Profile | Binary & settings | Role |
|---------|-------------------|------|
| **A — Fast Sync / dump producer** | `dogecoind` `--without-gui`, `disablewallet=1`, prune, high `dbcache` during dump windows | Tip → `dumptxoutset` → ops publish to CDN |
| **B — Settlement host** | `dogecoind` `--without-gui`, **wallet enabled**, RPC `127.0.0.1` only | GPE merchant addresses / receive verify |

Same consensus binary family. Can be one box (B + dump with wallet on) or two boxes later. Profile A is the leanest dump-only host.

Conf samples:

- `conf/dogecoin.dump.conf.example` — Profile A  
- `conf/dogecoin.settlement.conf.example` — Profile B  

## Efficiency (real, not fantasy)

| Lever | Effect |
|-------|--------|
| `--without-gui` | No Qt RAM/CPU/link |
| prune + no `txindex` (dump profile) | Disk bound |
| `dbcache` tuned for dump windows | Faster tip + dump I/O |
| Ops in Go | Single static binary; scheduling, rsync, verify |
| NVMe block volume | Hot chainstate (never FUSE LevelDB) |

## Explicit non-goals

- Rewrite dogecoind in Rust/Go/Zig for mainnet dumps  
- Public RPC  
- GUI on the dump server  
- Live chainstate on object storage  

## Windows headless (next product cut)

Same rules: **C++ dogecoind**, no Qt product package, Windows **Service**.

See **`windows/ARCHITECTURE-WINDOWS-HEADLESS.md`** and `windows/install-service.ps1`.

| Phase | Deliverable |
|-------|-------------|
| W0 | Service install scripts (done in tree) |
| W1 | Win64 zip release of headless binaries |
| W2 | Scheduled dump task |
| W3 | Optional tray + operator TUI (RPC only) |

## Related

- `build-dump-daemon.sh` — Linux headless build  
- `package-headless-release.sh` — Linux GitHub release tarball  
- `windows/` — Windows service packaging  
- `../gpenode-ops/` — Go operator CLI  
- `OPERATOR_KIT.md`, `GPENODE.md`  

