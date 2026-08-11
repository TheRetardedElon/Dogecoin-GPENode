#!/usr/bin/env bash
# Build dogecoin-gpenode_${VERSION}-1_${ARCH}.deb from staged Linux binaries.
# Run on Linux/WSL with dpkg-deb installed.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
VERSION="${VERSION:-1.14.102}"
ARCH="${ARCH:-amd64}"
PKG_REL="${PKG_REL:-1}"
OUT_DIR="${OUT_DIR:-${ROOT}/out/debian}"
STAGE="${OUT_DIR}/stage-dogecoin-gpenode"
DEB_NAME="dogecoin-gpenode_${VERSION}-${PKG_REL}_${ARCH}.deb"

# BIN_DIR must contain dogecoind, dogecoin-cli, gpenode-ops
BIN_DIR="${BIN_DIR:-}"
LIB_DIR="${LIB_DIR:-}"

if [[ -z "$BIN_DIR" ]]; then
  for cand in \
    "${ROOT}/out/headless-release/dogecoin-gpenode-linux-x86_64-"*/bin \
    "${ROOT}/out/dump-daemon/bin" \
    "${ROOT}/gpenode-ops"
  do
    if [[ -x "${cand}/dogecoind" || -x "${cand}/../bin/dogecoind" ]]; then
      BIN_DIR="$cand"
      break
    fi
  done
fi

# Expand globs if needed
if [[ -n "$BIN_DIR" && ! -d "$BIN_DIR" ]]; then
  # shellcheck disable=SC2086
  BIN_DIR="$(ls -d $BIN_DIR 2>/dev/null | head -1 || true)"
fi

need() { command -v "$1" >/dev/null || { echo "missing $1"; exit 1; }; }
need dpkg-deb
need fakeroot || true

[[ -n "$BIN_DIR" && -d "$BIN_DIR" ]] || {
  echo "ERROR: set BIN_DIR to a directory containing dogecoind, dogecoin-cli, gpenode-ops"
  echo "  export BIN_DIR=/path/to/bin"
  exit 1
}

find_bin() {
  local n="$1"
  if [[ -x "${BIN_DIR}/${n}" ]]; then echo "${BIN_DIR}/${n}"; return 0; fi
  if [[ -x "${ROOT}/gpenode-ops/${n}" ]]; then echo "${ROOT}/gpenode-ops/${n}"; return 0; fi
  if [[ -x "${ROOT}/gpenode-ops/${n}-linux-amd64" ]]; then echo "${ROOT}/gpenode-ops/${n}-linux-amd64"; return 0; fi
  return 1
}

DOGECOIND="$(find_bin dogecoind || true)"
CLI="$(find_bin dogecoin-cli || true)"
OPS="$(find_bin gpenode-ops || true)"
TUI=""
if [[ -x "${BIN_DIR}/gpenode-tui" ]]; then TUI="${BIN_DIR}/gpenode-tui"; fi
if [[ -z "$TUI" && -x "${ROOT}/gpenode-tui/gpenode-tui" ]]; then TUI="${ROOT}/gpenode-tui/gpenode-tui"; fi

[[ -n "$DOGECOIND" && -x "$DOGECOIND" ]] || { echo "missing dogecoind in BIN_DIR=$BIN_DIR"; exit 1; }
[[ -n "$CLI" && -x "$CLI" ]] || { echo "missing dogecoin-cli"; exit 1; }
[[ -n "$OPS" && -x "$OPS" ]] || { echo "missing gpenode-ops (run gpenode-ops/build-linux.sh)"; exit 1; }

if [[ -z "$LIB_DIR" ]]; then
  parent="$(dirname "$BIN_DIR")"
  if [[ -d "${parent}/lib" ]]; then LIB_DIR="${parent}/lib"; fi
fi

echo "==> staging package tree"
rm -rf "$STAGE"
mkdir -p \
  "${STAGE}/DEBIAN" \
  "${STAGE}/usr/bin" \
  "${STAGE}/usr/lib/dogecoin-gpenode" \
  "${STAGE}/usr/share/dogecoin-gpenode/conf" \
  "${STAGE}/usr/share/doc/dogecoin-gpenode" \
  "${STAGE}/lib/systemd/system" \
  "${STAGE}/etc/dogecoin-gpenode"

install -m 755 "$DOGECOIND" "${STAGE}/usr/bin/dogecoind"
install -m 755 "$CLI" "${STAGE}/usr/bin/dogecoin-cli"
install -m 755 "$OPS" "${STAGE}/usr/bin/gpenode-ops"
if [[ -n "$TUI" ]]; then
  install -m 755 "$TUI" "${STAGE}/usr/bin/gpenode-tui"
fi

if [[ -n "$LIB_DIR" && -d "$LIB_DIR" ]]; then
  cp -a "${LIB_DIR}/." "${STAGE}/usr/lib/dogecoin-gpenode/" 2>/dev/null || true
fi

install -m 644 "${HERE}/dogecoin-gpenode.service" "${STAGE}/lib/systemd/system/dogecoin-gpenode.service"
install -m 755 "${HERE}/gen-rpc-password.sh" "${STAGE}/usr/share/dogecoin-gpenode/gen-rpc-password.sh"
install -m 755 "${HERE}/write-install-conf.sh" "${STAGE}/usr/share/dogecoin-gpenode/write-install-conf.sh"

if [[ -f "${ROOT}/deploy/conf/dogecoin.dump.conf.example" ]]; then
  install -m 644 "${ROOT}/deploy/conf/dogecoin.dump.conf.example" \
    "${STAGE}/usr/share/dogecoin-gpenode/conf/"
  install -m 644 "${ROOT}/deploy/conf/dogecoin.settlement.conf.example" \
    "${STAGE}/usr/share/dogecoin-gpenode/conf/" 2>/dev/null || true
fi

# control + maintainer scripts
sed -e "s/__VERSION__/${VERSION}/g" -e "s/__ARCH__/${ARCH}/g" \
  "${HERE}/DEBIAN/control.in" > "${STAGE}/DEBIAN/control"
install -m 755 "${HERE}/DEBIAN/postinst.in" "${STAGE}/DEBIAN/postinst"
install -m 755 "${HERE}/DEBIAN/prerm.in" "${STAGE}/DEBIAN/prerm"
install -m 755 "${HERE}/DEBIAN/postrm.in" "${STAGE}/DEBIAN/postrm"

# strip CR if scripts were edited on Windows
sed -i 's/\r$//' \
  "${STAGE}/DEBIAN/postinst" "${STAGE}/DEBIAN/prerm" "${STAGE}/DEBIAN/postrm" \
  "${STAGE}/usr/share/dogecoin-gpenode/"*.sh 2>/dev/null || true

# dpkg-deb rejects control dirs with mode 0777 (common on /mnt/c WSL mounts).
# Stage under /tmp when OUT_DIR is on a Windows drive, or chmod aggressively.
chmod 0755 "${STAGE}/DEBIAN" 2>/dev/null || true
chmod 0644 "${STAGE}/DEBIAN/control" 2>/dev/null || true
chmod 0755 "${STAGE}/DEBIAN/postinst" "${STAGE}/DEBIAN/prerm" "${STAGE}/DEBIAN/postrm" 2>/dev/null || true

cat > "${STAGE}/usr/share/doc/dogecoin-gpenode/README.Debian" <<EOF
dogecoin-gpenode ${VERSION}

After install:
  systemctl status dogecoin-gpenode
  gpenode-ops status
  # credentials:
  sudo cat /var/lib/dogecoin-gpenode/RPC-CREDENTIALS.txt

Conf:    /etc/dogecoin-gpenode/dogecoin.conf
Datadir: /var/lib/dogecoin-gpenode

Apt origin: https://apt.dogecli.gopastearth.com/
Repo: https://github.com/TheRetardedElon/Dogecoin-GPENode
EOF

# conffiles: only mark conf if we ship a default (we write at postinst, so skip)

mkdir -p "$OUT_DIR"
# If staging is on a Windows mount (mode stuck at 777), rebuild under /tmp
DEBIAN_MODE="$(stat -c '%a' "${STAGE}/DEBIAN" 2>/dev/null || echo 777)"
BUILD_STAGE="$STAGE"
if [[ "$DEBIAN_MODE" == "777" ]] || [[ "$STAGE" == /mnt/* ]]; then
  BUILD_STAGE="/tmp/dogecoin-gpenode-deb-stage-$$"
  echo "==> restaging under ${BUILD_STAGE} (dpkg-deb needs DEBIAN mode 0755)"
  rm -rf "$BUILD_STAGE"
  mkdir -p "$(dirname "$BUILD_STAGE")"
  cp -a "$STAGE" "$BUILD_STAGE"
  chmod 0755 "${BUILD_STAGE}/DEBIAN"
  chmod 0644 "${BUILD_STAGE}/DEBIAN/control"
  chmod 0755 "${BUILD_STAGE}/DEBIAN/postinst" "${BUILD_STAGE}/DEBIAN/prerm" "${BUILD_STAGE}/DEBIAN/postrm"
fi

echo "==> dpkg-deb --build"
if command -v fakeroot >/dev/null 2>&1; then
  fakeroot dpkg-deb --build "$BUILD_STAGE" "${OUT_DIR}/${DEB_NAME}"
else
  dpkg-deb --build "$BUILD_STAGE" "${OUT_DIR}/${DEB_NAME}"
fi
if [[ "$BUILD_STAGE" != "$STAGE" ]]; then
  rm -rf "$BUILD_STAGE"
fi

( cd "$OUT_DIR" && sha256sum "$DEB_NAME" > "${DEB_NAME}.sha256" )
echo "==> DEB_OK ${OUT_DIR}/${DEB_NAME}"
ls -lh "${OUT_DIR}/${DEB_NAME}" "${OUT_DIR}/${DEB_NAME}.sha256"
cat "${OUT_DIR}/${DEB_NAME}.sha256"
