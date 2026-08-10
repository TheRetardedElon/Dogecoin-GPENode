#!/usr/bin/env bash
# Daemon-only regtest pay flow: new address → send → generate → confirm received.
# Run ON the settlement host as root.
set -eo pipefail

DATADIR="$(cat /etc/dogecoin/datadir.path)"
CLI="sudo -u dogecoin dogecoin-cli -datadir=${DATADIR}"

echo "==> chain"
CHAIN=$($CLI getblockchaininfo | python3 -c "import sys,json; print(json.load(sys.stdin).get('chain'))")
if [ "$CHAIN" != "regtest" ]; then
  echo "ERROR: expected regtest, got chain=$CHAIN"
  echo "Run: bash /opt/gpe-deploy/enable_regtest_lab.sh"
  exit 1
fi

HEIGHT=$($CLI getblockcount)
if [ "$HEIGHT" -lt 101 ]; then
  echo "==> generate blocks for maturity"
  $CLI generate $((101 - HEIGHT + 10)) >/dev/null
fi

echo "balance_before=$($CLI getbalance)"

INV_ADDR=$($CLI getnewaddress "invoice-smoke")
echo "invoice_address=${INV_ADDR}"
echo "payment_uri=dogecoin:${INV_ADDR}?amount=12.5"

TXID=$($CLI sendtoaddress "$INV_ADDR" 12.5)
echo "txid=${TXID}"

$CLI generate 1 >/dev/null

RECV0=$($CLI getreceivedbyaddress "$INV_ADDR" 0)
RECV1=$($CLI getreceivedbyaddress "$INV_ADDR" 1)
echo "received_0conf=${RECV0}"
echo "received_1conf=${RECV1}"

python3 -c "r=float('${RECV1}'); print('PAYFLOW_OK' if r>=12.5 else 'PAYFLOW_FAIL'); raise SystemExit(0 if r>=12.5 else 1)"
