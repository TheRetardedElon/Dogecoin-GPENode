//go:build windows

package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

func cmdService(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "usage: gpenode-ops service <status|start|stop|restart> [ServiceName]")
		os.Exit(2)
	}
	action := strings.ToLower(args[0])
	name := defaultServiceName
	if len(args) >= 2 && args[1] != "" {
		name = args[1]
	}

	switch action {
	case "status":
		printServiceStatus(name)
	case "start":
		runSC("start", name)
		waitService(name, "RUNNING", 30*time.Second)
		printServiceStatus(name)
	case "stop":
		runSC("stop", name)
		waitService(name, "STOPPED", 60*time.Second)
		printServiceStatus(name)
	case "restart":
		_ = exec.Command("sc.exe", "stop", name).Run()
		waitService(name, "STOPPED", 60*time.Second)
		runSC("start", name)
		waitService(name, "RUNNING", 30*time.Second)
		printServiceStatus(name)
	default:
		fmt.Fprintf(os.Stderr, "unknown service action: %s\n", action)
		os.Exit(2)
	}
}

func runSC(action, name string) {
	cmd := exec.Command("sc.exe", action, name)
	out, err := cmd.CombinedOutput()
	fmt.Print(string(out))
	if err != nil {
		fmt.Fprintf(os.Stderr, "sc %s %s: %v\n", action, name, err)
		os.Exit(1)
	}
}

func printServiceStatus(name string) {
	cmd := exec.Command("sc.exe", "query", name)
	out, err := cmd.CombinedOutput()
	s := string(out)
	fmt.Print(s)
	if err != nil {
		fmt.Fprintf(os.Stderr, "service %q not found or sc query failed: %v\n", name, err)
		os.Exit(1)
	}
	state := "UNKNOWN"
	for _, line := range strings.Split(s, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "STATE") {
			// STATE              : 4  RUNNING
			parts := strings.Fields(line)
			if len(parts) >= 4 {
				state = parts[len(parts)-1]
			}
		}
	}
	fmt.Printf("service=%s state=%s\n", name, state)
}

func waitService(name, want string, timeout time.Duration) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		cmd := exec.Command("sc.exe", "query", name)
		out, _ := cmd.CombinedOutput()
		if strings.Contains(strings.ToUpper(string(out)), want) {
			return
		}
		time.Sleep(500 * time.Millisecond)
	}
}

// serviceState returns RUNNING/STOPPED/… for tray/status.
func serviceState(name string) string {
	if name == "" {
		name = defaultServiceName
	}
	cmd := exec.Command("sc.exe", "query", name)
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
