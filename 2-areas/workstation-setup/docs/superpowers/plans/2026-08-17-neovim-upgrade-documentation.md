# Neovim Upgrade Documentation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Document the Neovim 0.12 compatibility requirement and the user-local tarball fallback used when Ubuntu's package source cannot provide it.

**Architecture:** Keep `~/utils/nvim-custom` as the shared configuration overlay, document Neovim's minimum runtime separately, and link one focused how-to guide from the workstation overview and Linux/base profile docs. Documentation must distinguish the package-managed path from the user-local fallback and must not claim that bootstrap automatically upgrades Neovim.

**Tech Stack:** Markdown, Debian/Ubuntu `apt`, official Neovim Linux tarball, existing workstation-setup profile documentation.

---

### Task 1: Add the focused Neovim upgrade how-to

**Files:**
- Create: `docs/how-to/neovim-upgrade.md`

- [x] **Step 1: Document the compatibility contract**

State that the current Kickstart baseline and custom plugin overlay use `vim.pack`/`PackChanged`, so Neovim 0.12 or newer is required. Explain that `apt install neovim` may leave an older distro version installed.

- [x] **Step 2: Document the package-managed path**

Show how to inspect `nvim --version` and `apt-cache policy neovim`. Document the official stable PPA command as optional, with a check that the candidate is actually 0.12 or newer before replacing the binary.

- [x] **Step 3: Document the sudo-free user-local fallback**

Provide commands that download the official `v0.12.4` x86_64 tarball into `$HOME/.local/opt/nvim-v0.12.4`, symlink `$HOME/.local/bin/nvim`, and leave `/bin/nvim` untouched. Include the `aarch64` variation and state that `$HOME/.local/bin` must precede `/bin` in `PATH`.

- [x] **Step 4: Document verification and known follow-ups**

Include clean API checks, normal configuration startup, and a note that Tree-sitter parser compilation may require the `tree-sitter` CLI. State that the guide does not copy credentials or modify the shared overlay.

### Task 2: Link the guide from existing profile documentation

**Files:**
- Modify: `README.md` in the migration and verification sections
- Modify: `profiles/base.md` in the Neovim configuration section
- Modify: `profiles/linux-debian.md` in platform prerequisites and configuration destinations

- [x] **Step 1: Add the migration link and compatibility warning**

Tell Linux users to verify the Neovim runtime after package installation and link `docs/how-to/neovim-upgrade.md` when the distro candidate is below 0.12.

- [x] **Step 2: Clarify the base profile contract**

Describe the minimum Neovim version and distinguish the shared `nvim-custom` overlay from the runtime/API contract it requires.

- [x] **Step 3: Add focused verification commands**

Link the guide from the existing verification list without changing bootstrap behavior or claiming automatic upgrade support.

### Task 3: Validate documentation accuracy

**Files:**
- Read: all files changed in Tasks 1–2

- [x] **Step 1: Check Markdown links and command paths**

Verify that every relative link resolves from its containing file and that commands use the existing repository paths and the remote machine's x86_64 architecture.

- [x] **Step 2: Run the existing workstation dry-run check**

Run `WORKSTATION_PROFILE=server bash scripts/bootstrap.sh --os linux --profile base --utils-path "$HOME/utils"` from the package directory and confirm the documentation change does not alter bootstrap behavior.

- [x] **Step 3: Confirm the working tree contains only intentional documentation changes**

Run `git status --short` and review the changed paths.
