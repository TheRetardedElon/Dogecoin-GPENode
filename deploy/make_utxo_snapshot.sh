#!/usr/bin/env bash
# Produce a UTXO snapshot + digests under /mnt/gpedogecloud/snapshots.
# Requires dogecoind with dumptxoutset (custom GPE build — NOT stock 1.14.9).
set -euo pipefail

DATADIR="$(cat /etc/dogecoin/datadir.path 2>/dev/null || echo /mnt/gpedogecloud/dogecoin)"
OUTDIR="${OUTDIR:-/mnt/gpedogecloud/snapshots}"
CLI=(sudo -u dogecoin dogecoin-cli -datadir="${DATADIR}")

mkdir -p "${OUTDIR}"
chmod 755 "${OUTDIR}"

# Stock 1.14.9: `help dumptxoutset` often exits 0 with "unknown command: dumptxoutset".
HELP_OUT="$("${CLI[@]}" help dumptxoutset 2>&1 || true)"
if echo "${HELP_OUT}" | grep -qiE 'unknown command|Method not found'; then
  cat <<EOF
ERROR: this dogecoind has no dumptxoutset RPC.
Stock v1.14.9 cannot produce AssumeUTXO snapshots.
Install a custom GPE daemon build (with loadtxoutset/dumptxoutset), then re-run.
Binary now: $(dogecoind -version 2>/dev/null | head -1 || echo unknown)
help said: ${HELP_OUT}
EOF
  exit 2
fi
if ! echo "${HELP_OUT}" | grep -qi 'dumptxoutset'; then
  cat <<EOF
ERROR: dumptxoutset help did not look valid.
${HELP_OUT}
Binary: $(dogecoind -version 2>/dev/null | head -1 || echo unknown)
EOF
  exit 2
fi

echo "==> chain tip"
"${CLI[@]}" getblockchaininfo > "${OUTDIR}/.last_blockchaininfo.json"
python3 - "${OUTDIR}/.last_blockchaininfo.json" <<'PY'
import json, sys
from pathlib import Path
d = json.loads(Path(sys.argv[1]).read_text())
print("chain", d.get("chain"), "blocks", d.get("blocks"), "headers", d.get("headers"),
      "ibd", d.get("initialblockdownload"), "progress", round(d.get("verificationprogress",0)*100,2))
if d.get("initialblockdownload"):
    print("WARNING: still in IBD — prefer waiting for tip before publishing")
if d.get("chain") != "main":
    print("WARNING: not mainnet")
PY

BLOCKS="$("${CLI[@]}" getblockcount)"
BEST="$("${CLI[@]}" getbestblockhash)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BASE="utxo-${BLOCKS}-${STAMP}"
TMP="${OUTDIR}/${BASE}.dat.partial"
FINAL="${OUTDIR}/${BASE}.dat"
chown dogecoin:dogecoin "${OUTDIR}" 2>/dev/null || true

echo "==> dumptxoutset -> ${TMP}"
# RPC returns JSON with coins_written, base_hash, base_height, path, txoutset_hash / hash_serialized (build-dependent)
DUMP_JSON="$("${CLI[@]}" dumptxoutset "${TMP}")"
echo "${DUMP_JSON}" | tee "${OUTDIR}/${BASE}.dumptxoutset.json"

# some builds write exactly to path; ensure final name
if [[ -f "${TMP}" ]]; then
  mv -f "${TMP}" "${FINAL}"
elif [[ -f "${OUTDIR}/utxo.dat" ]]; then
  mv -f "${OUTDIR}/utxo.dat" "${FINAL}"
else
  # parse path from JSON if present
  PATH_FROM_JSON="$(echo "${DUMP_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null || true)"
  if [[ -n "${PATH_FROM_JSON}" && -f "${PATH_FROM_JSON}" ]]; then
    mv -f "${PATH_FROM_JSON}" "${FINAL}"
  else
    echo "ERROR: could not locate dump output file"
    exit 1
  fi
fi

echo "==> sha256"
SHA="$(sha256sum "${FINAL}" | awk '{print $1}')"
echo "${SHA}  $(basename "${FINAL}")" | tee "${FINAL}.sha256"
BYTES="$(stat -c%s "${FINAL}")"

# Write latest.json via env vars (avoid nested shell quoting bugs)
export SNAP_OUTDIR="${OUTDIR}"
export SNAP_FINAL="${FINAL}"
export SNAP_SHA="${SHA}"
export SNAP_BYTES="${BYTES}"
export SNAP_BLOCKS="${BLOCKS}"
export SNAP_BEST="${BEST}"
export SNAP_DUMP_JSON="${OUTDIR}/${BASE}.dumptxoutset.json"
python3 <<'PY'
import json, os, pathlib
from datetime import datetime, timezone
out = pathlib.Path(os.environ["SNAP_OUTDIR"])
final = pathlib.Path(os.environ["SNAP_FINAL"])
dump = {}
p = pathlib.Path(os.environ.get("SNAP_DUMP_JSON", ""))
if p.is_file():
    dump = json.loads(p.read_text())
primary = "https://sync.doge.gopastearth.com/" + final.name
# urls[] reserved for mesh M2 multi-mirror failover (same sha256). Today: single primary.
meta = {
  "network": "main",
  "hostname": "sync.doge.gopastearth.com",
  "url": primary,
  "urls": [primary],
  "filename": final.name,
  "sha256": os.environ["SNAP_SHA"],
  "bytes": int(os.environ["SNAP_BYTES"]),
  "blocks": int(dump.get("base_height") or os.environ["SNAP_BLOCKS"]),
  "bestblock": dump.get("base_hash") or os.environ["SNAP_BEST"],
  "hash_serialized": dump.get("hash_serialized") or dump.get("txoutset_hash") or dump.get("coins_hash"),
  "created_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
  "producer": "gpenode-operator",
  "notes": "Pruned node UTXO dump for Fast Sync; clients verify sha256 fail-closed. Mesh M2: append mirror URLs to urls[].",
}
path = out / "latest.json"
path.write_text(json.dumps(meta, indent=2) + "\n")
path.chmod(0o644)
print(path.read_text())
PY

chown -R dogecoin:dogecoin "${OUTDIR}" 2>/dev/null || true
chmod 644 "${FINAL}" "${FINAL}.sha256" "${OUTDIR}/latest.json" 2>/dev/null || true

echo "==> SNAPSHOT_OK"
echo "file=${FINAL}"
echo "sha256=${SHA}"
echo "Publish: rsync -avP ${OUTDIR}/  <gpe-box>:/var/www/doge-sync/"
