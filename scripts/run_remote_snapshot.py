#!/usr/bin/env python3
"""Run make_utxo_snapshot.sh on gpednode with Core Pro LD_LIBRARY_PATH."""
from __future__ import annotations

import pathlib
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from ssh_cmd import connect, run

LIB = "/opt/dogecoin-pro/lib"
CLI = f"sudo -u dogecoin env LD_LIBRARY_PATH={LIB} /opt/dogecoin-pro/bin/dogecoin-cli"
DATADIR = "/mnt/gpedogecloud/dogecoin"


def main() -> None:
    client = connect()
    try:
        # Upload latest make_utxo_snapshot if present on GPEnode tree
        root = pathlib.Path(__file__).resolve().parents[1]
        local = root / "deploy" / "make_utxo_snapshot.sh"
        if local.is_file():
            sftp = client.open_sftp()
            try:
                sftp.put(str(local), "/opt/gpe-deploy/make_utxo_snapshot.sh")
            finally:
                sftp.close()
            run(client, "sed -i 's/\\r$//' /opt/gpe-deploy/make_utxo_snapshot.sh; chmod +x /opt/gpe-deploy/make_utxo_snapshot.sh")

        # Patch CLI invocation for custom binary
        run(
            client,
            r"""
sed -i 's|sudo -u dogecoin dogecoin-cli|sudo -u dogecoin env LD_LIBRARY_PATH=/opt/dogecoin-pro/lib /opt/dogecoin-pro/bin/dogecoin-cli|g' /opt/gpe-deploy/make_utxo_snapshot.sh
# avoid double-prefix if re-run
sed -i 's|env LD_LIBRARY_PATH=/opt/dogecoin-pro/lib /opt/dogecoin-pro/bin/env LD_LIBRARY_PATH=/opt/dogecoin-pro/lib /opt/dogecoin-pro/bin/dogecoin-cli|env LD_LIBRARY_PATH=/opt/dogecoin-pro/lib /opt/dogecoin-pro/bin/dogecoin-cli|g' /opt/gpe-deploy/make_utxo_snapshot.sh
""",
            check=False,
        )

        code, out, err = run(
            client,
            f"{CLI} -datadir={DATADIR} getblockcount 2>&1",
            check=False,
        )
        print("blocks:", (out or err).strip())

        print("==> make_utxo_snapshot.sh (long)")
        # run synchronously with long channel - may timeout; use nohup
        run(
            client,
            "rm -f /tmp/make_utxo_snapshot.log; "
            "nohup bash /opt/gpe-deploy/make_utxo_snapshot.sh "
            "> /tmp/make_utxo_snapshot.log 2>&1 & echo $!",
            check=False,
        )

        for i in range(180):  # up to ~45 min
            code, out, err = run(client, "tail -20 /tmp/make_utxo_snapshot.log 2>/dev/null; pgrep -af make_utxo || true; pgrep -af dumptxoutset || true", check=False)
            text = out or ""
            print(f"--- poll {i} ---")
            print(text[-1500:])
            if "SNAPSHOT_OK" in text:
                print("SUCCESS")
                break
            if "ERROR:" in text and "dumptxoutset" in text.lower() and "PID" not in text:
                # finished with error
                if not run(client, "pgrep -f make_utxo_snapshot >/dev/null; echo $?", check=False)[1].strip() == "0":
                    if "ERROR" in text:
                        # check if process still running
                        pass
            code2, out2, _ = run(client, "pgrep -f '/opt/gpe-deploy/make_utxo_snapshot' >/dev/null && echo RUN || echo DONE", check=False)
            if "DONE" in (out2 or "") and i > 2:
                if "SNAPSHOT_OK" in text:
                    break
                if "ERROR" in text or "exit" in text.lower() or "Method not found" in text:
                    print("FAILED")
                    raise SystemExit(1)
                # might have finished without our marker
                code3, out3, _ = run(client, "ls -lh /mnt/gpedogecloud/snapshots/ 2>/dev/null; cat /mnt/gpedogecloud/snapshots/latest.json 2>/dev/null | head -40", check=False)
                print(out3)
                if "sha256" in (out3 or "") and "awaiting" not in (out3 or ""):
                    print("SUCCESS_ARTIFACTS")
                    break
                if i > 5 and "DONE" in (out2 or ""):
                    # log complete?
                    code4, out4, _ = run(client, "wc -l /tmp/make_utxo_snapshot.log; tail -5 /tmp/make_utxo_snapshot.log", check=False)
                    print(out4)
            time.sleep(15)
        else:
            print("TIMEOUT waiting for snapshot")
            raise SystemExit(2)

        code, out, err = run(
            client,
            "ls -lah /mnt/gpedogecloud/snapshots/; echo '---'; cat /mnt/gpedogecloud/snapshots/latest.json 2>/dev/null",
            check=False,
        )
        print(out or err)
        print("SNAPSHOT_PIPELINE_DONE")
    finally:
        client.close()


if __name__ == "__main__":
    main()
