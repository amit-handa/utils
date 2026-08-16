# Base profile

The **base** package profile is the default developer workstation. It covers shell, Git, tmux, selected IDEs and editors, terminal and window utilities, common CLI utilities, AI clients, and intentionally managed language runtimes. It is separate from the optional `WORKSTATION_PROFILE` environment selector: `personal` selects the desktop-oriented mapping set, `server` selects the shell/editor subset, and `work` selects the personal-compatible set plus work mappings. Every other package profile composes on top of base.

## Included catalog IDs

From [`references/tool-catalog.tsv`](../references/tool-catalog.tsv), the base profile includes:

- **IDEs and editors:** `intellij`, `vscode`, `cursor`, `neovim`, `vim`
- **Terminal, session, and window utilities:** `ghostty`, `tmux`, `hammerspoon`
- **AI clients and coding agents:** `omp`, `claude-code`, `codex`, `copilot`
- **Developer CLI:** `git`
- **Package managers:** `npm`, plus `brew` on macOS (`base@macos`)
- **Runtimes:** `java`, `go`, `python`, `node`

These IDs are kept in the catalog even when a detector reports a given tool as not installed on a machine. Presence in the catalog means "this is a tracked tool whose state should be reported", not "this must be installed".

## Platform prerequisites

- **macOS:** Homebrew (`brew`) is the package manager. See [macOS profile](macos.md) for application-bundle, cask, and Hammerspoon behavior.
- **Debian/Ubuntu:** `apt`/`dpkg` is the package manager. See [Debian/Ubuntu profile](linux-debian.md) for desktop-entry and package-name differences.

Platform manifests in `manifests/macos/Brewfile` and `manifests/linux/apt-packages.txt` provide the exact package names per platform.

## Configuration sources

Base maps these dotfiles from `~/utils` into `$HOME` when their package/profile and selected environment profile both match (see [`references/config-sources.md`](../references/config-sources.md)):

## Configuration environments

The `base` value passed to `--profile` selects packages and package-profile mappings; it does not mean that the machine is a personal desktop. Use the optional `WORKSTATION_PROFILE` selector for the configuration set:

- `WORKSTATION_PROFILE=personal` enables personal desktop mappings, including GUI settings, Hammerspoon, and portable Claude Code/OMP preferences.
- `WORKSTATION_PROFILE=server` enables only the shell/editor subset needed on a server and excludes GUI, Hammerspoon, AI-agent, and work mappings. Bootstrap skips menu-bar, IntelliJ, and IDE-extension actions for this environment.
- `WORKSTATION_PROFILE=work` enables mappings declared for both `personal` and `work`, including work aliases, GitHub CLI preferences, and the Herdr helper. Authentication remains manual.

Unset `WORKSTATION_PROFILE` preserves the legacy behavior. Platform constraints such as `base@macos` and `base@linux` remain enforced for every environment.


- `.zshrc`, `.bashrc`, `.tmux.conf`
- `.gitconfig` — `manual-review` mode; bootstrap prints it for hand-linking after preflight, never auto-links (the tracked source must be identity-free and must not contain any credential helper, including URL-scoped sections).
- `~/.gitconfig.local` — `local` mode; untracked, holds identity and credential helper, never sourced from `~/utils`.
- Ghostty `ghostty.config` — separate `base@macos` and `base@linux` mapping rows.
- Neovim via kickstart.nvim — bootstrap clones upstream kickstart into `~/.config/nvim/`, applies the versioned `~/utils/nvim-custom/kickstart.patch`, then symlinks `lua/custom/` from `~/utils/nvim-custom/`. Upstream and user-owned changes stay separate. See [`references/config-sources.md`](../references/config-sources.md).
- `.hammerspoon/` — `base@macos`, macOS-only, in the `personal|work` environments.
- Claude Code preferences — `json-merge` mode; `ai/claude/settings.json` is merged into `~/.claude/settings.json`, preserving unknown local keys. The source contains only six portable keys (`model`, `autoCompactEnabled`, `autoCompactWindow`, `tui`, `voice`, `voiceEnabled`) and belongs to the `personal|work` environments. If `claude` is absent during apply, bootstrap prints a follow-up and does not write. See [`references/config-sources.md`](../references/config-sources.md).
- OMP preferences — `omp-merge` mode; `ai/omp/preferences.json` is staged through `omp config set` into `~/.omp/agent/config.yml`, preserving unknown local keys. The source contains only 14 portable dotted keys and belongs to the `personal|work` environments. If `omp` is absent during apply, bootstrap prints a follow-up and does not write. See [`references/config-sources.md`](../references/config-sources.md).

## Manual authentication and licensing handoffs

The kit **never** installs credentials or authenticated state. Complete these manually after bootstrap:

- **IDEs:** sign in to IntelliJ IDEA, VS Code, and Cursor accounts; accept licenses for IntelliJ IDEA.
- **AI clients:** authenticate Claude Code, Codex, Copilot, and OMP per their own login flows. The curated preference sources (`ai/claude/settings.json`, `ai/omp/preferences.json`) contain only portable preference keys — they never store tokens, API keys, or login state. `~/.claude.json` (session/auth state), Claude plugin/marketplace/session state, OMP `.env` files, MCP secrets, databases, sessions, logs, extensions, and provider/model routing are explicitly excluded from restore and remain machine-local.
- **Git:** set `user.name`, `user.email`, `user.signingkey`, and any credential helper in **`~/.gitconfig.local`** (untracked, never committed). The tracked `~/utils/.gitconfig` must be identity-free and must not contain any credential helper — including URL-scoped `[credential "https://..."]` sections; bootstrap's preflight rejects any source containing `[user]` identity, any `[credential]` or `[credential "..."]` section, or any `credential.helper` key. See [Configuration sources](../references/config-sources.md).
- **Homebrew / npm:** no auth for Homebrew; run `npm login` only if you publish packages.

## What this profile does not restore

- No credentials, tokens, private keys, Keychain contents, or cloud profiles.
- No IDE project state, window layouts, recent-projects lists, or plugin accounts.
- No Git identity values (name/email/signing key) from the shared repository.
- No Kubernetes contexts, cluster credentials, or `~/.kube/config`.
- No shell history, command arguments, or search text (recent usage is normalized separately — see the [Privacy boundary](../README.md#privacy-boundary)).
- No `~/.claude.json`, Claude plugin/marketplace/session state, OMP `.env` files, MCP secrets, databases, sessions, logs, extensions, or provider/model routing — only portable preference keys are restored.
