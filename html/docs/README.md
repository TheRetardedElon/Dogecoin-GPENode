# GPENode — HTML operator documentation

Living docs for the **`C:\dogedevGPEnode`** worktree (settlement dump node + CDN publish path).

## Open

```
html/docs/index.html
```

No server required (`file://` works).

## This is not dogedev’s product dashboard

| Tree | Docs purpose |
|------|----------------|
| **This tree** | Operator: dump, publish, mesh M1, private RPC, deploy kit |
| **`C:\dogedev`** | Core Pro product: GUI, Windows packages, client Fast Sync |

After a bulk `sync-dogedev-to-gpenode`, **re-check** that `index.html` and `assets/nav.js` still say GPENode (see root `SYNC_FROM_DOGEDEV.txt`).

## Structure

| Path | Purpose |
|------|---------|
| `index.html` | **GPENode operator dashboard** |
| `pages/gpenode.html` | Operator overview |
| `pages/operator-roadmap.html` | What to build next on this tree |
| `pages/multi-operator-mesh.html` | Mesh M0–M4 |
| `pages/fast-sync.html` | Client story (what your CDN serves) |
| `pages/fast-sync-threat-model.html` | CDN threat model |
| `pages/diagrams.html` | Eraser architecture art |
| `pages/assumeutxo.html` | Why dump RPCs exist |
| `assets/nav.js` | **Operator-first** sidebar |
| `assets/diagrams/` | Master / Fast Sync / dual chainstate PNGs |

On-disk kit (markdown/scripts): root `GPENODE.md`, `deploy/*`, `scripts/README-GPENODE.md`.

## Secrets

Do **not** put host passwords, RPC passwords, or private keys in HTML.  
Use gitignored `serverdetails.txt` / `local/` only.

## When to update

- After dump/CDN/mesh changes on the live operator path  
- After changing `deploy/` scripts  
- When re-exporting architecture diagrams  
- After syncing daemon code from dogedev (confirm docs still operator-first)  
