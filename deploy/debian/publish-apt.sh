#!/usr/bin/env bash
# Publish one or more .deb files into a local apt tree, sign, rsync to CDN.
#
# Required env:
#   GPG_KEY_ID   — fingerprint or email of the signing key (private key on THIS machine)
# Optional:
#   APT_SSH      — default root@45.76.248.250 (prefer key auth)
#   APT_DOCROOT  — default /var/www/gpenode-apt
#   REPO_DIR     — local staging tree (default: out/apt-repo)
#   CODENAME     — default stable
#   COMPONENT    — default main
#   SKIP_RSYNC=1 — build local tree only
#
# Never copies GPG private keys to the CDN host.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
REPO_DIR="${REPO_DIR:-${ROOT}/out/apt-repo}"
CODENAME="${CODENAME:-stable}"
COMPONENT="${COMPONENT:-main}"
ARCH="${ARCH:-amd64}"
APT_SSH="${APT_SSH:-root@45.76.248.250}"
APT_DOCROOT="${APT_DOCROOT:-/var/www/gpenode-apt}"
GPG_KEY_ID="${GPG_KEY_ID:-}"

if [[ $# -lt 1 ]]; then
  echo "Usage: GPG_KEY_ID=... $0 path/to/package.deb [more.deb...]"
  exit 2
fi
[[ -n "$GPG_KEY_ID" ]] || { echo "ERROR: set GPG_KEY_ID to your apt signing key"; exit 1; }

need() { command -v "$1" >/dev/null || { echo "missing $1"; exit 1; }; }
need gpg
need rsync
need apt-ftparchive || {
  echo "missing apt-ftparchive (apt-utils / apt package)"
  exit 1
}

mkdir -p \
  "${REPO_DIR}/pool/${COMPONENT}" \
  "${REPO_DIR}/dists/${CODENAME}/${COMPONENT}/binary-${ARCH}"

for deb in "$@"; do
  [[ -f "$deb" ]] || { echo "not a file: $deb"; exit 1; }
  cp -a "$deb" "${REPO_DIR}/pool/${COMPONENT}/"
  echo "staged $(basename "$deb")"
done

# Packages index
(
  cd "$REPO_DIR"
  apt-ftparchive packages "pool/${COMPONENT}" > "dists/${CODENAME}/${COMPONENT}/binary-${ARCH}/Packages"
  gzip -9c "dists/${CODENAME}/${COMPONENT}/binary-${ARCH}/Packages" \
    > "dists/${CODENAME}/${COMPONENT}/binary-${ARCH}/Packages.gz"
)

# Release
APT_CONF="${REPO_DIR}/apt-ftparchive.conf"
cat > "$APT_CONF" <<EOF
APT::FTPArchive::Release {
  Origin "GPE Dogecoin";
  Label "dogecoin-gpenode";
  Suite "${CODENAME}";
  Codename "${CODENAME}";
  Architectures "${ARCH}";
  Components "${COMPONENT}";
  Description "GPE Dogecoin client apt repository";
};
EOF

(
  cd "$REPO_DIR"
  apt-ftparchive -c "$APT_CONF" release "dists/${CODENAME}" > "dists/${CODENAME}/Release"
  rm -f "dists/${CODENAME}/Release.gpg" "dists/${CODENAME}/InRelease"
  gpg --default-key "$GPG_KEY_ID" --armor --detach-sign -o "dists/${CODENAME}/Release.gpg" "dists/${CODENAME}/Release"
  gpg --default-key "$GPG_KEY_ID" --clearsign -o "dists/${CODENAME}/InRelease" "dists/${CODENAME}/Release"
)

# Export public key for CDN
PUBKEY_OUT="${REPO_DIR}/pubkey.gpg"
gpg --export --armor "$GPG_KEY_ID" > "$PUBKEY_OUT"
echo "wrote $PUBKEY_OUT"

# Minimal human page if missing (CDN may already have a nicer index.html)
if [[ ! -f "${REPO_DIR}/index.html" ]]; then
  cat > "${REPO_DIR}/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"/><title>GPE Dogecoin apt</title></head>
<body>
<h1>Dogecoin GPENode apt repository</h1>
<p>Static HTTPS only. Packages are GPG-signed.</p>
<pre>
curl -fsSL https://apt.dogecli.gopastearth.com/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/gpenode.gpg
echo "deb [signed-by=/usr/share/keyrings/gpenode.gpg] https://apt.dogecli.gopastearth.com stable main" | sudo tee /etc/apt/sources.list.d/gpenode.list
sudo apt update
sudo apt install dogecoin-gpenode
</pre>
</body></html>
HTML
fi

cat > "${REPO_DIR}/README.txt" <<EOF
GPE Dogecoin apt repository
Origin: https://apt.dogecli.gopastearth.com/
Package: dogecoin-gpenode
Static only — no RPC on this host.
EOF

echo "==> local tree ready at ${REPO_DIR}"

if [[ "${SKIP_RSYNC:-0}" == "1" ]]; then
  echo "SKIP_RSYNC=1 — not uploading"
  exit 0
fi

echo "==> rsync to ${APT_SSH}:${APT_DOCROOT}/ (public files only)"
# Do not sync apt-ftparchive.conf or any private material
rsync -av --delete \
  --exclude 'apt-ftparchive.conf' \
  --exclude '.git' \
  "${REPO_DIR}/" \
  "${APT_SSH}:${APT_DOCROOT}/"

echo "==> PUBLISH_OK"
echo "Verify:"
echo "  curl -fsSI https://apt.dogecli.gopastearth.com/pubkey.gpg"
echo "  curl -fsS https://apt.dogecli.gopastearth.com/dists/${CODENAME}/InRelease | head"
