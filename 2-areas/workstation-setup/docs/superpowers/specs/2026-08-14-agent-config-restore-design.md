# Portable OMP and Claude Configuration Restore

## Status

Approved design. Implementation is intentionally separate from the completed menu-bar utility restore.

## Goal

Add portable, privacy-safe OMP and Claude preference restoration to the workstation setup kit. A fresh workstation should receive the selected user-facing defaults, while an existing workstation keeps local hooks, plugins, permissions, extensions, provider credentials, and other settings that are not part of the curated preference set.

## Scope

### Included

- A sanitized Claude Code preference template under `~/utils/ai/claude/settings.json`.
- A sanitized OMP preference manifest under `~/utils/ai/omp/preferences.json`.
- Dedicated bootstrap restore paths for the two configuration destinations.
- Timestamped backups under `~/.workstation-setup-backups/<UTC timestamp>/` before replacing an existing destination.
- Merge behavior that updates only the allowlisted portable preferences.
- Dry-run plans, destination safety checks, malformed-source rejection, and focused fixture coverage.
- Documentation and configuration-source metadata for the new mappings.

### Excluded

The setup must not copy or restore:

- Claude authentication, `~/.claude.json`, session files, project history, plugin caches, marketplace caches, downloaded binaries, or credentials.
- Claude hooks, permission allowlists, permission modes, marketplace paths, status-line commands, or absolute paths.
- OMP `.env`, auth-broker tokens, MCP secrets, databases, WAL files, logs, sessions, blobs, model caches, extensions, or managed runtime state.
- OMP provider credentials, provider endpoints, model-role/fallback routing, account-specific model assignments, or internal service configuration.
- Any shell history, terminal history, clipboard data, or project-specific state.

## Portable preference sets

### Claude Code

The curated JSON may contain only these top-level keys:

- `model`
- `autoCompactEnabled`
- `autoCompactWindow`
- `tui`
- `voice`
- `voiceEnabled`

The source validator requires a JSON object, rejects unknown top-level keys, rejects command/path-shaped values, and rejects credential-shaped values. The template contains no `env`, `hooks`, `permissions`, `enabledPlugins`, `extraKnownMarketplaces`, `statusLine`, or login state.

### OMP

The curated JSON is a map from OMP dotted configuration keys to values. The initial allowlist is limited to portable UI and interaction preferences:

- `defaultThinkingLevel`
- `theme.dark`
- `theme.light`
- `symbolPreset`
- `colorBlindMode`
- `statusLine.preset`
- `statusLine.separator`
- `statusLine.sessionAccent`
- `statusLine.compactThinkingLevel`
- `terminal.showProgress`
- `tui.renderMermaid`
- `tui.titleState`
- `display.smoothStreaming`
- `display.showTokenUsage`

Values are restricted to JSON scalar values or arrays accepted by `omp config set`. Keys containing providers, models, credentials, paths, extensions, MCP, sessions, or storage are rejected even when they appear in a source file.

## Destinations and integration

The setup metadata records these mappings as preference restores, not symlinks:

| ID | Source | Destination | Behavior | Profile |
| --- | --- | --- | --- | --- |
| `claude-preferences` | `ai/claude/settings.json` | `.claude/settings.json` | JSON merge | `base` |
| `omp-preferences` | `ai/omp/preferences.json` | `.omp/agent/config.yml` | OMP staged merge | `base` |

The existing catalog roots remain `.claude` and `.omp`; this change adds the actual curated source mappings without treating runtime directories as portable trees.

## Restore algorithm

1. **Preflight source and destination**
   - Resolve each source inside the configured `~/utils` root.
   - Require regular, non-symlink source files.
   - Parse and validate the source against its per-tool allowlist.
   - Resolve the destination inside `$HOME` and reject destination symlinks or ancestors that escape `$HOME`.
   - Validate the timestamped backup target before any write.
   - If an existing destination is present, validate its format before mutation; malformed existing state fails closed.

2. **Back up existing state**
   - Copy an existing Claude settings file to `.workstation-setup-backups/<timestamp>/.claude/settings.json`.
   - Copy an existing OMP config file to `.workstation-setup-backups/<timestamp>/.omp/agent/config.yml`.
   - Do not back up or copy the surrounding runtime directories as part of this feature.

3. **Stage and merge**
   - Claude: merge only the allowlisted top-level keys into a temporary JSON file, preserving all other destination keys, then atomically replace the destination.
   - OMP: copy the existing config into a temporary OMP config root, apply each allowlisted source key with `PI_CODING_AGENT_DIR=<temporary-root> omp config set ...`, validate the staged result, then atomically replace the live `config.yml`.
   - Staging prevents a failed merge from partially updating the live destination.

4. **Unavailable tools**
   - Dry-run always prints the planned preference restore and backup behavior.
   - Apply prints a `FOLLOW_UP` message and leaves the source untouched when the corresponding CLI is unavailable. This is not a bootstrap failure; the user can install/authenticate the tool and rerun the setup.

5. **Reporting**
   - Print `PLAN AGENT_CONFIG` entries during dry-run.
   - Print `AGENT_CONFIG RESTORED <id>` after each successful merge.
   - Print a clear failure for unsafe paths, malformed source/destination JSON, invalid OMP keys/values, backup failures, or staged merge failures.

## Safety invariants

- No source path may escape `~/utils`.
- No destination or backup path may escape `$HOME`.
- Destination symlinks are rejected rather than followed.
- Source templates contain no authentication state, secret values, absolute user paths, or runtime databases.
- Existing unknown settings are preserved by merge; only the documented allowlist is overwritten.
- Staged updates are committed with an atomic same-filesystem rename after backup creation.
- No app is killed, no login is attempted, and no provider credential is generated.

## Tests and acceptance

Focused bootstrap fixtures must prove:

1. Valid Claude preferences merge into a fresh destination.
2. Valid Claude preferences overwrite only allowlisted keys and preserve unknown local keys.
3. Valid OMP preferences merge into an existing config through a fake `omp config set` implementation and preserve unknown local keys.
4. Existing destinations are backed up before replacement.
5. Malformed, unknown-key, path-like, credential-like, and invalid-value sources fail closed without mutation.
6. Existing destination symlinks fail closed without following the link.
7. Missing `claude` or `omp` commands produce manual follow-up output without failing unrelated bootstrap work.
8. Staged merge failures leave the live destinations unchanged.
9. No fixture captures credentials, runtime databases, logs, sessions, or generated state.

The existing `test_check.sh`, `test_bootstrap.sh`, and `test_snapshot.sh` suites must remain passing. Add a source-template parser/privacy check for both new files and update the setup documentation, profile references, and config-source catalog.

## Non-goals

- Installing Claude Code or OMP packages.
- Authenticating either tool.
- Synchronizing plugin marketplaces or skills.
- Restoring MCP server configuration.
- General-purpose configuration synchronization for arbitrary tools.
