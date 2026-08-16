# macOS profile

The macOS profile is not a separate tool selection — it documents the **platform-specific differences and prerequisites** for running [base](base.md), [work](work.md), or [mobile](mobile.md) on macOS. Package names, application discovery, and a few destinations differ from [Debian/Ubuntu](linux-debian.md).

## Included catalog IDs

The macOS platform does not select its own toolset; it applies whichever tool profile you chose ([base](base.md), [work](work.md), or [mobile](mobile.md)). The catalog IDs that apply on macOS are the union of the selected tool profile plus the macOS-only addition below. From [`references/tool-catalog.tsv`](../references/tool-catalog.tsv):

**Inherited from [base](base.md)** (applies on every macOS setup):

- IDEs and editors: `intellij`, `vscode`, `cursor`, `neovim`, `vim`
- Terminal, session, and window utilities: `ghostty`, `tmux`, `hammerspoon`
- AI clients and coding agents: `omp`, `claude-code`, `codex`, `copilot`
- Developer CLI: `git`
- Package managers: `npm`
- Runtimes: `java`, `go`, `python`, `node`

**Added by [work](work.md)** (opt-in, on top of base): `devbox`, `teleport`, `kubectl`, `bazel`, `github-cli`, `herdr`.

**Added by [mobile](mobile.md)** (opt-in, on top of base): `android`, `xcode`.

**macOS-only addition and platform differences:**

- `brew` — Homebrew is the macOS package manager (catalog token `base@macos`); inherited by every profile on macOS because `base` entries are inherited by `work` and `mobile` selections.
- `hammerspoon` — macOS-only window/automation utility; not detected or linked on Linux.
- `ghostty` — links to the macOS application-support destination (`~/Library/Application Support/com.mitchellh.ghostty/config`).
- `xcode` — iOS simulator and Xcode tooling are macOS-only.
- `alt-tab`, `maccy` — curated `base@macos` menu-bar utilities (AltTab and Maccy). Both are installed by the base macOS `Brewfile` casks and restored by a dedicated menu-bar bootstrap step; neither is detected or restored on Linux.

## Platform prerequisites

- **Package manager:** [Homebrew](https://brew.sh) (`brew`). The base profile assumes Homebrew is installed first; a future `manifests/macos/Brewfile` will declare the curated formulae and casks.
- **Shell:** `zsh` is the default login shell on modern macOS. `.zshrc` is linked from `~/utils`; `.bashrc` is also mapped for compatibility.
- **System integrity:** system-owned paths under `/usr`, `/System`, and `/Library` are not modified. All dotfile destinations are under `$HOME`.

## Application and IDE discovery

macOS GUI applications live in `/Applications` as `.app` bundles and are not always Homebrew formulae. The inventory (a future `scripts/snapshot.sh`) uses `mdfind`/`mdls` and Homebrew cask metadata so that IntelliJ IDEA, Visual Studio Code, Cursor, Ghostty, and Hammerspoon are inventoried even when they were installed outside Homebrew. This keeps GUI tools first-class — see [`references/tool-catalog.tsv`](../references/tool-catalog.tsv).

## Configuration destinations on macOS

From [`references/config-sources.md`](../references/config-sources.md), the macOS-specific mappings are selected by the `base@macos` profile token:

- **Ghostty:** the `ghostty-macos` row links `ghostty.config` to `~/Library/Application Support/com.mitchellh.ghostty/config` (the application-support path; the Linux row `ghostty-linux` is skipped on macOS).
- **Hammerspoon:** the `hammerspoon` row links `~/utils/.hammerspoon/` to `~/.hammerspoon/` (carries `base@macos`; skipped on Linux).

The remaining mappings use the same `$HOME`-relative destinations on macOS as on Linux, but they are **not all symlinks** — see [`references/config-sources.md`](../references/config-sources.md) for the mode definitions. Bootstrap installs the Oh My Zsh framework and its custom plugins, links `.zshrc`, `.zshrc.work` and `.local/bin/herdr-title-watch` for the `work` profile, `.bashrc`, `.tmux.conf`, `.vimrc`, the kickstart.nvim `lua/custom/` overlay, `.kubectlAliases`, and non-secret GitHub CLI `config.yml` preferences. It also installs Vundle and runs Vim's declared plugin installation. Bootstrap clones kickstart.nvim when absent and applies the versioned `nvim-custom/kickstart.patch` before linking the overlay. Work-only aliases, ETL variables, Devbox/Pedregal helpers, AWS profile selection, and Herdr hooks stay in `.zshrc.work`; authentication, sessions, caches, and machine-specific state remain excluded.

Agent preferences (Claude Code and OMP) are restored on macOS the same way as on Linux: `ai/claude/settings.json` is merged into `~/.claude/settings.json` (`json-merge`) and `ai/omp/preferences.json` is staged into `~/.omp/agent/config.yml` (`omp-merge`). Both preserve unknown local keys and back up the existing destination into `~/.workstation-setup-backups/<UTC timestamp>/` before writing. The sources contain only portable preference keys — no `~/.claude.json`, no Claude plugin/marketplace/session state, no OMP `.env`/MCP secrets/databases/sessions/logs/extensions/provider routing, and no credentials. If `claude` or `omp` is absent during apply, bootstrap prints a follow-up and does not write. Authentication for both is a manual handoff. See [`references/config-sources.md`](../references/config-sources.md).

## Hammerspoon on macOS

Hammerspoon is a macOS-only window/automation utility. The `~/utils/.hammerspoon/` directory is symlinked to `~/.hammerspoon/`. The kit links the **code** only — it never restores Hammerspoon's machine-specific state, Spoon install metadata, or any window layout.

## Menu-bar utilities on macOS

AltTab (`com.lwouis.alt-tab-macos`) and Maccy (`org.p0deje.Maccy`) are the curated `base@macos` menu-bar utilities. The base macOS `Brewfile` installs both casks, and a dedicated `restore_menu_bar_settings()` step in `bootstrap.sh` restores their preferences.

Unlike the symlinked dotfiles above, menu-bar preferences are **imported** into each app's `defaults` domain, not symlinked, because a macOS defaults database holds dynamic per-user state that must not be shared verbatim. Restore is defaults-domain export/import, never a move of `$HOME/Library/Preferences` files:

- The curated templates live in `~/utils/macos/menu-bar/{alt-tab,maccy}/preferences.plist` and contain only allowlisted keys (window-switcher options for AltTab; keyboard-shortcut/pasteboard/display options for Maccy).
- Each template is parsed with Python `plistlib` and validated against a per-app key allowlist before any restore; an unapproved key, malformed plist, or bad shortcut/pasteboard value fails closed with `invalid menu-bar plist` and no import runs.
- The target domains are `com.lwouis.alt-tab-macos` and `org.p0deje.Maccy`. Maccy is **sandboxed**, so its live defaults store is the logical destination `~/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist`, not `~/Library/Preferences/org.p0deje.Maccy.plist`. AltTab's store is the conventional `~/Library/Preferences/com.lwouis.alt-tab-macos.plist`.
- Before apply, `defaults domains` is probed for each domain. A present domain is backed up via `defaults export <domain> <path>` into `~/.workstation-setup-backups/<UTC timestamp>/<relative destination>`; an absent domain with a regular file at the logical destination is copied to the same timestamped backup path. A `defaults domains` failure aborts before any import. A symlink at the logical destination is rejected as `UNSAFE` on apply (dry-run emits a `PLAN REVIEW` note instead).
- The curated template is then applied with `defaults import <domain> <template>`. Bootstrap never kills the running app: import writes the defaults database, and the app picks up curated preferences on its next launch. Quit AltTab/Maccy before applying if you want the live preferences to take effect immediately.
- Dry-run prints `PLAN MENU_BAR <id> -> $HOME/<destination>` and the planned backup path (when a live store exists) without touching files; if `defaults` is unavailable, dry-run still plans the restore without probing backups.

See [`references/config-sources.md`](../references/config-sources.md) for the source templates, domains, live paths, and the public-repository privacy boundary.

## Mobile tooling on macOS


## Manual authentication and licensing handoffs

- Sign in to IntelliJ IDEA, VS Code, Cursor, and AI clients after bootstrap (see [base](base.md)). Claude Code and OMP preferences are restored as portable keys only; authenticate each tool per its own login flow. `~/.claude.json`, Claude plugin/marketplace/session state, OMP `.env`/MCP secrets/databases/sessions/logs/extensions/provider routing, and all credentials remain machine-local and are never restored.
- Xcode: Apple ID + developer license (see [mobile](mobile.md)).
- Homebrew needs no auth; `npm login` only if you publish.
- AltTab and Maccy: grant **Accessibility** (both) and **Screen Recording** (AltTab) permissions in *System Settings → Privacy & Security* on first launch; these are manual OS actions the kit cannot perform. Quit AltTab/Maccy before a live `--apply` if you want imported preferences to take effect immediately, since bootstrap imports the defaults database without killing the running app.

## What this profile does not restore

- No Keychain contents, iCloud accounts, login/session state, or system preferences — `~/Library/Preferences` is out of scope **except** the two curated menu-bar defaults domains (`com.lwouis.alt-tab-macos`, `org.p0deje.Maccy`), which are imported from allowlisted templates only.
- No `.app` application state, caches, or containers under `~/Library/Containers` — **except** Maccy's sandboxed defaults store at `~/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist`, which is the logical destination of the curated `defaults import` and is backed up before replacement.
- No Hammerspoon machine state or Spoon install metadata.
- No Maccy clipboard history, pasteboard contents, or any runtime/container state beyond the allowlisted preferences — only curated display/shortcut/pasteboard-type options are restored.
- No Accessibility or Screen Recording permissions (manual OS actions; see handoffs above).
- No security/enterprise agents (Cortex, Mosyle, Santa) or unselected menu-bar utilities (Tailscale, OrbStack, Alfred, Apple status items) — only AltTab and Maccy are curated.
- Nothing from the selected tool profile's "does not restore" list.
- No `~/.claude.json`, Claude plugin/marketplace/session state, OMP `.env` files, MCP secrets, databases, sessions, logs, extensions, or provider/model routing — only portable preference keys in `ai/claude/settings.json` and `ai/omp/preferences.json` are restored. Authentication for Claude Code and OMP is a manual handoff.

Private Android/iOS workflow notes remain in the private notes vault; see `../references/related-notes.md`.
