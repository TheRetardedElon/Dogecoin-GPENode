# Security policy

## Secrets

This repository must **never** contain:

- Root or SSH passwords  
- RPC passwords / cookies from live nodes  
- Private keys (`id_ed25519`, wallet seeds)  
- Live `dogecoin.conf` with credentials  
- Real host inventory that embeds credentials  

Use:

- `serverdetails.example.txt` → local `serverdetails.txt` (gitignored)  
- `local/` for keys (gitignored)  
- Placeholder conf under `deploy/conf/*.example`  

## Threat model (Fast Sync)

- CDN is a **dumb static file host** — not consensus.  
- Clients verify **file SHA-256** + **`mapAssumeutxo` / `hash_serialized`** + background prove.  
- Dump node RPC must stay on **127.0.0.1** (or private network only).  

## Reporting

If you find a credential or private key in this repo or a release artifact, open a private security report to the maintainers and assume the secret is burned (rotate immediately).
