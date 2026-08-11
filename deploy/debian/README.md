# Debian package: dogecoin-gpenode

Headless GPENode for Debian/Ubuntu: `dogecoind` + `dogecoin-cli` + `gpenode-ops` (+ optional `gpenode-tui`), systemd unit, unique RPC password on first install.

Same mainnet consensus as Core Pro — **no Qt GUI**.

## Paths after install

| Path | Purpose |
|------|---------|
| `/usr/bin/dogecoind` | Daemon |
| `/usr/bin/dogecoin-cli` | RPC CLI |
| `/usr/bin/gpenode-ops` | Operator glue |
| `/usr/bin/gpenode-tui` | Operator TUI (if built into package) |
| `/etc/dogecoin-gpenode/dogecoin.conf` | Node config |
| `/var/lib/dogecoin-gpenode/` | Datadir |
| `/var/lib/dogecoin-gpenode/RPC-CREDENTIALS.txt` | Unique password (root/dogecoin only) |
| `/lib/systemd/system/dogecoin-gpenode.service` | systemd unit |
| `/usr/lib/dogecoin-gpenode/` | Optional bundled libs (`LD_LIBRARY_PATH`) |

## Build a `.deb` (WSL / Linux)

Prerequisites:

- `dpkg-deb`
- Built Linux binaries:
  - `dogecoind`, `dogecoin-cli` (from headless build or staged release)
  - `gpenode-ops` (`gpenode-ops/build-linux.sh`)
  - optional: `gpenode-tui` Linux binary

```bash
cd deploy/debian
# Point at your staged Linux bins (example: headless release)
export BIN_DIR=/path/to/bin   # must contain dogecoind, dogecoin-cli, gpenode-ops
export VERSION=1.14.102
export ARCH=amd64
bash ./build-deb.sh
# Output: out/dogecoin-gpenode_${VERSION}-1_${ARCH}.deb
```

From a packaged headless tarball:

```bash
tar -xzf dogecoin-gpenode-linux-x86_64-*.tar.gz
export BIN_DIR="$PWD/dogecoin-gpenode-linux-x86_64-*/bin"
# if libs were bundled:
export LIB_DIR="$PWD/dogecoin-gpenode-linux-x86_64-*/lib"
bash deploy/debian/build-deb.sh
```

## First-install behavior (`postinst`)

1. Creates system user `dogecoin` (if missing).
2. Ensures datadir `/var/lib/dogecoin-gpenode`.
3. If conf missing: writes unique `rpcuser`/`rpcpassword` (UTF-8, no BOM concerns) + `RPC-CREDENTIALS.txt`.
4. `systemctl enable --now dogecoin-gpenode` (unless `DISABLE_GPENODE_AUTOSTART=1`).

## Publish to apt.dogecli.gopastearth.com

See [APT-ORIGIN.md](./APT-ORIGIN.md). High level:

```bash
# On build machine (GPG private key present, never on CDN):
export APT_SSH="root@45.76.248.250"   # or deploy user + key
export APT_DOCROOT="/var/www/gpenode-apt"
export GPG_KEY_ID="..."               # apt signing key fingerprint or email
bash ./publish-apt.sh out/dogecoin-gpenode_*.deb
```

`publish-apt.sh` stages `pool/` + regenerates `dists/` with `apt-ftparchive` (or uses `reprepro` if configured), signs `Release`, rsyncs to proxybox, and can push public `pubkey.gpg`.

## Shell experience (parity with Windows)

After install:

```bash
gpenode-ops status
gpenode-tui          # if packaged; colors when TERM supports it
sudo systemctl status dogecoin-gpenode
sudo journalctl -u dogecoin-gpenode -f
```

## Conflicts

This package installs `dogecoind` / `dogecoin-cli` into `/usr/bin`. It **Conflicts** with classic `dogecoind` / `dogecoin-qt` packages from other sources. Use a dedicated machine or remove the other packages first.
