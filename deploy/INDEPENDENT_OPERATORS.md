# Independent operators & CDN mesh — do you need a GPE API?

**Short answer: No.**  
Other operators do **not** need a GoPastEarth API, GPE account, or GPE backend to produce dumps or host a Fast Sync CDN.

---

## What every independent operator needs

| Piece | Required? | Notes |
|-------|-----------|--------|
| Honest full/pruned Dogecoin node | **Yes** | Same mainnet consensus (Core Pro / dump-capable `dogecoind`) |
| `dumptxoutset` | **Yes** | Produces `.dat` + `hash_serialized` |
| Static HTTPS host | **Yes** | nginx, Caddy, R2, S3, Cloudflare… **static files only** |
| File SHA-256 in `latest.json` | **Yes** | Clients fail closed on mismatch |
| GPE merchant API / DocHub | **No** | Only if they want GPE business features |
| Permission from GPE | **No** | Mesh is open participation; trust is hashes + client map |

---

## Trust model (not “trust GPE”)

```text
1. Attestation   mapAssumeutxo[H] inside Core Pro client releases
2. Delivery      any HTTPS host serving the same .dat bytes
3. Client verify file SHA-256 + coins hash + background P2P prove
```

- **CDN JSON is not consensus.** A malicious CDN can only waste bandwidth or serve a file that fails hash checks.  
- **New heights** enter `mapAssumeutxo` via the **client release process**, not via a live GPE API.  
- Operators may **re-host** another’s artifact only if **sha256 matches**, or **re-dump** independently at the same H.

---

## What GPE provides today (optional convenience)

| GPE surface | Role for Fast Sync |
|-------------|--------------------|
| `sync.doge.gopastearth.com` | First public CDN (M1) — convenience, not authority |
| Dump node + schedule | Produces artifacts for that CDN |
| GPE APIs (MemeStream, POS, …) | **Unrelated** to snapshot bootstrap |

You do **not** need to build a special public “Fast Sync control plane API” for independence.  
Optional later (nice-to-have, not required):

- Public **operator directory** JSON (list of mirror base URLs) — still not consensus  
- Status page “CDN healthy / last dump age”  
- Multi-URL `urls[]` in `latest.json` (mesh M2) — clients already support this in Core Pro tree  

---

## How another org joins the mesh

1. Run dump-capable `dogecoind` (see Dogecoin-GPENode / Core Pro).  
2. `dumptxoutset` → publish `.dat` + `latest.json` on **their** HTTPS host.  
3. Clients use their manifest URL (`-snapshotmanifest=…`) **or** you add their URL to `urls[]` on a shared manifest once digests match.  
4. For a **new** height: coordinate attestation into a Core Pro release (`mapAssumeutxo`). Until then, clients need that map entry (or `-assumeutxodev` for testing only).

They never call GPE RPC. They never need GPE app credentials.

---

## GPE dump storage layout (this deployment)

| Volume | Role |
|--------|------|
| NVMe `/mnt/gpedogecloud` | Hot chainstate / wallet / live node |
| File System **gpenodestoredumps** `/mnt/gpenodestoredumps` | Scheduled UTXO dump artifacts (export only) |
| CDN box docroot | Public HTTPS copies of latest dump |

**Note:** A single dump is ~11 GB. A **50 GB** file system should keep **1–2** dumps max (retention in the scheduled runner).

---

## Do you need a GPE public API “to handle all of this properly”?

| Goal | Need GPE API? |
|------|----------------|
| Independent Fast Sync operators | **No** |
| GPE as one convenient CDN | **No** (static files enough) |
| GPE merchant settlement | Separate product path (private RPC) — not Fast Sync |
| Fancy operator registry / multi-CDN UI | Optional product later |

**Proper** = static HTTPS + hashes + client map + scheduled dumps.  
**Not required** = new public GPE control API for snapshots.
