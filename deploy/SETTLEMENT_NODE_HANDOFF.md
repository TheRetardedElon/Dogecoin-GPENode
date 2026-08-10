# Settlement / dump node — operator handoff

**Daemon only.** Headless `dogecoind` (no Qt / Core Pro GUI on this host).

**Roles on this host:**

1. **Fast Sync producer** — `dumptxoutset` → snapshots → CDN publish pipeline  
2. **Optional GPE settlement RPC** — private money engine (addresses, received amounts)

GPE app remains the Business OS. This node is **not** consensus and **not** a public API.

**Secrets:** passwords, keys, and live RPC credentials stay in operator-local files  
(`serverdetails.txt`, `local/`) — **gitignored**. Do not paste into public docs or GPE git.

---

## Product status (2026-08-10)

| Item | Value |
|------|--------|
| Network (prod) | **mainnet** |
| Dump RPCs | Custom Core Pro / GPE daemon (not stock 1.14.9 alone) |
| Hot storage | NVMe / cloud **block** volume for datadir |
| Snapshots | Export dir on block volume → rsync to CDN |
| CDN | `sync.doge.gopastearth.com` (static host — separate box preferred) |
| Mesh | **M1 live**; M2 multi-URL next |
| Attested H (client map) | `6324519` (more heights as dumps publish) |

Lab regtest remains available for GPE integration tests without public peers — see `enable_regtest_lab.sh`.

---

## Host facts (fill from operator secrets)

| Field | Notes |
|--------|--------|
| Label | e.g. `gpednode1` |
| Provider / region | operator-local |
| Public IP | operator-local — not required in public HTML |
| OS | Debian-class recommended |
| SSH | key-based; password only as emergency fallback |

---

## Storage layout (target)

```text
/mnt/<block-volume>/dogecoin/     ← live -datadir (chainstate, pruned blocks, wallet)
/mnt/<block-volume>/snapshots/    ← dumptxoutset artifacts + latest.json
/mnt/<optional-lab-fs>/…          ← regtest / experiments only
```

**Hosting model:** block volume = live hot state.  
**Never** put live LevelDB on FUSE/Drive/object mount.

```bash
# example after attach (paths may match your install under /opt/gpe-deploy)
bash /opt/gpe-deploy/mount_nvme_block_storage.sh
# optional migrate:
bash /opt/gpe-deploy/migrate_mainnet_to_block.sh
```

---

## Binary / process

| Field | Value |
|--------|--------|
| Binary | Custom `dogecoind` with AssumeUTXO dump RPCs |
| Install helper | `install_custom_dogecoind.sh` |
| systemd | `dogecoind.service` |
| User | system user `dogecoin` (recommended) |
| CLI | `dogecoin-cli -datadir=<path> …` |

```bash
systemctl status dogecoind
journalctl -u dogecoind -f
sudo -u dogecoin dogecoin-cli -datadir="$(cat /etc/dogecoin/datadir.path)" getblockchaininfo
sudo -u dogecoin dogecoin-cli -datadir="$(cat /etc/dogecoin/datadir.path)" help dumptxoutset
```

---

## RPC (watchers / GPE)

| Field | Value |
|--------|--------|
| Bind | **`127.0.0.1` only** |
| Public internet | **Do not expose RPC** |
| Credentials | conf on server only — never commit |
| Mainnet RPC port | **22555** |
| Regtest RPC port | **18332** |

GPE / watchers connect via **private network, SSH tunnel, or VPC** — never bind RPC to `0.0.0.0` on a public IP.

---

## Snapshot production

```bash
bash /opt/gpe-deploy/make_utxo_snapshot.sh
# → snapshots/utxo-HEIGHT-STAMP.dat
# → snapshots/latest.json
# → publish: rsync/pull to CDN docroot
```

New heights need a **mapAssumeutxo** entry in Core Pro releases before clients activate without `-assumeutxodev`. CDN JSON alone is not the activation authority.

---

## Firewall / surface

- Allow P2P if this node should serve the network (mainnet **22556**).  
- Allow SSH from operator IPs only where possible.  
- **Deny** public RPC.  
- CDN traffic is on the **CDN box**, not via RPC here.

---

## Related

| Doc | Use |
|-----|-----|
| `README.md` | Kit index + keep/lab inventory |
| `OPERATOR_KIT.md` | Clean public checklist |
| `SYNC_CDN_HANDOFF.md` | CDN host |
| Product HTML | `gpenode.html`, `multi-operator-mesh.html`, `fast-sync-threat-model.html` |
