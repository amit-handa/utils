# Workstation Setup Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a shareable workstation setup kit that inventories all developer tools, preserves `~/utils` as the dotfiles source, and supports safe macOS and Debian/Ubuntu migration.

**Architecture:** `2-areas/workstation-setup/` is the setup control plane. Curated manifests describe desired packages, a catalog guarantees coverage of GUI apps and non-package utilities, `snapshot.sh` produces installed and recent-usage inventories, `bootstrap.sh` applies profiles with dry-run protection, and `check.sh` reports drift. The existing public `~/utils` repository remains the only source for actual dotfiles; the vault stores mappings and migration rules, not duplicate config files.

**Tech Stack:** Bash compatible with macOS Bash 3.2 and modern Linux Bash, Python 3 for deterministic recent-usage normalization, Homebrew, `apt`/`dpkg`, macOS `mdfind`/`mdls`, Linux desktop-entry metadata, POSIX text formats, and shell fixture tests.

**Privacy decision:** The user explicitly requested a bounded audit of tools used during the last seven days to catch omitted IDEs and utilities, including IntelliJ IDEA, VS Code, Cursor, Herdr, and Hammerspoon. The audit is invoked by the explicit snapshot command, reads only the selected window, and writes normalized tool names and dates. It never writes raw history lines, command arguments, paths, hostnames, search text, or credentials.

---

## File map

Create these files under the vault:

- `2-areas/workstation-setup/README.md` -- migration guide, profile selection, update loop, privacy rules, and links.
- `2-areas/workstation-setup/profiles/base.md` -- default developer profile.
- `2-areas/workstation-setup/profiles/work.md` -- optional work-tool profile without authentication state.
- `2-areas/workstation-setup/profiles/mobile.md` -- optional Android/iOS profile and links to existing notes.
- `2-areas/workstation-setup/profiles/macos.md` -- macOS prerequisites and package/app behavior.
- `2-areas/workstation-setup/profiles/linux-debian.md` -- Debian/Ubuntu prerequisites and package behavior.
- `2-areas/workstation-setup/manifests/common.txt` -- shared package names, one per line, comments allowed.
- `2-areas/workstation-setup/manifests/macos/Brewfile` -- curated Homebrew formulae and casks.
- `2-areas/workstation-setup/manifests/linux/apt-packages.txt` -- curated Debian/Ubuntu packages.
- `2-areas/workstation-setup/manifests/runtimes.txt` -- intentionally managed runtime names and constraints.
- `2-areas/workstation-setup/references/tool-catalog.tsv` -- machine-readable coverage catalog.
- `2-areas/workstation-setup/references/config-sources.tsv` -- dotfile source-to-destination mappings.
- `2-areas/workstation-setup/references/config-sources.md` -- human-readable mapping and sharing rules.
- `2-areas/workstation-setup/references/related-notes.md` -- links to existing vault notes.
- `2-areas/workstation-setup/inventory/current-machine.md` -- generated installed-state inventory.
- `2-areas/workstation-setup/inventory/recent-usage.md` -- generated normalized seven-day usage inventory.
- `2-areas/workstation-setup/scripts/lib.sh` -- shared argument, path, output, detection, and safety helpers.
- `2-areas/workstation-setup/scripts/recent_usage.py` -- bounded history normalizer that emits names and dates only.
- `2-areas/workstation-setup/scripts/snapshot.sh` -- package, app, runtime, config-footprint, and usage inventory generator.
- `2-areas/workstation-setup/scripts/bootstrap.sh` -- dry-run-first profile installer and dotfile linker.
- `2-areas/workstation-setup/scripts/check.sh` -- read-only package, link, checksum, and source-revision checker.
- `2-areas/workstation-setup/scripts/tests/test_recent_usage.py` -- deterministic history-redaction tests.
- `2-areas/workstation-setup/scripts/tests/test_snapshot.sh` -- fixture tests for catalog and inventory discovery.
- `2-areas/workstation-setup/scripts/tests/test_bootstrap.sh` -- dry-run, backup, and symlink tests.
- `2-areas/workstation-setup/scripts/tests/test_check.sh` -- compliant and drifted fixture tests.

All implementation commits must stage explicit paths and include the required trailer:

```text
Co-authored-by: oh-my-pi <https://omp.sh>
```

---

### Task 1: Create the catalog and documentation skeleton

**Files:**
- Create: `2-areas/workstation-setup/README.md`
- Create: `2-areas/workstation-setup/profiles/base.md`
- Create: `2-areas/workstation-setup/profiles/work.md`
- Create: `2-areas/workstation-setup/profiles/mobile.md`
- Create: `2-areas/workstation-setup/profiles/macos.md`
- Create: `2-areas/workstation-setup/profiles/linux-debian.md`
- Create: `2-areas/workstation-setup/references/tool-catalog.tsv`
- Create: `2-areas/workstation-setup/references/config-sources.tsv`
- Create: `2-areas/workstation-setup/references/config-sources.md`
- Create: `2-areas/workstation-setup/references/related-notes.md`

- [ ] **Step 1: Create the package directories**

```bash
mkdir -p 2-areas/workstation-setup/{profiles,manifests/macos,manifests/linux,references,inventory,scripts/tests}
```

Expected result: all listed directories exist and no files outside `2-areas/workstation-setup/` change.

- [ ] **Step 2: Write the coverage catalog**

Use tab-separated columns. In the code block, each `\t` marker represents one literal tab character:

```text
id\tdisplay_name\tcategory\tcommand_candidates\tapp_candidates\tconfig_roots\tprofiles
intellij\tIntelliJ IDEA\tide\tidea\tIntelliJ IDEA\tLibrary/Application Support/JetBrains\tbase
vscode\tVisual Studio Code\tide\tcode\tVisual Studio Code\t.vscode\tbase
cursor\tCursor\tide\tcursor\tCursor\t.cursor\tbase
neovim\tNeovim\tide\tnvim\t\t.config/nvim\tbase
vim\tVim\tide\tvim:vi\t\t.vim\tbase
herdr\tHerdr\tsession\therdr\t\t.config/herdr\tbase,work
omp\tOh My Pi\tai\tomp\t\t.omp\tbase
claude-code\tClaude Code\tai\tclaude\tClaude\t.claude\tbase
codex\tCodex\tai\tcodex\t\t.codex\tbase
copilot\tGitHub Copilot\tai\t\tGitHub Copilot\t.config/github-copilot\tbase
ghostty\tGhostty\tterminal\t\tGhostty\tutils/ghostty.config\tbase
tmux\ttmux\tterminal\ttmux\t\t.tmux.conf\tbase
hammerspoon\tHammerspoon\twindow-utility\t\tHammerspoon\tutils/.hammerspoon\tbase
git\tGit\tdeveloper\tgit:gst:gco:gd:gp:gl\t\t.gitconfig\tbase
brew\tHomebrew\tpackage-manager\tbrew\t\t\tmacos
npm\tnpm\tpackage-manager\tnpm\t\t.npmrc\tbase
devbox\tDevbox\twork\tdevbox\t\t.devbox\twork
teleport\tTeleport CLI\twork\ttsh\t\t.tsh\twork
kubectl\tkubectl\twork\tkubectl:k:kgpo:kgcmoyaml\t\t.kube\twork
bazel\tBazel\twork\tbazel\t\t\twork
android\tAndroid tooling\tmobile\tadb:gradlew\tAndroid Studio\t.android\tmobile
xcode\tXcode and simulators\tmobile\txcodebuild:simctl\tXcode\tLibrary/Developer\tmobile
java\tJava and jenv\truntime\tjava:jenv\t\t.jenv\tbase
python\tPython\truntime\tpython3\t\t\tbase
node\tNode and Bun\truntime\tnode:bun\t\t.bun\tbase
```

The catalog must keep the requested IntelliJ, VS Code, Cursor, Herdr, and Hammerspoon entries even if a detector later reports them as unavailable.

- [ ] **Step 3: Write the configuration mapping**

Use tab-separated columns `id`, `source_relative_to_utils`, `destination_relative_to_home`, `mode`, and `profile`. In the code block, each `\t` marker represents one literal tab character:

```text
zshrc\t.zshrc\t.zshrc\tsymlink\tbase
bashrc\t.bashrc\t.bashrc\tsymlink\tbase
gitconfig\t.gitconfig\t.gitconfig\tsymlink\tbase
tmux\t.tmux.conf\t.tmux.conf\tsymlink\tbase
ghostty\tghostty.config\tLibrary/Application Support/com.mitchellh.ghostty/config\tsymlink\tbase
neovim\tinit.lua\t.config/nvim/init.lua\tsymlink\tbase
kubectl-aliases\t.kubectlAliases\t.kubectlAliases\tsymlink\twork
hammerspoon\t.hammerspoon\t.hammerspoon\tsymlink\tbase
```

The implementation must validate source existence and destination safety before applying a mapping. Identity values in Git configuration remain local and are not copied into documentation.

- [ ] **Step 4: Write the README and profile documentation**

`README.md` must contain sections titled `What this manages`, `Choose a profile`, `Migration`, `Update workflow`, `Privacy boundary`, `Configuration sources`, `Inventory categories`, `Verification`, and `Related notes`. Link each package file, the public `https://github.com/amit-handa/utils` repository, and these existing notes:

- Related private note names are listed in [references/related-notes.md](../../../references/related-notes.md).
- `tools/gdoc-md/`

Each profile document must list its included catalog IDs, platform prerequisites, manual authentication/licensing steps, and files it does not restore. `mobile.md` must link to both Android and iOS notes.

- [ ] **Step 5: Commit the documentation foundation**

```bash
git add \
  2-areas/workstation-setup/README.md \
  2-areas/workstation-setup/profiles/base.md \
  2-areas/workstation-setup/profiles/work.md \
  2-areas/workstation-setup/profiles/mobile.md \
  2-areas/workstation-setup/profiles/macos.md \
  2-areas/workstation-setup/profiles/linux-debian.md \
  2-areas/workstation-setup/references/tool-catalog.tsv \
  2-areas/workstation-setup/references/config-sources.tsv \
  2-areas/workstation-setup/references/config-sources.md \
  2-areas/workstation-setup/references/related-notes.md
git commit -m "docs: catalog workstation setup coverage" -m "Make GUI applications, session tools, AI clients, and utility configurations first-class setup entries." -m "Co-authored-by: oh-my-pi <https://omp.sh>"
git push origin master
```

Expected result: one vault commit containing only the new package documentation and catalogs.


### Task 2: Add deterministic recent-usage normalization tests

**Files:**
- Create: `2-areas/workstation-setup/scripts/tests/test_recent_usage.py`
- Create: `2-areas/workstation-setup/scripts/recent_usage.py`

- [ ] **Step 1: Write the failing redaction test**

Create a temporary fixture file with safe commands, a token-like argument, a hostname argument, a wrapper, and a malformed line. The test body must be executable as written:

```python
import subprocess
import sys
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory() as temp_dir:
    history_path = Path(temp_dir) / "history"
    history_path.write_text(
        ": 1780000100:0;devbox run\\n"
        ": 1780000200:0;herdr --token=super-secret-token\\n"
        ": 1780000300:0;idea .\\n"
        ": 1780000400:0;open sandbox.example.internal\\n"
        "malformed history record\\n"
    )
    output = subprocess.check_output(
        [
            sys.executable,
            "2-areas/workstation-setup/scripts/recent_usage.py",
            "--history",
            str(history_path),
            "--start-epoch",
            "1780000000",
            "--end-epoch",
            "1781000000",
        ],
        text=True,
    )
    rows = [line.split("\\t") for line in output.splitlines()]
    names = {row[1] for row in rows}
    assert "devbox" in names
    assert "herdr" in names
    assert "idea" in names
    assert "super-secret-token" not in output
    assert "sandbox.example.internal" not in output
    assert "--token" not in output
    assert all(len(row) == 3 for row in rows)
```

The test must use this temporary fixture, never the real history file.

- [ ] **Step 2: Run the test to verify the expected failure**

```bash
python3 -m unittest 2-areas/workstation-setup/scripts/tests/test_recent_usage.py -v
```

Expected result: FAIL because `recent_usage.py` is not present.

- [ ] **Step 3: Implement the normalizer**

`recent_usage.py` accepts:

```text
--history PATH
--start-epoch INTEGER
--end-epoch INTEGER
```

It parses only lines matching the zsh timestamp prefix, ignores records outside the epoch bounds, splits the command transiently with `shlex`, strips environment assignments and wrappers (`sudo`, `env`, `time`, `command`, `builtin`), reduces the first executable to its basename, and accepts only `[A-Za-z0-9_.+-]+`. It emits exactly `YYYY-MM-DD<TAB>normalized_name<TAB>count`. It emits no source line, argument, path, hostname, or token. A malformed or unsafe command becomes `unclassified` without including the original value.

- [ ] **Step 4: Run the redaction test to verify it passes**

```bash
python3 -m unittest 2-areas/workstation-setup/scripts/tests/test_recent_usage.py -v
```

Expected result: PASS with all assertions satisfied.

- [ ] **Step 5: Commit the normalizer**

```bash
git add 2-areas/workstation-setup/scripts/recent_usage.py 2-areas/workstation-setup/scripts/tests/test_recent_usage.py
git commit -m "feat: normalize recent tool usage safely" -m "Capture bounded usage evidence without retaining command arguments or private payloads." -m "Co-authored-by: oh-my-pi <https://omp.sh>"
git push origin master
```

### Task 3: Implement complete inventory discovery

**Files:**
- Create: `2-areas/workstation-setup/scripts/lib.sh`
- Create: `2-areas/workstation-setup/scripts/snapshot.sh`
- Create: `2-areas/workstation-setup/scripts/tests/test_snapshot.sh`
- Create: `2-areas/workstation-setup/manifests/common.txt`
- Create: `2-areas/workstation-setup/manifests/macos/Brewfile`
- Create: `2-areas/workstation-setup/manifests/linux/apt-packages.txt`
- Create: `2-areas/workstation-setup/manifests/runtimes.txt`
- Create: `2-areas/workstation-setup/inventory/current-machine.md`
- Create: `2-areas/workstation-setup/inventory/recent-usage.md`

- [ ] **Step 1: Write fixture tests for non-package tools**

`test_snapshot.sh` must create a temporary fake home, fake `brew`, fake `dpkg`, fake `mdfind`, fake `mdls`, and a fake `recent_usage.py` output. It must place a `.hammerspoon` fixture and a minimal `~/utils` tree in the temporary home. Run snapshot with:

```bash
HOME="$fixture/home" PATH="$fixture/bin:$PATH" \
  bash 2-areas/workstation-setup/scripts/snapshot.sh \
  --os macos --since 7d --utils-path "$fixture/home/utils" \
  --output-dir "$fixture/out"
```

Assert that `current-machine.md` contains `IntelliJ IDEA`, `Visual Studio Code`, `Cursor`, `Herdr`, `Hammerspoon`, and `Ghostty`, and that `recent-usage.md` contains normalized names only. Assert that an absent catalog item is listed as `not detected` rather than omitted.

- [ ] **Step 2: Run the inventory test to verify the expected failure**

```bash
bash 2-areas/workstation-setup/scripts/tests/test_snapshot.sh
```

Expected result: FAIL because `snapshot.sh` is not present.

- [ ] **Step 3: Implement shared shell helpers**

`lib.sh` must provide Bash-3.2-compatible functions:

```text
die(message)
usage_error(message)
require_value(flag, value)
command_exists(name)
normalize_display_name(value)
path_is_forbidden(path)
write_markdown_row(category, name, status, source)
backup_destination(path, backup_root)
link_or_report(source, destination, apply_mode)
```

Do not use associative arrays, `mapfile`, Bash 4-only syntax, recursive home-directory copies, or unvalidated `eval`. All external command output must be normalized before it is written.

- [ ] **Step 4: Implement `snapshot.sh` argument handling and collectors**

Support:

```text
--os macos|linux
--since 7d|Nd
--utils-path PATH
--output-dir PATH
```

Default `--since` to seven days and `--output-dir` to the package `inventory/` directory. Reject unknown operating systems, negative windows, and forbidden output paths. If `--utils-path` is absent, record the unavailable configuration source and continue package, application, runtime, and usage discovery.

Collectors must run independently and continue when an optional source is unavailable:

- macOS Homebrew formulae and casks through `brew list --versions` and `brew list --cask --versions`.
- Debian/Ubuntu packages through `dpkg-query` or `apt list --installed`.
- Global npm, pipx, Go, and Cargo tools when their commands exist.
- macOS application bundles through `mdfind` and `mdls`; fallback to direct `/Applications/*.app` and `$HOME/Applications/*.app` globs.
- Linux desktop entries from `/usr/share/applications/*.desktop` and `$HOME/.local/share/applications/*.desktop`.
- Runtime versions through `java`, `jenv`, `go`, `python3`, `node`, `bun`, `adb`, and `xcodebuild` when present.
- Configuration footprints from the catalog and `config-sources.tsv`, recording presence and safe checksums only.
- Recent usage by invoking `recent_usage.py` with a computed epoch window and writing only its three-column output.

Always render the full catalog, including `not detected` and `manual review` statuses. Group output under Applications and IDEs, CLI and shells, terminal and session utilities, AI tools, developer and cloud tools, language and mobile stacks, configuration sources, recent usage, and Unclassified.

- [ ] **Step 5: Add the initial desired manifests**

Populate `common.txt`, `Brewfile`, `apt-packages.txt`, and `runtimes.txt` from the inventory after reviewing each entry. Include only intentional setup requirements. Do not copy transient dependencies, caches, credentials, or machine-specific paths. Keep GUI casks such as Ghostty, IntelliJ IDEA, VS Code, Cursor, and Hammerspoon explicit when they are part of the base profile; keep Devbox, Teleport CLI, Kubernetes tooling, Bazel, and related work tools in the work profile.

- [ ] **Step 6: Run inventory tests and syntax checks**

```bash
bash -n 2-areas/workstation-setup/scripts/lib.sh 2-areas/workstation-setup/scripts/snapshot.sh
bash 2-areas/workstation-setup/scripts/tests/test_snapshot.sh
```

Expected result: syntax checks exit 0 and the fixture test reports PASS without writing outside its temporary output directory.

- [ ] **Step 7: Run a real read-only snapshot on the current Mac**

```bash
bash 2-areas/workstation-setup/scripts/snapshot.sh \
  --os macos --since 7d --utils-path "$HOME/utils" \
  --output-dir 2-areas/workstation-setup/inventory
```

Review both generated files for the required IDEs, Herdr, Hammerspoon, OMP, terminal utilities, AI clients, work tools, language/mobile tools, and `Unclassified`. Remove any secret-like or machine-specific value before committing. Do not run bootstrap apply on the current machine.

- [ ] **Step 8: Commit inventory implementation and reviewed manifests**

```bash
git add \
  2-areas/workstation-setup/scripts/lib.sh \
  2-areas/workstation-setup/scripts/snapshot.sh \
  2-areas/workstation-setup/scripts/tests/test_snapshot.sh \
  2-areas/workstation-setup/manifests/common.txt \
  2-areas/workstation-setup/manifests/macos/Brewfile \
  2-areas/workstation-setup/manifests/linux/apt-packages.txt \
  2-areas/workstation-setup/manifests/runtimes.txt \
  2-areas/workstation-setup/inventory/current-machine.md \
  2-areas/workstation-setup/inventory/recent-usage.md
git commit -m "feat: inventory complete workstation toolset" -m "Discover GUI applications, IDEs, utilities, runtimes, package entries, configuration footprints, and bounded usage evidence." -m "Co-authored-by: oh-my-pi <https://omp.sh>"
git push origin master
```

### Task 4: Implement profile-aware bootstrap with safe dotfile linking

**Files:**
- Create: `2-areas/workstation-setup/scripts/bootstrap.sh`
- Create: `2-areas/workstation-setup/scripts/tests/test_bootstrap.sh`
- Modify: `2-areas/workstation-setup/references/config-sources.tsv`
- Modify: `2-areas/workstation-setup/README.md`

- [ ] **Step 1: Write dry-run and backup fixture tests**

The fixture test must create a temporary home with an existing `.zshrc`, a temporary `utils` source, and fake package-manager commands. Run:

```bash
HOME="$fixture/home" PATH="$fixture/bin:$PATH" \
  bash 2-areas/workstation-setup/scripts/bootstrap.sh \
  --os macos --profile base --utils-path "$fixture/home/utils"
```

Assert that dry-run output lists package installation, backup, symlink, and manual-authentication actions, while the existing `.zshrc` checksum and directory tree remain unchanged. Then run the same command with `--apply` and assert that the old `.zshrc` is in a timestamped backup directory and the destination symlink points to the declared source.

- [ ] **Step 2: Run the bootstrap test to verify the expected failure**

```bash
bash 2-areas/workstation-setup/scripts/tests/test_bootstrap.sh
```

Expected result: FAIL because `bootstrap.sh` is not present.

- [ ] **Step 3: Implement bootstrap argument handling and profile resolution**

Support:

```text
--os macos|linux
--profile base|work|mobile
--utils-path PATH
--apply
```

Without `--apply`, print a plan and perform no writes or package-manager installs. Resolve profile membership from the catalog and manifests, then select the platform manifest. Refuse unsupported profile/OS combinations with a non-zero exit.

- [ ] **Step 4: Implement package installation actions**

For macOS, set `BREWFILE=2-areas/workstation-setup/manifests/macos/Brewfile` and use `brew bundle --file="$BREWFILE"` only in apply mode; print that exact path in dry-run mode. For Debian/Ubuntu, read non-comment package names from `apt-packages.txt`; use `apt-get --simulate` in dry-run mode and `sudo apt-get install -y` only in apply mode. Never pass manifest comments or blank lines to a package manager.

- [ ] **Step 5: Implement explicit dotfile mappings**

Read `config-sources.tsv`, restrict sources to the supplied `utils` root and destinations to the selected home root, reject forbidden files, and create only declared mappings. Before replacing an existing destination, move it into `$HOME/.workstation-setup-backups/$(date -u +%Y%m%dT%H%M%SZ)/`. Do not follow unexpected symlinks, overwrite without backup, or copy credential-bearing files.

- [ ] **Step 6: Print manual follow-up actions**

After package and link actions, print non-secret steps for GitHub CLI, cloud tools, Teleport, Devbox, Xcode licensing, and Android SDK licensing when the selected profile includes them. The script must not execute authentication commands or write credential files.

- [ ] **Step 7: Run bootstrap tests and commit**

```bash
bash -n 2-areas/workstation-setup/scripts/bootstrap.sh
bash 2-areas/workstation-setup/scripts/tests/test_bootstrap.sh
```

Expected result: syntax checks and both dry-run/apply fixture cases pass.

```bash
git add 2-areas/workstation-setup/scripts/bootstrap.sh 2-areas/workstation-setup/scripts/tests/test_bootstrap.sh 2-areas/workstation-setup/references/config-sources.tsv 2-areas/workstation-setup/README.md
git commit -m "feat: bootstrap workstation profiles safely" -m "Apply declared package profiles and dotfile links only after an explicit dry-run review and backup." -m "Co-authored-by: oh-my-pi <https://omp.sh>"
git push origin master
```

### Task 5: Implement read-only drift checks

**Files:**
- Create: `2-areas/workstation-setup/scripts/check.sh`
- Create: `2-areas/workstation-setup/scripts/tests/test_check.sh`
- Modify: `2-areas/workstation-setup/README.md`

- [ ] **Step 1: Write compliant and drifted fixture tests**

The test must construct one fixture matching the selected base profile and one fixture with a missing binary, a broken dotfile link, and a modified config checksum. Assert that the compliant fixture exits 0 and the drifted fixture exits non-zero with the exact affected paths in its report.

- [ ] **Step 2: Run the check test to verify the expected failure**

```bash
bash 2-areas/workstation-setup/scripts/tests/test_check.sh
```

Expected result: FAIL because `check.sh` is not present.

- [ ] **Step 3: Implement package, source, link, and checksum checks**

Support the same `--os`, `--profile`, and `--utils-path` inputs as bootstrap. Check required commands from the catalog, desired package entries, declared mapping targets, source checksums, and the `~/utils` Git revision. Print one line per finding with `PASS`, `MISSING`, `DRIFT`, or `UNSAFE`. Never modify files, invoke package installers, or read forbidden credential content.

- [ ] **Step 4: Run checks and commit**

```bash
bash -n 2-areas/workstation-setup/scripts/check.sh
bash 2-areas/workstation-setup/scripts/tests/test_check.sh
```

Expected result: syntax checks and compliant/drifted fixture cases pass.

```bash
git add 2-areas/workstation-setup/scripts/check.sh 2-areas/workstation-setup/scripts/tests/test_check.sh 2-areas/workstation-setup/README.md
git commit -m "feat: report workstation setup drift" -m "Give migration users actionable package, link, checksum, and source-revision status without changing the machine." -m "Co-authored-by: oh-my-pi <https://omp.sh>"
git push origin master
```

### Task 6: Run the end-to-end migration smoke test and finish documentation

**Files:**
- Modify: `2-areas/workstation-setup/README.md`
- Modify: `2-areas/workstation-setup/profiles/*.md`
- Modify: `2-areas/workstation-setup/references/*.md`
- Modify: `2-areas/workstation-setup/inventory/current-machine.md`
- Modify: `2-areas/workstation-setup/inventory/recent-usage.md`

- [ ] **Step 1: Run the complete fixture suite**

```bash
python3 -m unittest 2-areas/workstation-setup/scripts/tests/test_recent_usage.py -v
bash 2-areas/workstation-setup/scripts/tests/test_snapshot.sh
bash 2-areas/workstation-setup/scripts/tests/test_bootstrap.sh
bash 2-areas/workstation-setup/scripts/tests/test_check.sh
```

Expected result: all tests pass, including redaction, catalog coverage, dry-run safety, backup creation, compliant checks, and drift detection.

- [ ] **Step 2: Run the read-only current-machine verification**

```bash
before_utils=$(git -C "$HOME/utils" status --short)
bash 2-areas/workstation-setup/scripts/snapshot.sh --os macos --since 7d --utils-path "$HOME/utils" --output-dir 2-areas/workstation-setup/inventory
bash 2-areas/workstation-setup/scripts/check.sh --os macos --profile base --utils-path "$HOME/utils"
after_utils=$(git -C "$HOME/utils" status --short)
test "$before_utils" = "$after_utils"
```

Expected result: snapshot completes without writing to `~/utils`; check reports either `PASS` or explicit actionable drift. Review generated inventory for secret-like values and remove any before staging.

- [ ] **Step 3: Verify the migration dry run on the current Mac**

```bash
bash 2-areas/workstation-setup/scripts/bootstrap.sh --os macos --profile base --utils-path "$HOME/utils"
```

Expected result: a plan is printed, no package is installed, no destination changes, and no backup directory is created.

- [ ] **Step 4: Verify documentation completeness**

Check that `README.md` links every package member, names all required tool categories, explains the seven-day usage audit and redaction boundary, points to `~/utils`, and links all existing related notes. Confirm profile documents do not promise unsupported Linux distributions or automatic authentication.

- [ ] **Step 5: Commit and push the complete smoke-tested kit**

```bash
git add \
  2-areas/workstation-setup/README.md \
  2-areas/workstation-setup/profiles/base.md \
  2-areas/workstation-setup/profiles/work.md \
  2-areas/workstation-setup/profiles/mobile.md \
  2-areas/workstation-setup/profiles/macos.md \
  2-areas/workstation-setup/profiles/linux-debian.md \
  2-areas/workstation-setup/references/tool-catalog.tsv \
  2-areas/workstation-setup/references/config-sources.tsv \
  2-areas/workstation-setup/references/config-sources.md \
  2-areas/workstation-setup/references/related-notes.md \
  2-areas/workstation-setup/inventory/current-machine.md \
  2-areas/workstation-setup/inventory/recent-usage.md
git commit -m "docs: document workstation migration workflow" -m "Finish the central setup guide after exercising inventory, bootstrap, and drift checks end to end." -m "Co-authored-by: oh-my-pi <https://omp.sh>"
git push origin master
```

Expected result: the vault contains a complete, shareable setup package and the final commit is present on `origin/master`.

## Final verification checklist

- [ ] The tool catalog renders IntelliJ IDEA, VS Code, Cursor, Herdr, Hammerspoon, OMP, Ghostty, tmux, AI clients, work CLIs, and language/mobile tooling even when a package manager does not own them.
- [ ] The seven-day usage audit retains only normalized names and dates and never writes raw command lines or arguments.
- [ ] Installed applications, package entries, runtimes, configuration footprints, recent usage, and unclassified discoveries appear in the generated inventory.
- [ ] Desired manifests remain curated and do not blindly mirror observed state.
- [ ] Bootstrap defaults to dry run, backs up existing destinations, and never manages credentials.
- [ ] Check is read-only and detects package, link, checksum, and source-revision drift.
- [ ] Current-machine smoke testing leaves `~/utils` and credential locations unchanged.
- [ ] Every commit includes the Oh My Pi co-author trailer and vault changes are pushed through the existing Git sync.
