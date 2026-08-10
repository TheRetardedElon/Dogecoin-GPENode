//go:build !windows

package main

import (
	"fmt"
	"os"
)

func cmdServiceRun(args []string) {
	fmt.Fprintln(os.Stderr, "service-run is only supported on Windows (SCM wrapper for dogecoind)")
	os.Exit(2)
}
