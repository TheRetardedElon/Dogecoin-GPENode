// gpenode-tui - gold-dark dense operator TUI (Grok Build / mockup style).
// Localhost RPC + service control (Windows SCM or Linux systemd). NO consensus logic.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/muesli/termenv"
)

const tuiVersion = "0.5.0"

func init() {
	// Color when the terminal can do it; plain when it cannot (PuTTY/dumb/NO_COLOR).
	if os.Getenv("NO_COLOR") != "" || os.Getenv("GPENODE_NO_COLOR") != "" {
		lipgloss.SetColorProfile(termenv.Ascii)
		return
	}
	if runtime.GOOS == "windows" {
		// Windows Terminal often under-detects color; force truecolor so gold/green show.
		_ = os.Setenv("COLORTERM", "truecolor")
		if os.Getenv("TERM") == "" {
			_ = os.Setenv("TERM", "xterm-256color")
		}
		lipgloss.SetColorProfile(termenv.TrueColor)
		return
	}
	// Linux/mac: adaptive truecolor / 256 / 16 / ascii from TERM + TTY.
	lipgloss.SetColorProfile(termenv.ColorProfile())
}

// Gold-dark mockup palette
var (
	cBg      = lipgloss.Color("#0a0a0a")
	cFg      = lipgloss.Color("#f0f0f0")
	cMuted   = lipgloss.Color("#9a9a9a")
	cGold    = lipgloss.Color("#e8b923")
	cGoldDim = lipgloss.Color("#a67c00")
	cAmber   = lipgloss.Color("#ffc14d")
	cGreen   = lipgloss.Color("#3ddc84")
	cRed     = lipgloss.Color("#ff5c5c")
	cHiBg    = lipgloss.Color("#3d2e08")
	cHiFg    = lipgloss.Color("#ffe566")
	cPanel   = lipgloss.Color("#0c0c0c")
)

func main() {
	m := newModel()
	// Pointer model so View/scroll mutations persist across frames
	p := tea.NewProgram(&m, tea.WithAltScreen(), tea.WithMouseCellMotion())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "gpenode-tui: %v\n", err)
		os.Exit(1)
	}
}

type screen int

const (
	screenHome screen = iota
	screenOverview
	screenNode
	screenDump
	screenCDN
	screenLogs
	screenWallet
	screenSettings
	screenHelp
)

type focusMode int

const (
	modeBrowse focusMode = iota
	modeCommand
	modeSettingsEdit // editing a conf value at the prompt
)

type menuItem struct {
	key, title, desc string
	goTo             screen
	quit             bool
}

type actionItem struct {
	key, title, run string
}

type model struct {
	width, height int
	screen        screen
	mode          focusMode
	cursor        int
	input         string
	statusMsg     string
	tip           string
	snap          nodeSnapshot
	cdnText       string
	logText       string
	dumpText      string
	busy          bool
	errFlash      string
	menuTop       int

	// Responsive scroll (full content, windowed to terminal height - no "lines hidden")
	scroll     int
	contentLen int // total content lines last frame
	viewRows   int // visible content rows last frame
	menuOff    int // first selectable line in full content

	// Settings / dogecoin.conf
	confFile    string
	confValues  map[string]string // lower key -> value (includes dirty)
	confSaved   map[string]string // last loaded from disk
	confDirty   map[string]bool   // lower key dirty
	confEditKey string            // key being edited (canonical)
}

type refreshMsg struct{ snap nodeSnapshot }
type cdnMsg struct {
	text string
	err  error
}
type logsMsg struct{ text string }
type dumpMsg struct {
	text string
	err  error
}
type actionMsg struct {
	text string
	err  error
}
type tickMsg struct{}

var homeItems = []menuItem{
	{"O", "Overview", "Live tip  |  peers  |  dual status", screenOverview, false},
	{"N", "Node Control", "Service start/stop/restart", screenNode, false},
	{"D", "Dump", "dumptxoutset  |  snapshots", screenDump, false},
	{"C", "CDN", "latest.json pointer", screenCDN, false},
	{"L", "Logs", "debug.log tail", screenLogs, false},
	{"S", "Settings", "edit dogecoin.conf  |  save", screenSettings, false},
	{"W", "Wallet", "RPC if enabled (optional)", screenWallet, false},
	{"?", "Help", "keys & commands", screenHelp, false},
	{"Q", "Quit", "exit TUI (service keeps running)", screenHome, true},
}

func nodeActions() []actionItem {
	return []actionItem{
		{"1", "Start service", "start"},
		{"2", "Stop service", "stop"},
		{"3", "Restart service", "restart"},
		{"R", "Refresh", "refresh"},
		{"B", "Back", "back"},
	}
}

func dumpActions() []actionItem {
	return []actionItem{
		{"X", "Run dumptxoutset", "dump"},
		{"R", "Refresh list", "refresh"},
		{"B", "Back", "back"},
	}
}

func genericActions() []actionItem {
	return []actionItem{
		{"R", "Refresh", "refresh"},
		{"B", "Back", "back"},
	}
}

func settingsActions() []actionItem {
	return []actionItem{
		{"W", "Write conf to disk", "conf-save"},
		{"U", "Reload from disk", "conf-reload"},
		{"E", "Open conf in Notepad", "conf-open"},
		{"3", "Restart service (apply)", "restart"},
		{"B", "Back", "back"},
	}
}

func newModel() model {
	return model{
		screen:     screenHome,
		mode:       modeBrowse,
		tip:        "up/dn highlight  |  Enter  |  click  |  letters  |  / command  |  Q quit",
		snap:       fetchSnapshot(),
		confValues: map[string]string{},
		confSaved:  map[string]string{},
		confDirty:  map[string]bool{},
	}
}

func (m *model) Init() tea.Cmd { return tea.Batch(refreshCmd(), tickCmd()) }

func tickCmd() tea.Cmd {
	return tea.Tick(12*time.Second, func(t time.Time) tea.Msg { return tickMsg{} })
}

func refreshCmd() tea.Cmd {
	return func() tea.Msg { return refreshMsg{snap: fetchSnapshot()} }
}

func (m model) actions() []actionItem {
	switch m.screen {
	case screenNode:
		return nodeActions()
	case screenDump:
		return dumpActions()
	case screenSettings:
		return settingsActions()
	case screenHome:
		return nil
	default:
		return genericActions()
	}
}

// settingsListLen = editable keys + action rows
func (m model) settingsListLen() int {
	return len(editableConfKeys()) + len(settingsActions())
}

func (m model) maxCursor() int {
	if m.screen == screenHome {
		return len(homeItems) - 1
	}
	if m.screen == screenSettings {
		n := m.settingsListLen()
		if n == 0 {
			return 0
		}
		return n - 1
	}
	a := m.actions()
	if len(a) == 0 {
		return 0
	}
	return len(a) - 1
}

func (m *model) loadConf() {
	m.confFile = confPath()
	m.confValues = map[string]string{}
	m.confSaved = map[string]string{}
	m.confDirty = map[string]bool{}
	vals, err := loadConfMap(m.confFile)
	if err != nil {
		m.errFlash = "conf load: " + err.Error()
		// still allow creating new keys
		return
	}
	for _, ck := range editableConfKeys() {
		lk := strings.ToLower(ck.Key)
		if v, ok := vals[lk]; ok {
			m.confValues[lk] = v
			m.confSaved[lk] = v
		}
	}
}

func (m model) dirtyCount() int {
	n := 0
	for _, d := range m.confDirty {
		if d {
			n++
		}
	}
	return n
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.clampScroll()
		return m, nil
	case refreshMsg:
		m.snap, m.busy = msg.snap, false
		return m, nil
	case cdnMsg:
		m.busy = false
		if msg.err != nil {
			m.cdnText, m.errFlash = "CDN fetch failed: "+msg.err.Error(), msg.err.Error()
		} else {
			m.cdnText, m.statusMsg = msg.text, "CDN refreshed"
		}
		return m, nil
	case logsMsg:
		m.busy, m.logText = false, msg.text
		return m, nil
	case dumpMsg:
		m.busy = false
		if msg.err != nil {
			m.dumpText, m.errFlash = msg.text+"\n"+msg.err.Error(), "dump failed"
		} else {
			m.dumpText, m.statusMsg = msg.text, "ok"
		}
		return m, nil
	case actionMsg:
		m.busy = false
		if msg.err != nil {
			m.errFlash = msg.err.Error()
			m.statusMsg = strings.TrimSpace(msg.text + " " + msg.err.Error())
		} else {
			m.statusMsg = strings.TrimSpace(msg.text)
			if m.statusMsg == "" {
				m.statusMsg = "ok"
			}
		}
		return m, refreshCmd()
	case tickMsg:
		cmds := []tea.Cmd{tickCmd()}
		if m.screen == screenHome || m.screen == screenOverview || m.screen == screenNode {
			cmds = append(cmds, refreshCmd())
		}
		return m, tea.Batch(cmds...)
	case tea.MouseMsg:
		return m.handleMouse(msg)
	case tea.KeyMsg:
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
		if m.mode == modeCommand || m.mode == modeSettingsEdit {
			return m.handleCommandKeys(msg)
		}
		return m.handleBrowseKeys(msg)
	}
	return m, nil
}

func (m *model) handleCommandKeys(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.Type {
	case tea.KeyEsc:
		m.mode, m.input, m.confEditKey = modeBrowse, "", ""
		if m.screen == screenSettings {
			m.tip = "Settings  |  Enter edit  |  W write  |  U reload  |  3 restart  |  B back"
		} else {
			m.tip = "up/dn highlight  |  Enter  |  click  |  / command  |  Q quit"
		}
		return m, nil
	case tea.KeyEnter:
		if m.mode == modeSettingsEdit {
			return m.commitSettingsEdit()
		}
		cmd := strings.TrimSpace(m.input)
		m.input, m.mode = "", modeBrowse
		return m.handleCommand(cmd)
	case tea.KeyBackspace:
		if len(m.input) > 0 {
			m.input = m.input[:len(m.input)-1]
		}
		return m, nil
	case tea.KeyRunes:
		m.input += string(msg.Runes)
		return m, nil
	case tea.KeySpace:
		m.input += " "
		return m, nil
	}
	return m, nil
}

func (m *model) commitSettingsEdit() (tea.Model, tea.Cmd) {
	key := m.confEditKey
	val := strings.TrimSpace(m.input)
	m.input, m.mode, m.confEditKey = "", modeBrowse, ""
	if key == "" {
		return m, nil
	}
	var ck confKey
	for _, c := range editableConfKeys() {
		if strings.EqualFold(c.Key, key) {
			ck = c
			break
		}
	}
	if ck.Validate != nil {
		if err := ck.Validate(val); err != nil {
			m.errFlash = ck.Key + ": " + err.Error()
			m.tip = "Settings  |  fix value and try again"
			return m, nil
		}
	}
	lk := strings.ToLower(ck.Key)
	if m.confValues == nil {
		m.confValues = map[string]string{}
	}
	if m.confDirty == nil {
		m.confDirty = map[string]bool{}
	}
	m.confValues[lk] = val
	saved := m.confSaved[lk]
	m.confDirty[lk] = val != saved
	m.errFlash = ""
	m.statusMsg = fmt.Sprintf("staged %s (not on disk until Write)", ck.Key)
	if ck.Restart {
		m.statusMsg += "  |  restart needed after Write"
	}
	m.tip = "Settings  |  W write conf  |  3 restart service  |  Enter edit"
	return m, nil
}

func (m *model) handleBrowseKeys(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "/", ":":
		m.mode, m.input = modeCommand, ""
		m.tip = "Command mode - Enter run  |  Esc cancel"
		return m, nil
	case "up", "k":
		if m.cursor > 0 {
			m.cursor--
		}
		m.ensureCursorVisible()
		return m, nil
	case "down", "j":
		if m.cursor < m.maxCursor() {
			m.cursor++
		}
		m.ensureCursorVisible()
		return m, nil
	case "pgup", "ctrl+u":
		m.scroll -= max(1, m.viewRows-2)
		m.clampScroll()
		return m, nil
	case "pgdown", "ctrl+d":
		m.scroll += max(1, m.viewRows-2)
		m.clampScroll()
		return m, nil
	case "home":
		if m.screen != screenHome {
			m.scroll = 0
			return m, nil
		}
	case "end":
		m.scroll = 1 << 20
		m.clampScroll()
		return m, nil
	case "enter", " ":
		return m.activateSelection()
	case "esc", "b":
		if m.screen != screenHome {
			m.screen, m.cursor = screenHome, 0
			m.tip = "up/dn highlight  |  Enter  |  click  |  / command  |  Q quit"
			return m, nil
		}
	case "q":
		return m, tea.Quit
	case "o":
		return m.goScreen(screenOverview)
	case "n":
		return m.goScreen(screenNode)
	case "d":
		return m.goScreen(screenDump)
	case "c":
		return m.goScreen(screenCDN)
	case "l":
		return m.goScreen(screenLogs)
	case "s":
		return m.goScreen(screenSettings)
	case "w":
		if m.screen == screenSettings {
			return m.runAction("conf-save")
		}
		return m.goScreen(screenWallet)
	case "u":
		if m.screen == screenSettings {
			return m.runAction("conf-reload")
		}
	case "e":
		if m.screen == screenSettings {
			return m.runAction("conf-open")
		}
	case "?", "h":
		return m.goScreen(screenHelp)
	case "r":
		m.busy, m.statusMsg = true, "refreshing..."
		return m, m.refreshScreenCmd()
	case "1", "2", "3", "x":
		return m.hotkeyAction(msg.String())
	}
	return m, nil
}

func (m *model) hotkeyAction(k string) (tea.Model, tea.Cmd) {
	if m.screen == screenSettings {
		// action keys are after conf rows
		off := len(editableConfKeys())
		for i, a := range settingsActions() {
			if strings.EqualFold(a.key, k) {
				m.cursor = off + i
				return m.activateSelection()
			}
		}
		return m, nil
	}
	for i, a := range m.actions() {
		if strings.EqualFold(a.key, k) {
			m.cursor = i
			return m.activateSelection()
		}
	}
	return m, nil
}

func (m *model) activateSelection() (tea.Model, tea.Cmd) {
	if m.screen == screenHome {
		it := homeItems[m.cursor]
		if it.quit {
			return m, tea.Quit
		}
		return m.goScreen(it.goTo)
	}
	if m.screen == screenSettings {
		keys := editableConfKeys()
		if m.cursor < len(keys) {
			// begin edit
			ck := keys[m.cursor]
			lk := strings.ToLower(ck.Key)
			m.confEditKey = ck.Key
			m.input = m.confValues[lk]
			m.mode = modeSettingsEdit
			m.tip = fmt.Sprintf("Edit %s - type value  |  Enter stage  |  Esc cancel", ck.Key)
			m.statusMsg = ck.Help
			if ck.Restart {
				m.statusMsg += " (restart after Write)"
			}
			return m, nil
		}
		ai := m.cursor - len(keys)
		acts := settingsActions()
		if ai >= 0 && ai < len(acts) {
			return m.runAction(acts[ai].run)
		}
		return m, nil
	}
	acts := m.actions()
	if m.cursor < 0 || m.cursor >= len(acts) {
		return m, nil
	}
	return m.runAction(acts[m.cursor].run)
}

func (m *model) runAction(id string) (tea.Model, tea.Cmd) {
	switch id {
	case "back":
		m.screen, m.cursor = screenHome, 0
		m.mode = modeBrowse
		m.tip = "up/dn highlight  |  Enter  |  click  |  / command  |  Q quit"
		return m, nil
	case "refresh":
		m.busy, m.statusMsg = true, "refreshing..."
		return m, m.refreshScreenCmd()
	case "start", "stop", "restart":
		m.busy, m.statusMsg = true, id+"..."
		return m, func() tea.Msg {
			out, err := serviceAction(id)
			return actionMsg{text: out, err: err}
		}
	case "dump":
		m.busy, m.statusMsg = true, "dumptxoutset running (can take a long time)..."
		return m, func() tea.Msg {
			text, err := runDumpNative()
			return dumpMsg{text: text, err: err}
		}
	case "conf-reload":
		m.loadConf()
		m.statusMsg = "reloaded " + m.confFile
		m.errFlash = ""
		return m, nil
	case "conf-open":
		path := confPath()
		if runtimeGOOSWindows() {
			_ = execCommandStart("notepad.exe", path)
		}
		m.statusMsg = "opened " + path
		return m, nil
	case "conf-save":
		return m.saveConf()
	}
	return m, nil
}

func runtimeGOOSWindows() bool {
	return strings.Contains(strings.ToLower(os.Getenv("OS")), "windows") ||
		fileExists(`C:\Windows\System32\notepad.exe`)
}

func execCommandStart(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	return cmd.Start()
}

func (m *model) saveConf() (tea.Model, tea.Cmd) {
	if m.dirtyCount() == 0 {
		m.statusMsg = "no staged changes - edit a value first (Enter on a row)"
		return m, nil
	}
	updates := map[string]string{}
	needsRestart := false
	for _, ck := range editableConfKeys() {
		lk := strings.ToLower(ck.Key)
		if m.confDirty[lk] {
			updates[ck.Key] = m.confValues[lk]
			if ck.Restart {
				needsRestart = true
			}
		}
	}
	path := confPath()
	if err := writeConfUpdates(path, updates); err != nil {
		m.errFlash = "write failed: " + err.Error()
		return m, nil
	}
	// refresh saved baseline
	m.loadConf()
	m.errFlash = ""
	m.statusMsg = fmt.Sprintf("wrote %d key(s) -> %s", len(updates), path)
	if needsRestart {
		m.statusMsg += "  |  restart service to apply"
	}
	return m, nil
}

func (m *model) handleMouse(msg tea.MouseMsg) (tea.Model, tea.Cmd) {
	// Wheel scroll
	if msg.Action == tea.MouseActionPress {
		switch msg.Button {
		case tea.MouseButtonWheelUp:
			m.scroll--
			m.clampScroll()
			return m, nil
		case tea.MouseButtonWheelDown:
			m.scroll++
			m.clampScroll()
			return m, nil
		}
	}
	if msg.Action != tea.MouseActionPress || msg.Button != tea.MouseButtonLeft {
		return m, nil
	}
	if m.menuTop <= 0 {
		return m, nil
	}
	// Relative to first menu row on screen
	relVis := msg.Y - m.menuTop
	if relVis < 0 {
		return m, nil
	}
	// Map click to cursor index accounting for scroll vs menu base line
	idx := relVis
	if m.menuOff >= m.scroll {
		// menu starts below top of window
		idx = relVis - (m.menuOff - m.scroll)
	} else {
		// menu partially scrolled off top
		idx = relVis + (m.scroll - m.menuOff)
	}
	if idx < 0 {
		return m, nil
	}
	if m.screen == screenHome {
		if idx < len(homeItems) {
			m.cursor = idx
			return m.activateSelection()
		}
		return m, nil
	}
	if m.screen == screenSettings {
		if idx < m.settingsListLen() {
			m.cursor = idx
			return m.activateSelection()
		}
		return m, nil
	}
	acts := m.actions()
	if idx < len(acts) {
		m.cursor = idx
		return m.activateSelection()
	}
	return m, nil
}

func (m *model) clampScroll() {
	maxScroll := m.contentLen - m.viewRows
	if maxScroll < 0 {
		maxScroll = 0
	}
	if m.scroll < 0 {
		m.scroll = 0
	}
	if m.scroll > maxScroll {
		m.scroll = maxScroll
	}
}

// ensureCursorVisible scrolls so the highlighted row stays in the panel window.
func (m *model) ensureCursorVisible() {
	line := m.cursorLine()
	if m.viewRows <= 0 {
		return
	}
	if line < m.scroll {
		m.scroll = line
	}
	if line >= m.scroll+m.viewRows {
		m.scroll = line - m.viewRows + 1
	}
	m.clampScroll()
}

func (m model) cursorLine() int {
	// Absolute content line of selection
	switch m.screen {
	case screenHome:
		return m.menuOff + m.cursor
	case screenSettings:
		keys := len(editableConfKeys())
		if m.cursor < keys {
			return m.menuOff + m.cursor
		}
		// keys, then rule line, then actions
		return m.menuOff + keys + 1 + (m.cursor - keys)
	default:
		return m.menuOff + m.cursor
	}
}

func (m *model) handleCommand(cmd string) (tea.Model, tea.Cmd) {
	if cmd == "" {
		return m, nil
	}
	parts := strings.Fields(strings.ToLower(cmd))
	switch parts[0] {
	case "q", "quit", "exit":
		return m, tea.Quit
	case "?", "help":
		return m.goScreen(screenHelp)
	case "home", "menu":
		m.screen, m.cursor = screenHome, 0
		return m, nil
	case "o", "overview":
		return m.goScreen(screenOverview)
	case "n", "node":
		return m.goScreen(screenNode)
	case "d", "dump":
		return m.goScreen(screenDump)
	case "c", "cdn":
		return m.goScreen(screenCDN)
	case "l", "logs", "log":
		return m.goScreen(screenLogs)
	case "s", "settings":
		return m.goScreen(screenSettings)
	case "w", "wallet":
		return m.goScreen(screenWallet)
	case "r", "refresh":
		m.busy = true
		return m, m.refreshScreenCmd()
	case "service":
		if len(parts) < 2 {
			m.statusMsg = "usage: service start|stop|restart"
			return m, nil
		}
		return m, func() tea.Msg {
			out, err := serviceAction(parts[1])
			return actionMsg{text: out, err: err}
		}
	case "start", "stop", "restart":
		return m, func() tea.Msg {
			out, err := serviceAction(parts[0])
			return actionMsg{text: out, err: err}
		}
	default:
		m.statusMsg = "unknown: " + cmd
		return m, nil
	}
}

func (m *model) refreshScreenCmd() tea.Cmd {
	switch m.screen {
	case screenCDN:
		return func() tea.Msg {
			t, err := fetchCDN("")
			return cdnMsg{text: t, err: err}
		}
	case screenLogs:
		return func() tea.Msg { return logsMsg{text: tailDebugLog(28)} }
	case screenDump:
		return func() tea.Msg {
			return dumpMsg{text: listSnapshots() + "\ndumptxoutset: " + m.snap.DumpRPC}
		}
	default:
		return refreshCmd()
	}
}

func (m *model) goScreen(s screen) (tea.Model, tea.Cmd) {
	m.screen, m.cursor, m.errFlash, m.mode, m.scroll = s, 0, "", modeBrowse, 0
	switch s {
	case screenOverview:
		m.tip = "Overview - dual status  |  up/dn actions  |  B back"
		m.busy = true
		return m, refreshCmd()
	case screenNode:
		m.tip = "Node Control - up/dn  |  Enter run  |  may need Admin"
		m.busy = true
		return m, refreshCmd()
	case screenDump:
		m.tip = "Dump - prefer SYNCED before multi-GB  |  X run"
		m.busy = true
		return m, func() tea.Msg {
			return dumpMsg{text: listSnapshots() + "\ndumptxoutset: " + m.snap.DumpRPC}
		}
	case screenCDN:
		m.tip = "CDN - static latest.json (dumb pipe)"
		m.busy = true
		return m, func() tea.Msg {
			t, err := fetchCDN("")
			return cdnMsg{text: t, err: err}
		}
	case screenLogs:
		m.tip = "Logs - debug.log tail  |  R refresh"
		m.busy = true
		return m, func() tea.Msg { return logsMsg{text: tailDebugLog(28)} }
	case screenSettings:
		m.loadConf()
		m.tip = "Settings  |  Enter edit  |  W write  |  U reload  |  E notepad  |  3 restart  |  B back"
		m.busy = false
		return m, refreshCmd()
	case screenWallet:
		m.tip = "Wallet optional - dump nodes often disablewallet=1 (expected)"
		m.busy = true
		return m, refreshCmd()
	case screenHelp:
		m.tip = "Help  |  B back  |  Q quit"
		return m, nil
	default:
		m.tip = "up/dn highlight  |  Enter  |  click  |  / command  |  Q quit"
		return m, nil
	}
}

// ===================== VIEW =====================

func (m *model) View() string {
	if m.width == 0 {
		return "..."
	}

	// Stretch with terminal: use almost full width (leave small margin)
	panelW := m.width - 4
	if panelW < 50 {
		panelW = max(40, m.width-2)
	}

	// Chrome: cwd, blanks, tip(+msgs), input(~3), footer, scroll hint
	tipLines := 1
	if m.statusMsg != "" {
		tipLines++
	}
	if m.errFlash != "" {
		tipLines++
	}
	if m.busy {
		tipLines++
	}
	chrome := 2 + 1 + tipLines + 1 + 3 + 1 + 1 // header/blank/tip/blank/input/footer/margin
	if m.contentLen > 0 && m.contentLen > m.viewRows {
		chrome++ // scroll hint line
	}
	maxPanelH := m.height - chrome
	if maxPanelH < 12 {
		maxPanelH = max(8, m.height-6)
	}

	cwd, _ := os.Getwd()
	header := lipgloss.NewStyle().Foreground(cMuted).Render(cwd)

	panel, menuOff := m.renderPanel(panelW, maxPanelH)
	m.menuOff = menuOff
	// Horizontal: fill width when large; slight center only if we wanted - stretch full
	outer := lipgloss.NewStyle().Width(m.width - 2).Align(lipgloss.Center).Render(panel)

	// First menu row screen Y when scrolled to show it
	// panel starts at row ~2 (header+blank); content pad +1 border
	panelStart := 2
	contentStart := panelStart + 1 // border
	// menu row 0 is at content line menuOff; on screen at contentStart + (menuOff - scroll)
	m.menuTop = contentStart + (menuOff - m.scroll) + 1 // + pad inside border approx

	tip := lipgloss.NewStyle().Foreground(cMuted).Width(panelW).Align(lipgloss.Center).Render(m.tip)
	if m.statusMsg != "" {
		tip += "\n" + lipgloss.NewStyle().Foreground(cAmber).Width(panelW).Align(lipgloss.Center).Render(m.statusMsg)
	}
	if m.errFlash != "" {
		tip += "\n" + lipgloss.NewStyle().Foreground(cRed).Width(panelW).Align(lipgloss.Center).Render(m.errFlash)
	}
	if m.busy {
		tip += "\n" + lipgloss.NewStyle().Foreground(cMuted).Width(panelW).Align(lipgloss.Center).Render("...working")
	}

	scrollHint := ""
	if m.contentLen > m.viewRows && m.viewRows > 0 {
		scrollHint = lipgloss.NewStyle().Foreground(cGoldDim).Width(panelW).Align(lipgloss.Center).Render(
			fmt.Sprintf("scroll %d-%d / %d   |   PgUp/PgDn   |   mouse wheel", m.scroll+1, min(m.scroll+m.viewRows, m.contentLen), m.contentLen),
		)
	}

	input := m.renderInput(panelW)
	footer := lipgloss.NewStyle().Foreground(cMuted).Width(panelW).Align(lipgloss.Center).Render(m.footerRight())

	parts := []string{
		lipgloss.NewStyle().Width(m.width-2).Align(lipgloss.Left).Foreground(cMuted).Render(header),
		"",
		outer,
		"",
		lipgloss.NewStyle().Width(m.width-2).Align(lipgloss.Center).Render(tip),
	}
	if scrollHint != "" {
		parts = append(parts, lipgloss.NewStyle().Width(m.width-2).Align(lipgloss.Center).Render(scrollHint))
	}
	parts = append(parts, "",
		lipgloss.NewStyle().Width(m.width-2).Align(lipgloss.Center).Render(input),
		footer,
	)

	body := lipgloss.JoinVertical(lipgloss.Left, parts...)

	return lipgloss.NewStyle().
		Width(m.width).
		Height(m.height).
		AlignVertical(lipgloss.Top).
		Background(cBg).
		Foreground(cFg).
		Padding(0, 1).
		Render(body)
}

func (m model) footerRight() string {
	phase := m.snap.Phase
	if phase == "" {
		phase = "..."
	}
	// TUI version !=  daemon version - show both
	daemon := shortDaemonVer(m.snap.Version)
	if daemon == "" {
		daemon = "daemon?"
	}
	return fmt.Sprintf("TUI %s  |  %s  |  %s  |  svc %s", tuiVersion, daemon, phase, m.snap.Service)
}

// shortDaemonVer: "Dogecoin Core Daemon version v1.14.102.0-g2c5..." -> "v1.14.102.0"
func shortDaemonVer(full string) string {
	full = strings.TrimSpace(full)
	if full == "" {
		return ""
	}
	// prefer token starting with v and a digit
	for _, tok := range strings.Fields(full) {
		if strings.HasPrefix(tok, "v") && len(tok) > 2 && tok[1] >= '0' && tok[1] <= '9' {
			// strip build metadata after second hyphen cluster if needed: v1.14.102.0-ghash
			if i := strings.Index(tok, "-g"); i > 0 {
				return tok[:i]
			}
			if i := strings.Index(tok, "-dirty"); i > 0 {
				return tok[:i]
			}
			return tok
		}
	}
	return truncate(full, 24)
}

// productSubtitle uses live daemon version (not a hardcoded marketing string).
func (m model) productSubtitle() string {
	v := shortDaemonVer(m.snap.Version)
	if v == "" {
		return "Core Pro Headless"
	}
	return "Core Pro Headless " + v
}

func (m model) renderInput(w int) string {
	boxW := min(w, 90)
	prompt := lipgloss.NewStyle().Foreground(cGold).Render(">")
	if m.mode == modeCommand {
		prompt = lipgloss.NewStyle().Foreground(cGold).Bold(true).Render(":")
	}
	if m.mode == modeSettingsEdit {
		prompt = lipgloss.NewStyle().Foreground(cGold).Bold(true).Render(m.confEditKey + "=")
	}
	inner := prompt + " "
	switch m.mode {
	case modeCommand, modeSettingsEdit:
		inner += m.input + "#"
	default:
		if m.screen == screenSettings {
			inner += lipgloss.NewStyle().Foreground(cMuted).Render("Enter edit  |  W write  |  U reload  |  3 restart")
		} else {
			inner += lipgloss.NewStyle().Foreground(cMuted).Render("up/dn navigate  |  Enter select  |  / command")
		}
	}
	return lipgloss.NewStyle().
		Border(asciiBorder()).
		BorderForeground(cGold).
		Padding(0, 1).
		Width(boxW).
		Render(inner)
}

func (m *model) renderPanel(w, maxH int) (string, int) {
	// border + vertical padding eat ~4 rows of the panel height budget
	innerMax := maxH - 4
	if innerMax < 6 {
		innerMax = 6
	}

	innerW := w - 6
	var content string
	var menuOff int
	switch m.screen {
	case screenHome:
		content, menuOff = m.viewHome(innerW)
	case screenOverview:
		content, menuOff = m.viewOverview(innerW)
	case screenNode:
		content, menuOff = m.viewNode(innerW)
	case screenDump:
		content, menuOff = m.viewDump(innerW)
	case screenCDN:
		content, menuOff = m.viewCDN(innerW)
	case screenLogs:
		content, menuOff = m.viewLogs(innerW)
	case screenSettings:
		content, menuOff = m.viewSettings(innerW)
	case screenWallet:
		content, menuOff = m.viewWallet(innerW)
	case screenHelp:
		content, menuOff = m.viewHelp(innerW)
	}

	lines := strings.Split(content, "\n")
	m.contentLen = len(lines)
	m.viewRows = innerMax
	m.clampScroll()
	// Keep selection in view after content length known
	m.ensureCursorVisible()

	// Window the content - full list remains reachable via scroll (no permanent hide)
	end := m.scroll + innerMax
	if end > len(lines) {
		end = len(lines)
	}
	if m.scroll > end {
		m.scroll = 0
		end = min(innerMax, len(lines))
	}
	window := lines[m.scroll:end]
	// Subtle edge markers inside panel
	if m.scroll > 0 && len(window) > 0 {
		window[0] = lipgloss.NewStyle().Foreground(cGoldDim).Render("  ^  (more above)")
	}
	if end < len(lines) && len(window) > 0 {
		window[len(window)-1] = lipgloss.NewStyle().Foreground(cGoldDim).Render("  v  (more below)")
	}
	content = strings.Join(window, "\n")

	style := lipgloss.NewStyle().
		Border(asciiBorder()).
		BorderForeground(cGold).
		Padding(1, 2).
		Width(w).
		Height(maxH).
		AlignVertical(lipgloss.Top).
		Background(cPanel)

	return style.Render(content), menuOff
}

func gold(s string) string {
	return lipgloss.NewStyle().Foreground(cGold).Bold(true).Render(s)
}
func muted(s string) string {
	return lipgloss.NewStyle().Foreground(cMuted).Render(s)
}
func white(s string) string {
	return lipgloss.NewStyle().Foreground(cFg).Render(s)
}
func rule(w int) string {
	if w < 8 {
		w = 8
	}
	return lipgloss.NewStyle().Foreground(cGoldDim).Render(strings.Repeat("-", w))
}

func titleBlock(w int, product, section, sub string) string {
	t1 := lipgloss.NewStyle().Foreground(cFg).Bold(true).Width(w).Align(lipgloss.Center).Render(product)
	t2 := lipgloss.NewStyle().Foreground(cGold).Bold(true).Width(w).Align(lipgloss.Center).Render(section)
	t3 := lipgloss.NewStyle().Foreground(cMuted).Width(w).Align(lipgloss.Center).Render(sub)
	return t1 + "\n" + t2 + "\n" + t3 + "\n" + rule(w)
}

func hi(selected bool, w int, text string) string {
	if selected {
		return lipgloss.NewStyle().
			Background(cHiBg).
			Foreground(cHiFg).
			Bold(true).
			Width(w).
			Render(" > " + text)
	}
	return lipgloss.NewStyle().Foreground(cFg).Width(w).Render("   " + text)
}

func colorPhase(p string) string {
	switch p {
	case "SYNCED":
		return lipgloss.NewStyle().Foreground(cGreen).Bold(true).Render(p)
	case "IBD", "INIT":
		return lipgloss.NewStyle().Foreground(cAmber).Bold(true).Render(p)
	case "OFFLINE":
		return lipgloss.NewStyle().Foreground(cRed).Bold(true).Render(p)
	default:
		return p
	}
}

func colorSvc(s string) string {
	switch s {
	case "RUNNING":
		return lipgloss.NewStyle().Foreground(cGreen).Bold(true).Render(s)
	case "STOPPED", "NOT_INSTALLED":
		return lipgloss.NewStyle().Foreground(cRed).Bold(true).Render(s)
	default:
		return lipgloss.NewStyle().Foreground(cAmber).Render(s)
	}
}

func nz(s, d string) string {
	if s == "" {
		return d
	}
	return s
}

func pct(progress, blocks, headers string) string {
	if p, err := strconv.ParseFloat(progress, 64); err == nil && p > 0 {
		return fmt.Sprintf("%.1f%%", p*100)
	}
	b, _ := strconv.ParseFloat(blocks, 64)
	h, _ := strconv.ParseFloat(headers, 64)
	if h > 0 && b > 0 {
		return fmt.Sprintf("%.1f%%", (b/h)*100)
	}
	return "-"
}

func kvLine(labelW int, label, value string) string {
	return fmt.Sprintf("%s %s",
		lipgloss.NewStyle().Foreground(cMuted).Width(labelW).Render(label),
		value)
}

func countLines(s string) int {
	if s == "" {
		return 0
	}
	return strings.Count(s, "\n")
}

func actionBlock(m model, w int, acts []actionItem) (string, int) {
	var b strings.Builder
	b.WriteString(rule(w))
	b.WriteString("\n")
	// footer action bar style when few items - still vertical for arrow nav
	start := countLines(b.String())
	for i, a := range acts {
		b.WriteString(hi(i == m.cursor, w, fmt.Sprintf("[%s]  %s", a.key, a.title)))
		b.WriteString("\n")
	}
	return b.String(), start
}

// ---- screens ----

func (m model) viewHome(w int) (string, int) {
	var b strings.Builder
	b.WriteString(titleBlock(w, "Dogecoin GPENode", m.productSubtitle(), "same mainnet consensus  |  localhost RPC  |  no Qt"))
	b.WriteString("\n\n")

	// dense status strip
	strip := fmt.Sprintf("  phase %s   service %s   blocks %s/%s   peers %s   dump %s",
		colorPhase(m.snap.Phase),
		colorSvc(m.snap.Service),
		nz(m.snap.Blocks, "-"),
		nz(m.snap.Headers, "-"),
		nz(m.snap.Connections, "-"),
		nz(m.snap.DumpRPC, "-"),
	)
	b.WriteString(strip)
	b.WriteString("\n\n")
	b.WriteString(rule(w))
	b.WriteString("\n")

	menuOff := countLines(b.String())
	for i, it := range homeItems {
		// two-column feel: key+title left, desc muted right
		left := fmt.Sprintf("[%s]  %-14s", it.key, it.title)
		row := left + "  " + muted(it.desc)
		b.WriteString(hi(i == m.cursor, w, row))
		b.WriteString("\n")
	}
	return b.String(), menuOff
}

func (m model) viewOverview(w int) (string, int) {
	s := m.snap
	var b strings.Builder
	b.WriteString(titleBlock(w, "Dogecoin GPENode", "Overview", "live chain + service (operator home)"))
	b.WriteString("\n\n")

	// Dual column like mockup Transactions & Node
	leftW := w/2 - 2
	if leftW < 28 {
		leftW = w
	}
	rightW := w - leftW - 3
	if rightW < 20 {
		// stack
		b.WriteString(gold("  NODE"))
		b.WriteString("\n")
		b.WriteString(kvLine(14, "  Phase", colorPhase(s.Phase)) + "\n")
		b.WriteString(kvLine(14, "  Service", colorSvc(s.Service)) + "\n")
		b.WriteString(kvLine(14, "  Blocks", fmt.Sprintf("%s / %s (%s)", nz(s.Blocks, "-"), nz(s.Headers, "-"), pct(s.Progress, s.Blocks, s.Headers))) + "\n")
		b.WriteString(kvLine(14, "  Peers", nz(s.Connections, "-")) + "\n")
		b.WriteString(kvLine(14, "  Dump RPC", nz(s.DumpRPC, "-")) + "\n")
		b.WriteString(kvLine(14, "  Chain", nz(s.Chain, "main")) + "\n")
	} else {
		var left, right strings.Builder
		left.WriteString(gold("CHAIN / SYNC") + "\n")
		left.WriteString(kvLine(12, "Phase", colorPhase(s.Phase)) + "\n")
		left.WriteString(kvLine(12, "Blocks", nz(s.Blocks, "-")) + "\n")
		left.WriteString(kvLine(12, "Headers", nz(s.Headers, "-")) + "\n")
		left.WriteString(kvLine(12, "Progress", pct(s.Progress, s.Blocks, s.Headers)) + "\n")
		left.WriteString(kvLine(12, "IBD", nz(s.IBD, "-")) + "\n")
		left.WriteString(kvLine(12, "Chain", nz(s.Chain, "main")) + "\n")

		right.WriteString(gold("NODE STATUS") + "\n")
		right.WriteString(kvLine(12, "Service", colorSvc(s.Service)+" (headless)") + "\n")
		right.WriteString(kvLine(12, "Peers", nz(s.Connections, "-")) + "\n")
		right.WriteString(kvLine(12, "Dump RPC", nz(s.DumpRPC, "-")) + "\n")
		right.WriteString(kvLine(12, "Network", truncate(nz(s.Network, "mainnet"), rightW-14)) + "\n")
		if s.WalletOn {
			right.WriteString(kvLine(12, "Balance", gold(s.Balance+" DOGE")) + "\n")
		} else {
			right.WriteString(kvLine(12, "Wallet", muted("disabled (dump profile)")) + "\n")
		}

		colL := lipgloss.NewStyle().Width(leftW).Render(left.String())
		div := lipgloss.NewStyle().Foreground(cGoldDim).Render(" | ")
		colR := lipgloss.NewStyle().Width(rightW).Render(right.String())
		b.WriteString(lipgloss.JoinHorizontal(lipgloss.Top, colL, div, colR))
		b.WriteString("\n")
	}

	if s.Message != "" {
		b.WriteString("\n")
		b.WriteString(lipgloss.NewStyle().Foreground(cAmber).Render("  " + s.Message))
		b.WriteString("\n")
	}
	b.WriteString("\n")
	b.WriteString(muted("  " + truncate(s.Version, w-4)))
	b.WriteString("\n")
	b.WriteString(muted("  datadir " + s.DataDir))
	b.WriteString("\n\n")

	ab, off := actionBlock(m, w, genericActions())
	// off is relative to ab; menu absolute offset = lines before actions
	before := countLines(b.String())
	b.WriteString(ab)
	return b.String(), before + off
}

func (m model) viewNode(w int) (string, int) {
	s := m.snap
	var b strings.Builder
	svcHint := "Windows service  |  gpenode-ops  |  dogecoind"
	if runtime.GOOS != "windows" {
		svcHint = "systemd  |  dogecoin-gpenode.service  |  dogecoind"
	}
	b.WriteString(titleBlock(w, "Dogecoin GPENode", "Node Control", svcHint))
	b.WriteString("\n\n")

	// Dense status block (mockup-style)
	rows := []struct{ k, v string }{
		{"Service", activeServiceName()},
		{"State", colorSvc(s.Service) + " (headless)"},
		{"Phase", colorPhase(s.Phase)},
		{"Daemon", gold(nz(shortDaemonVer(s.Version), "-"))},
		{"Blocks", fmt.Sprintf("%s / %s  (%s)", nz(s.Blocks, "-"), nz(s.Headers, "-"), pct(s.Progress, s.Blocks, s.Headers))},
		{"Connections", nz(s.Connections, "-")},
		{"P2P UA", truncate(nz(s.Network, "-"), w-20)}, // bip14 subversion e.g. /Shibetoshi:1.15.2/
		{"Dump RPC", nz(s.DumpRPC, "-")},
		{"CLI", truncate(s.CLI, w-20)},
		{"Data Dir", truncate(s.DataDir, w-20)},
	}
	for _, r := range rows {
		b.WriteString(kvLine(14, "  "+r.k, r.v))
		b.WriteString("\n")
	}
	b.WriteString("\n")
	if runtime.GOOS == "windows" {
		b.WriteString(muted("  dogecoind is supervised by gpenode-ops service-run (not a native SCM binary)."))
		b.WriteString("\n")
		b.WriteString(muted("  Start/stop may require Administrator elevation."))
	} else {
		b.WriteString(muted("  dogecoind runs under systemd unit dogecoin-gpenode.service."))
		b.WriteString("\n")
		b.WriteString(muted("  Start/stop may require sudo (polkit/password)."))
	}
	b.WriteString("\n\n")

	before := countLines(b.String())
	ab, off := actionBlock(m, w, nodeActions())
	b.WriteString(ab)
	return b.String(), before + off
}

func (m model) viewDump(w int) (string, int) {
	var b strings.Builder
	b.WriteString(titleBlock(w, "Dogecoin GPENode", "UTXO Dump / Fast Sync", "producer path  |  clients fail-closed on hash"))
	b.WriteString("\n\n")
	b.WriteString(kvLine(16, "  dumptxoutset", nz(m.snap.DumpRPC, "-")) + "\n")
	b.WriteString(kvLine(16, "  phase", colorPhase(m.snap.Phase)) + "\n")
	b.WriteString(kvLine(16, "  blocks", fmt.Sprintf("%s / %s", nz(m.snap.Blocks, "-"), nz(m.snap.Headers, "-"))) + "\n")
	b.WriteString("\n")
	body := m.dumpText
	if body == "" {
		body = listSnapshots()
	}
	b.WriteString(lipgloss.NewStyle().Foreground(cFg).Render(body))
	b.WriteString("\n\n")
	before := countLines(b.String())
	ab, off := actionBlock(m, w, dumpActions())
	b.WriteString(ab)
	return b.String(), before + off
}

func (m model) viewCDN(w int) (string, int) {
	var b strings.Builder
	b.WriteString(titleBlock(w, "Dogecoin GPENode", "CDN Pointer", "static latest.json only - dumb pipe"))
	b.WriteString("\n\n")
	if m.cdnText == "" {
		b.WriteString(muted("  (select Refresh)"))
	} else {
		b.WriteString(m.cdnText)
	}
	b.WriteString("\n\n")
	before := countLines(b.String())
	ab, off := actionBlock(m, w, genericActions())
	b.WriteString(ab)
	return b.String(), before + off
}

func (m model) viewLogs(w int) (string, int) {
	var b strings.Builder
	b.WriteString(titleBlock(w, "Dogecoin GPENode", "Logs", "debug.log tail"))
	b.WriteString("\n")
	text := m.logText
	if text == "" {
		text = "(empty - Refresh)"
	}
	lines := strings.Split(text, "\n")
	if len(lines) > 16 {
		lines = lines[len(lines)-16:]
	}
	b.WriteString(lipgloss.NewStyle().Foreground(cMuted).Render(strings.Join(lines, "\n")))
	b.WriteString("\n\n")
	before := countLines(b.String())
	ab, off := actionBlock(m, w, genericActions())
	b.WriteString(ab)
	return b.String(), before + off
}

func (m model) viewSettings(w int) (string, int) {
	var b strings.Builder
	sub := "edit dogecoin.conf  |  Write stages to disk  |  restart applies"
	if m.dirtyCount() > 0 {
		sub = fmt.Sprintf("%d unsaved change(s)  |  W to write", m.dirtyCount())
	}
	b.WriteString(titleBlock(w, "Dogecoin GPENode", "Settings", sub))
	b.WriteString("\n")
	b.WriteString(muted("  file  " + confPath()))
	b.WriteString("\n")
	b.WriteString(muted("  " + shortDaemonVer(m.snap.Version) + "  |  svc " + m.snap.Service))
	b.WriteString("\n")
	b.WriteString(rule(w))
	b.WriteString("\n")

	menuOff := countLines(b.String())
	keys := editableConfKeys()
	for i, ck := range keys {
		lk := strings.ToLower(ck.Key)
		raw := m.confValues[lk]
		disp := confDisplayValue(ck, raw)
		if m.confDirty[lk] {
			disp = gold(disp + " *")
		} else {
			disp = white(disp)
		}
		// label left, value right-ish
		lab := fmt.Sprintf("%-16s", ck.Label)
		row := lab + "  " + disp
		if ck.Restart {
			row += muted("  *")
		}
		b.WriteString(hi(i == m.cursor, w, row))
		b.WriteString("\n")
	}

	b.WriteString(rule(w))
	b.WriteString("\n")
	// action rows continue the cursor index
	acts := settingsActions()
	base := len(keys)
	// menuOff stays at first conf key; mouse for actions still approximate
	for i, a := range acts {
		label := fmt.Sprintf("[%s]  %s", a.key, a.title)
		b.WriteString(hi(base+i == m.cursor, w, label))
		b.WriteString("\n")
	}
	b.WriteString("\n")
	b.WriteString(muted("  * staged (memory) until Write  |  * needs service restart after Write"))
	b.WriteString("\n")
	b.WriteString(muted("  Never expose RPC; keep rpcbind=127.0.0.1"))
	return b.String(), menuOff
}

func (m model) viewWallet(w int) (string, int) {
	var b strings.Builder
	b.WriteString(titleBlock(w, "Dogecoin GPENode", "Wallet (optional)", "not required for Fast Sync dump operators"))
	b.WriteString("\n\n")

	if !m.snap.WalletOn {
		// Soft, expected - not an error banner
		b.WriteString(gold("  Profile: dump / headless producer"))
		b.WriteString("\n\n")
		b.WriteString(white("  Wallet RPC is off by design for pure dump nodes."))
		b.WriteString("\n")
		b.WriteString(muted("  conf often includes:  disablewallet=1"))
		b.WriteString("\n\n")
		b.WriteString(muted("  This is normal. Dump + CDN + service do not need a wallet."))
		b.WriteString("\n")
		b.WriteString(muted("  Settlement profile can enable wallet later; send/receive UI can follow."))
		b.WriteString("\n\n")
		b.WriteString(kvLine(16, "  Balance", muted("n/a")))
		b.WriteString("\n")
		b.WriteString(kvLine(16, "  Status", gold("EXPECTED for dump profile")))
		b.WriteString("\n")
	} else {
		b.WriteString(kvLine(16, "  Available", gold(m.snap.Balance+" DOGE")))
		b.WriteString("\n")
		b.WriteString(muted("\n  Send/Receive forms: next polish pass (mockup-ready)."))
		b.WriteString("\n")
	}
	b.WriteString("\n")
	before := countLines(b.String())
	ab, off := actionBlock(m, w, genericActions())
	b.WriteString(ab)
	return b.String(), before + off
}

func (m model) viewHelp(w int) (string, int) {
	var b strings.Builder
	b.WriteString(titleBlock(w, "GPENode TUI", "Help", tuiVersion))
	b.WriteString("\n")
	b.WriteString(`
  Navigation
    up dn       move gold highlight
    Enter     open / run
    click     open row
    B / Esc   back home
    Q         quit TUI (node keeps running)
    / or :    command line

  Screens
    O Overview     N Node Control    D Dump
    C CDN          L Logs            S Settings
    W Wallet       ? Help

  Consensus stays in dogecoind. This UI is operator chrome only.
`)
	b.WriteString("\n")
	before := countLines(b.String())
	ab, off := actionBlock(m, w, genericActions())
	b.WriteString(ab)
	return b.String(), before + off
}

func truncate(s string, n int) string {
	if n < 4 {
		return s
	}
	if len(s) <= n {
		return s
	}
	return s[:n-3] + "..."
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}


func asciiBorder() lipgloss.Border {
	return lipgloss.Border{
		Top: "-", Bottom: "-", Left: "|", Right: "|",
		TopLeft: "+", TopRight: "+", BottomLeft: "+", BottomRight: "+",
	}
}
