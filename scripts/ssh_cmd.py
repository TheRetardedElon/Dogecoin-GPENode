#!/usr/bin/env python3
"""Run remote commands using local serverdetails.txt (never commit that file).

Copy serverdetails.example.txt → serverdetails.txt and fill placeholders.
Prefers SSH key under local/ssh/ if present; optional password fallback.
Does not print secrets.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

import paramiko

ROOT = pathlib.Path(__file__).resolve().parents[1]
DETAILS = ROOT / "serverdetails.txt"


def load_details() -> tuple[str, str, str | None]:
    ip = user = password = None
    if not DETAILS.is_file():
        raise SystemExit(
            f"Missing {DETAILS}\n"
            f"Copy serverdetails.example.txt → serverdetails.txt (gitignored)."
        )
    for line in DETAILS.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or ":" not in line or line.startswith("#"):
            continue
        k, v = line.split(":", 1)
        k, v = k.strip().lower(), v.strip()
        if k == "ip":
            ip = v
        elif k == "user":
            user = v
        elif k == "pass":
            password = v
    if not ip or not user:
        raise SystemExit(f"Need at least ip: and user: in {DETAILS}")
    if ip.startswith("<") or "DUMP_NODE" in ip:
        raise SystemExit("Replace <DUMP_NODE_HOST> in serverdetails.txt with your host")
    return ip, user, password


def connect() -> paramiko.SSHClient:
    ip, user, password = load_details()
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    key_candidates = [
        ROOT / "local" / "ssh" / "id_ed25519_operator",
        ROOT / "local" / "ssh" / "id_ed25519",
    ]
    for key_path in key_candidates:
        if not key_path.is_file():
            continue
        try:
            pkey = paramiko.Ed25519Key.from_private_key_file(str(key_path))
            client.connect(
                ip,
                username=user,
                pkey=pkey,
                timeout=60,
                allow_agent=False,
                look_for_keys=False,
                banner_timeout=60,
                auth_timeout=60,
            )
            return client
        except Exception:
            client.close()
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    if not password or password.startswith("<"):
        raise SystemExit("No usable SSH key and no password in serverdetails.txt")
    client.connect(
        ip,
        username=user,
        password=password,
        timeout=60,
        allow_agent=False,
        look_for_keys=False,
        banner_timeout=60,
        auth_timeout=60,
    )
    return client


def run(client: paramiko.SSHClient, cmd: str, check: bool = True) -> tuple[int, str, str]:
    stdin, stdout, stderr = client.exec_command(cmd, get_pty=False)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    if check and code != 0:
        sys.stderr.write(f"$ {cmd}\nexit={code}\n{err}\n{out}\n")
        raise SystemExit(code)
    return code, out, err


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("command", nargs="?", help="Remote shell command")
    ap.add_argument("-c", "--check", action="store_true")
    ap.add_argument("--probe", action="store_true")
    args = ap.parse_args()

    client = connect()
    try:
        if args.probe:
            for cmd in (
                "uname -a",
                "head -5 /etc/os-release",
                "df -h",
                "free -h",
                "systemctl is-active dogecoind-mainnet 2>/dev/null || true",
            ):
                print(f"=== {cmd} ===")
                code, out, err = run(client, cmd, check=False)
                print(out or err)
            return
        if not args.command:
            ap.error("command or --probe required")
        code, out, err = run(client, args.command, check=args.check)
        if out:
            print(out, end="" if out.endswith("\n") else "\n")
        if err and not out:
            print(err, end="" if err.endswith("\n") else "\n")
        raise SystemExit(code)
    finally:
        client.close()


if __name__ == "__main__":
    main()
