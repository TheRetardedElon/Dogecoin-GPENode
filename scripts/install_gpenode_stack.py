#!/usr/bin/env python3
"""Install staged headless dump daemon + gpenode-ops + deploy kit onto gpednode1.

Uses:
  out/dump-daemon/bin/{dogecoind,dogecoin-cli}
  out/gpenode-ops/gpenode-ops-linux-amd64
  deploy/*

Does not print secrets. Requires serverdetails.txt + paramiko.
"""
from __future__ import annotations

import pathlib
import sys
import time

# Unbuffered logs when piped
try:
    sys.stdout.reconfigure(line_buffering=True)  # type: ignore[attr-defined]
    sys.stderr.reconfigure(line_buffering=True)  # type: ignore[attr-defined]
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from ssh_cmd import connect, run  # noqa: E402

DUMP_BIN = ROOT / "out" / "dump-daemon" / "bin"
OPS_LINUX = ROOT / "out" / "gpenode-ops" / "gpenode-ops-linux-amd64"
DEPLOY = ROOT / "deploy"
LOG = ROOT / "out" / "install-gpenode-stack.log"


def log(msg: str) -> None:
    line = msg if msg.endswith("\n") else msg + "\n"
    sys.stdout.write(line)
    sys.stdout.flush()
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(line)


def sftp_put(client, local: pathlib.Path, remote: str) -> None:
    sftp = client.open_sftp()
    try:
        size_mb = local.stat().st_size / (1024 * 1024)
        log(f"  put {local.name} -> {remote} ({size_mb:.1f} MiB)")
        # Callback progress every ~8 MiB
        last = [0.0]

        def cb(transferred: int, total: int) -> None:
            mb = transferred / (1024 * 1024)
            if mb - last[0] >= 8 or transferred == total:
                last[0] = mb
                log(f"    … {mb:.1f}/{total / (1024 * 1024):.1f} MiB")

        sftp.put(str(local), remote, callback=cb)
        log(f"  done {local.name}")
    finally:
        sftp.close()


def sftp_put_dir_files(client, local_dir: pathlib.Path, remote_dir: str, names: list[str]) -> None:
    run(client, f"mkdir -p {remote_dir}")
    for name in names:
        p = local_dir / name
        if p.is_file():
            sftp_put(client, p, f"{remote_dir}/{name}")


def main() -> None:
    if LOG.exists():
        LOG.write_text("", encoding="utf-8")
    log(f"==> install_gpenode_stack start {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}")

    if not (DUMP_BIN / "dogecoind").is_file():
        raise SystemExit(f"missing {DUMP_BIN / 'dogecoind'} — stage dump daemon first")
    if not OPS_LINUX.is_file():
        raise SystemExit(f"missing {OPS_LINUX} — build linux gpenode-ops first")
    if not DEPLOY.is_dir():
        raise SystemExit(f"missing {DEPLOY}")

    log("==> connect")
    client = connect()
    log("==> connected")
    try:
        log("==> preflight")
        for cmd in (
            "hostname; date -u",
            "systemctl is-active dogecoind-mainnet 2>/dev/null; systemctl is-active dogecoind 2>/dev/null; true",
            "cat /etc/dogecoin/datadir.path 2>/dev/null || true",
            "which dogecoind dogecoin-cli 2>/dev/null; dogecoind -version 2>/dev/null | head -1 || true",
            "df -h /mnt/gpedogecloud / | tail -5",
            "free -h | head -2",
        ):
            code, out, err = run(client, cmd, check=False)
            log(f"$ {cmd}\n{(out or err).rstrip()}\n")

        log("==> upload deploy kit")
        run(client, "mkdir -p /opt/gpe-deploy /opt/gpe-deploy/conf /opt/gpe-deploy/systemd /opt/gpe-deploy/samples /opt/gpenode-ops/bin /tmp/gpe-custom-bin")
        for p in sorted(DEPLOY.iterdir()):
            if p.is_file() and (p.suffix in (".sh", ".md") or p.name.endswith(".example") or p.name == "dogecoin.conf.example"):
                sftp_put(client, p, f"/opt/gpe-deploy/{p.name}")
        for sub in ("conf", "systemd", "samples"):
            d = DEPLOY / sub
            if d.is_dir():
                run(client, f"mkdir -p /opt/gpe-deploy/{sub}")
                for p in d.rglob("*"):
                    if p.is_file():
                        rel = p.relative_to(d).as_posix()
                        remote = f"/opt/gpe-deploy/{sub}/{rel}"
                        run(client, f"mkdir -p $(dirname {remote})")
                        sftp_put(client, p, remote)
        run(client, "find /opt/gpe-deploy -type f -name '*.sh' -exec sed -i 's/\\r$//' {} \\; -exec chmod +x {} \\;")

        log("==> upload gpenode-ops")
        sftp_put(client, OPS_LINUX, "/opt/gpenode-ops/bin/gpenode-ops")
        code, out, err = run(client, "chmod +x /opt/gpenode-ops/bin/gpenode-ops; /opt/gpenode-ops/bin/gpenode-ops version", check=False)
        log(out or err)

        log("==> upload dogecoind + dogecoin-cli (large)")
        sftp_put(client, DUMP_BIN / "dogecoind", "/tmp/gpe-custom-bin/dogecoind")
        if (DUMP_BIN / "dogecoin-cli").is_file():
            sftp_put(client, DUMP_BIN / "dogecoin-cli", "/tmp/gpe-custom-bin/dogecoin-cli")
        code, out, err = run(client, "chmod +x /tmp/gpe-custom-bin/*; ls -lh /tmp/gpe-custom-bin", check=False)
        log(out or err)

        log("==> remote ldd check")
        code, out, err = run(client, "ldd /tmp/gpe-custom-bin/dogecoind 2>&1 | head -50", check=False)
        log(out or err)
        if "not found" in (out or err).lower():
            log("WARN: missing libs — attempting apt install of common deps")
            run(
                client,
                "export DEBIAN_FRONTEND=noninteractive; "
                "apt-get update -qq && apt-get install -y -qq "
                "libboost-filesystem1.83.0 libboost-program-options1.83.0 "
                "libboost-thread1.83.0 libboost-chrono1.83.0 "
                "libevent-2.1-7t64 libevent-pthreads-2.1-7t64 "
                "libdb5.3++ libzmq5 libminiupnpc18 2>/dev/null || "
                "apt-get install -y -qq libboost-all-dev libevent-dev libzmq3-dev libdb++-dev libminiupnpc-dev 2>&1 | tail -30",
                check=False,
            )
            code, out, err = run(
                client,
                "ldd /tmp/gpe-custom-bin/dogecoind 2>&1 | grep 'not found' || echo 'no missing libs reported'",
                check=False,
            )
            log(out or err)

        log("==> install_custom_dogecoind.sh")
        code, out, err = run(
            client,
            "bash /opt/gpe-deploy/install_custom_dogecoind.sh /tmp/gpe-custom-bin",
            check=False,
        )
        log(out or "")
        if err:
            log(err)
        if code != 0:
            code, out, err = run(
                client,
                "ldd /opt/dogecoin-pro/bin/dogecoind 2>&1 | grep -i 'not found' || true; "
                "journalctl -u dogecoind-mainnet -n 40 --no-pager 2>/dev/null || "
                "journalctl -u dogecoind -n 40 --no-pager 2>/dev/null || true",
                check=False,
            )
            log(out or err)
            raise SystemExit(f"install failed exit={code}")

        log("==> wait for RPC")
        datadir_cmd = "cat /etc/dogecoin/datadir.path 2>/dev/null || echo /mnt/gpedogecloud/dogecoin"
        _, datadir, _ = run(client, datadir_cmd, check=False)
        datadir = (datadir or "/mnt/gpedogecloud/dogecoin").strip().splitlines()[-1].strip()
        log(f"datadir={datadir}")

        ok = False
        last = ""
        for i in range(90):
            code, out, err = run(
                client,
                f"sudo -u dogecoin /opt/dogecoin-pro/bin/dogecoin-cli -datadir={datadir} getblockchaininfo 2>&1",
                check=False,
            )
            last = out or err
            if code == 0 and "chain" in last:
                ok = True
                log(last[:800])
                break
            if i % 10 == 0:
                log(f"  waiting RPC… ({i}s) {(last or '')[:160]}")
            time.sleep(2)
        if not ok:
            code, out, err = run(
                client,
                "systemctl status dogecoind-mainnet --no-pager -l 2>&1 | tail -40 || "
                "systemctl status dogecoind --no-pager -l 2>&1 | tail -40",
                check=False,
            )
            log(out or err)
            log(last)
            raise SystemExit("RPC did not come up")

        log("==> dumptxoutset present?")
        code, out, err = run(
            client,
            f"sudo -u dogecoin /opt/dogecoin-pro/bin/dogecoin-cli -datadir={datadir} help dumptxoutset 2>&1 | head -12",
            check=False,
        )
        log(out or err)
        if "unknown command" in (out or err).lower():
            raise SystemExit("dumptxoutset still missing after install")

        log("==> gpenode-ops status + verify-cdn")
        env = (
            f"export DOGECOIN_CLI=/opt/dogecoin-pro/bin/dogecoin-cli; "
            f"export DOGECOIN_DATADIR={datadir}; "
            f"export SNAP_SCRIPT=/opt/gpe-deploy/make_utxo_snapshot.sh; "
            f"export PUBLISH_SCRIPT=/opt/gpe-deploy/publish_snapshots.sh; "
        )
        code, out, err = run(client, env + "/opt/gpenode-ops/bin/gpenode-ops status 2>&1", check=False)
        log(out or err)
        code, out, err = run(client, "/opt/gpenode-ops/bin/gpenode-ops verify-cdn 2>&1", check=False)
        log(out or err)

        log("==> INSTALL_OK")
        log("Next: optional dump with /opt/gpenode-ops/bin/gpenode-ops dump")
        log("      enable timer: see /opt/gpe-deploy/systemd/README.md")
    finally:
        client.close()
        log("==> disconnected")


if __name__ == "__main__":
    main()
