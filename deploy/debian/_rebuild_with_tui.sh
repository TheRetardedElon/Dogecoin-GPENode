#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TUI="${ROOT}/gpenode-tui/gpenode-tui"
[[ -x "$TUI" ]] || { echo "missing $TUI — run gpenode-tui/build-linux.sh"; exit 1; }
BIN="$(ls -d "${ROOT}/out/headless-release/dogecoin-gpenode-linux-x86_64-"*/bin 2>/dev/null | head -1 || true)"
[[ -n "$BIN" && -x "${BIN}/dogecoind" ]] || { echo "missing headless release bin"; exit 1; }
cp -a "$TUI" "${BIN}/gpenode-tui"
echo "installed TUI into $BIN"
export BIN_DIR="$BIN"
export LIB_DIR="$(dirname "$BIN")/lib"
export VERSION=1.14.102
cd "${ROOT}/deploy/debian"
sed -i 's/\r$//' build-deb.sh || true
./build-deb.sh
# confirm tui inside deb
dpkg-deb -c "${ROOT}/out/debian/dogecoin-gpenode_${VERSION}-1_amd64.deb" | grep -E 'gpenode-tui|dogecoind' || true
