# Debian/Ubuntu profile

The Debian/Ubuntu profile is not a separate tool selection — it documents the **platform-specific differences and prerequisites** for running [base](base.md), [work](work.md), or [mobile](mobile.md) on Debian or Ubuntu Linux. The first Linux implementation targets `apt`/`dpkg` only; it does not claim support for Fedora, Arch, or other distributions.

## Included catalog IDs

The Debian/Ubuntu platform does not select its own toolset; it applies whichever tool profile you chose ([base](base.md), [work](work.md), or [mobile](mobile.md)). The catalog IDs that apply on Debian/Ubuntu are the union of the selected tool profile, minus the platform-unavailable IDs listed below. From [`references/tool-catalog.tsv`](../references/tool-catalog.tsv):

**Inherited from [base](base.md)** (applies on every Debian/Ubuntu setup):

- IDEs and editors: `intellij`, `vscode`, `cursor`, `neovim`, `vim`
- Terminal, session, and window utilities: `ghostty`, `tmux`
- AI clients and coding agents: `omp`, `claude-code`, `codex`, `copilot`
- Developer CLI: `git`
- Package managers: `npm`
- Runtimes: `java`, `go`, `python`, `node`

**Added by [work](work.md)** (opt-in, on top of base): `devbox`, `teleport`, `kubectl`, `bazel`, `github-cli`, `herdr`.

**Added by [mobile](mobile.md)** (opt-in, on top of base): `android`. (`xcode` is macOS-only — see platform differences below.)

**Platform differences and unavailable IDs:**

- `brew` — Homebrew is not the package manager on Linux; `apt`/`dpkg` is used instead (the `macos`-only `brew` row does not apply).
- `hammerspoon` — macOS-only; not present in the base list above and not detected or linked on Linux.
- `ghostty` — links to a Linux XDG config path, **not** the macOS application-support destination.
- `xcode` — no Xcode or iOS simulator on Linux; this ID is macOS-only and is not applied on Debian/Ubuntu.
- `android` — `adb` and the Android SDK are available on Linux via the SDK manager / `apt`.

## Platform prerequisites

- **Package manager:** `apt`/`dpkg`. A future `manifests/linux/apt-packages.txt` will declare the curated package list. Package names differ from Homebrew formulae, so the platform manifest provides the mapping rather than forcing one name across systems.
- **Shell:** `bash` is the traditional default; `zsh` is available via `apt`. Both `.bashrc` and `.zshrc` are mapped from `~/utils`.
- **System paths:** system-owned paths under `/usr`, `/etc`, and `/bin` are not modified. All dotfile destinations are under `$HOME`.

## Application and IDE discovery

Linux GUI applications are described by `.desktop` entries and installed packages, not macOS `.app` bundles. The inventory (a future `scripts/snapshot.sh`) reads desktop-entry metadata and `dpkg` records so that IntelliJ IDEA, Visual Studio Code, Cursor, Ghostty, and other GUI tools are inventoried even when they were installed outside `apt`. This keeps GUI tools first-class — see [`references/tool-catalog.tsv`](../references/tool-catalog.tsv).

## Configuration destinations on Linux

From [`references/config-sources.md`](../references/config-sources.md), the Linux-specific mapping is selected by the `base@linux` profile token:

- **Ghostty:** the `ghostty-linux` row links `ghostty.config` to `~/.config/ghostty/config` (an XDG config path, **not** the macOS application-support path; the `ghostty-macos` row is skipped on Linux).

The remaining mappings use the same `$HOME`-relative destinations on Linux as on macOS, but they are **not all symlinks** — see [`references/config-sources.md`](../references/config-sources.md) for the mode definitions. Bootstrap installs the Oh My Zsh framework and its custom plugins, links `.zshrc`, `.zshrc.work` and `.local/bin/herdr-title-watch` for the `work` profile, `.bashrc`, `.tmux.conf`, `.vimrc`, the kickstart.nvim `lua/custom/` overlay, `.kubectlAliases`, and non-secret GitHub CLI `config.yml` preferences. It also installs Vundle and runs Vim's declared plugin installation. Bootstrap clones kickstart.nvim when absent and applies the versioned `nvim-custom/kickstart.patch` before linking the overlay. Work-only aliases, ETL variables, Devbox/Pedregal helpers, AWS profile selection, and Herdr hooks stay in `.zshrc.work`; authentication, sessions, caches, and machine-specific state remain excluded.

## Mobile tooling on Linux


## Manual authentication and licensing handoffs

- Sign in to IntelliJ IDEA, VS Code, Cursor, and AI clients after bootstrap (see [base](base.md)).
- Android SDK: accept licenses via `sdkmanager --licenses`.
- Work tools (Devbox, Teleport, Kubernetes, Bazel, GitHub CLI): manual auth only — see [work](work.md).

## What this profile does not restore

- No `apt` sources, GPG keyrings, or system-level `/etc` configuration.
- No desktop-environment settings, GNOME/KDE configs, or display-server state.
- No application caches, logs, or `~/.cache` contents.
- No iOS simulator state (unsupported on Linux).
- Nothing from the selected tool profile's "does not restore" list.

Private Android/iOS workflow notes remain in the private notes vault; see `../references/related-notes.md`.
