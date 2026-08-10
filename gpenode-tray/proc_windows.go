//go:build windows

package main

import (
	"os/exec"
	"syscall"
)

// hideConsole prevents sc.exe / dogecoin-cli / gpenode-ops from flashing a CMD window
// when launched from a windowsgui tray process.
func hideConsole(cmd *exec.Cmd) {
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	cmd.SysProcAttr.HideWindow = true
	cmd.SysProcAttr.CreationFlags |= 0x08000000 // CREATE_NO_WINDOW
}
