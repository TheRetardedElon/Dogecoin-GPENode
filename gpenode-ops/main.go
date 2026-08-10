// gpenode-ops — operator glue for GPENode.
// Talks to headless dogecoind over localhost RPC / dogecoin-cli.
// Does NOT implement consensus. See deploy/ARCHITECTURE.md.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

const (
	opsVersion         = "0.3.0"
	defaultServiceName = "DogecoinGPENode"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	switch os.Args[1] {
	case "status":
		cmdStatus(os.Args[2:])
	case "dump":
		cmdDump(os.Args[2:])
	case "publish":
		cmdPublish(os.Args[2:])
	case "verify-cdn":
		cmdVerifyCDN(os.Args[2:])
	case "service":
		cmdService(os.Args[2:])
	case "service-run":
		cmdServiceRun(os.Args[2:])
	case "version":
		fmt.Printf("gpenode-ops %s (glue only; consensus is dogecoind)\n", opsVersion)
	case "help", "-h", "--help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprintf(os.Stderr, `gpenode-ops — GPENode operator glue (RPC only; no consensus)

Commands:
  status       Phase + chain tip / IBD / dump RPC presence
  dump         dumptxoutset (native) or make_utxo_snapshot.sh
  publish      Run publish_snapshots.sh (CDN_TARGET for push)
  verify-cdn   Fetch latest.json and print pointer fields
  service      Windows: status|start|stop|restart [ServiceName]
  service-run  Windows only: SCM host that supervises dogecoind
  version      Print ops binary version

Env:
  DOGECOIN_CLI      path to dogecoin-cli
  DOGECOIN_DATADIR  -datadir for cli
  DOGECOIND         path to dogecoind (service-run / discovery)
  SNAP_SCRIPT       path to make_utxo_snapshot.sh
  PUBLISH_SCRIPT    path to publish_snapshots.sh
  CDN_LATEST_URL    default https://sync.doge.gopastearth.com/latest.json

Windows defaults (when env unset):
  CLI/daemon: %%ProgramFiles%%\DogecoinGPENode\bin\
  datadir:    %%ProgramData%%\DogecoinGPENode

Phases (status):
  OFFLINE  service/process down or RPC unreachable
  INIT     RPC -28 (loading block index / verifying)
  IBD      initial block download
  SYNCED   caught up (or nearly)
`)
}

func cliBase() []string {
	bin := resolveCLI()
	args := []string{bin}
	if d := resolveDataDir(); d != "" {
		args = append(args, "-datadir="+d)
	}
	return args
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func runCLI(rpcArgs ...string) (string, error) {
	base := cliBase()
	args := append(append([]string{}, base[1:]...), rpcArgs...)
	cmd := exec.Command(base[0], args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func cmdStatus(args []string) {
	fs := flag.NewFlagSet("status", flag.ExitOnError)
	jsonOut := fs.Bool("json", false, "machine-readable JSON summary")
	_ = fs.Parse(args)

	cli := resolveCLI()
	datadir := resolveDataDir()
	daemon := resolveDogecoind()

	type summary struct {
		Time     string `json:"time"`
		Phase    string `json:"phase"`
		Service  string `json:"service,omitempty"`
		CLI      string `json:"cli"`
		DataDir  string `json:"datadir"`
		Dogecoind string `json:"dogecoind,omitempty"`
		Chain    string `json:"chain,omitempty"`
		Blocks   string `json:"blocks,omitempty"`
		Headers  string `json:"headers,omitempty"`
		IBD      string `json:"ibd,omitempty"`
		Progress string `json:"progress,omitempty"`
		DumpRPC  string `json:"dumptxoutset,omitempty"`
		Message  string `json:"message,omitempty"`
	}
	sum := summary{
		Time:      time.Now().UTC().Format(time.RFC3339),
		CLI:       cli,
		DataDir:   datadir,
		Dogecoind: daemon,
	}
	if runtime.GOOS == "windows" {
		sum.Service = serviceState(defaultServiceName)
	}

	printHuman := func() {
		if *jsonOut {
			return
		}
		fmt.Println("==> gpenode-ops status")
		fmt.Println("time", sum.Time)
		fmt.Println("cli", sum.CLI)
		fmt.Println("datadir", sum.DataDir)
		if sum.Service != "" {
			fmt.Println("service", sum.Service)
		}
	}
	printHuman()

	out, err := runCLI("getblockchaininfo")
	if err != nil {
		if isRPCWarmup(out) {
			sum.Phase = "INIT"
			sum.Message = strings.TrimSpace(out)
			if !*jsonOut {
				fmt.Println("phase INIT")
				fmt.Println("rpc warmup: node is loading block index (like GUI splash)")
				fmt.Println("wait a minute and re-run: gpenode-ops status")
				if sum.Service == "RUNNING" || sum.Service == "" {
					fmt.Println("(service/process looks up — this is normal)")
				}
			} else {
				enc, _ := json.MarshalIndent(sum, "", "  ")
				fmt.Println(string(enc))
			}
			os.Exit(0)
		}
		sum.Phase = "OFFLINE"
		sum.Message = strings.TrimSpace(out)
		if sum.Message == "" {
			sum.Message = err.Error()
		}
		if !*jsonOut {
			fmt.Println("phase OFFLINE")
			fmt.Fprintf(os.Stderr, "getblockchaininfo failed: %v\n%s\n", err, out)
			if runtime.GOOS == "windows" && sum.Service != "RUNNING" {
				fmt.Fprintln(os.Stderr, "hint: gpenode-ops service start   (Admin if needed)")
			}
		} else {
			enc, _ := json.MarshalIndent(sum, "", "  ")
			fmt.Println(string(enc))
		}
		os.Exit(1)
	}

	var info map[string]json.RawMessage
	get := func(k string) string {
		raw, ok := info[k]
		if !ok {
			return ""
		}
		s := strings.TrimSpace(string(raw))
		return strings.Trim(s, `"`)
	}
	if err := json.Unmarshal([]byte(out), &info); err != nil {
		if !*jsonOut {
			fmt.Print(out)
		}
		sum.Phase = "UNKNOWN"
	} else {
		sum.Chain = get("chain")
		sum.Blocks = get("blocks")
		sum.Headers = get("headers")
		sum.IBD = get("initialblockdownload")
		sum.Progress = get("verificationprogress")
		sum.Phase = phaseFromChain(sum.IBD, sum.Blocks, sum.Headers, sum.Progress)
		if !*jsonOut {
			fmt.Printf("phase %s\n", sum.Phase)
			fmt.Printf("chain=%s blocks=%s headers=%s ibd=%s progress=%s\n",
				sum.Chain, sum.Blocks, sum.Headers, sum.IBD, sum.Progress)
		}
	}

	help, err := runCLI("help", "dumptxoutset")
	if err != nil || strings.Contains(strings.ToLower(help), "unknown command") {
		sum.DumpRPC = "MISSING"
		if !*jsonOut {
			fmt.Println("dumptxoutset: MISSING (need Core Pro / GPENode dump daemon)")
		}
		if *jsonOut {
			enc, _ := json.MarshalIndent(sum, "", "  ")
			fmt.Println(string(enc))
		}
		os.Exit(2)
	}
	sum.DumpRPC = "OK"
	if !*jsonOut {
		fmt.Println("dumptxoutset: OK")
	}
	if *jsonOut {
		enc, _ := json.MarshalIndent(sum, "", "  ")
		fmt.Println(string(enc))
	}
}

func phaseFromChain(ibd, blocks, headers, progress string) string {
	if strings.EqualFold(ibd, "true") {
		return "IBD"
	}
	// nearly caught up
	b, _ := strconv.ParseInt(blocks, 10, 64)
	h, _ := strconv.ParseInt(headers, 10, 64)
	if h > 0 && b > 0 && (h-b) <= 2 {
		return "SYNCED"
	}
	p, _ := strconv.ParseFloat(progress, 64)
	if p >= 0.999 {
		return "SYNCED"
	}
	if b > 0 {
		return "IBD"
	}
	return "UNKNOWN"
}

func cmdDump(args []string) {
	fs := flag.NewFlagSet("dump", flag.ExitOnError)
	outPath := fs.String("out", "", "output path for dumptxoutset (default: datadir/snapshots/utxo-TIMESTAMP.dat)")
	native := fs.Bool("native", false, "force dogecoin-cli dumptxoutset (skip bash script)")
	_ = fs.Parse(args)

	script := env("SNAP_SCRIPT", defaultDeployScript("make_utxo_snapshot.sh"))
	if !*native {
		if _, err := os.Stat(script); err == nil {
			fmt.Println("==> dump via", script)
			cmd := exec.Command("bash", script)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				fmt.Fprintf(os.Stderr, "dump failed: %v\n", err)
				os.Exit(1)
			}
			return
		}
	}

	// Native path (Windows-friendly)
	datadir := resolveDataDir()
	path := *outPath
	if path == "" {
		snapDir := filepath.Join(datadir, "snapshots")
		_ = os.MkdirAll(snapDir, 0o755)
		path = filepath.Join(snapDir, fmt.Sprintf("utxo-%s.dat", time.Now().UTC().Format("20060102T150405Z")))
	}
	fmt.Println("==> dump native dumptxoutset")
	fmt.Println("out", path)
	out, err := runCLI("dumptxoutset", path)
	fmt.Print(out)
	if err != nil {
		fmt.Fprintf(os.Stderr, "dumptxoutset failed: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("dump OK")
}

func cmdPublish(args []string) {
	fs := flag.NewFlagSet("publish", flag.ExitOnError)
	_ = fs.Parse(args)

	script := env("PUBLISH_SCRIPT", defaultDeployScript("publish_snapshots.sh"))
	if _, err := os.Stat(script); err != nil {
		fmt.Fprintf(os.Stderr, "publish script not found: %s\nset PUBLISH_SCRIPT=\n", script)
		os.Exit(1)
	}
	if os.Getenv("CDN_TARGET") == "" {
		fmt.Fprintln(os.Stderr, "warning: CDN_TARGET unset — publish script may require it (or use CDN-side pull)")
	}
	fmt.Println("==> publish via", script)
	cmd := exec.Command("bash", script)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "publish failed: %v\n", err)
		os.Exit(1)
	}
}

func cmdVerifyCDN(args []string) {
	fs := flag.NewFlagSet("verify-cdn", flag.ExitOnError)
	_ = fs.Parse(args)
	url := env("CDN_LATEST_URL", "https://sync.doge.gopastearth.com/latest.json")
	fmt.Println("==> GET", url)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		// fallback curl for minimal envs
		cmd := exec.Command("curl", "-fsS", url)
		out, err2 := cmd.CombinedOutput()
		if err2 != nil {
			fmt.Fprintf(os.Stderr, "fetch failed: %v / curl: %v\n%s\n", err, err2, out)
			os.Exit(1)
		}
		printCDNMeta(out)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		fmt.Fprintf(os.Stderr, "HTTP %s\n", resp.Status)
		os.Exit(1)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		fmt.Fprintf(os.Stderr, "read failed: %v\n", err)
		os.Exit(1)
	}
	printCDNMeta(body)
}

func printCDNMeta(out []byte) {
	var meta map[string]json.RawMessage
	if err := json.Unmarshal(out, &meta); err != nil {
		fmt.Print(string(out))
		return
	}
	for _, k := range []string{"blocks", "sha256", "bytes", "url", "hash_serialized", "filename", "created_utc", "producer"} {
		if raw, ok := meta[k]; ok {
			s := strings.TrimSpace(string(raw))
			s = strings.Trim(s, `"`)
			fmt.Printf("%s=%s\n", k, s)
		}
	}
	if raw, ok := meta["urls"]; ok {
		var urls []string
		if err := json.Unmarshal(raw, &urls); err == nil && len(urls) > 0 {
			fmt.Println("urls:")
			for _, u := range urls {
				fmt.Println(" ", u)
			}
		}
	}
}

func defaultDeployScript(name string) string {
	candidates := []string{
		filepath.Join("/opt/gpe-deploy", name),
		filepath.Join("deploy", name),
		filepath.Join("..", "deploy", name),
	}
	if exe, err := os.Executable(); err == nil {
		dir := filepath.Dir(exe)
		candidates = append(candidates,
			filepath.Join(dir, name),
			filepath.Join(dir, "..", "deploy", name),
			filepath.Join(dir, "deploy", name),
		)
	}
	for _, c := range candidates {
		if st, err := os.Stat(c); err == nil && !st.IsDir() {
			return c
		}
	}
	return candidates[0]
}
