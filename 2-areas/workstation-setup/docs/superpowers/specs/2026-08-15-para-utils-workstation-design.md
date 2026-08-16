# PARA Utils and Workstation Setup Migration Design

## Goal

Reorganize the remote `~/utils` repository into the numbered PARA layout while moving the complete workstation-setup control plane from `private notes vault` into the utils repository, without breaking active shell, editor, AI, or menu-bar configuration paths.

## Constraints

- All repository changes and commits are performed on `amit@192.168.1.127`.
- Runtime configuration paths consumed by bootstrap and external tools remain stable at the utils root.
- The untracked remote `~/utils/abc` file is user-owned and must remain untouched.
- No credentials, private keys, SSH agent state, GitHub authentication state, cloud credentials, or generated caches enter the migration.
- Generated workstation inventories must remain outside the utils source tree by default.

## Target layout

The repository keeps its runtime integration surface at the root and adds the numbered PARA folders used by the personal vault:

```text
~/utils/
├── 1-projects/
├── 2-areas/
│   └── workstation-setup/
├── 3-resources/
└── 4-archives/
```

Existing active configuration paths remain root-level: `.zshrc`, `.zshrc.work`, `.config/`, `.local/`, `.hammerspoon/`, `ai/`, `ide/`, `macos/`, `nvim-custom/`, and `ghostty.config`.

## PARA classification

- `2-areas/workstation-setup/` contains the complete workstation package: README, profiles, references, manifests, scripts, and tests. Snapshot reports are generated outside the utils source tree.
- `3-resources/` contains durable reference material such as `ubuntu2mac.md`.
- `4-archives/` contains legacy or superseded material: `.bashrc0`, `.bashrc0.mac`, the old root `init.lua`, and the legacy Redis utilities `client.py` and `redmon.py`.
- `1-projects/` is reserved for bounded outcome-driven work and receives no unrelated runtime configuration.

## Workstation package migration

The existing remote `workstation-setup/` package is merged with the `private notes vault/2-areas/workstation-setup/` package and moved to `2-areas/workstation-setup/`. The notes package supplies the complete README, profiles, human-readable references, manifests, scripts, tests, and inventory workflow; the existing remote package supplies the already-relocated script hardening and real-source behavior. Generated reports remain external to the repository.

All package-relative script references are updated for the new location. The scripts continue to resolve the actual dotfile source as `~/utils`, and `snapshot.sh` continues to default generated reports to `~/.workstation-setup/inventory` rather than writing machine state into the source repository.

Internal links that previously pointed into `private notes vault` are rewritten to the new utils PARA paths. The old root-level `workstation-setup/` directory is removed after the relocated package passes verification.

## Compatibility and safety

- `config-sources.tsv` source paths remain relative to `~/utils`; active mappings do not gain a second configuration tree.
- Runtime files and directories stay at their current paths, so shell startup, editor discovery, and bootstrap destinations remain unchanged.
- The migration uses explicit `git mv` operations and a pre-migration manifest. The untracked `abc` file is excluded from staging.
- Source validation is rerun after relocation, including JSON and plist privacy checks.

## Verification

On the remote host:

1. Run `git diff --check` and verify the staged path list contains only intentional PARA and workstation package changes.
2. Run Python recent-usage tests plus the bootstrap, check, and snapshot fixture suites from `2-areas/workstation-setup/scripts/tests/`.
3. Run the real dry-run/check commands with `--utils-path ~/utils`.
4. Verify all active runtime source paths remain present and no sensitive paths are tracked.
5. Verify `git status` shows only the preserved pre-existing `abc` as untracked.

## Commit structure

Create commits only on `192.168.1.127`:

1. PARA repository layout and legacy/reference moves.
2. Workstation package relocation and link/path updates.

Each commit includes the `Co-authored-by: oh-my-pi <https://omp.sh>` trailer.
