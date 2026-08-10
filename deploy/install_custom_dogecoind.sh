#!/usr/bin/env bash
# Install custom Core Pro dogecoind/cli onto gpednode1 (replace stock release).
# Expects binaries already uploaded to /tmp/gpe-custom-bin/{dogecoind,dogecoin-cli}
set -euo pipefail

SRC_DIR="${1:-/tmp/gpe-custom-bin}"
PREFIX="${PREFIX:-/opt/dogecoin-pro}"
DATADIR="$(cat /etc/dogecoin/datadir.path 2>/dev/null || echo /mnt/gpedogecloud/dogecoin)"
SERVICE="${SERVICE:-dogecoind-mainnet}"

if [[ ! -x "${SRC_DIR}/dogecoind" || ! -x "${SRC_DIR}/dogecoin-cli" ]]; then
  echo "ERROR: need executable dogecoind and dogecoin-cli in ${SRC_DIR}"
  ls -la "${SRC_DIR}" || true
  exit 1
fi

echo "==> stop ${SERVICE}"
systemctl stop "${SERVICE}" 2>/dev/null || true
# also stop legacy unit name if present
systemctl stop dogecoind 2>/dev/null || true
for i in $(seq 1 60); do
  pgrep -x dogecoind >/dev/null 2>&1 || break
  sleep 1
done
if pgrep -x dogecoind >/dev/null 2>&1; then
  echo "ERROR: dogecoind still running"
  exit 1
fi

echo "==> install to ${PREFIX}"
mkdir -p "${PREFIX}/bin" "${PREFIX}/bin.stock-backup"
# backup currently linked stock binaries once
if [[ -x /opt/dogecoin/bin/dogecoind && ! -e "${PREFIX}/bin.stock-backup/dogecoind" ]]; then
  cp -a /opt/dogecoin/bin/dogecoind /opt/dogecoin/bin/dogecoin-cli \
    "${PREFIX}/bin.stock-backup/" 2>/dev/null || true
fi
if [[ -x /usr/local/bin/dogecoind ]]; then
  cp -a /usr/local/bin/dogecoind "${PREFIX}/bin.stock-backup/dogecoind.usr-local" 2>/dev/null || true
  cp -a /usr/local/bin/dogecoin-cli "${PREFIX}/bin.stock-backup/dogecoin-cli.usr-local" 2>/dev/null || true
fi

install -m 0755 "${SRC_DIR}/dogecoind" "${PREFIX}/bin/dogecoind"
install -m 0755 "${SRC_DIR}/dogecoin-cli" "${PREFIX}/bin/dogecoin-cli"
ln -sfn "${PREFIX}/bin/dogecoind" /usr/local/bin/dogecoind
ln -sfn "${PREFIX}/bin/dogecoin-cli" /usr/local/bin/dogecoin-cli

# WSL/Ubuntu-built binaries need bundled boost/miniupnpc under ${PREFIX}/lib
export LD_LIBRARY_PATH="${PREFIX}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

echo "==> version"
if ! dogecoind -version 2>/dev/null | head -3; then
  echo "ERROR: dogecoind will not start — check LD_LIBRARY_PATH=${PREFIX}/lib and ldd"
  ldd "${PREFIX}/bin/dogecoind" 2>&1 | grep -i 'not found' || true
  exit 1
fi
if ! dogecoind -version 2>/dev/null | head -1 | grep -qi dogecoin; then
  echo "WARN: unexpected version string"
fi

# Ensure mainnet unit points at NVMe datadir (do not rewrite if already correct)
if [[ -f /etc/systemd/system/dogecoind-mainnet.service ]]; then
  systemctl daemon-reload
fi

echo "==> start ${SERVICE}"
systemctl start "${SERVICE}"
sleep 3
systemctl is-active "${SERVICE}" || systemctl status "${SERVICE}" --no-pager -l | head -30

echo "==> wait for RPC"
for i in $(seq 1 90); do
  if sudo -u dogecoin dogecoin-cli -datadir="${DATADIR}" getblockcount >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

echo "==> tip + dumptxoutset help"
sudo -u dogecoin dogecoin-cli -datadir="${DATADIR}" getblockchaininfo | \
  python3 -c "import sys,json;d=json.load(sys.stdin);print('chain',d.get('chain'),'blocks',d.get('blocks'),'ibd',d.get('initialblockdownload'))"
if sudo -u dogecoin dogecoin-cli -datadir="${DATADIR}" help dumptxoutset 2>&1 | grep -qi 'unknown command'; then
  echo "ERROR: dumptxoutset still missing"
  exit 2
fi
sudo -u dogecoin dogecoin-cli -datadir="${DATADIR}" help dumptxoutset | head -8
echo "INSTALL_OK custom Core Pro daemon on ${SERVICE}"
