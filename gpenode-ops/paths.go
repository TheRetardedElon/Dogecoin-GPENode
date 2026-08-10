package main

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// resolvePaths picks dogecoin-cli, datadir, and install bin for operator commands.
// Order: flags/env → next to this exe → Windows defaults / registry-style env.
func resolveCLI() string {
	if v := os.Getenv("DOGECOIN_CLI"); v != "" {
		return v
	}
	exeDir := exeDir()
	names := []string{"dogecoin-cli"}
	if runtime.GOOS == "windows" {
		names = []string{"dogecoin-cli.exe", "dogecoin-cli"}
	}
	for _, n := range names {
		p := filepath.Join(exeDir, n)
		if fileExists(p) {
			return p
		}
		// install layout: .../DogecoinGPENode/bin/
		p = filepath.Join(exeDir, "bin", n)
		if fileExists(p) {
			return p
		}
	}
	if runtime.GOOS == "windows" {
		pf := os.Getenv("ProgramFiles")
		if pf == "" {
			pf = `C:\Program Files`
		}
		p := filepath.Join(pf, "DogecoinGPENode", "bin", "dogecoin-cli.exe")
		if fileExists(p) {
			return p
		}
	}
	return names[0]
}

func resolveDataDir() string {
	if v := os.Getenv("DOGECOIN_DATADIR"); v != "" {
		return v
	}
	if runtime.GOOS == "windows" {
		pd := os.Getenv("ProgramData")
		if pd == "" {
			pd = `C:\ProgramData`
		}
		return filepath.Join(pd, "DogecoinGPENode")
	}
	// Linux dump node common layout
	for _, c := range []string{
		"/var/lib/dogecoin-gpenode",
		filepath.Join(homeDir(), ".dogecoin"),
	} {
		if dirExists(c) {
			return c
		}
	}
	return filepath.Join(homeDir(), ".dogecoin")
}

func resolveDogecoind() string {
	if v := os.Getenv("DOGECOIND"); v != "" {
		return v
	}
	exeDir := exeDir()
	names := []string{"dogecoind"}
	if runtime.GOOS == "windows" {
		names = []string{"dogecoind.exe", "dogecoind"}
	}
	for _, n := range names {
		for _, p := range []string{
			filepath.Join(exeDir, n),
			filepath.Join(exeDir, "bin", n),
		} {
			if fileExists(p) {
				return p
			}
		}
	}
	if runtime.GOOS == "windows" {
		pf := os.Getenv("ProgramFiles")
		if pf == "" {
			pf = `C:\Program Files`
		}
		p := filepath.Join(pf, "DogecoinGPENode", "bin", "dogecoind.exe")
		if fileExists(p) {
			return p
		}
	}
	return names[0]
}

func exeDir() string {
	exe, err := os.Executable()
	if err != nil {
		return "."
	}
	// Resolve symlinks when possible
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

func fileExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}

func dirExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.IsDir()
}

func isRPCWarmup(out string) bool {
	s := strings.ToLower(out)
	return strings.Contains(s, "error code: -28") ||
		strings.Contains(s, "loading block index") ||
		strings.Contains(s, "verifying blocks") ||
		strings.Contains(s, "loading wallet") ||
		strings.Contains(s, "rewinding blocks") ||
		strings.Contains(s, "loading banlist")
}
