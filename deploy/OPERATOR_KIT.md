# Operator kit — Fast Sync dump + CDN (clean)

Open-source-oriented checklist. **No secrets.**  
GPE is the first live operator (mesh **M1**); any serious org can follow the same pattern.

## You will run

1. **Dump node** — headless `dogecoind` with `dumptxoutset` (custom Core Pro / GPE build).
2. **CDN** — static HTTPS host for `latest.json` + multi‑GB `.dat` files.

Optional: private RPC for your own merchant backend. Not required for public Fast Sync clients.

## Dump node checklist

- [ ] Real block storage for datadir (NVMe / cloud block). Not FUSE as live chainstate.
- [ ] Custom daemon installed (`help dumptxoutset` works).
- [ ] RPC on `127.0.0.1` only; firewall denies public RPC ports.
- [ ] Node at tip (or known stable height H you will attest).
- [ ] Run dump script → `.dat` + file SHA-256 + `hash_serialized` + `latest.json`.
- [ ] Retain dump JSON + digests for release/map process when H is new.

## CDN checklist

- [ ] Public hostname (example: `sync.example.org`) with valid TLS.
- [ ] Docroot serves only static files (nginx sketch in `SYNC_CDN_HANDOFF.md`).
- [ ] Versioned `.dat` long-cache; `latest.json` short-cache.
- [ ] Publish pipeline: pull from dump node via SSH key (preferred).
- [ ] Acceptance: `curl -I https://…/latest.json` → 200; sha256 matches.

## Manifest (minimum)

```json
{
  "network": "main",
  "url": "https://sync.example.org/utxo-HEIGHT-STAMP.dat",
  "sha256": "<file sha256 hex>",
  "bytes": 0,
  "blocks": 0,
  "hash_serialized": "<from dumptxoutset>",
  "created_utc": "2026-08-10T00:00:00Z",
  "producer": "your-operator-id",
  "notes": "Clients verify sha256 fail-closed; activation needs mapAssumeutxo."
}
```

### Mesh-ready (M2+)

Add the same digest under multiple hosts:

```json
{
  "sha256": "<same>",
  "blocks": 0,
  "hash_serialized": "<same>",
  "url": "https://primary.example/utxo-….dat",
  "urls": [
    "https://primary.example/utxo-….dat",
    "https://mirror.example/utxo-….dat"
  ]
}
```

Mirrors must serve **byte-identical** (or same-hash) artifacts. Clients never switch digests.

## Trust (non-negotiable)

| Check | Who enforces |
|-------|----------------|
| File SHA-256 | Client during download |
| `hash_serialized` / `mapAssumeutxo[H]` | Client at activate (+ release process for map) |
| Background prove | Client over P2P |
| CDN honesty | Optional; wrong file fails closed |

More operators ≠ more consensus trust. More operators = more bandwidth and uptime.

## Do not

- Expose dogecoind RPC on the public internet  
- Mount live LevelDB on object storage / consumer Drive  
- Claim “trust our cloud” without hashes  
- Commit passwords, wallets, or live `dogecoin.conf` with rpcpassword  

## Related product docs

- `html/docs/pages/gpenode.html`
- `html/docs/pages/multi-operator-mesh.html`
- `html/docs/pages/fast-sync.html`
- `html/docs/pages/fast-sync-threat-model.html`
