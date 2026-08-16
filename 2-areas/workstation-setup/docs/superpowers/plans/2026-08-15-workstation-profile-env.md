# Workstation Configuration Environment Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional `WORKSTATION_PROFILE=personal|server|work` selector that filters configuration mappings without bypassing existing package-profile or platform constraints.

**Architecture:** Keep `--profile base|work|mobile` as the package/manifest selector. Extend the mapping metadata with an `environment_profiles` membership column. When the environment variable is set, bootstrap and check enforce both the existing `ws_profile_matches` result and the selected environment membership; snapshot parses the new field without filtering inventory. Gate non-TSV desktop actions and the existing `.zshrc.work` include for personal/server runtime safety; when unset, behavior remains unchanged.

**Tech Stack:** Bash 3.2-compatible scripts, TSV metadata, existing shell fixture tests, Markdown reference documentation.

---

### Task 1: Add failing environment-profile fixture coverage

**Files:**
- Create: `2-areas/workstation-setup/scripts/tests/test_environment_profile.sh`
- Modify: `2-areas/workstation-setup/scripts/tests/test_bootstrap.sh`
- Modify: `2-areas/workstation-setup/scripts/tests/test_check.sh`
- Modify: `2-areas/workstation-setup/scripts/tests/test_snapshot.sh`

- [ ] **Step 1: Add bootstrap dry-run assertions before implementation**

In `test_bootstrap.sh`, after the existing package/profile dry-run assertions, add three isolated dry-run calls using the existing fixture variables:

```bash
PERSONAL_DRY=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  WORKSTATION_PROFILE=personal \
  bash "$BOOTSTRAP" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$PERSONAL_DRY" 'PLAN LINK $HOME/.zshrc <- $UTILS/.zshrc'
assert_contains "$PERSONAL_DRY" 'PLAN LINK $HOME/Library/Application Support/Code/User/settings.json'
assert_not_contains "$PERSONAL_DRY" '$HOME/.kubectlAliases'

SERVER_DRY=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  WORKSTATION_PROFILE=server \
  bash "$BOOTSTRAP" --os linux --profile base --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$SERVER_DRY" 'PLAN LINK $HOME/.zshrc <- $UTILS/.zshrc'
assert_contains "$SERVER_DRY" 'PLAN LINK $HOME/.tmux.conf <- $UTILS/.tmux.conf'
assert_not_contains "$SERVER_DRY" '$HOME/.hammerspoon'
assert_not_contains "$SERVER_DRY" '$HOME/.claude/settings.json'
assert_not_contains "$SERVER_DRY" '$HOME/.kubectlAliases'

WORK_DRY=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  WORKSTATION_PROFILE=work \
  bash "$BOOTSTRAP" --os macos --profile work --utils-path "$UTILS_DIR" 2>&1)
assert_contains "$WORK_DRY" '$HOME/.kubectlAliases'
assert_contains "$WORK_DRY" '$HOME/.config/gh/config.yml'
assert_contains "$WORK_DRY" '$HOME/.local/bin/herdr-title-watch'
```

Use the script's existing `assert_contains`/`assert_not_contains` helpers and keep the calls dry-run-only so no fixture state is mutated.

- [ ] **Step 2: Add invalid-value and platform assertions**

Append to the same test:

```bash
if HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" WORKSTATION_PROFILE=unknown \
  bash "$BOOTSTRAP" --os linux --profile base --utils-path "$UTILS_DIR" \
  >"$FIXTURE/invalid-profile.out" 2>&1; then
  printf 'invalid WORKSTATION_PROFILE unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$(cat "$FIXTURE/invalid-profile.out")" 'invalid bootstrap arguments'

SERVER_MAC_DRY=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  WORKSTATION_PROFILE=server \
  bash "$BOOTSTRAP" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1)
assert_not_contains "$SERVER_MAC_DRY" '$HOME/.config/Code/User/settings.json'
assert_not_contains "$SERVER_MAC_DRY" '$HOME/Library/Application Support/Code/User/settings.json'
assert_not_contains "$SERVER_MAC_DRY" 'PLAN MENU_BAR'
assert_not_contains "$SERVER_MAC_DRY" 'PLAN IDE'
assert_not_contains "$SERVER_MAC_DRY" 'PLAN PREREQ code extensions'
assert_not_contains "$SERVER_MAC_DRY" 'PLAN PREREQ cursor extensions'
```

The platform assertions prove that the environment filter cannot re-enable a platform-inapplicable row.

- [ ] **Step 3: Add check-script role filtering assertions**

In `test_check.sh`, preserve the existing no-environment-variable `SAFE_OUTPUT` check, then run:

```bash
SERVER_CHECK=$(HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  WORKSTATION_PROFILE=server \
  bash "$CHECK" --os macos --profile base --utils-path "$UTILS_DIR" 2>&1 || true)
assert_contains "$SERVER_CHECK" 'OK zshrc'
assert_not_contains "$SERVER_CHECK" 'hammerspoon'
assert_not_contains "$SERVER_CHECK" 'claude-preferences'
assert_not_contains "$SERVER_CHECK" 'kubectl-aliases'

if HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" WORKSTATION_PROFILE=unknown \
  bash "$CHECK" --os macos --profile base --utils-path "$UTILS_DIR" \
  >"$FIXTURE/invalid-check-profile.out" 2>&1; then
  printf 'invalid WORKSTATION_PROFILE unexpectedly passed check\n' >&2
  exit 1
fi
assert_contains "$(cat "$FIXTURE/invalid-check-profile.out")" 'invalid check arguments'
```

- [ ] **Step 4: Add shell and snapshot regression assertions**

Create `test_environment_profile.sh` to exercise the existing production `.zshrc` against a controlled fixture:

```bash
#!/usr/bin/env bash
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
UTILS_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd -P)
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/environment-profile-test.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT HUP INT TERM
HOME_DIR="$FIXTURE/home"
mkdir -p "$HOME_DIR/.oh-my-zsh"
printf '%s\n' '# fixture oh-my-zsh' >"$HOME_DIR/.oh-my-zsh/oh-my-zsh.sh"
printf '%s\n' 'print -r -- loaded >"$PROFILE_MARKER"' >"$HOME_DIR/.zshrc.work"

run_profile() {
  local profile=$1
  rm -f "$FIXTURE/marker"
  HOME="$HOME_DIR" UTILS_DIR="$UTILS_DIR" PROFILE_MARKER="$FIXTURE/marker" \
    WORKSTATION_PROFILE="$profile" zsh -d -f -c \
    'source "$UTILS_DIR/.zshrc"' >/dev/null 2>&1
}

run_profile personal
[ ! -e "$FIXTURE/marker" ] || exit 1
run_profile server
[ ! -e "$FIXTURE/marker" ] || exit 1
run_profile work
[ -f "$FIXTURE/marker" ] || exit 1
```

The fixture uses a stale `.zshrc.work` file and proves that the selector, not link existence, controls runtime loading. In `test_snapshot.sh`, after `MAC_CURRENT` is loaded, assert that the Configuration sources section still reports the existing package profile value and does not leak the new role-membership field:

```bash
CONFIG_SECTION=$(section_content "$MAC_CURRENT" 'Configuration sources')
assert_contains "$CONFIG_SECTION" '| zshrc |'
assert_contains "$CONFIG_SECTION" '| base |'
assert_not_contains "$CONFIG_SECTION" 'personal|server|work'
```

- [ ] **Step 5: Run the focused tests and verify the expected red state**

Run:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=10 amit@192.168.1.127 \
  'cd "$HOME/utils/2-areas/workstation-setup" && \
   bash scripts/tests/test_environment_profile.sh && bash scripts/tests/test_snapshot.sh && \
   bash scripts/tests/test_check.sh && bash scripts/tests/test_bootstrap.sh'
```

Expected: failure from the new profile assertions because the current five-column metadata and scripts do not recognize `WORKSTATION_PROFILE`. Do not change the assertions to make this pass.

- [ ] **Step 6: Commit the failing test contract**

```bash
git add \
  2-areas/workstation-setup/scripts/tests/test_environment_profile.sh \
  2-areas/workstation-setup/scripts/tests/test_bootstrap.sh \
  2-areas/workstation-setup/scripts/tests/test_check.sh \
  2-areas/workstation-setup/scripts/tests/test_snapshot.sh
git commit -m "test(workstation): specify environment profile filtering" \
  -m "Capture personal, server, and work configuration-set behavior before implementation." \
  -m "Co-authored-by: oh-my-pi <https://omp.sh>"
```

### Task 2: Add shared environment-profile validation

**Files:**
- Modify: `2-areas/workstation-setup/scripts/lib.sh`
- Modify: `2-areas/workstation-setup/scripts/bootstrap.sh`
- Modify: `2-areas/workstation-setup/scripts/check.sh`

- [ ] **Step 1: Add Bash 3.2-compatible shared helpers**

Add after `ws_profile_matches()` in `lib.sh`:

```bash
ws_valid_environment_profile() {
  case $1 in
    personal|server|work) return 0 ;;
    *) return 1 ;;
  esac
}

ws_valid_environment_profile_tokens() {
  local tokens=$1 token old_ifs=$IFS
  [ -n "$tokens" ] || return 1
  IFS='|'
  for token in $tokens; do
    ws_valid_environment_profile "$token" || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  return 0
}

ws_environment_profile_matches() {
  local tokens=$1 requested=$2 token old_ifs=$IFS
  [ -n "$requested" ] || return 0
  IFS='|'
  for token in $tokens; do
    if [ "$token" = "$requested" ]; then
      IFS=$old_ifs
      return 0
    fi
  done
  IFS=$old_ifs
  return 1
}
```

The validator rejects empty metadata; the matcher treats an empty selected environment as no additional filter.

- [ ] **Step 2: Read and validate the environment variable in bootstrap**

Near `PROFILE=''` in `bootstrap.sh`, add:

```bash
WORKSTATION_PROFILE=${WORKSTATION_PROFILE:-}
```

After the existing OS/package-profile argument validation, add:

```bash
if [ -n "$WORKSTATION_PROFILE" ] &&
   ! ws_valid_environment_profile "$WORKSTATION_PROFILE"; then
  usage_error
fi
```

The single-value validator rejects `server|work`, whitespace, empty segments, and shell syntax.

- [ ] **Step 3: Read and validate the environment variable in check**

Near `PROFILE=''` in `check.sh`, add the same `${WORKSTATION_PROFILE:-}` assignment and validation, using `usage_error` so invalid input exits with the existing check argument error.

- [ ] **Step 4: Run syntax checks**

Run:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=10 amit@192.168.1.127 \
  'cd "$HOME/utils/2-areas/workstation-setup" && \
   bash -n scripts/lib.sh scripts/bootstrap.sh scripts/check.sh'
```

Expected: exit 0 with no output.

### Task 3: Extend mapping metadata and apply the dual filter

**Files:**
- Modify: `2-areas/workstation-setup/references/config-sources.tsv`
- Modify: `2-areas/workstation-setup/scripts/bootstrap.sh`
- Modify: `2-areas/workstation-setup/scripts/check.sh`
- Modify: `2-areas/workstation-setup/scripts/snapshot.sh`
- Modify: `.zshrc`

- [ ] **Step 1: Add the sixth metadata column**

Change the header to:

```text
id	source_relative_to_utils	destination_relative_to_home	mode	profile	environment_profiles
```

Add these environment memberships to every row while preserving the existing first five fields:

```text
zshrc                         personal|server|work
zshrc-work                    work
bashrc                        personal|server|work
bashrc0-linux                 personal|server|work
bashrc0-macos                 personal|server|work
gitconfig                     personal|server|work
gitconfig-local               personal|server|work
tmux                          personal|server|work
ghostty-macos                 personal|work
ghostty-linux                 personal|work
nvim-custom                   personal|server|work
vimrc                         personal|server|work
kubectl-aliases               work
gh-config                     work
herdr-title-watch             work
hammerspoon                   personal|work
vscode-settings-macos         personal|work
vscode-settings-linux         personal|work
cursor-settings-macos         personal|work
cursor-settings-linux         personal|work
cursor-keybindings-macos      personal|work
cursor-keybindings-linux      personal|work
claude-preferences            personal|work
omp-preferences               personal|work
```

- [ ] **Step 2: Update bootstrap row parsing and preflight filtering**

In `preflight_mapping`, add `environment_profiles=$6` to the local arguments and validate it with `ws_valid_environment_profile_tokens`. Keep this order:

```bash
ws_profile_matches "$profile" "$PROFILE" "$OS" || return 0
ws_environment_profile_matches "$environment_profiles" "$WORKSTATION_PROFILE" || return 0
```

In `preflight_configs`, parse six fields:

```bash
local line fields id source destination mode profile environment_profiles row=0
IFS=$'\034' read -r id source destination mode profile environment_profiles <<EOF
$fields
EOF
```

Pass the sixth value into `preflight_mapping`.

In `process_configs`, parse the same sixth field and apply `ws_profile_matches` first, followed by `ws_environment_profile_matches`. Keep all destination/source safety checks unchanged.

- [ ] **Step 3: Update snapshot parsing and non-TSV action gates**

In `snapshot.sh` `collect_config_state`, add `environment_profiles` to the local variables and parse six fields:

```bash
local revision='unavailable' line fields id source destination mode profile environment_profiles
IFS=$'\034' read -r id source destination mode profile environment_profiles <<EOF
$fields
EOF
```

Continue passing only `profile` to `ws_tokens_apply_to_os`; snapshot remains an all-source inventory and does not filter by `WORKSTATION_PROFILE`.

In `bootstrap.sh`, add a helper after the environment matcher:

```bash
environment_profile_allows_desktop() {
  ws_environment_profile_matches 'personal|work' "$WORKSTATION_PROFILE"
}
```

At the main action sequence, wrap the three non-TSV desktop actions so the guard runs before any defaults probe, IntelliJ scan, or extension CLI call:

```bash
if environment_profile_allows_desktop; then
  restore_menu_bar_settings || exit 1
  restore_intellij_settings || exit 1
  install_ide_extensions || exit 1
else
  printf 'SKIP desktop configuration for WORKSTATION_PROFILE=%s\n' "$WORKSTATION_PROFILE"
fi
```

Leave `ensure_kickstart`, `apply_kickstart_patch`, and `ensure_vim` enabled for the minimal server set. In `.zshrc`, change the existing work include to:

```zsh
if [[ -r "$HOME/.zshrc.work" ]] &&
   [[ -z ${WORKSTATION_PROFILE:-} || "$WORKSTATION_PROFILE" == work ]]; then
  source "$HOME/.zshrc.work"
fi
```

This preserves unset behavior and prevents a stale work link from leaking into personal/server shells.

- [ ] **Step 4: Update check row parsing and filtering**

Change the loop locals and reader in `check.sh` to:

```bash
while IFS=$'\034' read -r id source destination mode profiles environment_profiles; do
```

Validate `environment_profiles` with `ws_valid_environment_profile_tokens`, then apply:

```bash
ws_profile_matches "$profiles" "$PROFILE" "$OS" || continue
ws_environment_profile_matches "$environment_profiles" "$WORKSTATION_PROFILE" || continue
```

The existing `base@macos`/`base@linux` platform decision must remain before the environment membership decision.

- [ ] **Step 5: Run the focused tests and verify green**

Run:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=10 amit@192.168.1.127 \
  'cd "$HOME/utils/2-areas/workstation-setup" && \
   bash scripts/tests/test_environment_profile.sh && bash scripts/tests/test_snapshot.sh && \
   bash scripts/tests/test_check.sh && bash scripts/tests/test_bootstrap.sh'
```

Expected:

```text
agent preference privacy check: PASS
check fixture tests: PASS
bootstrap fixture tests: PASS
```

- [ ] **Step 6: Commit the implementation**

```bash
git add \
  2-areas/workstation-setup/references/config-sources.tsv \
  2-areas/workstation-setup/scripts/lib.sh \
  2-areas/workstation-setup/scripts/bootstrap.sh \
  2-areas/workstation-setup/scripts/check.sh \
  2-areas/workstation-setup/scripts/snapshot.sh \
  .zshrc
git commit -m "feat(workstation): filter mappings by environment profile" \
  -m "Apply personal, server, and work configuration sets while preserving package and platform profile constraints." \
  -m "Co-authored-by: oh-my-pi <https://omp.sh>"
```

### Task 4: Update user-facing mapping documentation

**Files:**
- Modify: `2-areas/workstation-setup/README.md`
- Modify: `2-areas/workstation-setup/references/config-sources.md`
- Modify: `2-areas/workstation-setup/profiles/base.md`
- Modify: `2-areas/workstation-setup/profiles/work.md`

- [ ] **Step 1: Document invocation and role semantics in README**

Add a configuration-profile subsection stating that `WORKSTATION_PROFILE` is optional, accepts `personal|server|work`, and is an additional filter after the existing package/platform profile selection. Include these examples:

```bash
WORKSTATION_PROFILE=personal bash scripts/bootstrap.sh --os macos --profile base --utils-path "$HOME/utils"
WORKSTATION_PROFILE=server bash scripts/bootstrap.sh --os linux --profile base --utils-path "$HOME/utils"
WORKSTATION_PROFILE=work bash scripts/check.sh --os macos --profile work --utils-path "$HOME/utils"
```

Document that server excludes GUI, Hammerspoon, AI-agent, and work mappings.

- [ ] **Step 2: Update the configuration reference**

Change the mapping table header to include `Environment profiles`, add the sixth value to every row, and document the grammar:

```text
environment_profiles: pipe-separated values from personal|server|work
```

State explicitly that `profile` remains the package and platform selector and is always enforced before `environment_profiles`.

- [ ] **Step 3: Clarify base/work profile documentation**

In `profiles/base.md`, distinguish the base package profile from the `personal` environment profile and mention that server uses only the shell/editor subset. In `profiles/work.md`, state that `WORKSTATION_PROFILE=work` includes the personal set plus the work mappings, while authentication remains manual.

- [ ] **Step 4: Validate documentation and commit**

Run the existing Markdown link audit and a TSV/reference consistency check, then commit:

```bash
git add \
  2-areas/workstation-setup/README.md \
  2-areas/workstation-setup/references/config-sources.md \
  2-areas/workstation-setup/profiles/base.md \
  2-areas/workstation-setup/profiles/work.md
git commit -m "docs(workstation): document environment profiles" \
  -m "Explain personal, server, and work configuration-set selection and the dual profile filters." \
  -m "Co-authored-by: oh-my-pi <https://omp.sh>"
```

### Task 5: Run full verification and preserve clean scope

**Files:**
- No source changes expected unless verification identifies a concrete defect.

- [ ] **Step 1: Run the complete package suite**

```bash
ssh -o BatchMode=yes -o ConnectTimeout=10 amit@192.168.1.127 \
  'cd "$HOME/utils/2-areas/workstation-setup" && \
   bash -n scripts/bootstrap.sh scripts/check.sh scripts/lib.sh scripts/snapshot.sh \
     scripts/tests/test_environment_profile.sh scripts/tests/test_bootstrap.sh \
     scripts/tests/test_check.sh scripts/tests/test_snapshot.sh && \
   python3 -m unittest scripts/tests/test_recent_usage.py && \
   bash scripts/tests/test_environment_profile.sh && \
   bash scripts/tests/test_check.sh && \
   bash scripts/tests/test_bootstrap.sh && \
   bash scripts/tests/test_snapshot.sh'
```

Expected: 5 Python tests pass, followed by `check fixture tests: PASS`, `bootstrap fixture tests: PASS`, and `snapshot fixture tests: PASS`.

- [ ] **Step 2: Verify platform filtering explicitly**

Run the environment-profile fixture plus bootstrap with `WORKSTATION_PROFILE=server` on both `--os macos` and `--os linux`; confirm no `base@macos` mapping appears in the Linux output, no desktop mapping or non-TSV desktop action appears in either server output, and the stale `.zshrc.work` fixture is not loaded. Run check with `WORKSTATION_PROFILE=personal`, `server`, and `work` and confirm each output contains only its declared IDs.

- [ ] **Step 3: Verify metadata and repository boundaries**

Confirm every TSV row has six fields, every environment token is allowlisted, all Markdown links resolve, `git diff --check` is clean, and the pre-existing untracked `abc` file is not staged.

- [ ] **Step 4: Remove generated caches and record final status**

Remove only the test-generated `2-areas/workstation-setup/scripts/tests/__pycache__/` directory if present. Confirm `git status --short --branch` shows only intentional changes and commits contain the Oh My Pi trailer.
