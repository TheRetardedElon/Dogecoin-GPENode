#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from ssh_cmd import connect, run

def main() -> None:
    client = connect()
    try:
        sftp = client.open_sftp()
        sftp.put(str(ROOT / "deploy" / "install_custom_dogecoind.sh"), "/opt/gpe-deploy/install_custom_dogecoind.sh")
        ops = ROOT / "gpenode-ops" / "gpenode-ops"
        if ops.is_file():
            sftp.put(str(ops), "/opt/gpenode-ops/bin/gpenode-ops")
        sftp.close()
        run(client, "sed -i 's/\\r$//' /opt/gpe-deploy/install_custom_dogecoind.sh")
        run(client, "chmod +x /opt/gpe-deploy/install_custom_dogecoind.sh /opt/gpenode-ops/bin/gpenode-ops")
        code, out, err = run(
            client,
            "export DOGECOIN_CLI=/opt/dogecoin-pro/bin/dogecoin-cli "
            "DOGECOIN_DATADIR=/mnt/gpedogecloud/dogecoin "
            "LD_LIBRARY_PATH=/opt/dogecoin-pro/lib; "
            "/opt/gpenode-ops/bin/gpenode-ops status",
            check=False,
        )
        print(out or err)
        print("PATCH_OK")
    finally:
        client.close()

if __name__ == "__main__":
    main()
