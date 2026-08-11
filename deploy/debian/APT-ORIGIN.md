# GPENode apt origin (static HTTPS)

Public package feed for Debian/Ubuntu operators. **Static files only** — no Dogecoin RPC, no app API, no GPG private keys on the CDN host.

## Live origin

| Item | Value |
|------|--------|
| Hostname | `apt.dogecli.gopastearth.com` |
| Host (gpeproxybox) | `45.76.248.250` |
| Docroot | `/var/www/gpenode-apt` |
| Role | HTTPS origin for `pool/`, `dists/`, public `pubkey.gpg` |
| TLS | Let's Encrypt (managed on proxybox) |

Related hosts (**do not mix**):

| Host | Role |
|------|------|
| Main GPE (`104.207.140.143`) | App, `sync.doge.gopastearth.com` UTXO CDN |
| gpednode1 | Dump / snapshot producer |
| gpeproxybox | Edge static apt (this origin) |

## Security rules

1. **Only signed static files** under `/var/www/gpenode-apt`.
2. **`pubkey.gpg` = public key only** on the CDN.
3. **Never** put GPG private keys or signing secrets on proxybox.
4. Build and sign on a **build / main / CI** machine; publish via `rsync`/`scp`.
5. Prefer SSH keys into proxybox; disable password root login when practical.

## Operator install (after first signed publish)

```bash
curl -fsSL https://apt.dogecli.gopastearth.com/pubkey.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/gpenode.gpg
echo "deb [signed-by=/usr/share/keyrings/gpenode.gpg] https://apt.dogecli.gopastearth.com stable main" \
  | sudo tee /etc/apt/sources.list.d/gpenode.list
sudo apt update
sudo apt install dogecoin-gpenode
```

## Layout under docroot

```text
/var/www/gpenode-apt/
  index.html          # human install page (already on shell)
  README.txt
  pubkey.gpg          # public key (publish when ready)
  pool/main/...       # .deb files
  dists/stable/...    # Packages, Release, InRelease (signed)
```

## Build side (this repo)

| Script | Purpose |
|--------|---------|
| `build-deb.sh` | Assemble `.deb` from Linux binaries |
| `publish-apt.sh` | Sign indexes + rsync to proxybox (needs GPG + SSH) |
| `gen-rpc-password.sh` / `write-install-conf.sh` | Unique RPC for `postinst` |

See [README.md](./README.md).

## Package name

Default package: **`dogecoin-gpenode`** (lowercase, Debian style).

Do not advertise `apt install` until `pubkey.gpg`, `InRelease`, and at least one `.deb` are live.
