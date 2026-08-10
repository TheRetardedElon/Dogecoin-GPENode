# gpenode-ops

Operator glue for **Dogecoin GPENode**. Talks to headless `dogecoind` over localhost RPC / `dogecoin-cli`.

**Does not implement consensus.**

## Commands

| Command | Role |
|---------|------|
| `status` | Phase + tip (`OFFLINE` / `INIT` / `IBD` / `SYNCED`) |
| `status -json` | Machine-readable summary |
| `dump` | Bash snapshot script, or native `dumptxoutset` (`-native`) |
| `publish` | CDN publish script |
| `verify-cdn` | Fetch `latest.json` |
| `service status\|start\|stop\|restart` | Windows SCM helpers |
| `service-run` | Windows service host (supervises dogecoind) |
| `version` | Binary version |

## Windows defaults

When env vars are unset:

- CLI/daemon: `%ProgramFiles%\DogecoinGPENode\bin\`
- datadir: `%ProgramData%\DogecoinGPENode`

```powershell
gpenode-ops status
gpenode-ops service status
# Admin may be required:
gpenode-ops service start
```

## Build

```powershell
# Windows
go build -ldflags="-s -w" -o gpenode-ops.exe .
# or
powershell -File .\build-windows.ps1
```

```bash
# Linux
bash build-linux.sh
```
