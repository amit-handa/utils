# Configuration Sanitization Design

## Goal

Make the portable `~/utils` configuration set easier to maintain and safer to share without changing active workstation behavior unnecessarily.

## Scope

Modernize active configurations: `.zshrc`, `.vimrc`, `.gitconfig`, `.tmux.conf`, `ghostty.config`, `.config/gh/config.yml`, `.hammerspoon/keyboard/init.lua`, `.hammerspoon/keyboard/spaces.lua`, and the `nvim-custom/lua/custom/` overlay. Legacy files remain unchanged except for credential removal from `.bashrc0` and `.bashrc0.mac`.

## Cleanup rules

- Consolidate duplicate environment variables, PATH mutations, hooks, and tool initialization in `.zshrc`.
- Remove stale commented templates and invalid shell settings while preserving active integrations.
- Deduplicate Vim options, retain the effective final values, and remove obsolete commented blocks.
- Remove identity and credential-helper sections from shared `.gitconfig`; retain only non-sensitive Git behavior and localize identity/authentication.
- Remove dead Hammerspoon blocks and unused data while preserving layouts, hotkeys, and Spaces movement.
- Normalize other active configs only where no behavior changes.

## Security boundary

The SMTP credential previously present in commented legacy lines has been rotated. Remove those lines from both legacy files, then scrub the credential from every reachable Git ref. Do not add replacement credentials. `~/.gitconfig.local` and GitHub `hosts.yml` remain local and untracked.

## Verification

Run syntax checks for Zsh, Vim, Lua, Git, tmux, and YAML-backed CLI configuration; exercise the workstation fixture tests; run the config safety checker; verify the secret is absent from current files, reachable history, and unreachable Git objects before preparing any force-push.
