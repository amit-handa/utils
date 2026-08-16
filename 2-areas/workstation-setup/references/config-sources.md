# Configuration sources

The existing public dotfiles repository at [`~/utils`](https://github.com/amit-handa/utils) is the **single source of truth** for actual configuration files. Active runtime destinations remain the root-facing `$HOME` paths; most source files live at the utils root, while the superseded Bash sources are stored under `4-archives/` and exposed through root compatibility symlinks. This package never creates a second configuration tree that can drift. The repository stores the mappings below and the rules for applying them safely.

`bootstrap.sh` resolves each mapping's source path relative to `--utils-path` (default `~/utils`) and its destination relative to the target `$HOME`. It validates source existence and destination safety before creating any link, and it backs up an existing destination into a timestamped setup backup directory before replacing it. Without `--apply`, every action is printed as a dry-run plan and nothing is changed.

The machine-readable mapping is [`config-sources.tsv`](config-sources.tsv). Columns are `id`, `source_relative_to_utils`, `destination_relative_to_home`, `mode`, `profile`.

## Profile selector grammar

The `profile` column uses a small, machine-parseable grammar so `bootstrap.sh` and `check.sh` can decide which mappings apply to a given `--os`/`--profile` pair **without relying on prose**:

| Token | Meaning |
| --- | --- |
| `base` | Applies for `--profile base` on **any** platform. |
| `work` | Applies for `--profile work` on **any** platform. |
| `mobile` | Applies for `--profile mobile` on **any** platform. |
| `base@macos` | Applies for `--profile base` **only on macOS** (`--os macos`). |
| `base@linux` | Applies for `--profile base` **only on Debian/Ubuntu** (`--os linux`). |
| `mobile@macos` | Applies for `--profile mobile` **only on macOS**. |

Matching rules for scripts:

- A mapping with a bare profile token (`base`, `work`, `mobile`) applies whenever the requested `--profile` equals that token, regardless of `--os`.
- A mapping with a platform-suffixed token (`profile@platform`) applies only when **both** the requested `--profile` and `--os` match.
- **Inheritance:** `base` and `base@platform` entries are inherited by `work` and `mobile` selections, because those profiles layer on top of base. A `--profile work` run applies every `base`/`base@platform` mapping plus every `work`/`work@platform` mapping; a `--profile mobile` run applies every `base`/`base@platform` mapping plus every `mobile`/`mobile@platform` mapping. `work` and `mobile` tokens are additions, not replacements. These matching rules are identical to the tool-catalog grammar in the [README](../README.md#catalog-grammar).
- A mapping whose profile token does not match the request is skipped (not an error).

This keeps the table at five columns while making platform selection data-driven: the macOS and Linux Ghostty destinations are separate explicit rows rather than a single row with conditional prose.

The tool catalog's `config_roots` column uses a single `$HOME`-relative path when the same path applies on all platforms, or a `platform=value|platform=value` encoding when a tool's config footprint differs by platform (e.g. Ghostty and IntelliJ). See the [README Catalog grammar](../README.md#catalog-grammar) for the `config_roots` resolution rule.

## Modes

- **`symlink`** — the destination is a symlink into `~/utils`. Editing the dotfile updates both trees at once; there is exactly one copy of the file.
  - *bootstrap:* backs up any existing destination into a timestamped setup backup directory, then creates the symlink. Without `--apply`, prints the planned link and makes no change.
  - *check:* verifies the destination is a symlink pointing at the declared `~/utils` source; reports `OK` or `DRIFT` (broken link, wrong target, or missing).

- **`manual-review`** — the source is **never linked or copied automatically**. This mode is required for any tracked file that can carry identity or credential-helper values, because the kit refuses to apply such a file unattended.
  - *bootstrap:* runs the source preflight (see [Git configuration](#git-configuration-tracked-vs-local)). If the preflight fails, reports `UNSAFE` and the offending source path, and skips the mapping entirely. If the preflight passes, reports `MANUAL_REVIEW` with the source and destination paths and instructs the user to link by hand. No symlink or copy is created in either case.
  - *check:* runs the same preflight. If it fails, reports `UNSAFE`. If it passes, reports `MANUAL_REVIEW` (the file is not auto-linked, so check does not assert a symlink target).

- **`local`** — the destination is a **local-only regular file** that is never sourced from `~/utils` and never committed. It holds untracked, user-owned state that must not enter shared history.
  - *bootstrap:* requires the destination path to be outside `~/utils`. If absent, `--apply` creates an empty regular file with user-only permissions. If it exists, bootstrap requires a regular file and rejects symlinks, directories, or paths resolving inside `~/utils` as `UNSAFE`; it never overwrites contents. Without `--apply`, it prints the planned ensure action and makes no change.
- **`json-merge`** — the curated Claude Code preference source is merged into the destination JSON, preserving unknown local keys. The destination is a real file (not a symlink).
  - *bootstrap:* validates the source against a strict six-key allowlist (`model`, `autoCompactEnabled`, `autoCompactWindow`, `tui`, `voice`, `voiceEnabled`), backs up the existing destination into a timestamped setup backup directory, writes a staged merge file, and atomically moves it into place. Curated keys overwrite existing values; unknown local keys are preserved. If `claude` is absent from `PATH` during `--apply`, bootstrap prints `FOLLOW_UP Claude Code: install/authenticate Claude Code, then rerun bootstrap.` and returns success without writing or backing up. Without `--apply`, prints the planned merge and backup path and makes no change.
  - *check:* validates the source against the same allowlist; a symlink or directory at the destination is `UNSAFE`. An absent destination (tool not yet installed) is `OK` — managed state, not a failure. A regular-file destination is `OK`. Source allowlist validation is also exercised by `scripts/tests/test_check.sh` as a standalone privacy check over the curated files.

- **`omp-merge`** — the curated Oh My Pi preference source is staged through `omp config set` against a temporary `PI_CODING_AGENT_DIR`, then atomically installed into the live config. The destination is a real file (not a symlink).
  - *bootstrap:* validates the source against a strict 14-key dotted allowlist (`defaultThinkingLevel`, `theme.dark`, `theme.light`, `symbolPreset`, `colorBlindMode`, `statusLine.preset`, `statusLine.separator`, `statusLine.sessionAccent`, `statusLine.compactThinkingLevel`, `terminal.showProgress`, `tui.renderMermaid`, `tui.titleState`, `display.smoothStreaming`, `display.showTokenUsage`), stages every key/value through `omp config set` in a temporary root, validates the staged result against the curated source via `omp config list --json`, backs up the existing destination with a copy (not move) so a failed final install leaves the live destination intact, then atomically moves the staged config into place. If `omp` is absent from `PATH` during `--apply`, bootstrap prints `FOLLOW_UP OMP: install Oh My Pi, then rerun bootstrap.` and returns success without writing or backing up. Without `--apply`, prints the planned merge and backup path and makes no change.
  - *check:* validates the source against the same allowlist; a symlink or directory at the destination is `UNSAFE`. An absent destination (tool not yet installed) is `OK` — managed state, not a failure. A regular-file destination is `OK`. Source allowlist validation is also exercised by `scripts/tests/test_check.sh` as a standalone privacy check over the curated files.

## Mappings

| ID | Source (in `~/utils`) | Destination (in `$HOME`) | Mode | Profile |
| --- | --- | --- | --- | --- |
| `zshrc` | `.zshrc` | `.zshrc` | symlink | base |
| `zshrc-work` | `.zshrc.work` | `.zshrc.work` | symlink | work |
| `bashrc` | `.bashrc` | `.bashrc` | symlink | base |
| `bashrc0-linux` | `4-archives/.bashrc0` | `.bashrc0` | symlink | base@linux |
| `bashrc0-macos` | `4-archives/.bashrc0.mac` | `.bashrc0` | symlink | base@macos |
| `gitconfig` | `.gitconfig` | `.gitconfig` | manual-review | base |
| `gitconfig-local` | — | `.gitconfig.local` | local | base |
| `tmux` | `.tmux.conf` | `.tmux.conf` | symlink | base |
| `ghostty-macos` | `ghostty.config` | `Library/Application Support/com.mitchellh.ghostty/config` | symlink | base@macos |
| `ghostty-linux` | `ghostty.config` | `.config/ghostty/config` | symlink | base@linux |
| `nvim-custom` | `nvim-custom/lua/custom` | `.config/nvim/lua/custom` | symlink | base |
| `vimrc` | `.vimrc` | `.vimrc` | symlink | base |
| `kubectl-aliases` | `.kubectlAliases` | `.kubectlAliases` | symlink | work |
| `gh-config` | `.config/gh/config.yml` | `.config/gh/config.yml` | symlink | work |
| `herdr-title-watch` | `.local/bin/herdr-title-watch` | `.local/bin/herdr-title-watch` | symlink | work |
| `hammerspoon` | `.hammerspoon` | `.hammerspoon` | symlink | base@macos |
| `vscode-settings-macos` | `ide/vscode/settings.json` | `Library/Application Support/Code/User/settings.json` | symlink | base@macos |
| `vscode-settings-linux` | `ide/vscode/settings.json` | `.config/Code/User/settings.json` | symlink | base@linux |
| `cursor-settings-macos` | `ide/cursor/settings.json` | `Library/Application Support/Cursor/User/settings.json` | symlink | base@macos |
| `cursor-settings-linux` | `ide/cursor/settings.json` | `.config/Cursor/User/settings.json` | symlink | base@linux |
| `cursor-keybindings-macos` | `ide/cursor/keybindings.json` | `Library/Application Support/Cursor/User/keybindings.json` | symlink | base@macos |
| `cursor-keybindings-linux` | `ide/cursor/keybindings.json` | `.config/Cursor/User/keybindings.json` | symlink | base@linux |
| `claude-preferences` | `ai/claude/settings.json` | `.claude/settings.json` | json-merge | base |
| `omp-preferences` | `ai/omp/preferences.json` | `.omp/agent/config.yml` | omp-merge | base |

The legacy Bash startup sources are stored under `4-archives/` because they are superseded runtime material; the root `~/.bashrc0` and `~/.bashrc0.mac` paths remain compatibility symlinks so existing shell startup behavior is unchanged. Bootstrap maps the platform-specific archived source to the active `~/.bashrc0` destination.

The VS Code and Cursor extension manifests under `ide/{vscode,cursor}/extensions.txt` are installed by `bootstrap.sh` when the corresponding CLI is available; otherwise bootstrap reports a follow-up.

IntelliJ uses a version-aware curated restore. `bootstrap.sh` selects the newest installed `IntelliJIdea*` or `IdeaIC*` options directory and copies only the tracked editor, UI, and terminal option files, backing up replaced files under `.workstation-setup-backups/`. Caches, workspace state, credentials, keymaps, and machine-specific plugin state remain untracked.
The `kubectl-aliases` mapping is scoped to the `work` profile. It links the alias file only; it never links `~/.kube/config` or any cluster credential.
`.zshrc.work` contains work-only shell state: AWS profile selection, Kubernetes aliases, DoorDash ETL variables, Devbox/Pedregal helpers, and Herdr workspace hooks. The main `.zshrc` sources it only when the work-profile symlink exists; it contains no credentials or Kubernetes configuration.
`herdr-title-watch` is the portable work-profile helper launched by `.zshrc.work`; its runtime Herdr sockets and session state remain under `~/.config/herdr` and are not tracked.

`gh-config` contains only GitHub CLI preferences and aliases. The authentication file `~/.config/gh/hosts.yml` is intentionally excluded.

Vim is restored as a configuration plus dependency bootstrap: `.vimrc` is linked, then `bootstrap.sh` installs Vundle and runs the declared Vundle plugin installation. The plugin checkout is machine-local state and is never copied into the shared source tree.

The Neovim setup uses a **bootstrap + overlay** model: `bootstrap.sh` clones [`kickstart.nvim`](https://github.com/nvim-lua/kickstart.nvim) into `~/.config/nvim/` once, applies `~/utils/nvim-custom/kickstart.patch` for the small tracked-file customisations, then symlinks `lua/custom/` from `~/utils/nvim-custom/`. Upstream remains a separate Git checkout; user plugins and the explicit upstream patch are versioned in utils. `check.sh` verifies that the patch is applied and that the overlay symlink targets the declared source.

## Agent preferences (Claude Code and OMP)

The curated agent preference sources are real JSON files in the public `~/utils` repository — they are **not symlinks**. They hold only portable, shareable preference keys; authentication, credentials, and runtime state remain machine-local and are never restored.

### Claude Code preferences (`json-merge`)

| Property | Value |
| --- | --- |
| Source | `ai/claude/settings.json` |
| Destination | `.claude/settings.json` |
| Mode | `json-merge` |
| Profile | `base` |

The source contains exactly six keys: `model`, `autoCompactEnabled`, `autoCompactWindow`, `tui`, `voice` (with `enabled`/`mode` sub-keys), and `voiceEnabled`. Bootstrap merges these into the destination JSON, preserving unknown local keys (for example, `permissions`, `customLocalKey`, or plugin/marketplace configuration a user added). Curated keys overwrite existing values; unknown keys are kept. The merge is atomic — a staged file is written and moved into place only after the backup succeeds.

If `claude` is not on `PATH` during `--apply`, bootstrap prints `FOLLOW_UP Claude Code: install/authenticate Claude Code, then rerun bootstrap.` and returns success without writing, backing up, or creating a misleading backup. The user installs and authenticates Claude Code manually, then reruns bootstrap.

### OMP preferences (`omp-merge`)

| Property | Value |
| --- | --- |
| Source | `ai/omp/preferences.json` |
| Destination | `.omp/agent/config.yml` |
| Mode | `omp-merge` |
| Profile | `base` |

The source contains exactly 14 dotted keys: `defaultThinkingLevel`, `theme.dark`, `theme.light`, `symbolPreset`, `colorBlindMode`, `statusLine.preset`, `statusLine.separator`, `statusLine.sessionAccent`, `statusLine.compactThinkingLevel`, `terminal.showProgress`, `tui.renderMermaid`, `tui.titleState`, `display.smoothStreaming`, `display.showTokenUsage`. Bootstrap stages every key/value through `omp config set` against a temporary `PI_CODING_AGENT_DIR` (never the live `~/.omp/agent`), validates the staged result against the curated source via `omp config list --json`, backs up the existing destination with a copy (not move) so a failed final install leaves the live destination intact, then atomically moves the staged config into place. Unknown local keys in the existing config are preserved through the staging copy.

If `omp` is not on `PATH` during `--apply`, bootstrap prints `FOLLOW_UP OMP: install Oh My Pi, then rerun bootstrap.` and returns success without writing, backing up, or creating a misleading backup.

### Privacy boundary

The tracked sources are in a public repository, so they must be safe for public visibility. The source validator rejects:

- any key outside the per-tool allowlist;
- credential-shaped values (strings containing `secret`, `password`, `token`, `apikey`, `api_key`, `credential`, `private_key`, `bearer`, `authorization`);
- absolute paths (values starting with `/` or `~`);
- shell-command-shaped values (containing `;`, `|`, `` ` ``, `$`, `&&`, `(`, `)`);
- bytes values or malformed JSON.

**Explicitly excluded** from the curated sources and from restore: `~/.claude.json` (Claude session/auth state), Claude plugin/marketplace/session state, OMP `.env` files, OMP MCP secrets, OMP databases/sessions/logs/extensions, OMP provider/model routing, and all credentials. These are machine-local and are never collected, copied, or committed. Authentication for both Claude Code and OMP is a manual handoff — the kit never stores tokens, API keys, or login state.

### Dry-run output

Without `--apply`, bootstrap prints `PLAN AGENT_CONFIG claude-preferences -> $HOME/.claude/settings.json` and `PLAN AGENT_CONFIG omp-preferences -> $HOME/.omp/agent/config.yml`. When an existing destination file is present, it also prints `PLAN BACKUP $HOME/.workstation-setup-backups/<UTC timestamp>/<destination>`. Nothing is written and no backup directory is created.

## Git configuration: tracked vs. local

The tracked `~/utils/.gitconfig` **must be identity-free and must not configure any credential helper**. It must not contain `user.name`, `user.email`, `user.signingkey`, any `[credential]` section, any URL-scoped `[credential "https://..."]` section, or any `credential.helper` key — wherever it appears. Those values are machine-local and must never enter the shared repository. The existing public `~/utils/.gitconfig` is known to carry identity, a hard-coded credential-helper path, and URL-scoped credential helper sections, so it is **not** linked automatically — see the `manual-review` mode below.

The tracked `.gitconfig` should include the local file instead:

```gitconfig
[include]
    path = ~/.gitconfig.local
```

Each machine keeps its identity and credential helper in `~/.gitconfig.local` (the `gitconfig-local` mapping, mode `local`). That file is never sourced from `~/utils`, never committed, and never overwritten by bootstrap. You set it manually — for example, identity:

```gitconfig
[user]
    name = Your Name
    email = you@example.com
```

Any `credential.helper` setting also belongs in `~/.gitconfig.local`, never in the tracked source. The kit does not prescribe a specific helper value; choose the one appropriate for your platform and store it only in the untracked local file.

**Preflight rejection (fails closed):** before doing anything with the `gitconfig` mapping, `bootstrap.sh` and `check.sh` must scan the tracked `~/utils/.gitconfig`. The scan must reject **all** identity and credential-helper forms, not just the top-level ones. If the source contains any of the following, the run **fails closed** — no link or copy is created and the tool reports the offending source path:

- a `[user]` section (or any `[user ...]` subsection) with `name`, `email`, or `signingkey`;
- any `[credential]` section, regardless of whether it contains a `helper` key;
- any URL-scoped `[credential "https://..."]` or `[credential "ssh://..."]` section, regardless of whether it contains a `helper` key;
- any `credential.helper` key, wherever it appears (redundant with the section rejection above, but explicit for safety);
- any `credential` helper value that is a machine-specific absolute path (e.g. a hard-coded `/usr/local/...` or `/opt/...` helper binary).

The scan must parse the Git config section structure, not just grep for the literal string `credential.helper`, so that any `[credential]` or `[credential "..."]` section is caught by its header — even when the section body has no `helper` key or the section header and its keys are on different lines.

**Test requirement:** `scripts/tests/test_bootstrap.sh` must include fixture `.gitconfig` files that assert the preflight rejects: (a) a URL-scoped `[credential "https://example.invalid"]` section with a `helper` key, and (b) a `[credential]` section with no `helper` key (e.g. only a `username` key). It must also assert that a `local` destination symlinked into the utils repository is rejected as `UNSAFE`. All fixtures use placeholder values and contain no real hostname, token, or concrete helper value.

Because the `gitconfig` mapping uses `manual-review` mode, even a passing preflight does **not** auto-link: bootstrap prints the reviewed source and destination and instructs the user to link by hand. The preflight exists so that a source carrying identity or auth is never applied silently, reviewed or not.

Do **not** set Git identity or credential helpers in the tracked source. If your working copy of `~/utils/.gitconfig` currently carries them, remove them and move them into `~/.gitconfig.local` before committing or sharing. The kit never modifies the public `~/utils` repository for you.

## Menu-bar utility preferences (macOS, defaults-domain import)

The curated macOS menu-bar utilities — AltTab and Maccy — are **not** part of `config-sources.tsv`. They are not symlinked dotfiles; they are curated preference templates imported into each app's `defaults` domain by the dedicated `restore_menu_bar_settings()` step in `bootstrap.sh`. This keeps the symlink-vs-local-vs-manual-review table above purely about dotfile mappings while the defaults-domain restore is documented here.

### Source templates

| ID | Source template (in `~/utils`) | Defaults domain | Live defaults path (logical destination under `$HOME`) |
| --- | --- | --- | --- |
| `alt-tab` | `macos/menu-bar/alt-tab/preferences.plist` | `com.lwouis.alt-tab-macos` | `Library/Preferences/com.lwouis.alt-tab-macos.plist` |
| `maccy` | `macos/menu-bar/maccy/preferences.plist` | `org.p0deje.Maccy` | `Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist` |

AltTab's domain lives at the conventional `~/Library/Preferences/` location. Maccy is **sandboxed**, so its defaults store is the container path `~/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist` — not `~/Library/Preferences/org.p0deje.Maccy.plist`. The catalog's `config_roots` column records these exact paths so snapshot detection and the restore destination agree.

### Defaults export/import restore and backup

Restore is `defaults`-domain export/import — it never moves or copies `$HOME/Library/Preferences` files directly:

1. **Source validation** — each template is resolved inside `~/utils` (`validate_source`) and parsed with Python `plistlib`; every key is checked against a per-app allowlist. AltTab retains only window-switcher options; Maccy retains only keyboard-shortcut, pasteboard-type, and display options. An unapproved key, malformed plist, bad shortcut value, or bad pasteboard-type value fails closed (`invalid menu-bar plist`) and **no** import runs for that domain.
2. **Destination validation** — the logical destination path is validated (`validate_destination`); a symlink at the destination is rejected as `UNSAFE` on apply (dry-run emits `PLAN REVIEW … is a symlink; resolve manually before apply`).
3. **Live-domain probe** — `defaults domains` is probed for each domain. A present domain is backed up with `defaults export <domain> <path>`; an absent domain with a regular file at the logical destination is copied. A `defaults domains` failure (return status 2) aborts before any import. If `defaults` is unavailable, dry-run still plans the restore without probing backups.
4. **Timestamped logical backup path** — backups land under `~/.workstation-setup-backups/<UTC timestamp>/<relative destination>`, e.g. `~/.workstation-setup-backups/20260101T000000Z/Library/Preferences/com.lwouis.alt-tab-macos.plist` or `…/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist`. The backup target is validated (`validate_backup_target`) before any write.
5. **Import** — `defaults import <domain> <template>` writes the curated preferences into the app's defaults domain. On success bootstrap prints `MENU_BAR RESTORED <id>`.

### No app-killing

`restore_menu_bar_settings()` never kills AltTab or Maccy. `defaults import` writes the defaults database; the app reads curated preferences on its next launch. Quit AltTab/Maccy before a live `--apply` if you want imported preferences to take effect immediately — this is a manual handoff documented in [`profiles/macos.md`](../profiles/macos.md).

### Source/destination safety

The same invariants as the symlink mappings apply: sources must be regular files inside the configured `~/utils` root; destinations must stay within `$HOME`; symlink destinations are rejected on apply; and every backup target is validated. The restore writes only to the two declared defaults domains and the timestamped backup directory — nothing under `/usr`, `/System`, `/Library`, or outside `$HOME`.

### Public-repository privacy boundary

`~/utils` is a public repository, so the tracked templates must be safe for public visibility. Before committing, each template must parse as a property list and contain **only** the allowlisted keys — no telemetry identifiers (`MSAppCenter*`, `SU*`), no window geometry (`NSWindow Frame *`), no `preferencesVersion`/`migrations`/`windowSize`, no clipboard-history or pasteboard contents (only the *types* Maccy may accept), no credentials, no device history, and no absolute paths. Raw exports from `~/Library/Preferences` MUST NOT be committed. See [`profiles/macos.md`](../profiles/macos.md) for the manual Accessibility/Screen Recording permission handoffs and the full exclusion list (clipboard history, Keychain/login state, permissions, runtime/container state, and unselected agents/utilities).

## What is excluded

Secrets and authenticated state are **never** collected, copied, generated, or committed by setup automation. Concretely, the kit does not touch:

- `~/.ssh` private keys and agent state
- `~/.aws` credentials and profiles
- `~/.kube/config` and cluster credentials
- Docker authentication files
- `.env*`, `.netrc`, `.npmrc` tokens, and other secret files
- Keychain contents, browser cookies, application login data, and session caches
- API tokens, private keys, certificates, and password files
- hostnames, usernames, absolute personal paths, and machine identifiers
- tool caches, logs, lock files, databases, and generated application state
- `~/.claude.json` and Claude plugin/marketplace/session state (only portable preference keys in `ai/claude/settings.json` are restored)
- OMP `.env` files, MCP secrets, databases, sessions, logs, extensions, and provider/model routing (only portable preference keys in `ai/omp/preferences.json` are restored)

Candidate configuration content is checked against forbidden paths and common credential patterns before it is written into tracked repository content. The safety check fails closed when a source cannot be classified.
