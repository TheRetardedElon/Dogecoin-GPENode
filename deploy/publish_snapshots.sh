#!/usr/bin/env bash
# Publish snapshot export dir to CDN docroot (push mode).
# Prefer pull on the CDN host when possible; this script is for node-side push.
#
# Config via env (no secrets in repo):
#   SNAP_DIR   default: /mnt/gpedogecloud/snapshots
#   CDN_TARGET rsync destination, e.g. deploy@cdn-box:/var/www/doge-sync/
#   DRY_RUN=1  print only
set -euo pipefail

SNAP_DIR="${SNAP_DIR:-/mnt/gpedogecloud/snapshots}"
CDN_TARGET="${CDN_TARGET:-}"
DRY_RUN="${DRY_RUN:-0}"

if [[ ! -d "${SNAP_DIR}" ]]; then
  echo "ERROR: SNAP_DIR missing: ${SNAP_DIR}"
  exit 1
fi
if [[ ! -f "${SNAP_DIR}/latest.json" ]]; then
  echo "ERROR: ${SNAP_DIR}/latest.json missing — run make_utxo_snapshot.sh first"
  exit 1
fi
if [[ -z "${CDN_TARGET}" ]]; then
  cat <<EOF
ERROR: set CDN_TARGET to rsync destination, e.g.
  export CDN_TARGET='deploy@cdn-host:/var/www/doge-sync/'
  $0
Or pull from CDN host instead:
  rsync -avP user@dump-node:${SNAP_DIR}/ /var/www/doge-sync/
EOF
  exit 2
fi

echo "==> latest.json"
python3 - <<PY
import json
from pathlib import Path
p = Path("${SNAP_DIR}") / "latest.json"
d = json.loads(p.read_text())
for k in ("filename", "sha256", "blocks", "bytes", "url"):
    print(f"  {k}: {d.get(k)}")
urls = d.get("urls") or []
if urls:
    print("  urls:")
    for u in urls:
        print(f"    - {u}")
PY

RSYNC=(rsync -avP --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r)
if [[ "${DRY_RUN}" == "1" ]]; then
  RSYNC+=(--dry-run)
  echo "==> DRY_RUN"
fi

echo "==> rsync ${SNAP_DIR}/ -> ${CDN_TARGET}"
"${RSYNC[@]}" "${SNAP_DIR}/" "${CDN_TARGET}"

echo "==> PUBLISH_OK"
echo "Verify from anywhere:"
echo "  curl -fsS https://sync.doge.gopastearth.com/latest.json | head"
echo "  # sha256sum of downloaded .dat must match latest.json sha256"
