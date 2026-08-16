# Workstation Setup Kit

A shareable developer-workstation setup kit. It inventories all developer tools, keeps [`~/utils`](https://github.com/amit-handa/utils) as the single source of truth for actual dotfiles, and supports safe migration to another Mac or Debian/Ubuntu Linux machine — without exposing credentials, tokens, hostnames, or machine-specific state.

This package is the **setup control plane**: it owns setup intent, profile documentation, manifests, migration instructions, inventory, and orchestration. Active runtime destinations remain the utils repository root and the corresponding `$HOME` paths; legacy Bash sources live under `4-archives/` and are exposed through root compatibility symlinks. This package does not create a second configuration tree.

> Package location: `2-areas/workstation-setup/`
> Design: [`docs/superpowers/specs/2026-08-13-workstation-setup-design.md`](docs/superpowers/specs/2026-08-13-workstation-setup-design.md)
> Plan: [`docs/superpowers/plans/2026-08-13-workstation-setup.md`](docs/superpowers/plans/2026-08-13-workstation-setup.md)

## What this manages

The kit manages **intent and orchestration**, not raw credentials:

- **Tool coverage catalog** — [`references/tool-catalog.tsv`](references/tool-catalog.tsv) guarantees first-class coverage of GUI applications, IDEs, terminal/session utilities, AI clients, window utilities, developer CLI, package managers, runtimes, and mobile tooling. A tool stays in the catalog even when a detector later reports it as not installed. Column grammar: `command_candidates` is a colon-separated exact-token list; `profiles` is a pipe-separated direct-membership list using bare profile names (`base`, `work`, `mobile`) and platform-suffixed tokens (`base@macos`, `mobile@macos`) where a tool is platform-specific. See [Catalog grammar](#catalog-grammar).
- **Configuration mappings** — [`references/config-sources.tsv`](references/config-sources.tsv) and [`references/config-sources.md`](references/config-sources.md) document which dotfiles come from `~/utils`, where they link in `$HOME`, and which profile owns each mapping.
- **Profiles** — curated desired toolsets (see [Choose a profile](#choose-a-profile) below).
- **Manifests** — desired package sets per platform in `manifests/common.txt`, `manifests/macos/Brewfile`, `manifests/linux/apt-packages.txt`, and `manifests/runtimes.txt`. Each macOS Brewfile entry carries a `# profile:<token>` selector used to generate the profile-filtered apply file.
- **Inventory** — generated installed-state and recent-usage reports in `inventory/current-machine.md` and `inventory/recent-usage.md`.
- **Scripts** — `scripts/snapshot.sh` inventories observed state; `scripts/bootstrap.sh` installs the selected profile and applies safe configuration mappings. Shared helpers and focused fixtures live under `scripts/`.

What the kit does **not** manage: credentials, tokens, private keys, Keychain contents, Kubernetes contexts, cloud profiles, cookies, caches, logs, databases, raw shell history, or machine identifiers. See [Privacy boundary](#privacy-boundary).

## Choose a profile

Profiles are composed from common entries plus an OS-specific manifest. Discovery (inventory) does **not** automatically promote a tool into a desired profile — promoting an observed tool is an intentional manifest change.

- [**base**](profiles/base.md) — the default developer workstation: shell, Git, tmux, selected IDEs/editors, terminal and window utilities, AI clients, and intentionally managed runtimes. Every other profile composes on top of base.
- [**work**](profiles/work.md) — opt-in, on top of base. Adds Devbox, Teleport CLI, Kubernetes tooling, Bazel, GitHub CLI, and Herdr **without** authentication state.
- [**mobile**](profiles/mobile.md) — opt-in, on top of base. Points to the existing Android and iOS notes; may install prerequisites but does not restore simulator/device state.
- [**macos**](profiles/macos.md) — macOS platform differences and prerequisites (Homebrew, `.app` discovery, Hammerspoon, Ghostty destination).
- [**linux-debian**](profiles/linux-debian.md) — Debian/Ubuntu platform differences and prerequisites (`apt`/`dpkg`, desktop entries, no Xcode/iOS simulator).

Each profile doc lists its included catalog IDs, platform prerequisites, manual authentication/licensing handoffs, and what it does not restore.

## Migration

1. **Prerequisites** — on the target machine, install the platform package manager first:
   - **macOS:** install [Homebrew](https://brew.sh).
   - **Debian/Ubuntu:** `apt`/`dpkg` is preinstalled; ensure `git` and `bash`/`zsh` are available.
2. **Clone the dotfiles source** — clone [`~/utils`](https://github.com/amit-handa/utils) to the target `~/utils` (or pass `--utils-path` to point elsewhere). This is the single source of truth for dotfiles.
3. **Pick a profile** — see [Choose a profile](#choose-a-profile).
4. **Dry-run the bootstrap** — run `scripts/bootstrap.sh --os <macos|linux> --profile <base|work|mobile> [--utils-path PATH]` without `--apply`. Dry-run is the default: it prints package, link, backup, local-file, and manual follow-up actions without calling a package manager or modifying either tree.
5. **Apply** — re-run with `--apply`. It preflights every selected mapping before any mutation, installs only the composed base-plus-selected profile, backs up an existing destination under `~/.workstation-setup-backups/<UTC timestamp>/`, and creates only declared links or missing local-only files. It never applies the tracked `.gitconfig` or installs credentials.
6. **Manual handoffs** — complete the authentication/licensing steps listed in your profile doc. The kit never stores the resulting secrets.

## Update workflow

There is no background watcher. The explicit snapshot command is the update boundary and keeps changes reviewable. After installing, removing, or intentionally changing a developer tool:

1. Run `scripts/snapshot.sh --os <macos|linux>` for the current platform. The default recent-usage window is the **last seven days**.
2. Review both `inventory/current-machine.md` and `inventory/recent-usage.md`, including the `Unclassified` section.
3. Add intentional tools to the appropriate desired profile or manifest.
4. Update the configuration mapping or related-note links if needed.
5. Run the dry-run bootstrap and `scripts/check.sh`.
6. Commit the package and runtime configuration changes in `~/utils`.
7. Push the vault repository so the central setup page stays current.

A missing package-manager entry does **not** remove a tool from the inventory, because application, usage, and configuration discovery remain independent sources.

## Privacy boundary

The following are **never** collected, copied, generated, or committed by setup automation:

- `~/.ssh` private keys and agent state
- `~/.aws` credentials and profiles
- `~/.kube/config` and cluster credentials
- Docker authentication files
- `.env*`, `.netrc`, `.npmrc` tokens, and secret files
- Keychain contents, browser cookies, application login data, and session caches
- API tokens, private keys, certificates, and password files
- hostnames, usernames, absolute personal paths, and machine identifiers
- tool caches, logs, lock files, databases, and generated application state
- raw shell-history lines, command arguments, search text, and unclassified usage payloads
- `~/.claude.json` and Claude plugin/marketplace/session state (only portable preference keys in `ai/claude/settings.json` are restored)
- OMP `.env` files, MCP secrets, databases, sessions, logs, extensions, and provider/model routing (only portable preference keys in `ai/omp/preferences.json` are restored)

### Seven-day usage audit and redaction boundary

The kit performs an **explicit, bounded** audit of tools used during the **last seven days** to catch omitted IDEs and utilities (including IntelliJ IDEA, VS Code, Cursor, Herdr, and Hammerspoon). The audit is invoked only by the explicit snapshot command. It reads only the selected window transiently and writes **only normalized tool names and dates** — grouped into categories, with an explicit `Unclassified` section so no discovered tool disappears. It **never** retains raw history lines, command arguments, paths, hostnames, search text, or credentials. If a history source is unavailable, the run reports that limitation while continuing all other discovery.

Candidate configuration content is checked against forbidden paths and common credential patterns before being written into tracked repository content. The safety check **fails closed** when a source cannot be classified.

## Configuration sources

`~/utils` is the source of truth. See [`references/config-sources.md`](references/config-sources.md) for the full mapping table, profile-selector grammar, modes, and sharing rules, and [`references/config-sources.tsv`](references/config-sources.tsv) for the machine-readable version.

Current mappings: `.zshrc` plus its Oh My Zsh framework/plugins, `.zshrc.work` (work profile, sourced by `.zshrc`), `.bashrc`, platform-specific archived `.bashrc0`/`.bashrc0.mac` sources mapped to the active `~/.bashrc0` compatibility path, `.gitconfig` (manual-review), `~/.gitconfig.local` (local, untracked), `.tmux.conf`, Ghostty `ghostty.config` (separate `base@macos` and `base@linux` rows), the versioned kickstart.nvim patch plus `nvim-custom/lua/custom/` overlay, `.vimrc` plus Vundle/plugin bootstrap, `.kubectlAliases`, non-secret GitHub CLI `config.yml` preferences, the work-profile `.local/bin/herdr-title-watch` helper, `.hammerspoon/` (`base@macos`, macOS-only), VS Code settings, Cursor settings/keybindings, curated version-aware IntelliJ editor/UI/terminal options, curated `base@macos` AltTab and Maccy menu-bar preferences restored from `~/utils/macos/menu-bar/` via defaults-domain import, and curated Claude Code and OMP agent preferences (`ai/claude/settings.json` via `json-merge`, `ai/omp/preferences.json` via `omp-merge`) restored from `~/utils/ai/` with timestamped backups and merge/stage preservation. Agent preference sources contain only portable preference keys — no `~/.claude.json`, no Claude plugin/marketplace/session state, no OMP `.env`/MCP secrets/databases/sessions/logs/extensions/provider routing, and no credentials. Authentication for both Claude Code and OMP is a manual handoff.

## Catalog grammar

[`references/tool-catalog.tsv`](references/tool-catalog.tsv) uses a machine-parseable column grammar so future scripts can match profile and platform without relying on prose:

- **`command_candidates`** — a colon-separated (`:`) list of exact command tokens the detector checks (e.g. `git:gst:gco:gd:gp:gl`). An empty field means the tool is detected by application name or config footprint, not by a command.
- **`app_candidates`** — the exact GUI application display name the detector looks for (e.g. `IntelliJ IDEA`, `Cursor`), or empty when the tool has no GUI app to detect. A non-empty value is a single exact token; the detector matches it against macOS `.app` bundle names or Linux `.desktop` entries. This column is a TSV field, so the name must not contain a literal tab; it may contain spaces (e.g. `Visual Studio Code`).
- **`profiles`** — a pipe-separated (`|`) list of direct-membership tokens. Each token is either a bare profile name (`base`, `work`, `mobile`) or a platform-suffixed token (`base@macos`, `mobile@macos`) that applies only on the named platform. A tool listed as `base@macos|base@linux` applies to base on both platforms via separate tokens; a tool listed as `mobile@macos` applies to the mobile profile only on macOS.
- **`config_roots`** — either a single `$HOME`-relative path that applies on every platform (e.g. `.config/nvim`), or a pipe-separated (`|`) list of `platform=path` entries when the config location differs by platform (e.g. `macos=Library/Application Support/com.mitchellh.ghostty/config|linux=.config/ghostty/config`). A single path is valid even when `profiles` spans multiple platforms, as long as the same path applies on all of them; the `platform=path` encoding is required only when paths differ. An empty field means the tool has no declared config root.

Matching rules for scripts:

- A catalog row matches a `--profile`/`--os` request when **at least one** of its `profiles` tokens matches. A bare token matches the profile on any platform; a suffixed token matches only when both profile and platform match.
- **Inheritance:** `base` and `base@platform` entries are inherited by `work` and `mobile` selections, because those profiles layer on top of base. A `--profile work` run matches every `base`/`base@platform` token plus every `work`/`work@platform` token; a `--profile mobile` run matches every `base`/`base@platform` token plus every `mobile`/`mobile@platform` token. `work` and `mobile` tokens are additions, not replacements. This guarantees that a `base@macos` tool such as Homebrew is never omitted on macOS regardless of which profile is selected.
- Platform exclusions are expressed by omission: `hammerspoon` carries only `base@macos`, so it is not a member of base on Linux. `xcode` carries only `mobile@macos`, so it is not a member of mobile on Linux.
- **`config_roots` resolution:** when the field is a single path, it applies on every platform; when it is a `platform=path` list, the snapshot/check script selects the entry whose platform matches `--os`. A single path is valid for multi-platform rows as long as it applies on all of them; the `platform=path` encoding is required only when paths differ, so that no supported snapshot misses its footprint.
- The matching rules are identical for [`config-sources.tsv`](references/config-sources.tsv); see [`references/config-sources.md`](references/config-sources.md) for the selector grammar.

## Inventory categories

The generated inventory groups discoveries so GUI applications and non-package utilities do not disappear simply because they are not package-manager formulae:

- **Applications and IDEs** — IntelliJ IDEA, VS Code, Cursor, Ghostty, and other GUI tools.
- **CLI and shells** — shell, Git, and common CLI utilities.
- **Terminal and session utilities** — Ghostty, tmux, Herdr, OMP, Hammerspoon.
- **AI tools** — Claude Code, Codex, Copilot, OMP integrations.
- **Menu-bar utilities** — AltTab and Maccy, the curated `base@macos` menu-bar preferences. macOS-only; no section renders on Linux.
- **Developer and cloud tools** — Git, GitHub CLI, Homebrew, Devbox, Teleport CLI, kubectl aliases, Bazel.
- **Language and mobile stacks** — Java/jenv, Go, Python, Node/Bun, Android/adb, Xcode/simctl.
- **Configuration sources** — safe presence and version metadata for declared roots.
- **Recent usage** — normalized tool names and dates only, from the bounded seven-day window.
- **Unclassified** — anything that cannot yet be classified; retained for review, never dropped.

## Verification

Use these focused commands:

- `scripts/snapshot.sh --os <macos|linux>` — generate the normalized inventory and recent-usage reports (read-only; never modifies `~/utils` or credential locations).
- `scripts/bootstrap.sh --os <macos|linux> --profile <base|work|mobile> [--utils-path PATH] [--apply]` — dry-run-first profile installer and configuration linker. `base` entries are inherited by `work` and `mobile`; vendor packages and authentication remain manual.
- `bash scripts/tests/test_bootstrap.sh` — exercise dry-run invariants, profile filtering, package-manager arguments, backups, local-file permissions, fail-closed preflight, and redaction.

## Related notes

Related private notes are intentionally not duplicated in public `utils`; see `references/related-notes.md` for their source names.
