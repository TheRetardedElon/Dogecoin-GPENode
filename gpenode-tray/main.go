// gpenode-tray — session tray icon for GPENode headless (Windows-first).
// Localhost RPC / service control only. NO consensus logic.
//
// Important: all background probes must use CREATE_NO_WINDOW (hideConsole).
// dogecoin-cli / sc.exe / gpenode-ops are console apps — without that, Windows
// flashes a CMD window every poll / click.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/energye/systray"
)

const (
	appName     = "Dogecoin GPENode"
	serviceName = "DogecoinGPENode"
	pollEvery   = 20 * time.Second
)

func main() {
	systray.Run(onReady, onExit)
}

func onExit() {}

func onReady() {
	systray.SetTitle(appName)
	systray.SetTooltip(appName + " — starting…")
	if len(iconICO) > 0 {
		systray.SetIcon(iconICO)
	}

	mStatus := systray.AddMenuItem("Refresh status", "Poll RPC + service (no console flash)")
	mOpenStatus := systray.AddMenuItem("Open status window", "Keep-open PowerShell status")
	mOpenData := systray.AddMenuItem("Open data folder", "Explorer datadir")
	mOpenConf := systray.AddMenuItem("Edit dogecoin.conf", "Notepad conf")
	systray.AddSeparator()
	mStart := systray.AddMenuItem("Start service", "Start DogecoinGPENode service")
	mStop := systray.AddMenuItem("Stop service", "Stop DogecoinGPENode service")
	systray.AddSeparator()
	mQuit := systray.AddMenuItem("Quit tray", "Exit tray only (service keeps running)")

	mStatus.Click(func() { go updateTooltip() })
	mOpenStatus.Click(func() { go openStatusWindow() })
	mOpenData.Click(func() { go openPath(resolveDataDir()) })
	mOpenConf.Click(func() { go openConf() })
	mStart.Click(func() {
		go func() {
			_ = runOpsHidden("service", "start")
			time.Sleep(2 * time.Second)
			updateTooltip()
		}()
	})
	mStop.Click(func() {
		go func() {
			_ = runOpsHidden("service", "stop")
			time.Sleep(2 * time.Second)
			updateTooltip()
		}()
	})
	mQuit.Click(func() { systray.Quit() })

	// Left-click: show menu (do NOT spawn console tools in the click path alone).
	// Right-click: also show menu (explicit for energye when click handlers are set).
	systray.SetOnClick(func(menu systray.IMenu) {
		_ = menu.ShowMenu()
	})
	systray.SetOnRClick(func(menu systray.IMenu) {
		_ = menu.ShowMenu()
	})
	systray.SetOnDClick(func(menu systray.IMenu) {
		go openStatusWindow()
	})

	go pollLoop()
}

func pollLoop() {
	// small delay so tray paints before first probe
	time.Sleep(500 * time.Millisecond)
	updateTooltip()
	t := time.NewTicker(pollEvery)
	defer t.Stop()
	for range t.C {
		updateTooltip()
	}
}

var tipMu sync.Mutex

func updateTooltip() {
	tipMu.Lock()
	defer tipMu.Unlock()

	phase, detail := probeStatus()
	// Tooltips: keep short (Windows truncates multi-line sometimes)
	tip := fmt.Sprintf("%s | %s | %s", appName, phase, detail)
	if len(tip) > 120 {
		tip = tip[:117] + "..."
	}
	systray.SetTooltip(tip)
}

func probeStatus() (phase, detail string) {
	svc := "n/a"
	if runtime.GOOS == "windows" {
		svc = queryService(serviceName)
	}

	out, err := runCLIHidden("getblockchaininfo")
	if err != nil {
		if isWarmup(out) {
			return "INIT", fmt.Sprintf("loading index svc=%s", svc)
		}
		if svc == "RUNNING" {
			return "WARMUP", fmt.Sprintf("RPC not ready svc=%s", svc)
		}
		return "OFFLINE", fmt.Sprintf("svc=%s", svc)
	}

	var info map[string]json.RawMessage
	if json.Unmarshal([]byte(out), &info) != nil {
		return "RPC-OK", fmt.Sprintf("svc=%s", svc)
	}
	get := func(k string) string {
		raw, ok := info[k]
		if !ok {
			return "?"
		}
		return strings.Trim(strings.TrimSpace(string(raw)), `"`)
	}
	blocks := get("blocks")
	headers := get("headers")
	ibd := get("initialblockdownload")
	if strings.EqualFold(ibd, "true") {
		return "IBD", fmt.Sprintf("%s/%s svc=%s", blocks, headers, svc)
	}
	return "SYNCED", fmt.Sprintf("tip=%s svc=%s", blocks, svc)
}

func isWarmup(out string) bool {
	s := strings.ToLower(out)
	return strings.Contains(s, "error code: -28") ||
		strings.Contains(s, "loading block index") ||
		strings.Contains(s, "verifying blocks")
}

func queryService(name string) string {
	cmd := exec.Command("sc.exe", "query", name)
	hideConsole(cmd)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "NOT_INSTALLED"
	}
	up := strings.ToUpper(string(out))
	switch {
	case strings.Contains(up, "RUNNING"):
		return "RUNNING"
	case strings.Contains(up, "STOPPED"):
		return "STOPPED"
	case strings.Contains(up, "START_PENDING"):
		return "START_PENDING"
	case strings.Contains(up, "STOP_PENDING"):
		return "STOP_PENDING"
	default:
		return "UNKNOWN"
	}
}

func runCLIHidden(rpcArgs ...string) (string, error) {
	cli := resolveCLI()
	datadir := resolveDataDir()
	args := append([]string{"-datadir=" + datadir}, rpcArgs...)
	cmd := exec.Command(cli, args...)
	hideConsole(cmd)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func runOpsHidden(args ...string) error {
	ops := resolveOps()
	cmd := exec.Command(ops, args...)
	hideConsole(cmd)
	out, err := cmd.CombinedOutput()
	if err != nil {
		// keep for debugging; no console flash
		_ = out
		return err
	}
	return nil
}

func resolveOps() string {
	dir := exeDir()
	for _, p := range []string{
		filepath.Join(dir, "gpenode-ops.exe"),
		filepath.Join(dir, "gpenode-ops"),
		filepath.Join(dir, "bin", "gpenode-ops.exe"),
	} {
		if fileExists(p) {
			return p
		}
	}
	pf := os.Getenv("ProgramFiles")
	if pf == "" {
		pf = `C:\Program Files`
	}
	p := filepath.Join(pf, "DogecoinGPENode", "bin", "gpenode-ops.exe")
	if fileExists(p) {
		return p
	}
	return "gpenode-ops"
}

func resolveCLI() string {
	if v := os.Getenv("DOGECOIN_CLI"); v != "" {
		return v
	}
	dir := exeDir()
	for _, p := range []string{
		filepath.Join(dir, "dogecoin-cli.exe"),
		filepath.Join(dir, "bin", "dogecoin-cli.exe"),
	} {
		if fileExists(p) {
			return p
		}
	}
	pf := os.Getenv("ProgramFiles")
	if pf == "" {
		pf = `C:\Program Files`
	}
	p := filepath.Join(pf, "DogecoinGPENode", "bin", "dogecoin-cli.exe")
	if fileExists(p) {
		return p
	}
	return "dogecoin-cli"
}

func resolveDataDir() string {
	if v := os.Getenv("DOGECOIN_DATADIR"); v != "" {
		return v
	}
	pd := os.Getenv("ProgramData")
	if pd == "" {
		pd = `C:\ProgramData`
	}
	return filepath.Join(pd, "DogecoinGPENode")
}

func resolveInstallRoot() string {
	dir := exeDir()
	// .../DogecoinGPENode/bin → parent
	base := filepath.Base(dir)
	if strings.EqualFold(base, "bin") {
		return filepath.Dir(dir)
	}
	return dir
}

func exeDir() string {
	exe, err := os.Executable()
	if err != nil {
		return "."
	}
	if r, err := filepath.EvalSymlinks(exe); err == nil {
		exe = r
	}
	return filepath.Dir(exe)
}

func fileExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}

func openPath(p string) {
	if runtime.GOOS == "windows" {
		// explorer is GUI — no hide needed
		_ = exec.Command("explorer.exe", p).Start()
		return
	}
	_ = exec.Command("xdg-open", p).Start()
}

func openConf() {
	conf := filepath.Join(resolveDataDir(), "dogecoin.conf")
	if runtime.GOOS == "windows" {
		_ = exec.Command("notepad.exe", conf).Start()
		return
	}
	_ = exec.Command("xdg-open", conf).Start()
}

func openStatusWindow() {
	if runtime.GOOS != "windows" {
		return
	}

	root := resolveInstallRoot()
	bin := filepath.Join(root, "bin")
	ps1Candidates := []string{
		filepath.Join(root, "status-service.ps1"),
		filepath.Join(exeDir(), "status-service.ps1"),
		filepath.Join(exeDir(), "..", "status-service.ps1"),
		filepath.Join(os.Getenv("ProgramFiles"), "DogecoinGPENode", "status-service.ps1"),
	}
	ps1 := ""
	for _, c := range ps1Candidates {
		if abs, err := filepath.Abs(c); err == nil {
			c = abs
		}
		if fileExists(c) {
			ps1 = c
			break
		}
	}

	psExe := filepath.Join(os.Getenv("WINDIR"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
	if !fileExists(psExe) {
		psExe = "powershell.exe"
	}

	var cmd *exec.Cmd
	if ps1 != "" {
		// Visible, stays open until user closes. Do NOT hideConsole.
		cmd = exec.Command(psExe,
			"-NoExit",
			"-ExecutionPolicy", "Bypass",
			"-File", ps1,
			"-BinDir", bin,
			"-DataDir", resolveDataDir(),
		)
	} else {
		// Fallback: keep-open console running gpenode-ops status
		ops := resolveOps()
		// cmd /k keeps window open
		cmd = exec.Command("cmd.exe", "/k",
			ops, "status",
		)
	}

	// Detach so tray doesn't own the console lifecycle oddly
	if err := cmd.Start(); err != nil {
		// last-ditch: write a note via notepad
		tmp := filepath.Join(os.TempDir(), "gpenode-tray-error.txt")
		_ = os.WriteFile(tmp, []byte("Failed to open status window:\n"+err.Error()+"\n"), 0o644)
		_ = exec.Command("notepad.exe", tmp).Start()
	}
}
