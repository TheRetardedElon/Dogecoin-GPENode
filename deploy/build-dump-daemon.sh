#!/usr/bin/env bash
# Build headless Core Pro dogecoind + dogecoin-cli for GPENode (no Qt).
# Run from a Linux/WSL tree that has full source (this worktree or dogedev sync).
#
# Usage:
#   cd /path/to/dogedevGPEnode   # or dogedev
#   bash deploy/build-dump-daemon.sh
#   bash deploy/build-dump-daemon.sh /out/dir
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-${ROOT}/out/dump-daemon}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}"

cd "${ROOT}"

if [[ ! -f configure && ! -f configure.ac ]]; then
  echo "ERROR: not a dogecoin source root: ${ROOT}"
  exit 1
fi

if [[ ! -x configure ]]; then
  echo "==> autogen"
  ./autogen.sh
fi

echo "==> configure --without-gui (headless dump/settlement daemon)"
# Wallet left enabled at compile time so Profile B works from the same binary;
# Profile A turns wallet off at runtime with disablewallet=1.
./configure \
  --prefix="${OUT}" \
  --without-gui \
  --disable-tests \
  --disable-bench \
  --disable-man \
  --with-incompatible-bdb \
  ${CONFIGURE_EXTRA:-}

echo "==> make -j${JOBS} dogecoind dogecoin-cli"
make -j"${JOBS}" src/dogecoind src/dogecoin-cli

echo "==> install to ${OUT}"
mkdir -p "${OUT}/bin"
install -m 755 src/dogecoind src/dogecoin-cli "${OUT}/bin/"
# Also stage classic names for install_custom_dogecoind.sh
mkdir -p /tmp/gpe-custom-bin
install -m 755 src/dogecoind src/dogecoin-cli /tmp/gpe-custom-bin/ 2>/dev/null || true

echo "==> versions"
"${OUT}/bin/dogecoind" -version | head -3
"${OUT}/bin/dogecoin-cli" -version | head -1 || true

echo "==> BUILD_OK"
echo "binaries: ${OUT}/bin/dogecoind  ${OUT}/bin/dogecoin-cli"
echo "next: copy to node and run deploy/install_custom_dogecoind.sh"
echo "conf:  deploy/conf/dogecoin.dump.conf.example  (Profile A)"
echo "       deploy/conf/dogecoin.settlement.conf.example  (Profile B)"
