#!/usr/bin/env python3
"""Edit ~/.config/hypr/hyprland/keybinds.lua and custom/keybinds.lua from the UI.

Subcommands read JSON spec from stdin and write JSON result to stdout.
On any error, exit code is 1 and stdout is {"ok": false, "error": "..."}.
"""
import json
import os
import re
import sys
import tempfile
from datetime import datetime
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
DEFAULT_FILE = HOME / ".config/hypr/hyprland/keybinds.lua"
CUSTOM_FILE = HOME / ".config/hypr/custom/keybinds.lua"
BACKUP_DIR = HOME / ".local/state/quickshell/keybinds-backup"
BACKUP_RETAIN_PER_FILE = 20

CUSTOM_HEADER = (
    "-- This file will not be overwritten across dots-hyprland updates.\n"
    "-- Add or override keybinds here. The cheatsheet edit UI writes here.\n"
)


def fail(msg):
    print(json.dumps({"ok": False, "error": msg}))
    sys.exit(1)


def ok(**fields):
    print(json.dumps({"ok": True, **fields}))
    sys.exit(0)


def source_path(source):
    if source == "default":
        return DEFAULT_FILE
    if source == "custom":
        return CUSTOM_FILE
    fail(f"unknown source: {source!r}")


def combo_re(combo):
    # Matches: hl.bind("<combo>", ...
    # The combo is taken literally; escape regex specials in case (e.g. dots).
    return re.compile(r'^(\s*hl\.bind\("' + re.escape(combo) + r'"\s*,)')


def find_lines(path, combo):
    if not path.exists():
        return []
    rx = combo_re(combo)
    out = []
    for i, line in enumerate(path.read_text().splitlines(), start=1):
        if rx.search(line):
            out.append(i)
    return out


DESC_RE = re.compile(r'(description\s*=\s*)"((?:[^"\\]|\\.)*)"')


def rewrite_description(line, full_desc):
    # full_desc is the already-composed "Category: text" string.
    escaped = full_desc.replace('\\', '\\\\').replace('"', '\\"')

    def sub(m):
        return f'{m.group(1)}"{escaped}"'

    return DESC_RE.sub(sub, line, count=1)


def sweep_backups():
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    by_stem = {}
    for p in BACKUP_DIR.glob("*.bak"):
        stem = p.name.split(".", 1)[0]
        by_stem.setdefault(stem, []).append(p)
    for stem, paths in by_stem.items():
        paths.sort(key=lambda p: p.stat().st_mtime, reverse=True)
        for old in paths[BACKUP_RETAIN_PER_FILE:]:
            try:
                old.unlink()
            except OSError:
                pass


def backup(path):
    sweep_backups()
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bak = BACKUP_DIR / f"{path.name}.{ts}.bak"
    bak.write_bytes(path.read_bytes())


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=path.name + ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp, str(path))
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def cmd_find(spec):
    combo = spec.get("combo")
    if not combo:
        fail("'combo' required")
    custom = find_lines(CUSTOM_FILE, combo)
    default = find_lines(DEFAULT_FILE, combo)
    if custom:
        ok(source="custom", occurrences=len(custom))
    if default:
        ok(source="default", occurrences=len(default))
    ok(source="generated", occurrences=0)


def cmd_edit(spec):
    for k in ("source", "oldCombo", "newCombo"):
        if k not in spec:
            fail(f"'{k}' required")
    path = source_path(spec["source"])
    if not path.exists():
        fail(f"source file does not exist: {path}")
    old_combo = spec["oldCombo"]
    new_combo = spec["newCombo"]
    desc = spec.get("description")
    cat = spec.get("category")

    rx_old = combo_re(old_combo)
    quote_old = f'hl.bind("{old_combo}"'
    quote_new = f'hl.bind("{new_combo}"'

    lines = path.read_text().splitlines(keepends=True)
    changed = []
    for i, line in enumerate(lines):
        if rx_old.search(line):
            new_line = line.replace(quote_old, quote_new, 1)
            if desc is not None and cat is not None and DESC_RE.search(new_line):
                new_line = rewrite_description(new_line, f"{cat}: {desc}")
            lines[i] = new_line
            changed.append(i + 1)

    if not changed:
        fail(f"no line matched combo {old_combo!r} in {path}")

    backup(path)
    atomic_write(path, "".join(lines))
    ok(changedLines=changed)


SUBCOMMANDS = {
    "find": cmd_find,
    "edit": cmd_edit,
}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in SUBCOMMANDS:
        fail(f"usage: keybind_edit.py <{'|'.join(SUBCOMMANDS)}>  (JSON on stdin)")
    try:
        spec = json.loads(sys.stdin.read() or "{}")
    except json.JSONDecodeError as e:
        fail(f"bad JSON on stdin: {e}")
    try:
        SUBCOMMANDS[sys.argv[1]](spec)
    except Exception as e:
        fail(f"{type(e).__name__}: {e}")


if __name__ == "__main__":
    main()
