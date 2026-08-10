# GPENode operator kit (`deploy/`)

**What this is:** scripts + handoffs for a **headless Dogecoin operator** that:

1. Runs `dogecoind` (custom build with AssumeUTXO dump RPCs) — **C++ consensus, no GUI**
2. Produces UTXO snapshots (`dumptxoutset`)
3. Publishes static files to a Fast Sync CDN (ops glue: Go `../gpenode-ops/`)
4. Optionally serves **private** RPC for GPE merchant settlement

**What this is not:** Core Pro desktop, public RPC, consensus rewrite in another language, or a place for secrets.

**Architecture (locked):** [ARCHITECTURE.md](./ARCHITECTURE.md) — C++ core + Go ops glue; Profile A dump / Profile B settlement.

Public docs: `html/docs/` (operator dashboard).

---

## Roles (keep separate)

| Role | Host | Public | Private |
|------|------|--------|---------|
| **Dump / settlement node** | noderunner (GPENode) | P2P only | RPC `127.0.0.1`, SSH, snapshot dir |
| **CDN** | GPE app / static box | `https://sync.doge.gopastearth.com/` | rsync/SSH pull from dump node |
| **Client** | End-user Core Pro | downloads + verifies | local datadir |

GPE today wears dump + CDN hats (**mesh M1**). Next: multi-URL mirrors (**M2**).

---

## Current product truth (2026-08-10)

| Item | State |
|------|--------|
| Mesh stage | **M1 live** — public CDN + client Fast Sync |
| Attested height | `mapAssumeutxo[6324519]` in Core Pro releases |
| CDN | `sync.doge.gopastearth.com` — static HTTPS only |
| Dump RPC | Requires **custom** daemon (`dumptxoutset`) — not stock 1.14.9 alone |
| GUI on server | **No** — headless only |
| Secrets | `serverdetails.txt` + `local/` — **gitignored, never commit** |

---

## Script inventory — keep vs lab vs noise

### Keep (production operator path)

| File | Purpose |
|------|---------|
| `ARCHITECTURE.md` | Locked design: C++ daemon + Go glue + profiles A/B |
| `build-dump-daemon.sh` | Headless `--without-gui` build → dogecoind + cli |
| `conf/dogecoin.dump.conf.example` | Profile A dump-only |
| `conf/dogecoin.settlement.conf.example` | Profile B wallet settlement |
| `make_utxo_snapshot.sh` | Dump → SHA-256 → `latest.json` (+ mesh-ready `urls[]`) |
| `publish_snapshots.sh` | Optional rsync push to CDN (`CDN_TARGET` env) |
| `install_custom_dogecoind.sh` | Install daemon with dump RPCs |
| `mount_nvme_block_storage.sh` | Hot block volume mount |
| `migrate_mainnet_to_block.sh` | Move mainnet datadir onto NVMe |
| `configure_firewall.sh` | Host firewall baseline |
| `dogecoin.conf.example` | Localhost RPC shape (no real passwords) |
| `bootstrap_settlement.sh` | Initial settlement bootstrap |
| `systemd/` | Optional scheduled dump timer units |
| `samples/` | Example `latest.json` + CDN `index.html` |
| `SYNC_CDN_HANDOFF.md` | CDN box: nginx, rsync, acceptance |
| `GPE_BOX_AGENT_PROMPT.md` | Paste prompt for CDN-side agent |
| `SETTLEMENT_NODE_HANDOFF.md` | Dump-node operator handoff (**no passwords in git**) |
| `OPERATOR_KIT.md` | Clean open-source-oriented checklist |

### Lab only (keep, demote)

| File | Purpose |
|------|---------|
| `enable_regtest_lab.sh` | Integration without public peers |
| `enable_testnet_and_start.sh` | Public testnet experiments |
| `regtest_payflow_smoke.sh` | Address → pay → confirm smoke |
| `install_dogecoind_release.sh` | Stock release binary (settlement wiring only; **no dump**) |

### Do not treat as operator kit

- Full Core Pro **Windows build/packaging** scripts that appear under `../scripts/` after a dogedev sync — those belong to **client** development, not noderunner ops.
- Prefer GPE-only helpers: `ssh_cmd.py`, `node_status.py`, `rpc_smoke.py`, `run_remote_snapshot.py`, `deploy_custom_daemon*.py`, `push_deploy.py`, `rpc_tunnel.ps1`, etc.

---

## Production loop

```text
synced tip → make_utxo_snapshot.sh → snapshots/*.dat + latest.json
         → publish_snapshots.sh OR CDN pull → clients Fast Sync (fail closed)
```

```bash
# on dump node (after custom dogecoind is installed)
bash /opt/gpe-deploy/make_utxo_snapshot.sh

# option A — CDN host pulls (preferred)
rsync -avP <dump-node>:/path/to/snapshots/ /var/www/doge-sync/

# option B — dump node pushes
export CDN_TARGET='deploy@cdn-host:/var/www/doge-sync/'
bash /opt/gpe-deploy/publish_snapshots.sh

# option C — schedule dumps
# see systemd/README.md

curl -I https://sync.doge.gopastearth.com/latest.json
```

---

## Storage model (honesty)

| Data | Where |
|------|--------|
| Live `chainstate` / wallet / hot blocks | **Local NVMe / cloud block volume** only |
| Snapshot artifacts | Export dir → CDN objects (immutable files) |
| Never | Live LevelDB on FUSE / Drive / object mount |

---

## Security rules

1. RPC bind **127.0.0.1** only — never public.
2. CDN serves **static files only** — never proxy RPC.
3. No secrets in this directory’s committed files.
4. Clients verify **file SHA-256** + **`mapAssumeutxo` / `hash_serialized`** + background prove.
5. Mesh mirrors may only re-host bytes that match the **same** digests.

---

## Handoffs

| Doc | Audience |
|-----|----------|
| [OPERATOR_KIT.md](./OPERATOR_KIT.md) | Clean public operator checklist |
| [SYNC_CDN_HANDOFF.md](./SYNC_CDN_HANDOFF.md) | CDN / app-box agent |
| [GPE_BOX_AGENT_PROMPT.md](./GPE_BOX_AGENT_PROMPT.md) | Paste-ready CDN prompt |
| [SETTLEMENT_NODE_HANDOFF.md](./SETTLEMENT_NODE_HANDOFF.md) | Dump-node operator (facts; secrets offline) |

Product HTML: **GPENode**, **Multi-operator mesh**, **Fast Sync**, **Threat model**.
