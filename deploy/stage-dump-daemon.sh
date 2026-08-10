#!/usr/bin/env bash
# Stage existing Linux dogecoind/cli (prefer dogedev 1.14.102 build with dump RPCs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/out/dump-daemon"
mkdir -p "${OUT}/bin"

SRC_DAEMON=""
for c in \
  "${ROOT}/../dogedev/src/dogecoind" \
  "/mnt/c/dogedev/src/dogecoind" \
  "${ROOT}/src/dogecoind"
do
  if [[ -x "$c" ]]; then SRC_DAEMON="$c"; break; fi
done

if [[ -z "${SRC_DAEMON}" ]]; then
  echo "ERROR: no dogecoind found — run build-dump-daemon.sh first"
  exit 1
fi

cp -f "${SRC_DAEMON}" "${OUT}/bin/dogecoind"
chmod 755 "${OUT}/bin/dogecoind"

SRC_CLI="$(dirname "${SRC_DAEMON}")/dogecoin-cli"
if [[ -x "${SRC_CLI}" ]]; then
  cp -f "${SRC_CLI}" "${OUT}/bin/dogecoin-cli"
  chmod 755 "${OUT}/bin/dogecoin-cli"
fi

echo "==> staged from ${SRC_DAEMON}"
"${OUT}/bin/dogecoind" -version | head -3
if command -v file >/dev/null; then file "${OUT}/bin/dogecoind"; fi
if ldd "${OUT}/bin/dogecoind" 2>/dev/null | grep -qi qt; then
  echo "WARN: Qt libs linked — prefer --without-gui rebuild"
else
  echo "OK: no Qt libs linked"
fi

cat > "${OUT}/README.txt" <<'EOF'
Headless dump daemon stage package
==================================

Contains dogecoind (+ dogecoin-cli when present) with AssumeUTXO dump RPCs.
Daemon binary should not link Qt.

Install on dump node:
  scp -r out/dump-daemon/bin/* root@node:/tmp/gpe-custom-bin/
  ssh root@node 'bash /opt/gpe-deploy/install_custom_dogecoind.sh /tmp/gpe-custom-bin'

Or rebuild from source:
  bash deploy/build-dump-daemon.sh
EOF

ls -la "${OUT}/bin"
echo "==> STAGE_OK ${OUT}"
