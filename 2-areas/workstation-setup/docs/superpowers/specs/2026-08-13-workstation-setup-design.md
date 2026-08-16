# Workstation Setup Kit

## Context

The vault at `the private notes vault` is a Git-synced, private repository with a growing `knowledge/` area. Workstation setup information is currently split between vault notes and the existing public dotfiles repository at `~/utils` (`https://github.com/amit-handa/utils`). The dotfiles repository contains shell, Git, tmux, Ghostty, Neovim, kubectl, and Hammerspoon configuration. The vault also contains tool-specific notes, including terminal workflows, editor setup, Android tooling, iOS simulator workflows, and document tooling.

The goal is a shareable developer-workstation setup kit that is useful for two scenarios:

1. Migrating Amit's setup to another Mac or Debian/Ubuntu Linux machine.
2. Giving teammates a safe, understandable baseline without exposing credentials or machine-specific state.

The kit must stay current through an explicit snapshot workflow. It must not silently collect home-directory state or create a second source of truth for dotfiles.

## Goals

- Provide one vault landing page for workstation setup and migration.
- Inventory all developer-workstation tools across GUI apps and IDEs, CLI and session tools, shell utilities, AI tools, language and mobile stacks, and configuration-backed utilities.
- Capture recent usage evidence separately from installed state, with an unclassified review section so no discovered tool disappears.
- Record observed tools and versions without treating every installed item as desired state.
- Maintain curated, cross-platform desired profiles for base, work, and optional mobile tooling.
- Keep actual dotfiles in `~/utils` as the single configuration source.
- Reproduce declared setup through dry-run-first bootstrap and explicit symlink mappings.
- Support macOS and Debian/Ubuntu Linux with platform-specific manifests.
- Make shared content safe by default through path exclusions, normalization, and secret checks.
- Link existing vault notes from the landing page instead of duplicating their content.

## Non-goals

- Capturing or restoring credentials, cookies, tokens, private keys, Keychain contents, cloud profiles, Kubernetes contexts, or authenticated application state.
- Reproducing every macOS preference, GUI application setting, cache, database, or project-local environment.
- Supporting every Linux distribution in the first version. The first Linux implementation targets Debian/Ubuntu package management.
- Replacing `~/utils` or copying its files into a second configuration tree.
- Installing or configuring work authentication automatically.
- Running a background watcher or scheduled collector.
- Persisting raw shell-history lines or command arguments. Recent-usage extraction retains only normalized tool names and dates.

## Design decisions

### Vault as the setup hub, `~/utils` as the dotfiles source

The vault package owns setup intent, profile documentation, manifests, migration instructions, inventory generation, and orchestration scripts. Snapshot reports remain external generated artifacts; the existing `~/utils` repository remains the source of truth for actual dotfiles. This avoids duplicate configuration files that can drift.

The vault documents each managed configuration file in a mapping table:

| Tool | Source | Destination | Management | Sharing rule |
| --- | --- | --- | --- | --- |
| zsh | `~/utils/.zshrc` | `~/.zshrc` | Explicit symlink | Share only after secret scan |
| bash | `~/utils/.bashrc` | `~/.bashrc` | Explicit symlink | Share only after secret scan |
| Git | `~/utils/.gitconfig` | `~/.gitconfig` | Explicit symlink or reviewed copy | Identity values remain local |
| tmux | `~/utils/.tmux.conf` | `~/.tmux.conf` | Explicit symlink | Shareable after review |
| Ghostty | `~/utils/ghostty.config` | Platform-specific Ghostty path | Explicit mapping | Shareable after review |
| Neovim | `~/utils/init.lua` | User-selected Neovim path | Explicit mapping | Shareable after review |
| kubectl | `~/utils/.kubectlAliases` | User-selected shell include path | Explicit mapping | No cluster or credential data |
| Hammerspoon | `~/utils/.hammerspoon/` | `~/.hammerspoon/` | Explicit symlink | Share only code, never machine state |

The implementation must discover the final destination paths from the documented mapping rather than guessing from filenames. Existing local changes in `~/utils` are outside the scope of the first vault change and must not be overwritten.

### Observed state versus desired state

The generated inventory answers "what is installed on this machine?" The curated manifests answer "what should a new machine install?" The distinction prevents accidental dependencies, caches, and one-off experiments from becoming migration requirements.

Inventory output is generated outside the repository and reviewable before sharing. Desired manifests are curated and edited intentionally. A tool can appear in inventory without appearing in a desired profile.

### Shareable by default

The setup kit may name work tools such as Devbox, Teleport CLI, Kubernetes tooling, Bazel, and GitHub CLI. It must not include work endpoints, user identifiers, credentials, tokens, cluster names, or private configuration values. Authentication is always a documented manual handoff.

## Package layout

The implementation adds this package to the vault:

```text
2-areas/workstation-setup/
├── README.md
├── profiles/
│   ├── base.md
│   ├── work.md
│   ├── mobile.md
│   ├── macos.md
│   └── linux-debian.md
├── manifests/
│   ├── common.txt
│   ├── macos/Brewfile
│   ├── linux/apt-packages.txt
│   └── runtimes.txt
├── references/
│   ├── config-sources.md
│   └── related-notes.md
└── scripts/
    ├── snapshot.sh
    ├── bootstrap.sh
    └── check.sh
```

`README.md` is the landing page. It contains the migration path, profile selection, update loop, safety rules, prerequisites, and links to all package members.

`profiles/` explains the intent and package groups. `base` is the default developer profile. `work` and `mobile` are opt-in. `macos` and `linux-debian` describe platform-specific differences and prerequisites.

`manifests/` contains machine-readable desired package sets. `common.txt` is line-oriented and shared across platforms. `Brewfile` is the macOS Homebrew manifest. `apt-packages.txt` is the Debian/Ubuntu package list. `runtimes.txt` records intentionally managed language runtimes and constraints without locking transient dependency trees.

`references/` maps setup entries to their true sources and consolidates links to existing notes. It is documentation, not another configuration directory.

By default, `snapshot.sh` writes `current-machine.md` and `recent-usage.md` under `$HOME/.workstation-setup/inventory/`; `--output-dir` selects another safe external directory. These reports are not committed under `~/utils`. `current-machine.md` is normalized so it does not contain usernames, hostnames, absolute home paths, or credential values; it covers installed applications, package entries, runtimes, configuration footprints, and classification status.

`recent-usage.md` is generated by the same command from a bounded usage window. It records normalized tool names and dates only, grouped into categories, and preserves an explicit unclassified section for review.

`scripts/` contains the only automation in this package. Scripts use explicit mappings and profile inputs; they do not recursively copy home directories.

## Inventory completeness and discovery sources

"All tools" means coverage across independent evidence sources, not a single package-manager dump. Every discovered item receives a display name, category, evidence source, observed or installed status, and a desired-profile classification. Items that cannot yet be classified remain in an `Unclassified` section instead of being dropped.

`snapshot.sh` combines these sources:

1. Package managers: Homebrew formulae and casks, Debian/Ubuntu packages, and available global package managers such as npm, pipx, Go, and Cargo.
2. Applications and IDEs: macOS application bundles and package-manager casks, plus Linux desktop entries and installed packages. This explicitly covers IntelliJ IDEA, Visual Studio Code, Cursor, Ghostty, and other GUI tools even when they were not launched from a shell.
3. Recent usage: a bounded default window of the last seven days from shell history, reduced transiently to normalized executable or alias names and dates. Raw lines, arguments, paths, hostnames, and search text are never retained.
4. Configuration footprints: safe presence and version metadata for declared roots such as `~/utils`, `~/.hammerspoon`, `~/.config/nvim`, `~/.config/zed`, `~/.cursor`, `~/.vscode`, `~/.claude`, `~/.codex`, and `~/.omp`. The collector does not read credential or session contents.
5. Runtimes and SDKs: selected versions for Java/jenv, Go, Python, Node/Bun, Android/adb, Xcode/simctl, and other intentionally managed toolchains.

The seed catalog must check, classify, and report at least these categories and examples:

- IDEs and editors: IntelliJ IDEA (`idea`), Visual Studio Code (`code`), Cursor (`cursor`), Neovim, and Vim.
- Terminal, session, and window utilities: Ghostty, tmux, Herdr, OMP, Hammerspoon, and the modules under `~/utils/.hammerspoon`.
- AI clients and coding agents: Claude Code, Codex, Copilot, and OMP integrations.
- Developer and work CLI tools: Git, GitHub CLI, Homebrew, Devbox, Teleport CLI (`tsh`), kubectl aliases such as `k`, `kgpo`, and `kgcmoyaml`, and Bazel.
- Language and mobile tooling: Java/jenv, Go, Python, Node/Bun, npm, Android/adb, and Xcode/simctl.

The generated inventory uses sections for Applications and IDEs, CLI and shells, terminal and session utilities, AI tools, developer and cloud tools, language and mobile stacks, configuration sources, recent usage, and Unclassified discoveries. This prevents GUI applications and utilities such as Hammerspoon from disappearing simply because they are not package-manager formulae.

## Interfaces and behavior

### `snapshot.sh`

Purpose: capture a normalized inventory and config-source state.

Inputs:

- `--os macos|linux`
- optional `--since`, defaulting to the last seven days for recent-usage extraction
- optional `--output-dir`, defaulting to `$HOME/.workstation-setup/inventory/`; output paths inside `~/utils` are rejected
- optional `--utils-path`, defaulting to `~/utils`

Behavior:

- Detect Homebrew formulae and casks on macOS when Homebrew is available.
- Detect macOS application bundles and Linux desktop entries so GUI tools and IDEs are inventoried even when package-manager metadata is absent.
- Detect Debian/Ubuntu packages through `apt`/`dpkg` on Linux when available.
- Detect selected globally installed developer tools from available package managers, including npm, pipx, Go, and Cargo where present.
- Record selected runtime versions, such as Java, Go, Node/Bun, and Python, without capturing runtime caches.
- Record the `~/utils` repository revision, safe configuration footprints, and checksums for declared configuration sources.
- Read the bounded recent-usage window transiently and retain only normalized tool names and dates. If a history source is unavailable, report that limitation while continuing all other discovery sources.
- Normalize user-specific paths and machine identity.
- Place every discovery item into a category or an explicit `Unclassified` section.
- Refuse to read declared forbidden paths.
- Write only the two inventory outputs under the selected external output directory; it does not modify `~/utils`, install packages, or create symlinks.

### `bootstrap.sh`

Purpose: apply a declared profile to a new or existing machine.

Inputs:

- `--os macos|linux`
- `--profile base|work|mobile`
- optional `--utils-path`
- optional `--apply`; without it, the command is a dry run

Dry-run behavior:

- Resolve the selected manifests and configuration mappings.
- Print package, link, backup, and manual-authentication actions.
- Make no filesystem, package-manager, or repository changes.

Apply behavior:

- Install only packages declared by the selected profile and platform manifest.
- Verify the dotfiles source exists and passes the safety preflight.
- Back up an existing destination into a timestamped setup backup directory before replacing it.
- Create only declared symlinks or mappings.
- Never overwrite an existing file without a backup.
- Never install credentials or authenticated state.
- Print manual follow-up steps for GitHub, cloud, Teleport, Devbox, Xcode, Android SDK, or other authentication/licensing actions as applicable.

### `check.sh`

Purpose: report whether the current machine matches a selected profile.

Inputs:

- `--os macos|linux`
- `--profile base|work|mobile`
- optional `--utils-path`

Behavior:

- Verify required binaries and declared package entries.
- Verify declared symlink targets and configuration checksums.
- Verify the expected dotfiles repository revision or report drift.
- Report missing packages, broken links, unmanaged destinations, and config drift with actionable paths.
- Return success only when all required checks pass; return a non-success status for drift or unsafe input.
- Never change the machine.

## Profiles and platform support

The first release supports macOS and Debian/Ubuntu Linux. It does not claim generic support for Fedora, Arch, or other distributions.

The base profile covers the common developer workstation: shell, Git, tmux, selected IDEs and editors, terminal and window utilities, common CLI utilities, AI clients, and intentionally managed language runtimes. The work profile adds work-oriented developer commands such as Devbox, Teleport CLI, Kubernetes tooling, Bazel, GitHub CLI, and Herdr when selected, without authentication state. The mobile profile is optional and points to the existing Android and iOS setup documentation; it may install prerequisites but does not restore simulator/device state.

Discovery does not automatically promote an application or command into a desired profile. The inventory is the complete review surface; profile membership remains an intentional change.

Each profile is composed from common entries plus an OS-specific manifest. If package names differ, the platform manifest provides the mapping instead of forcing one package name across systems.

The inventory may report additional tools used on the current laptop, including AI, IDE, Android, iOS, and internal developer utilities. Promoting an observed tool into a desired profile requires an intentional manifest change.

## Security and privacy boundaries

The following are never collected, copied, generated, or committed by setup automation:

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

When recent-usage mode is enabled, the scanner may read the bounded history window transiently, but it retains only normalized tool names and dates. It must discard the source line and arguments before writing output. Candidate configuration content is checked against forbidden paths and common credential patterns before being written into tracked setup content. The safety check fails closed when a source cannot be classified. A public source repository is treated as shareable only after this check passes.

Authentication and authorization are manual steps. The kit can document the command or service needed, but it never stores the resulting secret or authenticated state.

## Update and sharing workflow

After installing, removing, or intentionally changing a developer tool:

1. Run `snapshot.sh` for the current platform. The default recent-usage window is the last seven days.
2. Review both `current-machine.md` and `recent-usage.md`, including the `Unclassified` section.
3. Add intentional tools to the appropriate desired profile or manifest.
4. Update the configuration mapping or related-note links if needed.
5. Run the dry-run bootstrap and `check.sh`.
6. Commit the package and runtime configuration changes in `~/utils`.
7. Push the vault repository so the central setup page stays current.

There is no background watcher in the first release. The explicit snapshot command is the update boundary and keeps changes reviewable. A missing package-manager entry does not remove a tool from the inventory because application, usage, and configuration discovery remain independent.

Teammates can read the vault landing page, choose a profile, and use the public `utils` source when appropriate. The setup package remains useful without Amit's personal values because shared instructions contain only tool intent, package names, sanitized templates or links, and manual authentication handoffs.

## Existing-note cross-references

The landing page must link to, rather than duplicate, the current related material:

- [[knowledge/tools|Tool notes]]
- [[knowledge/ides/cursor-setup-pedregal|Cursor setup for Pedregal]]
- [[knowledge/android-dev-tooling|Android development tooling]]
- [[knowledge/ios-simulator-workflow|iOS simulator workflow]]
- [Recent terminal workflows](../../../references/related-notes.md)
- [[knowledge/ai/pi-ide-bridge-fix|Pi IDE bridge troubleshooting]]
- [[tools/gdoc-md|Google Docs Markdown tooling]]
- [Existing dotfiles source](https://github.com/amit-handa/utils)

## Alternatives considered

### Duplicate sanitized configuration into the vault

Rejected. It would create two sources of truth for shell, editor, terminal, and automation configuration. The vault will document and orchestrate `~/utils` instead.

### Create a separate setup repository

Rejected for the first release. A second repository would add another synchronization boundary and make the vault less central. The existing dotfiles repository already provides the code-oriented source; the vault can remain the setup control plane.

### Documentation and manifests only

Rejected as the complete solution. Documentation alone leaves migration manual and makes drift difficult to detect. The explicit snapshot, dry-run bootstrap, and check commands provide the minimum automation needed for repeatable migration without silent changes.

## Verification requirements

The implementation is complete only when all of the following are demonstrated:

- The package README points to every package member, existing related note, and configuration source.
- Inventory fixtures cover package-manager entries, application/IDE entries, configuration footprints, normalized recent-usage input, and an unclassified discovery.
- The seed catalog explicitly checks IntelliJ IDEA, Visual Studio Code, Cursor, Herdr, Hammerspoon, OMP, terminal/session utilities, and the other named tool categories.
- Snapshot output is reproducible enough for review and contains no forbidden values, raw history lines, command arguments, or paths.
- Profile manifests parse successfully for macOS and Debian/Ubuntu fixtures.
- Bootstrap dry-run produces a plan and leaves a temporary test home unchanged.
- Bootstrap apply creates declared mappings and backs up pre-existing destinations.
- Check detects both a compliant fixture and deliberate package/link/config drift.
- A recent-usage run stores only normalized tool names and dates and reports unavailable sources without failing unrelated discovery.
- A full run on the current Mac completes without modifying `~/utils` or credential locations.
- The vault change is committed with the required Oh My Pi co-author trailer and pushed through the vault's existing Git sync.
