# Scripts on the GPENode worktree

This tree is often **synced from dogedev** (Core Pro source of truth). That means
`scripts/` can contain a lot of **Windows client build noise** that is not part of
operator day-to-day work.

## Keep for GPENode ops

| Script | Use |
|--------|-----|
| `ssh_cmd.py` | Remote shell / probe |
| `remote_bootstrap.py` | First-time node setup |
| `push_deploy.py` | Push `deploy/` to host |
| `node_status.py` | Health |
| `rpc_smoke.py` | RPC smoke |
| `rpc_tunnel.ps1` | Local tunnel to node RPC |
| `run_payflow_smoke.py` | Lab payflow |
| `run_remote_snapshot.py` | Trigger dump remotely |
| `finalize_snapshot_meta.py` | Manifest polish if needed |
| `deploy_custom_daemon.py` / `deploy_custom_daemon_with_libs.py` | Install custom dogecoind |
| `install_ssh_keys_on_node.py` | Key install |
| `gpe-backup-wallet.sh` | Wallet backup helper |
| `finish_mainnet_on_cloud.sh`, `move_mainnet_*`, `switch_mainnet_*`, `reindex_*`, `restore_*` | Storage migration ops |
| `sync-dogedev-to-gpenode.ps1` | Pull Core Pro code into this worktree |

## Treat as client-build noise (ignore for operator kit)

Anything named like `build-*-win*`, `package-*-win*`, `relink-qt*`, `compile-*-manual*`,
`smoke-assumeutxo*.ps1` (client PE smokes), etc. — those belong to **dogedev** packaging.

Do not invent a second packaging farm on the noderunner. Build custom Linux
`dogecoind` on a real build machine / WSL, then deploy the binary.

## Secrets

Never put RPC passwords or host passwords in scripts. Use gitignored
`serverdetails.txt` / `local/` only.
