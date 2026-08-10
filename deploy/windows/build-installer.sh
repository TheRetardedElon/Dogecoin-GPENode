#!/usr/bin/env bash
# Build NSIS setup.exe for GPENode / Core Pro Headless (Windows x64).
# Run under WSL with makensis installed.
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/local/bin:${PATH:-}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="${VERSION:-1.14.102}"
BIN_DIR="${BIN_DIR:-${ROOT}/bin}"
OUT_DIR="${OUT_DIR:-/mnt/c/dogedevGPEnode/out/windows-headless}"
ASSETS="${ASSETS:-/mnt/c/dogedev/share/pixmaps}"
STAGE="${OUT_DIR}/nsis-stage"
SETUP_NAME="dogecoin-gpenode-${VERSION}-win64-setup.exe"

need() { command -v "$1" >/dev/null || { echo "missing $1"; exit 1; }; }
need makensis

[[ -f "${BIN_DIR}/dogecoind.exe" ]] || { echo "missing ${BIN_DIR}/dogecoind.exe — run build-headless-win64.sh first"; exit 1; }
[[ -f "${BIN_DIR}/dogecoin-cli.exe" ]] || { echo "missing ${BIN_DIR}/dogecoin-cli.exe"; exit 1; }
[[ -f "${ASSETS}/dogecoin.ico" ]] || { echo "missing ${ASSETS}/dogecoin.ico"; exit 1; }
[[ -f "${ASSETS}/nsis-wizard.bmp" ]] || { echo "missing nsis-wizard.bmp"; exit 1; }
[[ -f "${ASSETS}/nsis-header.bmp" ]] || { echo "missing nsis-header.bmp"; exit 1; }

rm -rf "${STAGE}"
mkdir -p "${STAGE}/bin" "${STAGE}/conf" "${OUT_DIR}"

cp -a "${BIN_DIR}/dogecoind.exe" "${BIN_DIR}/dogecoin-cli.exe" "${STAGE}/bin/"
# SCM wrapper (required for Windows Service — dogecoind is not a native service)
if [[ -f "${BIN_DIR}/gpenode-ops.exe" ]]; then
  cp -a "${BIN_DIR}/gpenode-ops.exe" "${STAGE}/bin/"
elif [[ -f /mnt/c/dogedevGPEnode/gpenode-ops/gpenode-ops.exe ]]; then
  cp -a /mnt/c/dogedevGPEnode/gpenode-ops/gpenode-ops.exe "${STAGE}/bin/"
elif [[ -f /mnt/c/dogedevGPEnode/out/gpenode-ops/gpenode-ops-windows-amd64.exe ]]; then
  cp -a /mnt/c/dogedevGPEnode/out/gpenode-ops/gpenode-ops-windows-amd64.exe "${STAGE}/bin/gpenode-ops.exe"
else
  echo "ERROR: missing gpenode-ops.exe (Windows service wrapper)"
  exit 1
fi
# Tray icon (W3)
if [[ -f "${BIN_DIR}/gpenode-tray.exe" ]]; then
  cp -a "${BIN_DIR}/gpenode-tray.exe" "${STAGE}/bin/"
elif [[ -f /mnt/c/dogedevGPEnode/gpenode-tray/gpenode-tray.exe ]]; then
  cp -a /mnt/c/dogedevGPEnode/gpenode-tray/gpenode-tray.exe "${STAGE}/bin/"
elif [[ -f /mnt/c/dogedevGPEnode/out/gpenode-ops/gpenode-tray.exe ]]; then
  cp -a /mnt/c/dogedevGPEnode/out/gpenode-ops/gpenode-tray.exe "${STAGE}/bin/"
else
  echo "ERROR: missing gpenode-tray.exe (build gpenode-tray/build-windows.ps1)"
  exit 1
fi
cp -a "${ROOT}/install-service.ps1" "${ROOT}/uninstall-service.ps1" "${ROOT}/status-service.ps1" "${STAGE}/"
# Unique RPC password helpers (required)
[[ -f "${ROOT}/write-install-conf.ps1" ]] || { echo "missing write-install-conf.ps1"; exit 1; }
[[ -f "${ROOT}/gen-rpc-password.ps1" ]] || { echo "missing gen-rpc-password.ps1"; exit 1; }
[[ -f "${ROOT}/nsis-rpc-credentials.nsh" ]] || { echo "missing nsis-rpc-credentials.nsh"; exit 1; }
cp -a "${ROOT}/write-install-conf.ps1" "${ROOT}/gen-rpc-password.ps1" "${ROOT}/nsis-rpc-credentials.nsh" "${STAGE}/"
cp -a "${ROOT}/conf/"*.example "${STAGE}/conf/"
cp -a "${ROOT}/setup-gpenode-headless.nsi" "${STAGE}/"
# Optional TUI
if [[ -f "${BIN_DIR}/gpenode-tui.exe" ]]; then
  cp -a "${BIN_DIR}/gpenode-tui.exe" "${STAGE}/bin/"
elif [[ -f /mnt/c/dogedevGPEnode/gpenode-tui/gpenode-tui.exe ]]; then
  cp -a /mnt/c/dogedevGPEnode/gpenode-tui/gpenode-tui.exe "${STAGE}/bin/"
fi

# License + readme for wizard
if [[ -f /mnt/c/dogedev/COPYING ]]; then
  cp -a /mnt/c/dogedev/COPYING "${STAGE}/LICENSE.txt"
elif [[ -f /mnt/c/dogedevGPEnode/COPYING ]]; then
  cp -a /mnt/c/dogedevGPEnode/COPYING "${STAGE}/LICENSE.txt"
else
  echo "MIT License — see https://opensource.org/licenses/MIT" > "${STAGE}/LICENSE.txt"
fi

cat > "${STAGE}/README.txt" <<EOF
Dogecoin GPENode / Core Pro Headless - Windows x64
Version: ${VERSION}

This package installs a headless Dogecoin node (dogecoind), not the Qt GUI wallet.

- Same mainnet consensus as Dogecoin Core Pro
- Optional Windows Service (auto-start, restart on failure)
- Service host: gpenode-ops.exe service-run (dogecoind is not a native SCM service)
- RPC defaults to 127.0.0.1 only
- UNIQUE rpcpassword generated per install (no shared default)
  See: %ProgramData%\\DogecoinGPENode\\RPC-CREDENTIALS.txt

Data directory (default):
  %ProgramData%\\DogecoinGPENode

After install:
  Start Menu -> Dogecoin GPENode -> GPENode Status / TUI / RPC credentials
  Or: services.msc -> DogecoinGPENode

GitHub: https://github.com/TheRetardedElon/Dogecoin-GPENode
EOF

# Convert paths for NSIS on Linux (forward slashes)
ASSETS_NSIS="${ASSETS//\\//}"
STAGE_NSIS="${STAGE//\\//}"

cd "${STAGE}"
# OutFile absolute path for WSL
OUT_ABS="${OUT_DIR}/${SETUP_NAME}"
makensis \
  -V3 \
  -DVERSION="${VERSION}" \
  -DOUT_SETUP="${OUT_ABS}" \
  -DBIN_DIR="bin" \
  -DASSETS="${ASSETS_NSIS}" \
  setup-gpenode-headless.nsi

# Fallback if OutFile was treated as relative
if [[ ! -f "${OUT_ABS}" && -f "${STAGE}/${SETUP_NAME}" ]]; then
  mv -f "${STAGE}/${SETUP_NAME}" "${OUT_ABS}"
fi
if [[ ! -f "${OUT_ABS}" ]]; then
  # Sometimes NSIS writes next to .nsi with full path broken — search
  found="$(find "${STAGE}" "${OUT_DIR}" -maxdepth 2 -name "${SETUP_NAME}" 2>/dev/null | head -1 || true)"
  if [[ -n "${found}" ]]; then
    mv -f "${found}" "${OUT_ABS}"
  fi
fi

test -f "${OUT_ABS}"
(
  cd "${OUT_DIR}"
  sha256sum "${SETUP_NAME}" > "${SETUP_NAME}.sha256"
)
echo "==> INSTALLER_OK"
ls -lh "${OUT_ABS}" "${OUT_DIR}/${SETUP_NAME}.sha256"
cat "${OUT_DIR}/${SETUP_NAME}.sha256"
