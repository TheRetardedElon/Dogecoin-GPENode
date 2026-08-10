// gpenode-ops — operator glue for GPENode.
// Talks to headless dogecoind over localhost RPC / dogecoin-cli.
// Does NOT implement consensus. See deploy/ARCHITECTURE.md.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
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
	case "version":
		fmt.Println("gpenode-ops 0.1.0 (glue only; consensus is dogecoind)")
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
  status       Chain tip / IBD / dump RPC presence
  dump         Run make_utxo_snapshot.sh (or dogecoin-cli dumptxoutset)
  publish      Run publish_snapshots.sh (CDN_TARGET required for push)
  verify-cdn   Fetch latest.json and print pointer fields
  version      Print ops binary version

Env:
  DOGECOIN_CLI   path to dogecoin-cli (default: dogecoin-cli)
  DOGECOIN_DATADIR  -datadir for cli
  SNAP_SCRIPT    path to make_utxo_snapshot.sh
  PUBLISH_SCRIPT path to publish_snapshots.sh
  CDN_LATEST_URL default https://sync.doge.gopastearth.com/latest.json
`)
}

func cliBase() []string {
	bin := env("DOGECOIN_CLI", "dogecoin-cli")
	args := []string{bin}
	if d := os.Getenv("DOGECOIN_DATADIR"); d != "" {
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
	args := append(base[1:], rpcArgs...)
	cmd := exec.Command(base[0], args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func cmdStatus(args []string) {
	fs := flag.NewFlagSet("status", flag.ExitOnError)
	_ = fs.Parse(args)

	fmt.Println("==> gpenode-ops status")
	fmt.Println("time", time.Now().UTC().Format(time.RFC3339))

	out, err := runCLI("getblockchaininfo")
	if err != nil {
		fmt.Fprintf(os.Stderr, "getblockchaininfo failed: %v\n%s\n", err, out)
		os.Exit(1)
	}
	var info map[string]json.RawMessage
	if err := json.Unmarshal([]byte(out), &info); err != nil {
		fmt.Print(out)
	} else {
		get := func(k string) string {
			raw, ok := info[k]
			if !ok {
				return ""
			}
			s := strings.TrimSpace(string(raw))
			return strings.Trim(s, `"`)
		}
		fmt.Printf("chain=%s blocks=%s headers=%s ibd=%s progress=%s\n",
			get("chain"), get("blocks"), get("headers"),
			get("initialblockdownload"), get("verificationprogress"))
	}

	help, err := runCLI("help", "dumptxoutset")
	if err != nil || strings.Contains(strings.ToLower(help), "unknown command") {
		fmt.Println("dumptxoutset: MISSING (need custom Core Pro daemon)")
		os.Exit(2)
	}
	fmt.Println("dumptxoutset: OK")
}

func cmdDump(args []string) {
	fs := flag.NewFlagSet("dump", flag.ExitOnError)
	_ = fs.Parse(args)

	script := env("SNAP_SCRIPT", defaultDeployScript("make_utxo_snapshot.sh"))
	if _, err := os.Stat(script); err != nil {
		fmt.Fprintf(os.Stderr, "snapshot script not found: %s\nset SNAP_SCRIPT=\n", script)
		os.Exit(1)
	}
	fmt.Println("==> dump via", script)
	cmd := exec.Command("bash", script)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "dump failed: %v\n", err)
		os.Exit(1)
	}
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
	// curl keeps deps zero; ops host always has it
	cmd := exec.Command("curl", "-fsS", url)
	out, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "fetch failed: %v\n%s\n", err, out)
		os.Exit(1)
	}
	var meta map[string]json.RawMessage
	if err := json.Unmarshal(out, &meta); err != nil {
		fmt.Print(string(out))
		return
	}
	// Prefer raw JSON text so large ints are not scientific notation.
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
	// Prefer /opt/gpe-deploy on node; else relative to this module's sibling deploy/
	candidates := []string{
		filepath.Join("/opt/gpe-deploy", name),
		filepath.Join("deploy", name),
		filepath.Join("..", "deploy", name),
	}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Join(filepath.Dir(exe), name))
	}
	for _, c := range candidates {
		if st, err := os.Stat(c); err == nil && !st.IsDir() {
			return c
		}
	}
	return candidates[0]
}
