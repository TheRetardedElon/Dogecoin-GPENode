#!/usr/bin/env bash
# Settlement node firewall — daemon host (gpednode1)
# Allows: SSH (tunnels + admin), Dogecoin P2P mainnet/testnet
# Blocks public: ALL dogecoind RPC ports (GPE uses SSH tunnel or private net)
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> baseline"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH: rate-limit brute force; required for admin + local RPC tunnels
ufw limit 22/tcp comment 'SSH admin + RPC tunnel'

# Dogecoin P2P only (not RPC)
ufw allow 22556/tcp comment 'dogecoin mainnet P2P'
ufw allow 44556/tcp comment 'dogecoin testnet P2P'

# Explicit denies for RPC / regtest P2P on public interface (documentation + safety)
# (default deny already blocks these; rules make intent obvious in `ufw status`)
for port in 18332 22555 44555 18444; do
  ufw deny "${port}/tcp" comment "block public dogecoin RPC/regtest (${port})"
done

ufw --force enable
ufw status verbose

echo ""
echo "==> listening sockets (RPC must be 127.0.0.1 only)"
ss -lntp | grep -E 'dogecoin|sshd|18332|22555|44555|18444|22556|44556' || ss -lntp

echo ""
echo "==> dogecoin.conf RPC bind check"
CONF="$(cat /etc/dogecoin/datadir.path 2>/dev/null)/dogecoin.conf"
if [[ -f "$CONF" ]]; then
  grep -E '^(rpcbind|rpcallowip|rpcport|regtest|testnet|server)=' "$CONF" || true
  if grep -qE '^rpcbind=0\.0\.0\.0' "$CONF" 2>/dev/null; then
    echo "WARNING: rpcbind=0.0.0.0 is unsafe — fix conf to 127.0.0.1"
  else
    echo "OK: no public rpcbind in conf (or not set to 0.0.0.0)"
  fi
fi

echo ""
echo "Firewall OK for:"
echo "  - SSH from anywhere (rate-limited) → tunnel: -L 18332:127.0.0.1:18332"
echo "  - P2P mainnet/testnet when you switch networks"
echo "  - RPC only on localhost (not open to internet)"
