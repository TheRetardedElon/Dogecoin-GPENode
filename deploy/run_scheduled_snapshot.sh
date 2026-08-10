#!/usr/bin/env bash
# One-shot entry for systemd timer: dump UTXO snapshot (+ optional publish).
# Safe to run while dogecoind is up; dumps are I/O heavy on small RAM boxes.
set -euo pipefail

export PATH="/opt/dogecoin-pro/bin:/usr/local/bin:${PATH:-}"
export LD_LIBRARY_PATH="/opt/dogecoin-pro/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

LOGDIR="${LOGDIR:-/var/log/gpenode}"
LOCK="${LOCK:-/run/gpenode-snapshot.lock}"
mkdir -p "${LOGDIR}"

exec 9>"${LOCK}"
if ! flock -n 9; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) SKIP: another snapshot run holds ${LOCK}" | tee -a "${LOGDIR}/snapshot.log"
  exit 0
fi

{
  echo "======== $(date -u +%Y-%m-%dT%H:%M:%SZ) START scheduled snapshot ========"

  # Load OUTDIR / CDN_TARGET / SNAPSHOT_PRODUCER (no secrets required)
  if [[ -f /etc/dogecoin/snapshot-publish.env ]]; then
    set -a
    # shellcheck disable=SC1091
    source /etc/dogecoin/snapshot-publish.env
    set +a
  fi
  # Default dump store: dedicated FS gpenodestoredumps (50GB) when mounted
  if [[ -z "${OUTDIR:-}" ]]; then
    if mountpoint -q /mnt/gpenodestoredumps 2>/dev/null; then
      OUTDIR=/mnt/gpenodestoredumps/snapshots
    else
      OUTDIR=/mnt/gpedogecloud/snapshots
    fi
  fi
  export OUTDIR
  mkdir -p "${OUTDIR}"
  echo "OUTDIR=${OUTDIR}"
  df -h "${OUTDIR}" || true

  # Retention: multi-GB dumps — keep newest N .dat files (default 2 on 50GB volume)
  KEEP_N="${KEEP_SNAPSHOTS:-2}"

  # Wait until RPC is ready (not -28 loading)
  DATADIR="$(cat /etc/dogecoin/datadir.path 2>/dev/null || echo /mnt/gpedogecloud/dogecoin)"
  for i in $(seq 1 60); do
    if sudo -u dogecoin env LD_LIBRARY_PATH="${LD_LIBRARY_PATH}" \
         dogecoin-cli -datadir="${DATADIR}" getblockcount >/dev/null 2>&1; then
      break
    fi
    sleep 5
  done

  bash /opt/gpe-deploy/make_utxo_snapshot.sh

  # Prune old utxo-*.dat (keep latest KEEP_N + sidecars for those bases)
  echo "==> retention keep=${KEEP_N}"
  mapfile -t olds < <(ls -1t "${OUTDIR}"/utxo-*.dat 2>/dev/null | tail -n +$((KEEP_N + 1)) || true)
  for f in "${olds[@]:-}"; do
    [[ -z "${f}" ]] && continue
    base="${f%.dat}"
    echo "  remove ${f}"
    rm -f "${f}" "${f}.sha256" "${base}.dumptxoutset.json" 2>/dev/null || true
  done

  if [[ -n "${CDN_TARGET:-}" ]]; then
    echo "==> publish CDN_TARGET=${CDN_TARGET}"
    bash /opt/gpe-deploy/publish_snapshots.sh
  else
    echo "==> no CDN_TARGET set — dump local only (CDN should pull)"
    echo "    On CDN box: rsync -avP root@DUMP_NODE:${OUTDIR}/ /var/www/doge-sync/"
  fi
  echo "======== $(date -u +%Y-%m-%dT%H:%M:%SZ) DONE ========"
} 2>&1 | tee -a "${LOGDIR}/snapshot.log"
