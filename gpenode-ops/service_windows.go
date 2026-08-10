//go:build windows

// Windows SCM host for dogecoind.
// dogecoind itself does not implement StartServiceCtrlDispatcher; this wrapper does.
// Consensus stays in dogecoind — this process only supervises it.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/eventlog"
)

const serviceCmdName = "service-run"

func cmdServiceRun(args []string) {
	fs := flag.NewFlagSet(serviceCmdName, flag.ExitOnError)
	dogecoind := fs.String("dogecoind", "", "path to dogecoind.exe (required)")
	datadir := fs.String("datadir", "", "datadir (required)")
	conf := fs.String("conf", "", "conf file (required)")
	cli := fs.String("cli", "", "path to dogecoin-cli.exe (optional; for graceful stop)")
	_ = fs.Parse(args)

	if *dogecoind == "" || *datadir == "" || *conf == "" {
		fmt.Fprintf(os.Stderr, "usage: gpenode-ops %s -dogecoind=... -datadir=... -conf=... [-cli=...]\n", serviceCmdName)
		os.Exit(2)
	}
	absD, err := filepath.Abs(*dogecoind)
	if err != nil {
		fatalf("dogecoind path: %v", err)
	}
	absData, err := filepath.Abs(*datadir)
	if err != nil {
		fatalf("datadir path: %v", err)
	}
	absConf, err := filepath.Abs(*conf)
	if err != nil {
		fatalf("conf path: %v", err)
	}
	absCLI := ""
	if *cli != "" {
		absCLI, _ = filepath.Abs(*cli)
	} else {
		cand := filepath.Join(filepath.Dir(absD), "dogecoin-cli.exe")
		if st, err := os.Stat(cand); err == nil && !st.IsDir() {
			absCLI = cand
		}
	}

	isSvc, err := svc.IsWindowsService()
	if err != nil {
		fatalf("IsWindowsService: %v", err)
	}

	h := &daemonHost{
		dogecoind: absD,
		datadir:   absData,
		conf:      absConf,
		cli:       absCLI,
	}

	if !isSvc {
		// Interactive smoke: run dogecoind in foreground until Ctrl+C / exit.
		fmt.Println("gpenode-ops service-run (console mode)")
		fmt.Println("  dogecoind:", absD)
		fmt.Println("  datadir:  ", absData)
		fmt.Println("  conf:     ", absConf)
		if err := h.runForeground(); err != nil {
			fatalf("%v", err)
		}
		return
	}

	elog, err := eventlog.Open("DogecoinGPENode")
	if err != nil {
		// Install source best-effort; Open may still fail without admin at install time.
		_ = eventlog.InstallAsEventCreate("DogecoinGPENode", eventlog.Error|eventlog.Warning|eventlog.Info)
		elog, err = eventlog.Open("DogecoinGPENode")
	}
	if err == nil {
		defer elog.Close()
		h.elog = elog
		_ = elog.Info(1, "GPENode service starting (wrapper for dogecoind)")
	}

	if err := svc.Run("DogecoinGPENode", h); err != nil {
		if elog != nil {
			_ = elog.Error(1, fmt.Sprintf("svc.Run failed: %v", err))
		}
		fatalf("svc.Run: %v", err)
	}
}

type daemonHost struct {
	dogecoind string
	datadir   string
	conf      string
	cli       string
	elog      *eventlog.Log

	mu     sync.Mutex
	cmd    *exec.Cmd
	done   chan struct{}
	exited error
}

func (h *daemonHost) logInfo(msg string) {
	if h.elog != nil {
		_ = h.elog.Info(1, msg)
	}
}

func (h *daemonHost) logErr(msg string) {
	if h.elog != nil {
		_ = h.elog.Error(1, msg)
	}
}

func (h *daemonHost) Execute(args []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (ssec bool, errno uint32) {
	const accepts = svc.AcceptStop | svc.AcceptShutdown
	changes <- svc.Status{State: svc.StartPending}

	if err := h.startDaemon(); err != nil {
		h.logErr(fmt.Sprintf("failed to start dogecoind: %v", err))
		return false, 1
	}
	h.logInfo("dogecoind started under GPENode service wrapper")
	changes <- svc.Status{State: svc.Running, Accepts: accepts}

	for {
		select {
		case <-h.done:
			// Child exited unexpectedly
			h.logErr(fmt.Sprintf("dogecoind exited: %v", h.exited))
			changes <- svc.Status{State: svc.StopPending}
			return false, 1
		case c := <-r:
			switch c.Cmd {
			case svc.Interrogate:
				changes <- c.CurrentStatus
			case svc.Stop, svc.Shutdown:
				changes <- svc.Status{State: svc.StopPending}
				h.logInfo("stop requested; stopping dogecoind")
				h.stopDaemon()
				changes <- svc.Status{State: svc.Stopped}
				return false, 0
			default:
				// ignore pause/continue etc.
			}
		}
	}
}

func (h *daemonHost) startDaemon() error {
	h.mu.Lock()
	defer h.mu.Unlock()

	cmd := exec.Command(h.dogecoind,
		"-datadir="+h.datadir,
		"-conf="+h.conf,
		"-printtoconsole=0",
	)
	// Detach from any console; service session has none.
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: 0x08000000, // CREATE_NO_WINDOW
	}
	// Keep stdout/stderr discarded (logs go to datadir debug.log).
	cmd.Stdout = nil
	cmd.Stderr = nil

	if err := cmd.Start(); err != nil {
		return err
	}
	h.cmd = cmd
	h.done = make(chan struct{})
	go func() {
		err := cmd.Wait()
		h.mu.Lock()
		h.exited = err
		h.mu.Unlock()
		close(h.done)
	}()
	return nil
}

func (h *daemonHost) stopDaemon() {
	// Prefer RPC stop so chain flushes cleanly.
	if h.cli != "" {
		stop := exec.Command(h.cli, "-datadir="+h.datadir, "-conf="+h.conf, "stop")
		stop.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
		_ = stop.Run()
		// Wait up to 60s for clean exit
		select {
		case <-h.done:
			return
		case <-time.After(60 * time.Second):
		}
	}

	h.mu.Lock()
	cmd := h.cmd
	h.mu.Unlock()
	if cmd != nil && cmd.Process != nil {
		_ = cmd.Process.Kill()
	}
	select {
	case <-h.done:
	case <-time.After(10 * time.Second):
	}
}

func (h *daemonHost) runForeground() error {
	if err := h.startDaemon(); err != nil {
		return err
	}
	<-h.done
	return h.exited
}

func fatalf(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
