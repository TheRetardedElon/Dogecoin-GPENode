package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const serviceName = "DogecoinGPENode"

type nodeSnapshot struct {
	Time        string
	Phase       string
	Service     string
	CLI         string
	DataDir     string
	Chain       string
	Blocks      string
	Headers     string
	IBD         string
	Progress    string
	Connections string
	Network     string
	Version     string
	DumpRPC     string
	WalletOn    bool
	Balance     string
	Message     string
	OK          bool
}

func resolveCLI() string {
	if v := os.Getenv("DOGECOIN_CLI"); v != "" {
		return v
	}
	dir := exeDir()
	for _, p := range []string{
		filepath.Join(dir, "dogecoin-cli.exe"),
		filepath.Join(dir, "dogecoin-cli"),
		filepath.Join(dir, "bin", "dogecoin-cli.exe"),
	} {
		if fileExists(p) {
			return p
		}
	}
	if runtime.GOOS == "windows" {
		pf := envOr("ProgramFiles", `C:\Program Files`)
		p := filepath.Join(pf, "DogecoinGPENode", "bin", "dogecoin-cli.exe")
		if fileExists(p) {
			return p
		}
	}
	return "dogecoin-cli"
}

func resolveDataDir() string {
	if v := os.Getenv("DOGECOIN_DATADIR"); v != "" {
		return v
	}
	if runtime.GOOS == "windows" {
		return filepath.Join(envOr("ProgramData", `C:\ProgramData`), "DogecoinGPENode")
	}
	return filepath.Join(homeDir(), ".dogecoin")
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
	if runtime.GOOS == "windows" {
		p := filepath.Join(envOr("ProgramFiles", `C:\Program Files`), "DogecoinGPENode", "bin", "gpenode-ops.exe")
		if fileExists(p) {
			return p
		}
	}
	return "gpenode-ops"
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

func homeDir() string {
	h, err := os.UserHomeDir()
	if err != nil {
		return "."
	}
	return h
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func fileExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}

func runCLI(args ...string) (string, error) {
	cli := resolveCLI()
	datadir := resolveDataDir()
	full := append([]string{"-datadir=" + datadir}, args...)
	cmd := exec.Command(cli, full...)
	hideConsole(cmd)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func serviceState() string {
	if runtime.GOOS != "windows" {
		return "N/A"
	}
	cmd := exec.Command("sc.exe", "query", serviceName)
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

func serviceAction(action string) (string, error) {
	if runtime.GOOS != "windows" {
		return "", fmt.Errorf("service control is Windows-only")
	}
	// Prefer gpenode-ops when present
	ops := resolveOps()
	var out []byte
	var err error
	if fileExists(ops) {
		cmd := exec.Command(ops, "service", action)
		hideConsole(cmd)
		out, err = cmd.CombinedOutput()
	} else {
		cmd := exec.Command("sc.exe", action, serviceName)
		hideConsole(cmd)
		out, err = cmd.CombinedOutput()
	}
	// Never dump raw sc.exe tables into the TUI tip line
	state := serviceState()
	if err != nil {
		msg := strings.TrimSpace(string(out))
		if len(msg) > 120 {
			msg = msg[:120] + "…"
		}
		if msg == "" {
			msg = err.Error()
		}
		return fmt.Sprintf("service %s failed (state=%s)", action, state), fmt.Errorf("%s", msg)
	}
	return fmt.Sprintf("service %s ok · state %s", action, state), nil
}

func isWarmup(out string) bool {
	s := strings.ToLower(out)
	return strings.Contains(s, "error code: -28") ||
		strings.Contains(s, "loading block index") ||
		strings.Contains(s, "verifying blocks") ||
		strings.Contains(s, "loading wallet")
}

func jsonField(m map[string]json.RawMessage, k string) string {
	raw, ok := m[k]
	if !ok {
		return ""
	}
	return strings.Trim(strings.TrimSpace(string(raw)), `"`)
}

func fetchSnapshot() nodeSnapshot {
	s := nodeSnapshot{
		Time:    time.Now().UTC().Format(time.RFC3339),
		CLI:     resolveCLI(),
		DataDir: resolveDataDir(),
		Service: serviceState(),
	}

	// version
	if out, err := runCLI("-version"); err == nil {
		line := strings.Split(strings.TrimSpace(out), "\n")[0]
		s.Version = strings.TrimSpace(line)
	}

	out, err := runCLI("getblockchaininfo")
	if err != nil {
		if isWarmup(out) {
			s.Phase = "INIT"
			s.Message = "Loading block index (RPC -28) — normal after start"
			s.OK = true
			return s
		}
		s.Phase = "OFFLINE"
		s.Message = strings.TrimSpace(out)
		if s.Message == "" {
			s.Message = err.Error()
		}
		return s
	}

	var info map[string]json.RawMessage
	if json.Unmarshal([]byte(out), &info) == nil {
		s.Chain = jsonField(info, "chain")
		s.Blocks = jsonField(info, "blocks")
		s.Headers = jsonField(info, "headers")
		s.IBD = jsonField(info, "initialblockdownload")
		s.Progress = jsonField(info, "verificationprogress")
		if strings.EqualFold(s.IBD, "true") {
			s.Phase = "IBD"
		} else {
			s.Phase = "SYNCED"
		}
		s.OK = true
	}

	if ni, err := runCLI("getnetworkinfo"); err == nil {
		var n map[string]json.RawMessage
		if json.Unmarshal([]byte(ni), &n) == nil {
			s.Connections = jsonField(n, "connections")
			s.Network = jsonField(n, "subversion")
			if s.Network == "" {
				s.Network = jsonField(n, "networkactive")
			}
		}
	}

	// dump RPC
	help, err := runCLI("help", "dumptxoutset")
	if err != nil || strings.Contains(strings.ToLower(help), "unknown command") {
		s.DumpRPC = "MISSING"
	} else {
		s.DumpRPC = "OK"
	}

	// wallet optional
	if bal, err := runCLI("getbalance"); err == nil {
		s.WalletOn = true
		s.Balance = strings.TrimSpace(bal)
	} else {
		s.WalletOn = false
		s.Balance = "(wallet disabled / unavailable)"
	}

	return s
}

func fetchCDN(url string) (string, error) {
	if url == "" {
		url = envOr("CDN_LATEST_URL", "https://sync.doge.gopastearth.com/latest.json")
	}
	client := &http.Client{Timeout: 20 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("HTTP %s", resp.Status)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", err
	}
	var meta map[string]json.RawMessage
	if err := json.Unmarshal(body, &meta); err != nil {
		return string(body), nil
	}
	var b strings.Builder
	fmt.Fprintf(&b, "url: %s\n", url)
	for _, k := range []string{"blocks", "sha256", "bytes", "filename", "hash_serialized", "created_utc", "producer"} {
		if raw, ok := meta[k]; ok {
			fmt.Fprintf(&b, "%s: %s\n", k, strings.Trim(strings.TrimSpace(string(raw)), `"`))
		}
	}
	return b.String(), nil
}

func tailDebugLog(n int) string {
	p := filepath.Join(resolveDataDir(), "debug.log")
	data, err := os.ReadFile(p)
	if err != nil {
		return fmt.Sprintf("(no debug.log at %s)\n%s", p, err.Error())
	}
	lines := strings.Split(string(data), "\n")
	if n < 1 {
		n = 20
	}
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	return strings.Join(lines, "\n")
}

func listSnapshots() string {
	dir := filepath.Join(resolveDataDir(), "snapshots")
	ents, err := os.ReadDir(dir)
	if err != nil {
		return fmt.Sprintf("snapshots dir: %s\n(%s)", dir, err.Error())
	}
	if len(ents) == 0 {
		return fmt.Sprintf("snapshots dir: %s\n(empty — run dump when fully synced)", dir)
	}
	var b strings.Builder
	fmt.Fprintf(&b, "snapshots dir: %s\n", dir)
	count := 0
	for i := len(ents) - 1; i >= 0 && count < 12; i-- {
		e := ents[i]
		if e.IsDir() {
			continue
		}
		info, _ := e.Info()
		sz := int64(0)
		if info != nil {
			sz = info.Size()
		}
		fmt.Fprintf(&b, "  %s  (%d bytes)\n", e.Name(), sz)
		count++
	}
	return b.String()
}

func runDumpNative() (string, error) {
	dir := filepath.Join(resolveDataDir(), "snapshots")
	_ = os.MkdirAll(dir, 0o755)
	name := fmt.Sprintf("utxo-%s.dat", time.Now().UTC().Format("20060102T150405Z"))
	path := filepath.Join(dir, name)
	out, err := runCLI("dumptxoutset", path)
	if err != nil {
		return out, err
	}
	return fmt.Sprintf("Wrote: %s\n%s", path, out), nil
}
