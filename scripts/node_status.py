#!/usr/bin/env python3
"""Print settlement node health (no secrets)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ssh_cmd import connect, run


def main() -> None:
    client = connect()
    try:
        cmds = [
            "hostname; uptime",
            "findmnt /mnt/gpenodestore || true",
            "df -h /mnt/gpenodestore / 2>/dev/null | head -5",
            "systemctl is-active dogecoind; systemctl is-enabled dogecoind",
            "cat /etc/dogecoin/datadir.path 2>/dev/null",
            "DATADIR=$(cat /etc/dogecoin/datadir.path); "
            "grep -E '^(testnet|prune|dbcache|rpcbind|server|listen)=' $DATADIR/dogecoin.conf 2>/dev/null || true",
            "DATADIR=$(cat /etc/dogecoin/datadir.path); "
            "sudo -u dogecoin dogecoin-cli -datadir=$DATADIR getblockchaininfo 2>&1 | "
            "python3 -c \"import sys,json; d=json.load(sys.stdin); "
            "print('chain=',d.get('chain'),'blocks=',d.get('blocks'),'headers=',d.get('headers'),"
            "'ibd=',d.get('initialblockdownload'),'progress=',round(d.get('verificationprogress',0)*100,2),'%')\" "
            "2>/dev/null || echo 'cli: not ready yet'",
            "DATADIR=$(cat /etc/dogecoin/datadir.path); "
            "sudo -u dogecoin dogecoin-cli -datadir=$DATADIR getconnectioncount 2>&1 || true",
            "free -h | head -2",
        ]
        for c in cmds:
            print(f"=== {c[:60]}... ===" if len(c) > 60 else f"=== {c} ===")
            code, out, err = run(client, c, check=False)
            print((out or err or "").rstrip())
            print()
    finally:
        client.close()


if __name__ == "__main__":
    main()
