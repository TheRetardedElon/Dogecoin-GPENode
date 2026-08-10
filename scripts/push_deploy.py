#!/usr/bin/env python3
"""Upload /opt/gpe-deploy scripts from dogedevGPEnode (no secrets printed)."""
from __future__ import annotations

import pathlib
import sys

import paramiko

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from ssh_cmd import connect, run  # noqa: E402

DEPLOY_FILES = [
    "bootstrap_settlement.sh",
    "install_dogecoind_release.sh",
    "dogecoin.conf.example",
    "configure_firewall.sh",
    "enable_regtest_lab.sh",
    "enable_testnet_and_start.sh",
    "mount_and_migrate_datadir.sh",
    "mount_nvme_block_storage.sh",
    "migrate_mainnet_to_block.sh",
    "make_utxo_snapshot.sh",
    "regtest_payflow_smoke.sh",
    "README.md",
    "SETTLEMENT_NODE_HANDOFF.md",
    "SYNC_CDN_HANDOFF.md",
    "GPE_BOX_AGENT_PROMPT.md",
]


def sftp_put(client: paramiko.SSHClient, local: pathlib.Path, remote: str) -> None:
    sftp = client.open_sftp()
    try:
        sftp.put(str(local), remote)
    finally:
        sftp.close()


def main() -> None:
    client = connect()
    try:
        run(client, "mkdir -p /opt/gpe-deploy")
        for name in DEPLOY_FILES:
            local = ROOT / "deploy" / name
            if not local.is_file():
                print(f"skip missing {name}")
                continue
            remote = f"/opt/gpe-deploy/{name}"
            print(f"upload {name} -> {remote}")
            sftp_put(client, local, remote)
            if name.endswith(".sh"):
                run(client, f"chmod +x {remote}")
        print("==> /opt/gpe-deploy")
        _, out, _ = run(client, "ls -la /opt/gpe-deploy", check=False)
        print(out)
        print("done")
    finally:
        client.close()


if __name__ == "__main__":
    main()
