//go:build !windows

package main

import (
	"fmt"
	"os"
)

func cmdService(args []string) {
	fmt.Fprintln(os.Stderr, "gpenode-ops service is Windows-only (use systemd on Linux)")
	os.Exit(2)
}

func serviceState(name string) string {
	return "N/A"
}
