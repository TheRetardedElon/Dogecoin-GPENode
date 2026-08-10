#!/usr/bin/env bash
# Copy built gpenode-ops into out/ for scp to the dump node.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/out/gpenode-ops"
mkdir -p "${OUT}"

if [[ -f "${ROOT}/gpenode-ops/gpenode-ops" ]]; then
  install -m 755 "${ROOT}/gpenode-ops/gpenode-ops" "${OUT}/gpenode-ops-linux-amd64"
  echo "staged ${OUT}/gpenode-ops-linux-amd64"
fi
if [[ -f "${ROOT}/gpenode-ops/gpenode-ops.exe" ]]; then
  install -m 755 "${ROOT}/gpenode-ops/gpenode-ops.exe" "${OUT}/gpenode-ops-windows-amd64.exe"
  echo "staged ${OUT}/gpenode-ops-windows-amd64.exe"
fi

# Ship deploy scripts alongside for /opt/gpe-deploy
mkdir -p "${OUT}/deploy"
cp -a "${ROOT}/deploy/"*.sh "${OUT}/deploy/" 2>/dev/null || true
cp -a "${ROOT}/deploy/"*.md "${OUT}/deploy/" 2>/dev/null || true
cp -a "${ROOT}/deploy/conf" "${OUT}/deploy/" 2>/dev/null || true
cp -a "${ROOT}/deploy/systemd" "${OUT}/deploy/" 2>/dev/null || true
cp -a "${ROOT}/deploy/samples" "${OUT}/deploy/" 2>/dev/null || true

cat > "${OUT}/INSTALL.txt" <<'EOF'
GPENode operator stage package
==============================

On dump node (Linux):
  sudo mkdir -p /opt/gpe-deploy /opt/gpenode-ops/bin
  sudo cp -a deploy/* /opt/gpe-deploy/
  sudo install -m 755 gpenode-ops-linux-amd64 /opt/gpenode-ops/bin/gpenode-ops

  export DOGECOIN_DATADIR=/path/to/datadir
  export DOGECOIN_CLI=/opt/dogecoin-pro/bin/dogecoin-cli
  export SNAP_SCRIPT=/opt/gpe-deploy/make_utxo_snapshot.sh
  /opt/gpenode-ops/bin/gpenode-ops status
  /opt/gpenode-ops/bin/gpenode-ops verify-cdn

Headless dogecoind build (on build machine with full deps):
  bash deploy/build-dump-daemon.sh
  # then install_custom_dogecoind.sh with staged binaries
EOF

echo "==> STAGE_OK ${OUT}"
ls -la "${OUT}"
