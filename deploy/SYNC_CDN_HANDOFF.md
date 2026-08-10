# Fast Sync CDN — handoff (static host only)

**Public hostname:** `sync.doge.gopastearth.com`  
**Role of this box:** HTTPS static file host for UTXO snapshots.  
**Role of dump node (GPENode):** produce snapshots on NVMe; **never** expose dogecoind RPC publicly.

Mesh stage: **M1 live** (single public CDN). **M2** adds multi-URL mirrors of the same digests.

Private host facts (IPs, keys) live in operator-local secrets — **not** in this file’s committed form if you strip them for OSS. Do not commit passwords.

---

## DNS

```text
sync.doge.gopastearth.com.   A   <PUBLIC_IP_OF_CDN_BOX>
```

- Point at the **CDN / app box**, not the dump node’s RPC.
- After TLS works, optional CDN/proxy in front is fine for static downloads.

---

## What to serve

```text
https://sync.doge.gopastearth.com/
  index.html                    (optional short status)
  latest.json                   (pointer: url, height, sha256, bytes, …)
  utxo-HEIGHT-TIMESTAMP.dat     (UTXO snapshot artifact)
  utxo-HEIGHT-TIMESTAMP.dat.sha256
```

**Do not** reverse-proxy to dogecoin RPC.  
**Do not** mount the live datadir over HTTP.

---

## nginx sketch

```nginx
# /etc/nginx/sites-available/sync.doge.gopastearth.com
server {
    listen 80;
    listen [::]:80;
    server_name sync.doge.gopastearth.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name sync.doge.gopastearth.com;

    # certbot fills ssl_certificate lines
    root /var/www/doge-sync;
    autoindex off;

    client_max_body_size 0;
    sendfile on;
    tcp_nopush on;

    location / {
        try_files $uri $uri/ =404;
        add_header Cache-Control "public, max-age=300";
        add_header X-Content-Type-Options nosniff;
        add_header Access-Control-Allow-Origin "*";
    }

    location ~* \.dat$ {
        add_header Cache-Control "public, max-age=31536000, immutable";
        add_header X-Content-Type-Options nosniff;
        add_header Access-Control-Allow-Origin "*";
        types { application/octet-stream dat; }
        default_type application/octet-stream;
    }

    location = /latest.json {
        add_header Cache-Control "public, max-age=60";
        add_header Access-Control-Allow-Origin "*";
        default_type application/json;
    }
}
```

```bash
sudo mkdir -p /var/www/doge-sync
sudo chown -R www-data:www-data /var/www/doge-sync
sudo ln -s /etc/nginx/sites-available/sync.doge.gopastearth.com \
           /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d sync.doge.gopastearth.com
```

Firewall: **80/tcp** and **443/tcp** for this vhost. No Dogecoin RPC ports on this box.

---

## How files arrive from the dump node

Prefer **pull on the CDN host** after a successful dump:

```bash
# CDN box pulls snapshot export dir (path is operator-specific)
rsync -avP <dump-node>:/path/to/snapshots/ /var/www/doge-sync/
```

Use SSH keys only. Never paste root passwords into chat or git.

---

## `latest.json` shape

```json
{
  "network": "main",
  "hostname": "sync.doge.gopastearth.com",
  "url": "https://sync.doge.gopastearth.com/utxo-….dat",
  "filename": "utxo-….dat",
  "sha256": "<file hex>",
  "bytes": 0,
  "blocks": 6324519,
  "bestblock": "<hash>",
  "hash_serialized": "<from dumptxoutset>",
  "created_utc": "2026-08-10T00:00:00Z",
  "producer": "gpenode-operator",
  "notes": "Clients verify sha256 fail-closed; activation needs mapAssumeutxo."
}
```

### Mesh-ready extension (M2)

```json
{
  "sha256": "<same file digest>",
  "blocks": 6324519,
  "hash_serialized": "<same>",
  "url": "https://sync.doge.gopastearth.com/utxo-….dat",
  "urls": [
    "https://sync.doge.gopastearth.com/utxo-….dat",
    "https://mirror.example.org/dogecoin/utxo-….dat"
  ]
}
```

Core Pro today uses primary `url`. M2 clients will try `urls[]` with the **same** expected sha256.

---

## Acceptance checklist

1. DNS → this box public IP  
2. HTTPS cert valid  
3. `curl -I https://sync.doge.gopastearth.com/latest.json` → 200  
4. Large `.dat` downloads complete; `sha256sum` matches published digests  
5. No open path to dogecoind RPC from the public internet  
6. Optional: short `index.html` for humans  

---

## Dump production note

Snapshot **creation** runs on the dump node with a custom daemon:

```bash
bash /opt/gpe-deploy/make_utxo_snapshot.sh
```

CDN only **hosts** artifacts. See `OPERATOR_KIT.md` and product page `gpenode.html`.
