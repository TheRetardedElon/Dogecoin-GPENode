#!/usr/bin/env bash
# Enable testnet on settlement datadir and start dogecoind.
set -euo pipefail

DATADIR="$(cat /etc/dogecoin/datadir.path 2>/dev/null || echo /mnt/gpenodestore/dogecoin)"
CONF="${DATADIR}/dogecoin.conf"
DOGE_USER=dogecoin

if [[ ! -f "$CONF" ]]; then
  echo "Missing conf: $CONF"
  exit 1
fi

systemctl stop dogecoind 2>/dev/null || true

# Ensure testnet=1 (idempotent)
if grep -qE '^testnet=' "$CONF"; then
  sed -i 's/^testnet=.*/testnet=1/' "$CONF"
else
  echo "testnet=1" >> "$CONF"
fi

# dogecoind requires prune >= 2200 MiB
if grep -qE '^prune=' "$CONF"; then
  sed -i 's/^prune=.*/prune=2200/' "$CONF"
else
  echo "prune=2200" >> "$CONF"
fi
if ! grep -qE '^dbcache=' "$CONF"; then
  echo "dbcache=256" >> "$CONF"
fi
if ! grep -qE '^maxmempool=' "$CONF"; then
  echo "maxmempool=50" >> "$CONF"
fi

chown "$DOGE_USER:$DOGE_USER" "$CONF"
chmod 600 "$CONF"

echo "==> conf:"
grep -E '^(testnet|listen|server|prune|dbcache|rpcbind|rpcallowip)=' "$CONF" || true

systemctl daemon-reload
systemctl start dogecoind
sleep 3
systemctl is-active dogecoind
systemctl status dogecoind --no-pager -l | head -25

echo "==> CLI getblockchaininfo (may be early IBD):"
sudo -u "$DOGE_USER" dogecoin-cli -datadir="$DATADIR" getblockchaininfo 2>&1 | head -40 || true
echo "==> getnetworkinfo connections:"
sudo -u "$DOGE_USER" dogecoin-cli -datadir="$DATADIR" getconnectioncount 2>&1 || true
