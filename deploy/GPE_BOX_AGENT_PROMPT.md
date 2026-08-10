# Prompt to paste to the CDN / app-box agent

Copy everything below the line into that agent’s chat.

---

You are working on the **CDN / application web host** (NOT the Dogecoin dump / settlement node).

## Goal

Stand up a **public Fast Sync CDN** hostname (example):

**`sync.doge.gopastearth.com`** (or your own hostname)

It must serve **static HTTPS files only** (UTXO snapshot `.dat` + checksums + `latest.json`).  
It must **never** proxy or expose Dogecoin RPC.

## Context

- **Dump node** (separate host): headless `dogecoind` with `dumptxoutset`; NVMe datadir; RPC **localhost only**  
- Snapshot export dir on dump node: e.g. `/mnt/<block-volume>/snapshots/`  
- **This box**: public website / static CDN — DNS for the sync hostname should point **here**  
- Ops write-up: `deploy/SYNC_CDN_HANDOFF.md`

## Your tasks

1. **DNS** — A record for the sync hostname → **this box’s public IPv4** (not the dump node RPC host unless you deliberately co-locate static files there)  
2. **Document root** — e.g. `/var/www/doge-sync`  
3. **nginx** — TLS, static only, long cache for versioned `.dat`, short cache for `latest.json`, **no** upstream to dogecoind / 22555  
4. **Firewall** — 80/443 only for this role; no Dogecoin RPC ports  
5. **Placeholder** until first snapshot — short `index.html` + optional stub `latest.json`  
6. **Receive pipeline** — prefer **pull** from dump node via SSH keys:  
   `rsync -avP user@<DUMP_NODE_HOST>:/path/to/snapshots/ /var/www/doge-sync/`  
   Never commit passwords  
7. **Acceptance** — HTTPS works; `curl -I https://…/latest.json` → 200  

## Out of scope

- Do not install or reconfigure dogecoind  
- Do not put wallet or RPC credentials in the web root  
- Snapshot **creation** is on the dump node; you only **host** artifacts  
- Mesh M1 = single CDN; M2 may add `urls[]` mirrors with the **same** sha256  
