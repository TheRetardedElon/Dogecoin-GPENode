#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
for f in build-deb.sh publish-apt.sh gen-rpc-password.sh write-install-conf.sh \
         DEBIAN/postinst.in DEBIAN/prerm.in DEBIAN/postrm.in; do
  sed -i 's/\r$//' "$f" 2>/dev/null || true
done
chmod +x build-deb.sh publish-apt.sh gen-rpc-password.sh write-install-conf.sh
bash -n build-deb.sh
bash -n publish-apt.sh
bash -n gen-rpc-password.sh
bash -n write-install-conf.sh
bash -n DEBIAN/postinst.in
bash -n DEBIAN/prerm.in
bash -n DEBIAN/postrm.in
echo "syntax_OK"

PASS="$(./gen-rpc-password.sh)"
TMP="$(mktemp -d)"
./write-install-conf.sh --datadir "$TMP" --rpcpassword "$PASS" --rpcuser gpenode --profile dump
head -8 "$TMP/dogecoin.conf"
python3 - <<PY
from pathlib import Path
b = Path("$TMP/dogecoin.conf").read_bytes()[:3]
print("BOM", b == bytes([0xEF, 0xBB, 0xBF]))
PY
rm -rf "$TMP"

BIN="$(ls -d /mnt/c/dogedevGPEnode/out/headless-release/dogecoin-gpenode-linux-x86_64-*/bin 2>/dev/null | head -1 || true)"
if [[ -n "${BIN:-}" && -x "${BIN}/dogecoind" ]]; then
  export BIN_DIR="$BIN"
  export LIB_DIR="$(dirname "$BIN")/lib"
  export VERSION=1.14.102
  echo "building deb from $BIN_DIR"
  ./build-deb.sh
else
  echo "skip_deb_no_bins"
  ls /mnt/c/dogedevGPEnode/out/headless-release/ 2>/dev/null || true
fi
