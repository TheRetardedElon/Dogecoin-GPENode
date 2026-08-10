#!/usr/bin/env bash
# Install official Dogecoin Core Linux x86_64 release (settlement daemon).
# Override version: DOGECOIN_VERSION=1.14.9
set -euo pipefail

VERSION="${DOGECOIN_VERSION:-1.14.9}"
ARCH="x86_64-linux-gnu"
BASE="dogecoin-${VERSION}"
TGZ="${BASE}-${ARCH}.tar.gz"
URL="https://github.com/dogecoin/dogecoin/releases/download/v${VERSION}/${TGZ}"
PREFIX="${PREFIX:-/opt/dogecoin}"
DATADIR="$(cat /etc/dogecoin/datadir.path 2>/dev/null || echo /var/lib/dogecoin)"
DOGE_USER="${DOGE_USER:-dogecoin}"

export DEBIAN_FRONTEND=noninteractive
mkdir -p /tmp/doge-install "$PREFIX"
cd /tmp/doge-install

echo "==> download $URL"
wget -q --show-progress -O "$TGZ" "$URL"
tar -xzf "$TGZ"
rm -rf "$PREFIX"/*
cp -a "${BASE}/bin/." "$PREFIX/bin/" 2>/dev/null || {
  mkdir -p "$PREFIX/bin"
  cp -a "${BASE}"/bin/* "$PREFIX/bin/"
}
chmod +x "$PREFIX/bin/"*
ln -sfn "$PREFIX/bin/dogecoind" /usr/local/bin/dogecoind
ln -sfn "$PREFIX/bin/dogecoin-cli" /usr/local/bin/dogecoin-cli
ln -sfn "$PREFIX/bin/dogecoin-tx" /usr/local/bin/dogecoin-tx

cat >/etc/systemd/system/dogecoind.service <<EOF
[Unit]
Description=Dogecoin Core settlement node (GPE)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${DOGE_USER}
Group=${DOGE_USER}
ExecStart=/usr/local/bin/dogecoind -datadir=${DATADIR} -pid=/run/dogecoin/dogecoind.pid
ExecStop=/usr/local/bin/dogecoin-cli -datadir=${DATADIR} stop
RuntimeDirectory=dogecoin
RuntimeDirectoryMode=0755
Restart=on-failure
RestartSec=10
LimitNOFILE=8192
# 2GB VPS: avoid OOM during IBD
MemoryMax=1500M

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dogecoind

echo "==> installed dogecoind v${VERSION}"
dogecoind -version | head -2
echo "Start with: systemctl start dogecoind"
echo "Logs: journalctl -u dogecoind -f"
echo "Datadir: ${DATADIR}"
