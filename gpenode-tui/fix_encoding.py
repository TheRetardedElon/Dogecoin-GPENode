#!/usr/bin/env python3
"""Fix mojibake / force ASCII-safe UI strings in main.go"""
from pathlib import Path

p = Path(__file__).with_name("main.go")
raw = p.read_text(encoding="utf-8", errors="replace")

# Mojibake sequences (UTF-8 misread as Latin-1 then saved as UTF-8)
repls = [
    ("Â·", " | "),
    ("Â ", " "),
    ("â†‘â†“", "up/dn"),
    ("â†‘", "up"),
    ("â†“", "dn"),
    ("â†»", "*"),
    ("â€”", "-"),
    ("â€“", "-"),
    ("â€˜", "'"),
    ("â€™", "'"),
    ("â€œ", '"'),
    ("â€\x9d", '"'),
    ("â€¢", "*"),
    ("â–¶", ">"),
    ("â–²", "^"),
    ("â–¼", "v"),
    ("â–ˆ", "#"),
    ("â”€", "-"),
    ("â”‚", "|"),
    ("â‰ ", "!="),
    ("â‰", "!="),
    # real unicode
    ("\u00b7", " | "),
    ("\u2191", "up"),
    ("\u2193", "dn"),
    ("\u25b6", ">"),
    ("\u25bc", "v"),
    ("\u25b2", "^"),
    ("\u2500", "-"),
    ("\u2502", "|"),
    ("\u2014", "-"),
    ("\u2013", "-"),
    ("\u2018", "'"),
    ("\u2019", "'"),
    ("\u201c", '"'),
    ("\u201d", '"'),
    ("\u2022", "*"),
    ("\u2588", "#"),
    ("\u21bb", "*"),
    ("\u2260", "!="),
    ("\u2014", "-"),
    ("\u2026", "..."),
    ("\u00a0", " "),
]

for a, b in repls:
    raw = raw.replace(a, b)

# strip remaining C2 A7-style leftovers of middot double-encoding
raw = raw.replace("Â|", "|")

for name in ("DoubleBorder", "RoundedBorder", "ThickBorder", "NormalBorder"):
    raw = raw.replace(f"lipgloss.{name}()", "asciiBorder()")

if "func asciiBorder" not in raw:
    raw += """

func asciiBorder() lipgloss.Border {
	return lipgloss.Border{
		Top: "-", Bottom: "-", Left: "|", Right: "|",
		TopLeft: "+", TopRight: "+", BottomLeft: "+", BottomRight: "+",
	}
}
"""

p.write_text(raw, encoding="utf-8", newline="\n")

bad = [(i + 1, line) for i, line in enumerate(raw.splitlines()) if any(ord(c) > 127 for c in line)]
print(f"non-ascii lines remaining: {len(bad)}")
for i, line in bad[:30]:
    print(f"{i}: {line[:140]!r}")
print("OK")
