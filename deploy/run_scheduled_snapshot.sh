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

  # Optional push: only if /etc/dogecoin/snapshot-publish.env defines CDN_TARGET
  if [[ -f /etc/dogecoin/snapshot-publish.env ]]; then
    # shellcheck disable=SC1091
    set -a
    # shellcheck source=/dev/null
    source /etc/dogecoin/snapshot-publish.env
    set +a
  fi
  if [[ -n "${CDN_TARGET:-}" ]]; then
    echo "==> publish CDN_TARGET=${CDN_TARGET}"
    bash /opt/gpe-deploy/publish_snapshots.sh
  else
    echo "==> no CDN_TARGET set — dump local only (CDN should pull)"
    echo "    Prefer on CDN box: rsync -avP root@DUMP_NODE:/mnt/gpedogecloud/snapshots/ /var/www/doge-sync/"
  fi
  echo "======== $(date -u +%Y-%m-%dT%H:%M:%SZ) DONE ========"
} 2>&1 | tee -a "${LOGDIR}/snapshot.log"
