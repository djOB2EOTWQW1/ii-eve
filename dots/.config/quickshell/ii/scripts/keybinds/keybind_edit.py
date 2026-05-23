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


def cmd_delete(spec):
    for k in ("source", "combo"):
        if k not in spec:
            fail(f"'{k}' required")
    path = source_path(spec["source"])
    if not path.exists():
        fail(f"source file does not exist: {path}")
    combo = spec["combo"]
    rx = combo_re(combo)

    raw = path.read_text().splitlines(keepends=True)
    kept = []
    removed = []
    for i, line in enumerate(raw, start=1):
        if rx.search(line):
            removed.append(i)
        else:
            kept.append(line)

    if not removed:
        fail(f"no line matched combo {combo!r} in {path}")

    backup(path)
    atomic_write(path, "".join(kept))
    ok(removedLines=removed)


def lua_string_literal(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def ensure_custom_exists():
    if CUSTOM_FILE.exists():
        return
    CUSTOM_FILE.parent.mkdir(parents=True, exist_ok=True)
    CUSTOM_FILE.write_text(CUSTOM_HEADER)


def cmd_add(spec):
    for k in ("combo", "command", "description", "category"):
        if k not in spec:
            fail(f"'{k}' required")
    combo = spec["combo"]
    command = spec["command"]
    desc = f"{spec['category']}: {spec['description']}"

    ensure_custom_exists()
    # Refuse if combo already present in custom (defaults can be overridden, but custom dups not).
    if find_lines(CUSTOM_FILE, combo):
        fail(f"combo {combo!r} already exists in {CUSTOM_FILE.name}")

    text = CUSTOM_FILE.read_text()
    if text and not text.endswith("\n"):
        text += "\n"
    line = (
        f"hl.bind({lua_string_literal(combo)}, "
        f"hl.dsp.exec_cmd({lua_string_literal(command)}), "
        f"{{ description = {lua_string_literal(desc)} }})\n"
    )
    new_text = text + line

    if CUSTOM_FILE.stat().st_size > 0:
        backup(CUSTOM_FILE)
    atomic_write(CUSTOM_FILE, new_text)

    appended_at = len(new_text.splitlines())
    ok(appendedAt=appended_at)


def inject_description(line, full_desc):
    # If line already has a description, replace it.
    if DESC_RE.search(line):
        return rewrite_description(line, full_desc)
    # Else find the last ')' that closes the hl.bind(...) call (assumed single-line)
    # and insert ", { description = "<full_desc>" }" before it.
    stripped = line.rstrip("\n")
    if not stripped.endswith(")"):
        return None  # cannot safely edit this line
    escaped = full_desc.replace('\\', '\\\\').replace('"', '\\"')
    insertion = f', {{ description = "{escaped}" }}'
    suffix = "\n" if line.endswith("\n") else ""
    return stripped[:-1] + insertion + ")" + suffix


def cmd_set_description(spec):
    for k in ("source", "combo", "description", "category"):
        if k not in spec:
            fail(f"'{k}' required")
    path = source_path(spec["source"])
    if not path.exists():
        fail(f"source file does not exist: {path}")
    combo = spec["combo"]
    full_desc = f"{spec['category']}: {spec['description']}"

    rx = combo_re(combo)
    lines = path.read_text().splitlines(keepends=True)
    changed = 0
    for i, line in enumerate(lines):
        if rx.search(line):
            new_line = inject_description(line, full_desc)
            if new_line is None:
                fail(f"cannot edit multi-line hl.bind on line {i + 1}")
            if new_line != line:
                lines[i] = new_line
                changed += 1

    if changed == 0:
        fail(f"no editable line matched combo {combo!r} in {path}")

    backup(path)
    atomic_write(path, "".join(lines))
    ok(changedLines=changed)


def cmd_rollback(spec):
    if "filename" not in spec:
        fail("'filename' required (relative to $HOME)")
    target = HOME / spec["filename"]
    candidates = sorted(BACKUP_DIR.glob(f"{target.name}.*.bak"),
                        key=lambda p: p.stat().st_mtime, reverse=True)
    if not candidates:
        fail("no backup available")
    target.write_bytes(candidates[0].read_bytes())
    ok(restoredFrom=str(candidates[0]))


SUBCOMMANDS = {
    "find": cmd_find,
    "edit": cmd_edit,
    "delete": cmd_delete,
    "add": cmd_add,
    "set-description": cmd_set_description,
    "rollback": cmd_rollback,
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
