# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`ii-eve` is a personal fork of [`dots-hyprland`](https://github.com/end-4/dots-hyprland) (a.k.a. *illogical-impulse*). It's a Hyprland Wayland-compositor "rice": Hyprland config + a Qt6 [Quickshell](https://quickshell.org/) widget system written in QML, plus an installer/CLI and per-distro packaging metadata. There is no compiled code in this repo — almost everything ships as configuration files copied into `~/.config` and `~/.local`.

Cloning requires submodules:
```
git clone --recurse-submodules ...
```
The only submodule is `dots/.config/quickshell/ii/modules/common/widgets/shapes` (`rounded-polygon-qmljs`).

## Repo layout (the parts that aren't obvious)

- `dots/` — payload staged for the user's home directory. `dots/.config/` and `dots/.local/` mirror the real targets one-to-one.
- `dots-extra/` — optional add-ons that the installer does NOT copy by default (e.g. `emacs/`, `fcitx5/`, `fedora/`, `via-nix/`, `swaylock/`). Reserved for opt-in setups.
- `sdata/` — "setup data": everything the `setup` / `setup-ii-eve.sh` scripts read.
  - `sdata/dist-{arch,fedora,gentoo,nix}/` — per-distro dependency definitions. `dist-arch` is the reference; PKGBUILDs prefixed `illogical-impulse-` are either *meta* packages (only `depends`) or *actual* packages (build local content). See `sdata/deps-info.md` for the full inventory of what each meta-package pulls in and where it's used.
  - `sdata/lib/` — shared shell helpers (`functions.sh`, `package-installers.sh`, `dist-determine.sh`, `environment-variables.sh`).
  - `sdata/cli/lib/` — implementation of the `eve` subcommands (see CLI section).
  - `sdata/subcmd-*` — implementations of the upstream `setup` subcommands (`install`, `exp-update`, `exp-merge`, `virtmon`, …).
  - `sdata/uv/` — Python virtualenv contract (see Python section).
- `setup-ii-eve.sh` — the ii-eve installer/updater. Same script doubles as the `eve` CLI when symlinked to `~/.local/bin/eve` (it dispatches on `basename "$0"`). Installer flags: `--no-pull` (skip `git pull`), `--no-backup` (skip dotfiles backup), `--force-install`, `--full-install` (run upstream `./setup` first), `--no-confirm`.
- `setup` — upstream illogical-impulse installer (Arch-only, called from `setup-ii-eve.sh` via `--full-install` or when `~/.config/illogical-impulse` is missing).
- `diagnose` — diagnostic dump script.

### The `eve` CLI (`sdata/cli/lib/`)

Subcommands dispatched from `setup-ii-eve.sh` when invoked as `eve`:

- `eve run` / `eve restart` — `pkill qs; hyprctl reload; qs -c ii` (run is foreground, restart detaches).
- `eve update` — pull this repo, then re-run the installer.
- `eve hyprset <args>` — thin wrapper around `sdata/cli/lib/hyprset.lua` for tweaking the merged `~/.local/share/ii-eve/hyprland.conf` (see Hyprland section).
- `eve remove-cli` — uninstall the `eve` symlink.

`-v`/`--verbose` is the only global flag.

## The Quickshell shell (`dots/.config/quickshell/ii/`)

This is where almost all real work happens. After install it lives at `~/.config/quickshell/ii/`. **Edits there hot-reload live** — there is no build step.

### Big-picture architecture

- `shell.qml` is the root. It loads exactly one **panel family** at a time (`ii` or `waffle`) via `PanelFamilyLoader`, switched by `Config.options.panelFamily`. Cycle them with `qs -c ii ipc call panelFamily cycle` or the `panelFamilyCycle` GlobalShortcut.
- `panelFamilies/` — top-level `Scope`s (`IllogicalImpulseFamily.qml`, `WaffleFamily.qml`) that instantiate the panel modules they need via `PanelLoader`. Adding a new panel = add a `PanelLoader { component: MyPanel {} }` here.
- `modules/ii/` — panels for the default *illogical-impulse* family (bar, dock, appLauncher, overview, sidebarDashboard, mediaControls, lock, sessionScreen, overlay, verticalBar, wallpaperSelector, etc.).
- `modules/waffle/` — WIP Windows-style alternate family (start menu, action center, task view…). See its `README.md`.
- `modules/settings/` — declarative settings UI pages (`GeneralConfig.qml`, `BarConfig.qml`, etc.) — these paths are also used as targets when "open settings file" actions are invoked (see `Directories.qml`).
- `modules/common/`
  - `Config.qml` — **singleton**. The single source of truth for runtime options. Backs `~/.config/illogical-impulse/config.json` via `FileView` + `JsonAdapter`; `watchChanges: true` so external edits hot-reload, and adapter writes are debounced through `readWriteDelay` timers. Options live under `Config.options.*` (panelFamily, policies, ai, appearance, audio, apps, background, bar, dock, …). Always add new options as `JsonObject` properties here.
  - `Directories.qml` — **singleton**. All XDG paths and every well-known file/dir the shell touches (config, state, cache, scripts, generated themes, AI chats, lyrics, screenshots, …). When you need a path, use this — don't hardcode.
  - `Appearance.qml`, `Icons.qml`, `Images.qml`, `Persistent.qml`, `BarComponentRegistry.qml` — other shared singletons.
  - `functions/` — JS/QML utility singletons (`StringUtils`, `FileUtils`, `ColorUtils`, `DateUtils`, `Fuzzy`/`fuzzysort.js`, `Levendist`, `ObjectUtils`, `NotificationUtils`, `Session`).
  - `widgets/` — reusable QML controls (buttons, sliders, dialogs, address bars, calendars, graphs, etc.). Prefer these over re-rolling primitives.
  - `models/`, `panels/`, `utils/` — supporting types and helpers.
- `services/` — one QML singleton per backend integration (`Audio`, `Bluetooth`, `Battery`, `Network`, `Notifications`, `Mpris*`, `Hyprland*`, `Polkit`, `Ai`, `Booru`, `Cliphist`, `Wallpapers`, `Updates`, …). Heavy imperative bootstrapping for these is wired up from `shell.qml`'s `Component.onCompleted` (e.g. `MaterialThemeLoader.reapplyTheme()`, `Cliphist.refresh()`, `Wallpapers.load()`).
- `scripts/` — shell/Python/JS scripts called by services and modules (`colors/switchwall.sh`, `colors/generate_colors_material.py`, `ai/gemini-translate.sh`, `images/find_regions.py`, `videos/record.sh`, `wallpapers/extract-colors.sh`, etc.). Path constants for these are exposed through `Directories.qml`.
- `translations/tools/` — translation pipeline (also referenced by upstream CONTRIBUTING).

### Conventions to follow when editing QML

From upstream CONTRIBUTING (`/.github/CONTRIBUTING.md`), and they are observed throughout the codebase:

- **Wrap conditional/optional content in `Loader`/`FadeLoader`.** Anchors and other positioning must live on the `Loader` itself, not the `sourceComponent`. For fading-without-affecting-layout, use `FadeLoader { shown: ... }` instead of `active`/`visible`.
- **Prefer early-return** (`if (!cond) return; doStuff()`) over deep nesting. When a block of QML would otherwise need a new file, declare an inline `component MyThing: Item { ... }` instead.
- Spaces between operators (`if (cond) { ... }` not `if(cond){...}`). Group related properties; one blank line between groups, never two.
- New runtime-tunable behavior goes through `Config.options.*` (add a property to the appropriate `JsonObject` in `Config.qml`). Don't introduce parallel config files.
- Practicality first: feature-flag fancy-but-expensive effects with a `Config.options.*` toggle disabled by default.

### Running, reloading, debugging

```bash
# Foreground (logs visible):
pkill qs; qs -c ii
```

Hot reload is automatic on file save. The reload UI is the `ReloadPopup` in `shell.qml`. Restart Hyprland with `hyprctl reload` (the installer does both).

QML LSP setup (one-time):
```bash
touch ~/.config/quickshell/ii/.qmlls.ini   # gitignored on purpose
```
VSCode: install "Qt Qml" and point the custom exe path to `/usr/bin/qmlls6`. `qmllint6` is what to invoke for lint-style checks (no project-wide command is wired up).

## Hyprland config (`dots/.config/hypr/`)

The installer does *not* overwrite the user's `~/.config/hypr/hyprland.conf`. Instead:

1. The shipped `dots/.local/share/ii-eve/hyprland.conf` is merged into `~/.local/share/ii-eve/hyprland.conf` by `sdata/cli/lib/hyprmerge.sh` (preserves local overrides).
2. A `source = ~/.local/share/ii-eve/hyprland.conf` line is appended to `~/.config/hypr/hyprland.conf`.

This is intentional — never replace `~/.config/hypr/hyprland.conf` outright in scripts, and don't bypass `hyprmerge.sh` when modifying installer flow.

The upstream `./setup` script (Arch-only) supports its own subcommands: `install`, `install-deps`, `install-setups`, `install-files`, `exp-update`, `exp-merge`, plus dev-only `virtmon` / `checkdeps` / `uninstall` / `resetfirstrun`. `setup-ii-eve.sh` will refuse to delegate to the dev-only ones.

## Python (in `scripts/` and elsewhere)

Python deps are installed into a uv-managed venv at `$ILLOGICAL_IMPULSE_VIRTUAL_ENV` (default `~/.local/state/quickshell/.venv`). **Never** `pip install` system-wide.

To add/remove a package:
```bash
cd sdata/uv
# edit requirements.in
uv pip compile requirements.in -o requirements.txt
```
`requirements.txt` is checked in as a lockfile.

When calling Python from QML/shell scripts there are two patterns (full details in `sdata/uv/README.md`):

- **Shebang activator** — replace `#!/usr/bin/env python3` with the long activator shebang. Simplest, but doesn't survive complex argv quoting and won't help if invoked as `python3 foo.py`.
- **Bash wrapper** — keep the standard shebang on the `.py`, write a sibling `*-venv.sh` that `source`s `$ILLOGICAL_IMPULSE_VIRTUAL_ENV/bin/activate`, calls the script with `"$@"`, then `deactivate`s. Update QML callers to point at the wrapper. Use this when arguments may be complex.

Inside an existing bash script, just bracket the python call with `source .../activate` / `deactivate`.

## Things to watch out for

- The shell uses many singletons (`Config`, `Directories`, `Appearance`, all of `services/*`). Import them as `qs.modules.common`, `qs.modules.common.functions`, `qs.services` — see existing files for pattern. Don't construct ad-hoc paths or duplicate state already on a singleton.
- Translation source for upstream tooling: `dots/.config/quickshell/ii/translations/tools` (CONTRIBUTING refers to this; do not move it).
- The repo does not contain test or formal lint commands; verification of changes is manual (`pkill qs; qs -c ii` and look at logs, optionally `qmllint6` on individual files).
- Submodule path `modules/common/widgets/shapes` is third-party (`rounded-polygon-qmljs`); don't edit in-place — push fixes upstream.
