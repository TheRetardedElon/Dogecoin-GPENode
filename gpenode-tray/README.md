# gpenode-tray

Session **system tray** icon for Dogecoin GPENode / Core Pro Headless (Windows).

- Shows phase in tooltip: `OFFLINE` / `INIT` / `IBD` / `SYNCED`
- Menu: refresh status, open status window, data folder, conf, start/stop service, quit tray
- **No consensus** — only localhost RPC + SCM helpers
- Quitting the tray does **not** stop the Windows Service / `dogecoind`

## Build

```powershell
cd gpenode-tray
powershell -ExecutionPolicy Bypass -File .\build-windows.ps1
```

Requires Go 1.22+ and `dogecoin.ico` from the dogedev pixmaps tree.

## Run

```powershell
# After install-service.ps1 — service can already be running
.\gpenode-tray.exe
```

Place next to `gpenode-ops.exe` / `dogecoin-cli.exe` (or under `Program Files\DogecoinGPENode\bin`).
