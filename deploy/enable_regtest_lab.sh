#!/usr/bin/env bash
# Settlement lab: regtest for RPC / watcher integration (no public peers required).
set -euo pipefail

DATADIR="$(cat /etc/dogecoin/datadir.path)"
CONF="${DATADIR}/dogecoin.conf"
DOGE_USER=dogecoin

systemctl stop dogecoind 2>/dev/null || true

# Rebuild conf for regtest lab (preserve rpcuser/rpcpassword if present)
RPCUSER=$(grep -E '^rpcuser=' "$CONF" 2>/dev/null | cut -d= -f2- || true)
RPCPASS=$(grep -E '^rpcpassword=' "$CONF" 2>/dev/null | cut -d= -f2- || true)
[[ -z "$RPCUSER" ]] && RPCUSER="gpe_$(openssl rand -hex 4)"
[[ -z "$RPCPASS" ]] && RPCPASS="$(openssl rand -hex 24)"

cat >"$CONF" <<EOF
# GPE settlement lab — regtest (local chain for integration)
regtest=1
listen=1
server=1
txindex=1
# no prune on regtest — chain is tiny
dbcache=128
maxmempool=50
maxconnections=16
rpcuser=${RPCUSER}
rpcpassword=${RPCPASS}
rpcallowip=127.0.0.1
rpcbind=127.0.0.1
printtoconsole=0
EOF

chown "$DOGE_USER:$DOGE_USER" "$CONF"
chmod 600 "$CONF"

systemctl start dogecoind
sleep 3
systemctl is-active dogecoind

CLI=(sudo -u "$DOGE_USER" dogecoin-cli -datadir="$DATADIR")

# Create wallet / mine if empty
"${CLI[@]}" getblockchaininfo
# generate enough for coinbase maturity (101)
HEIGHT=$("${CLI[@]}" getblockcount)
if [[ "$HEIGHT" -lt 101 ]]; then
  echo "==> generating 110 regtest blocks..."
  "${CLI[@]}" generate 110 >/dev/null
fi

echo "==> lab ready"
"${CLI[@]}" getblockchaininfo | head -20
echo "balance:"
"${CLI[@]}" getbalance
ADDR=$("${CLI[@]}" getnewaddress "gpe-lab")
echo "sample_receive_address=${ADDR}"
echo "URI=dogecoin:${ADDR}"
