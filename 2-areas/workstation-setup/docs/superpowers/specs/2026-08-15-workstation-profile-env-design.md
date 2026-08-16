# Workstation Configuration Environment Profiles

## Status

Approved design for implementation.

## Context

`bootstrap.sh` and `check.sh` currently select package/profile inheritance with the required `--profile base|work|mobile` argument. Configuration mappings in `references/config-sources.tsv` use the same selector. That selector cannot express the desired machine roles:

- `personal` — the personal desktop configuration set.
- `server` — a minimal non-GUI server configuration set.
- `work` — personal configuration plus work-only configuration.

A machine-role selector must not replace the existing package profile model or create copied configuration trees.

## Goals

- Add an optional `WORKSTATION_PROFILE` environment variable with exactly three values: `personal`, `server`, and `work`.
- Select configuration mappings declaratively from metadata.
- Keep existing `--profile base|work|mobile` package selection and behavior backward-compatible.
- Make `server` exclude GUI, Hammerspoon, AI-agent, and work-auth mappings.
- Fail closed on invalid environment-profile values before any mutation.
- Keep the implementation Bash 3.2-compatible and free of `eval` or path interpolation.

## Non-goals

- Changing shell startup behavior in `.zshrc` or `.bashrc`.
- Selecting package manifests from `WORKSTATION_PROFILE`.
- Adding copied or duplicated per-role dotfile trees.
- Managing credentials, work authentication, or server secrets.
- Renaming the existing `base`, `work`, or `mobile` package profiles.

## Design

### Separate selectors

`--profile` remains the package/profile selector. It is still required by both scripts and continues to control package manifests and the existing profile inheritance rules.

`WORKSTATION_PROFILE` is an optional configuration-set selector. When unset, mapping selection uses the existing `profile` column exactly as before. When set, mapping selection uses the new `environment_profiles` column instead of the existing mapping-profile filter. This lets an explicit machine role select its configuration set without changing package installation behavior.

Examples:

```bash
# Existing behavior; no environment filter.
bash scripts/bootstrap.sh --os macos --profile base --utils-path "$HOME/utils"

# Minimal server configuration, with the existing base package manifest.
WORKSTATION_PROFILE=server \
  bash scripts/bootstrap.sh --os linux --profile base --utils-path "$HOME/utils"

# Work configuration set, regardless of whether the package profile is base or work.
WORKSTATION_PROFILE=work \
  bash scripts/check.sh --os macos --profile work --utils-path "$HOME/utils"
```

The environment selector is read from `${WORKSTATION_PROFILE:-}`. Empty means unset. Any non-empty value outside the allowlist is an argument error. The value is never used as a path or shell expression.

### Mapping metadata

Extend `references/config-sources.tsv` with a sixth column:

```text
id  source_relative_to_utils  destination_relative_to_home  mode  profile  environment_profiles
```

`environment_profiles` is a pipe-separated allowlist containing one or more of `personal`, `server`, and `work`. It is required for every mapping row and is validated independently from the existing package-profile grammar.

The intended sets are:

| Environment profile | Included configuration mappings |
| --- | --- |
| `personal` | Base shell, Bash compatibility, Git manual-review/local state, tmux, Neovim/Vim, Ghostty, Hammerspoon, VS Code, Cursor, Claude, and OMP mappings. Work-only mappings are excluded. |
| `server` | `.zshrc`, `.bashrc`, platform Bash compatibility, Git manual-review/local state, tmux, Neovim/Vim, and `nvim-custom`. No GUI, Hammerspoon, AI-agent, or work mappings. |
| `work` | All `personal` mappings plus Kubernetes aliases, GitHub CLI config, and Herdr. |

Platform-specific rows retain their existing `profile` column constraints. For example, `bashrc0-linux` is available only on Linux even when `environment_profiles` includes all three roles.

### Script behavior

Both scripts add the same validation and filtering primitives:

1. Read and validate `WORKSTATION_PROFILE` before preflight or filesystem mutation.
2. Parse the six-column mapping row and validate the environment-profile field.
3. If the environment variable is empty, apply the existing `ws_profile_matches`/profile-column behavior.
4. If it is set, require the selected environment profile in the row's `environment_profiles` field and skip rows that do not contain it.
5. Use the same decision in bootstrap preflight, bootstrap application, and read-only check output.

No mapping is applied or reported as compliant unless it passes both path/mode safety validation and the selected configuration-set filter.

### Documentation

Update:

- `references/config-sources.md` with the sixth column, grammar, and complete mapping table.
- `README.md` with the environment variable, role descriptions, and invocation examples.
- `profiles/base.md` and `profiles/work.md` only where their mapping descriptions need to distinguish package profiles from environment profiles.

No new configuration tree is introduced.

## Error handling and safety

- Empty/unset `WORKSTATION_PROFILE`: preserve current behavior.
- `personal`, `server`, `work`: select declared mapping rows only.
- Any other value, whitespace-containing value, or malformed metadata: fail before any bootstrap mutation; check exits nonzero.
- Missing or malformed `environment_profiles` metadata: fail closed.
- Existing source, destination, JSON, Git-config, backup, and credential safety checks remain unchanged.

## Testing

Add test-first fixture coverage:

- Existing no-environment-variable behavior remains unchanged.
- `WORKSTATION_PROFILE=personal` includes personal mappings and excludes work mappings.
- `WORKSTATION_PROFILE=server` includes only the minimal server set and excludes GUI, Hammerspoon, AI, and work mappings.
- `WORKSTATION_PROFILE=work` includes personal and work mappings.
- Invalid values fail before any destination is created or changed.
- Both bootstrap dry-run/apply and check output use the same filter.
- Metadata validation rejects malformed or missing sixth-column values.

Run the focused red/green tests, then the complete package suite and Bash syntax checks.
