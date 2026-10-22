"""Generate App/macOS/Resources/Credits.html: the About window shows it (third-party licenses that must ship with the app).

Run after changing a dependency: python3 scripts/gen-credits.py
Reads license files from the SwiftPM checkouts (build once first), the font licenses, and scripts/licenses/.
"""

from html import escape
from pathlib import Path
import sys

apple = Path(__file__).resolve().parent.parent
checkouts = apple / "BarlyKit/.build/checkouts"


def first_existing(*candidates):
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    sys.exit(f"Missing license file: {candidates[0]} (build the app once so the packages are checked out)")


sparkle = first_existing(*sorted(apple.glob(".build/*/SourcePackages/checkouts/Sparkle/LICENSE")), apple / "missing/Sparkle/LICENSE")
components = [
    ("SwiftTerm", "https://github.com/migueldeicaza/SwiftTerm", first_existing(checkouts / "SwiftTerm/LICENSE")),
    ("Sparkle", "https://github.com/sparkle-project/Sparkle", sparkle),
    ("Ghostty (libghostty)", "https://github.com/ghostty-org/ghostty", first_existing(apple / "scripts/licenses/ghostty.txt")),
    ("libghostty-spm", "https://github.com/Lakr233/libghostty-spm", first_existing(checkouts / "libghostty-spm/LICENSE")),
    ("DisplayLink", "https://github.com/Lakr233/DisplayLink", first_existing(checkouts / "DisplayLink/LICENSE")),
    ("bash-preexec", "https://github.com/rcaloras/bash-preexec", first_existing(
        checkouts / "libghostty-spm/Sources/GhosttyTerminal/Resources/Ghostty/shell-integration/bash/LICENSE-bash-preexec.md")),
    ("Inter", "https://rsms.me/inter/", first_existing(apple / "LICENSE-fonts/inter.txt")),
    ("Geist", "https://github.com/vercel/geist-font", first_existing(apple / "LICENSE-fonts/geist.txt")),
    ("Geist Mono", "https://github.com/vercel/geist-font", first_existing(apple / "LICENSE-fonts/geistmono.txt")),
]

parts = ["""<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body { font: 11px -apple-system, sans-serif; color: #444; }
@media (prefers-color-scheme: dark) { body { color: #bbb; } a { color: #8ab4ff; } }
h3 { font-size: 11px; margin: 14px 0 4px; }
pre { font: 10px ui-monospace, monospace; white-space: pre-wrap; margin: 0; }
</style></head><body>
<p>Switchboard is MIT licensed. It includes the components below. tmux, libevent, ncurses and utf8proc licenses are in
Contents/Resources/Tmux/licenses.</p>
"""]
for name, url, path in components:
    parts.append(f'<h3><a href="{url}">{escape(name)}</a></h3>\n<pre>{escape(path.read_text(encoding="utf-8").strip())}</pre>\n')
parts.append("</body></html>\n")
out = apple / "App/macOS/Resources/Credits.html"
out.write_text("".join(parts), encoding="utf-8")
print(out)
