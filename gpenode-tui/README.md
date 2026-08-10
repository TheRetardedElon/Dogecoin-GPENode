# gpenode-tui

**Grok Build-style** operator TUI for Dogecoin GPENode / Core Pro Headless.

- Dark panel · letter shortcuts · `>` prompt · footer phase  
- Localhost RPC + Windows service only — **no consensus**  
- Quitting the TUI does **not** stop the node service  

## Screens (mapped to real features)

| Key | Screen | GPENode role |
|-----|--------|----------------|
| O | Overview | phase, blocks/headers, peers, dumptxoutset |
| N | Node | service start/stop/restart |
| D | Dump | snapshots + dumptxoutset |
| C | CDN | fetch `latest.json` |
| L | Logs | tail `debug.log` |
| W | Wallet | balance only if wallet RPC enabled |
| ? | Help | commands |

Wallet send/receive mockups are **not** the dump-node default (`disablewallet=1`). Settlement profile can enable wallet later; full send/receive can extend this TUI.

## Build / run

```powershell
cd gpenode-tui
powershell -ExecutionPolicy Bypass -File .\build-windows.ps1
.\gpenode-tui.exe
```

Use **Windows Terminal** or a normal console — not a double-clicked GUI-only launch with no TTY.
