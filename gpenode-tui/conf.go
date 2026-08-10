package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// confKey is an editable dogecoin.conf setting exposed in the TUI.
type confKey struct {
	Key      string
	Label    string
	Secret   bool // mask in list view
	Help     string
	Restart  bool // needs node restart to apply
	Validate func(string) error
}

func confPath() string {
	return filepath.Join(resolveDataDir(), "dogecoin.conf")
}

// Editable operator knobs (safe subset — not every Core option).
func editableConfKeys() []confKey {
	return []confKey{
		{Key: "rpcuser", Label: "RPC user", Restart: true, Help: "Local RPC username"},
		{Key: "rpcpassword", Label: "RPC password", Secret: true, Restart: true, Help: "Strong password; localhost only still"},
		{Key: "rpcbind", Label: "RPC bind", Restart: true, Help: "Prefer 127.0.0.1", Validate: nonEmpty},
		{Key: "rpcallowip", Label: "RPC allow IP", Restart: true, Help: "Prefer 127.0.0.1"},
		{Key: "prune", Label: "Prune (MiB)", Restart: true, Help: "0=off; 1.14.x min ~2200 when pruning", Validate: isUint},
		{Key: "dbcache", Label: "DB cache (MiB)", Restart: true, Help: "Memory for UTXO/cache", Validate: isUint},
		{Key: "maxconnections", Label: "Max peers", Restart: true, Help: "P2P connection cap", Validate: isUint},
		{Key: "maxmempool", Label: "Max mempool (MB)", Restart: true, Help: "Mempool size limit", Validate: isUint},
		{Key: "disablewallet", Label: "Disable wallet", Restart: true, Help: "1=dump profile; 0=wallet RPC on", Validate: is01},
		{Key: "txindex", Label: "txindex", Restart: true, Help: "1=full tx index (heavy)", Validate: is01},
		{Key: "listen", Label: "Listen P2P", Restart: true, Help: "1=accept peers", Validate: is01},
		{Key: "server", Label: "Server/RPC", Restart: true, Help: "Must be 1 for RPC", Validate: is01},
		{Key: "printtoconsole", Label: "Print to console", Restart: true, Help: "0 for service mode", Validate: is01},
	}
}

func nonEmpty(v string) error {
	if strings.TrimSpace(v) == "" {
		return fmt.Errorf("value required")
	}
	return nil
}

func isUint(v string) error {
	v = strings.TrimSpace(v)
	if v == "" {
		return fmt.Errorf("number required")
	}
	for _, c := range v {
		if c < '0' || c > '9' {
			return fmt.Errorf("must be a non-negative integer")
		}
	}
	return nil
}

func is01(v string) error {
	v = strings.TrimSpace(v)
	if v != "0" && v != "1" {
		return fmt.Errorf("must be 0 or 1")
	}
	return nil
}

// loadConfMap reads key=value pairs (last wins). Comments/blank ignored.
func loadConfMap(path string) (map[string]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	out := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		// strip inline comments? Core uses # only at start typically
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.TrimSpace(v)
		if k != "" {
			out[strings.ToLower(k)] = v
		}
	}
	return out, nil
}

// writeConfUpdates updates keys in-place, preserves comments/order, appends missing keys.
// Creates path.bak.<timestamp> backup first.
func writeConfUpdates(path string, updates map[string]string) error {
	if len(updates) == 0 {
		return fmt.Errorf("no changes to write")
	}
	// normalize keys lower for match; preserve write casing from editableConfKeys
	canon := map[string]string{} // lower -> canonical key name
	for _, ck := range editableConfKeys() {
		canon[strings.ToLower(ck.Key)] = ck.Key
	}
	norm := map[string]string{}
	for k, v := range updates {
		lk := strings.ToLower(strings.TrimSpace(k))
		if ck, ok := canon[lk]; ok {
			norm[ck] = strings.TrimSpace(v)
		} else {
			norm[strings.TrimSpace(k)] = strings.TrimSpace(v)
		}
	}

	var raw []byte
	var err error
	if _, err = os.Stat(path); err == nil {
		raw, err = os.ReadFile(path)
		if err != nil {
			return err
		}
		// backup
		bak := path + ".bak." + time.Now().UTC().Format("20060102T150405Z")
		if err := os.WriteFile(bak, raw, 0o600); err != nil {
			return fmt.Errorf("backup failed: %w", err)
		}
	} else if os.IsNotExist(err) {
		raw = []byte("# dogecoin.conf created by GPENode TUI\nserver=1\nlisten=1\n")
	} else {
		return err
	}

	lines := strings.Split(string(raw), "\n")
	// track trailing newline
	hadTrailingNL := strings.HasSuffix(string(raw), "\n")
	if len(lines) > 0 && lines[len(lines)-1] == "" && hadTrailingNL {
		lines = lines[:len(lines)-1]
	}

	seen := map[string]bool{}
	for i, line := range lines {
		trim := strings.TrimSpace(line)
		if trim == "" || strings.HasPrefix(trim, "#") {
			continue
		}
		k, _, ok := strings.Cut(trim, "=")
		if !ok {
			continue
		}
		lk := strings.ToLower(strings.TrimSpace(k))
		// find if this key is in updates (by lower)
		for uk, uv := range norm {
			if strings.ToLower(uk) == lk {
				// preserve indentation
				indent := line[:len(line)-len(strings.TrimLeft(line, " \t"))]
				lines[i] = indent + uk + "=" + uv
				seen[strings.ToLower(uk)] = true
				break
			}
		}
	}

	// append missing
	var missing []string
	for uk, uv := range norm {
		if !seen[strings.ToLower(uk)] {
			missing = append(missing, uk+"="+uv)
		}
	}
	if len(missing) > 0 {
		lines = append(lines, "", "# Updated by GPENode TUI "+time.Now().UTC().Format(time.RFC3339))
		lines = append(lines, missing...)
	}

	out := strings.Join(lines, "\n") + "\n"
	// restrictive perms on Unix; Windows ignores
	if err := os.WriteFile(path, []byte(out), 0o600); err != nil {
		return err
	}
	return nil
}

func maskSecret(v string) string {
	if v == "" {
		return "(empty)"
	}
	if len(v) <= 2 {
		return "**"
	}
	return v[:1] + strings.Repeat("*", min(12, len(v)-1))
}

func confDisplayValue(ck confKey, v string) string {
	if v == "" {
		return "(unset)"
	}
	if ck.Secret {
		return maskSecret(v)
	}
	return v
}
