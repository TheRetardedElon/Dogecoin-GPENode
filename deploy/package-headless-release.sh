#!/usr/bin/env bash
# Package Linux headless dump-node release for GitHub Releases.
# Run under WSL/Linux from dogedevGPEnode (or with BIN_SRC set).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-${ROOT}/out/headless-release}"
VER="${VER:-1.14.102-gpenode1}"
NAME="dogecoin-gpenode-linux-x86_64-${VER}"
STAGE="${OUT}/${NAME}"

BIN_SRC="${BIN_SRC:-${ROOT}/out/dump-daemon/bin}"
# Prefer dogedev built daemon if present
if [[ -x "${ROOT}/../dogedev/src/dogecoind" ]]; then
  BIN_SRC="${ROOT}/../dogedev/src"
fi
if [[ -x /mnt/c/dogedev/src/dogecoind ]]; then
  BIN_SRC=/mnt/c/dogedev/src
fi

OPS_BIN=""
for c in \
  "${ROOT}/gpenode-ops/gpenode-ops" \
  "${ROOT}/out/gpenode-ops/gpenode-ops-linux-amd64"
do
  if [[ -x "$c" ]]; then OPS_BIN="$c"; break; fi
done

if [[ ! -x "${BIN_SRC}/dogecoind" ]]; then
  echo "ERROR: no dogecoind at ${BIN_SRC}/dogecoind"
  exit 1
fi
if [[ -z "${OPS_BIN}" ]]; then
  echo "ERROR: build gpenode-ops first (gpenode-ops/build-linux.sh)"
  exit 1
fi

rm -rf "${STAGE}"
mkdir -p "${STAGE}/bin" "${STAGE}/lib" "${STAGE}/deploy"

cp -a "${BIN_SRC}/dogecoind" "${STAGE}/bin/"
cp -a "${BIN_SRC}/dogecoin-cli" "${STAGE}/bin/" 2>/dev/null || true
cp -a "${OPS_BIN}" "${STAGE}/bin/gpenode-ops"
chmod 755 "${STAGE}/bin/"*

# Bundle Boost/miniupnpc that often differ across distros
ldd "${STAGE}/bin/dogecoind" | awk '/=> \// {print $3}' | while read -r so; do
  [[ -z "$so" || ! -f "$so" ]] && continue
  base="$(basename "$so")"
  case "$base" in
    libboost_*|libminiupnpc*)
      cp -aL "$so" "${STAGE}/lib/"
      dir="$(dirname "$so")"
      stem="${base%%.so*}"
      for f in "${dir}/${stem}.so"*; do
        [[ -f "$f" ]] && cp -aL "$f" "${STAGE}/lib/" || true
      done
      ;;
  esac
done

# Operator kit
cp -a "${ROOT}/deploy/"*.sh "${STAGE}/deploy/" 2>/dev/null || true
cp -a "${ROOT}/deploy/"*.md "${STAGE}/deploy/" 2>/dev/null || true
cp -a "${ROOT}/deploy/conf" "${STAGE}/deploy/" 2>/dev/null || true
cp -a "${ROOT}/deploy/systemd" "${STAGE}/deploy/" 2>/dev/null || true
cp -a "${ROOT}/deploy/samples" "${STAGE}/deploy/" 2>/dev/null || true
find "${STAGE}/deploy" -type f -name '*.sh' -exec sed -i 's/\r$//' {} \;
chmod +x "${STAGE}/deploy/"*.sh 2>/dev/null || true

cat > "${STAGE}/README.txt" <<EOF
Dogecoin GPENode — Linux x86_64 headless release
Version: ${VER}

Contents
  bin/dogecoind       Core Pro dump-capable daemon (no Qt)
  bin/dogecoin-cli
  bin/gpenode-ops     Operator glue (Go)
  lib/                Bundled Boost/miniupnpc if needed
  deploy/             Snapshot/publish/timer scripts + conf examples

Install (Debian/Ubuntu-class)
  sudo mkdir -p /opt/dogecoin-pro/bin /opt/dogecoin-pro/lib /opt/gpe-deploy /opt/gpenode-ops/bin
  sudo cp -a bin/dogecoind bin/dogecoin-cli /opt/dogecoin-pro/bin/
  sudo cp -a lib/* /opt/dogecoin-pro/lib/ 2>/dev/null || true
  sudo cp -a deploy/* /opt/gpe-deploy/
  sudo install -m 755 bin/gpenode-ops /opt/gpenode-ops/bin/gpenode-ops
  sudo ln -sfn /opt/dogecoin-pro/bin/dogecoind /usr/local/bin/dogecoind
  sudo ln -sfn /opt/dogecoin-pro/bin/dogecoin-cli /usr/local/bin/dogecoin-cli

  # systemd unit must set:
  #   Environment=LD_LIBRARY_PATH=/opt/dogecoin-pro/lib

  export LD_LIBRARY_PATH=/opt/dogecoin-pro/lib
  dogecoind -version
  dogecoin-cli help dumptxoutset

See deploy/OPERATOR_KIT.md and deploy/INDEPENDENT_OPERATORS.md
Repo: https://github.com/TheRetardedElon/Dogecoin-GPENode
EOF

cat > "${STAGE}/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-/opt/dogecoin-pro}"
sudo mkdir -p "${PREFIX}/bin" "${PREFIX}/lib" /opt/gpe-deploy /opt/gpenode-ops/bin
sudo install -m 755 "${ROOT}/bin/dogecoind" "${ROOT}/bin/dogecoin-cli" "${PREFIX}/bin/"
if compgen -G "${ROOT}/lib/*" >/dev/null; then
  sudo cp -a "${ROOT}/lib/." "${PREFIX}/lib/"
fi
sudo cp -a "${ROOT}/deploy/." /opt/gpe-deploy/
sudo install -m 755 "${ROOT}/bin/gpenode-ops" /opt/gpenode-ops/bin/gpenode-ops
sudo ln -sfn "${PREFIX}/bin/dogecoind" /usr/local/bin/dogecoind
sudo ln -sfn "${PREFIX}/bin/dogecoin-cli" /usr/local/bin/dogecoin-cli
echo "Installed. Use LD_LIBRARY_PATH=${PREFIX}/lib when running outside systemd."
LD_LIBRARY_PATH="${PREFIX}/lib" "${PREFIX}/bin/dogecoind" -version | head -2
EOF
chmod +x "${STAGE}/install.sh"

# Verify
export LD_LIBRARY_PATH="${STAGE}/lib"
"${STAGE}/bin/dogecoind" -version | head -2
"${STAGE}/bin/gpenode-ops" version

mkdir -p "${OUT}"
TAR="${OUT}/${NAME}.tar.gz"
( cd "${OUT}" && tar -czf "${NAME}.tar.gz" "${NAME}" )
(
  cd "${OUT}"
  if command -v sha256sum >/dev/null; then
    sha256sum "${NAME}.tar.gz" > "${NAME}.tar.gz.sha256"
  else
    shasum -a 256 "${NAME}.tar.gz" > "${NAME}.tar.gz.sha256"
  fi
)

echo "==> PACKAGE_OK"
ls -lh "${TAR}" "${TAR}.sha256"
cat "${TAR}.sha256"
