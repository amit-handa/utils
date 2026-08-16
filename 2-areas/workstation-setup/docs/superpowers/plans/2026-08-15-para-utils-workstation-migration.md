# PARA Utils and Workstation Setup Migration Implementation Plan

> **For agentic workers:** Execute this plan on `amit@192.168.1.127` only. All commits must be created in `/home/amit/utils`.

**Goal:** Move the workstation-setup control plane from the notes layout into `~/utils/2-areas/workstation-setup/` and organize non-runtime utils content into the numbered PARA folders without breaking root runtime configuration paths.

**Architecture:** Keep active dotfile/config integration paths at the repository root. Use `2-areas/workstation-setup` as the single package location for README, profiles, references, manifests, scripts, tests, and inventory. Move durable references to `3-resources` and legacy artifacts to `4-archives`; leave `1-projects` reserved.

**Verification:** Run the relocated Python, bootstrap, check, and snapshot tests; run real remote dry-run/check commands; inspect the staged path list and preserve `abc`.

---

### Task 1: Capture and back up the remote tree

**Files:** `/home/amit/utils` only.

- [ ] Record `git status --short`, `git ls-files`, and current top-level paths.
- [ ] Create a timestamped backup outside the repository for all paths that will be moved.
- [ ] Confirm `abc` is untracked and exclude it from all staging commands.

### Task 2: Create PARA directories and move legacy/reference content

**Paths:**

- Create `1-projects/`, `2-areas/`, `3-resources/`, and `4-archives/`.
- Move `ubuntu2mac.md` to `3-resources/ubuntu2mac.md`.
- Move `.bashrc0`, `.bashrc0.mac`, root `init.lua`, `client.py`, and `redmon.py` to `4-archives/`.
- Leave active root config paths (`.zshrc`, `.zshrc.work`, `.config`, `.local`, `.hammerspoon`, `ai`, `ide`, `macos`, `nvim-custom`, `ghostty.config`, and other mapped dotfiles) unchanged.

### Task 3: Move and merge workstation-setup

- Merge the existing remote `workstation-setup/` package with the complete package from the local `private notes vault` worktree.
- Place the merged package at `2-areas/workstation-setup/`.
- Preserve the hardened remote script variants: safe snapshot output, real-source validation, Bash/Linux test portability, and current metadata.
- Move relevant existing `docs/superpowers` workstation specs into the relocated package or update links so no `private notes vault` paths remain.
- Remove the old root `workstation-setup/` directory only after all files are present in the new location.

### Task 4: Update paths and links

- Update script-relative package paths only where required by the new directory.
- Update README, references, profiles, and related-note links from `2-areas/workstation-setup` or `private notes vault` to `2-areas/workstation-setup`.
- Keep `~/utils` as the source root for all config mappings.
- Keep snapshot default output outside the repository at `~/.workstation-setup/inventory`.

### Task 5: Verify and commit remotely

- Run `git diff --check`.
- Run `python3 -m unittest 2-areas/workstation-setup/scripts/tests/test_recent_usage.py`.
- Run `bash 2-areas/workstation-setup/scripts/tests/test_check.sh`.
- Run `bash 2-areas/workstation-setup/scripts/tests/test_bootstrap.sh`.
- Run `bash 2-areas/workstation-setup/scripts/tests/test_snapshot.sh`.
- Run real `check.sh` and snapshot dry-run commands against `~/utils`; distinguish expected destination drift from missing source errors.
- Stage only intentional PARA/workstation paths, never `abc`.
- Create two remote commits with the required Oh My Pi trailer: PARA layout first, workstation package move second.
- Verify final status shows only the pre-existing `?? abc` entry.
