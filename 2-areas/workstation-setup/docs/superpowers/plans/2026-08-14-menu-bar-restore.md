# Menu-Bar Utility Restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add privacy-safe package installation and preference restoration for the confirmed macOS menu-bar utilities AltTab and Maccy.

**Architecture:** Keep curated preference templates in the separate `~/utils` source repository, add both casks to the macOS `base@macos` profile, and restore preferences through a dedicated macOS-only bootstrap function. The restore function validates source paths and plist syntax, backs up existing preference files, and imports only the curated templates; it never copies clipboard history, credentials, telemetry, permissions, or runtime databases.

**Tech Stack:** Bash, Homebrew Brewfile selectors, TSV catalog metadata, macOS `defaults`, Python `plistlib`, shell fixture tests.

---

## File map

- Create in `/Users/amit/utils`:
  - `macos/menu-bar/alt-tab/preferences.plist` — sanitized AltTab user preferences.
  - `macos/menu-bar/maccy/preferences.plist` — sanitized Maccy user preferences.
- Modify in `/Users/amit/Projects/doordash/private notes vault`:
  - `2-areas/workstation-setup/manifests/macos/Brewfile` — add the two `base@macos` casks.
  - `2-areas/workstation-setup/references/tool-catalog.tsv` — add menu-bar utility inventory rows.
  - `2-areas/workstation-setup/scripts/bootstrap.sh` — validate and restore the templates.
  - `2-areas/workstation-setup/scripts/tests/test_bootstrap.sh` — red/green restore, backup, and safety fixtures.
  - `2-areas/workstation-setup/scripts/tests/test_snapshot.sh` — fixture coverage for application and cask discovery.
  - `2-areas/workstation-setup/scripts/snapshot.sh` — render a dedicated menu-bar inventory category.
  - `2-areas/workstation-setup/README.md` — document the selected utilities and privacy boundary.
  - `2-areas/workstation-setup/profiles/macos.md` — document package and permission handoffs.
  - `2-areas/workstation-setup/references/config-sources.md` — document that menu-bar preferences use curated import rather than symlinks.

The existing Hammerspoon mapping and IntelliJ/VS Code/Cursor restore code remain unchanged except for the new bootstrap call ordering.

---

### Task 1: Add failing fixture coverage

**Files:**
- Modify: `2-areas/workstation-setup/scripts/tests/test_bootstrap.sh:15-41,64-139,157-215,239-291`
- Modify: `2-areas/workstation-setup/scripts/tests/test_snapshot.sh:14-122,152-179`

- [ ] **Step 1: Add menu-bar fixture sources and a fake defaults command**

Extend the bootstrap fixture with:

```bash
mkdir -p "$UTILS_DIR/macos/menu-bar/alt-tab" \
  "$UTILS_DIR/macos/menu-bar/maccy" \
  "$HOME_DIR/Library/Preferences"

cat >"$UTILS_DIR/macos/menu-bar/alt-tab/preferences.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0//EN">
<plist version="1.0"><dict>
  <key>appearanceSize</key><integer>1</integer>
  <key>nextWindowGesture</key><integer>4</integer>
  <key>previewFocusedWindow</key><false/>
  <key>showFullscreenWindows</key><string>1</string>
  <key>showHiddenWindows</key><string>1</string>
  <key>showMinimizedWindows</key><string>1</string>
  <key>spacesToShow</key><string>1</string>
  <key>windowOrder10</key><string>0</string>
</dict></plist>
PLIST

cat >"$UTILS_DIR/macos/menu-bar/maccy/preferences.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0//EN">
<plist version="1.0"><dict>
  <key>enabledPasteboardTypes</key><array><string>public.utf8-plain-text</string></array>
  <key>pasteByDefault</key><true/>
  <key>previewWidth</key><integer>400</integer>
  <key>removeFormattingByDefault</key><true/>
  <key>showFooter</key><true/>
  <key>showSearch</key><true/>
  <key>showTitle</key><true/>
</dict></plist>
PLIST
```

Add a fake `$BIN_DIR/defaults` that accepts `defaults domains`, `defaults read <domain>`, `defaults export <domain> <path>`, and `defaults import <domain> <plist>`. It maps `com.lwouis.alt-tab-macos` to `$HOME/Library/Preferences/com.lwouis.alt-tab-macos.plist` and the sandboxed `org.p0deje.Maccy` to `$HOME/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist`, copies the source to the domain's live store on `import`, reports a domain present in `domains` only when its live store file exists, and appends each invocation to `DEFAULTS_LOG`. It must exit nonzero for any other command or domain.

Define and export `DEFAULTS_LOG="$FIXTURE/defaults.log"` alongside the existing fixture logs. Add the fake command to the executable list.

- [ ] **Step 2: Add failing bootstrap assertions**

Before implementation exists, assert that the base dry-run output contains:

```bash
assert_contains "$BASE_PACKAGES" 'cask "alt-tab"'
assert_contains "$BASE_PACKAGES" 'cask "maccy"'
assert_contains "$DRY_RUN" 'PLAN MENU_BAR alt-tab'
assert_contains "$DRY_RUN" 'PLAN MENU_BAR maccy'
```

After the existing apply invocation, assert:

```bash
assert_file "$HOME_DIR/Library/Preferences/com.lwouis.alt-tab-macos.plist"
assert_file "$HOME_DIR/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist"
assert_contains "$(cat "$DEFAULTS_LOG")" 'import com.lwouis.alt-tab-macos'
assert_contains "$(cat "$DEFAULTS_LOG")" 'import org.p0deje.Maccy'
```

Create an existing AltTab and Maccy preference before apply (Maccy's live store at its sandboxed container path), then assert each is **exported/copied** to the timestamped backup directory before import — restore is defaults-domain export/import, not a file move:

```text
$HOME_DIR/.workstation-setup-backups/20260101T000000Z/Library/Preferences/com.lwouis.alt-tab-macos.plist
$HOME_DIR/.workstation-setup-backups/20260101T000000Z/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist
```

Add a second fixture invocation whose AltTab source is malformed XML. Assert bootstrap exits nonzero, reports `UNSAFE` or `invalid plist`, and does not create a backup directory or mutate the destination.

- [ ] **Step 3: Add failing inventory assertions**

In `test_snapshot.sh`:

- Add `/Applications/AltTab.app` and `/Applications/Maccy.app` to the fake `mdfind` output.
- Add `alt-tab` and `maccy` to the fake Homebrew cask version output.
- Add `AltTab` and `Maccy` to the expected macOS inventory rows.
- Assert both catalog **application** rows (`| AltTab | detected | application:AltTab | base@macos |`, `| Maccy | detected | application:Maccy | base@macos |`) are categorized under the `## Menu-bar utilities` heading and carry the `base@macos` profile. The package-manager **cask** rows (`| cask | alt-tab | 0.27 | base@macos |`, `| cask | maccy | 0.30 | base@macos |`) also resolve to `base@macos` via `catalog_id_profile`, because the casks are curated base@macos manifest entries (not `observed-only`).
- Assert the Linux snapshot has **no** `## Menu-bar utilities` section and no `| AltTab |`, `| Maccy |`, `| cask | alt-tab |`, or `| cask | maccy |` rows: the catalog rows carry platform-prefixed `macos=` config roots that do not resolve on Linux, so they are skipped and the section is suppressed. Hammerspoon (`base@macos` with a bare `.hammerspoon` root) still renders on Linux, so the Linux exclusion is specific to the menu-bar utilities.

- [ ] **Step 4: Run the red tests**

Run:

```bash
bash 2-areas/workstation-setup/scripts/tests/test_bootstrap.sh
bash 2-areas/workstation-setup/scripts/tests/test_snapshot.sh
```

Expected result: failure on the first missing AltTab/Maccy package or restore assertion. Do not modify production code before observing this failure.

---

### Task 2: Add sanitized sources and package/catalog metadata

**Files:**
- Create: `/Users/amit/utils/macos/menu-bar/alt-tab/preferences.plist`
- Create: `/Users/amit/utils/macos/menu-bar/maccy/preferences.plist`
- Modify: `2-areas/workstation-setup/manifests/macos/Brewfile:18-20`
- Modify: `2-areas/workstation-setup/references/tool-catalog.tsv:12-15`

- [ ] **Step 1: Generate AltTab's curated template from the live plist**

Use a temporary Python script with `plistlib` to read `~/Library/Preferences/com.lwouis.alt-tab-macos.plist` and write only these keys to the utils template when present:

```text
appearanceSize
appearanceStyle
appsToShow
appsToShow10
appsToShow2
crashPolicy
exceptions
nextWindowGesture
previewFocusedWindow
showFullscreenWindows
showFullscreenWindows10
showHiddenWindows
showHiddenWindows10
showMinimizedWindows
showMinimizedWindows10
spacesToShow
spacesToShow10
spacesToShow2
updatePolicy
windowOrder10
```

The script must omit every `MSAppCenter*`, `NSWindow Frame *`, `SU*`, `preferencesVersion`, permission, device-history, and telemetry key. If `exceptions` is retained, parse its JSON string and reject any object whose keys are outside `ignore`, `hide`, and `bundleIdentifier`, or whose bundle identifier contains `/`, `\\`, whitespace, `~`, or an absolute path.

Write the result as XML plist to `/Users/amit/utils/macos/menu-bar/alt-tab/preferences.plist`.

- [ ] **Step 2: Generate Maccy's curated template from the live plist**

Read `defaults export org.p0deje.Maccy -` into a temporary plist and retain only:

```text
KeyboardShortcuts_delete
KeyboardShortcuts_pin
KeyboardShortcuts_popup
KeyboardShortcuts_togglePreview
NSStatusItem VisibleCC Item-1
enabledPasteboardTypes
pasteByDefault
previewWidth
removeFormattingByDefault
showFooter
showSearch
showTitle
```

For each `KeyboardShortcuts_*` value, parse the JSON string and require only integer `carbonModifiers` and `carbonKeyCode` fields. Require `enabledPasteboardTypes` to contain only UTI-like strings matching `[A-Za-z0-9._-]+`. Omit `NSWindow Frame *`, `SU*`, `migrations`, and `windowSize` so no geometry, update timestamps, migration state, or clipboard contents are stored.

Write the result as XML plist to `/Users/amit/utils/macos/menu-bar/maccy/preferences.plist`.

- [ ] **Step 3: Add package entries**

Append these lines to the macOS Brewfile:

```text
cask "alt-tab" # profile:base@macos
cask "maccy" # profile:base@macos
```

- [ ] **Step 4: Add catalog entries**

Append these TSV rows:

```text
alt-tab	AltTab	menu-bar-utility		AltTab	macos=Library/Preferences/com.lwouis.alt-tab-macos.plist	base@macos
maccy	Maccy	menu-bar-utility		Maccy	macos=Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist	base@macos
```

The empty command column is intentional: discovery uses application names and preference footprints, not a CLI executable.

- [ ] **Step 5: Validate sources before production changes**

Run:

```bash
python3 -c 'import plistlib; [plistlib.load(open(p, "rb")) for p in ["/Users/amit/utils/macos/menu-bar/alt-tab/preferences.plist", "/Users/amit/utils/macos/menu-bar/maccy/preferences.plist"]]'
git -C /Users/amit/utils diff --check
git diff --check
```

Expected result: both plist loads succeed and both diff checks produce no output.

---

### Task 3: Implement safe menu-bar preference restore

**Files:**
- Modify: `2-areas/workstation-setup/scripts/bootstrap.sh:534-645`

- [ ] **Step 1: Add plist syntax validation**

Add this helper before `restore_intellij_settings`:

```bash
validate_menu_bar_plist() {
  python3 - "$1" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "rb") as stream:
    value = plistlib.load(stream)
if not isinstance(value, dict):
    raise SystemExit("menu-bar preference plist must contain a dictionary")
PY
}
```

- [ ] **Step 2: Add the restore function**

Add `restore_menu_bar_settings()` before the existing IntelliJ restore function. The function must:

- return immediately unless `OS=macos`;
- require `defaults` only when `APPLY=1`;
- iterate over these exact records:

```text
alt-tab|com.lwouis.alt-tab-macos|macos/menu-bar/alt-tab/preferences.plist|Library/Preferences/com.lwouis.alt-tab-macos.plist
maccy|org.p0deje.Maccy|macos/menu-bar/maccy/preferences.plist|Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist
```

The Maccy destination is the **sandboxed** container path, not `~/Library/Preferences/org.p0deje.Maccy.plist`, because Maccy runs in an App Sandbox. AltTab uses the conventional `~/Library/Preferences/` location.

- call `validate_source` and `validate_menu_bar_plist` (per-app key allowlist) for each source;
- call `validate_destination` and `validate_backup_target` using the relative destination path;
- reject a symlink at the logical destination as `UNSAFE` on apply (dry-run emits a `PLAN REVIEW` note) — destinations are defaults databases, never symlink targets;
- print `PLAN MENU_BAR <id> -> $HOME/<destination>` during dry-run, plus the planned timestamped backup path when a live store exists;
- probe `defaults domains` for each domain; a present domain is backed up with `defaults export <domain> <path>`, an absent domain with a regular file at the logical destination is copied, and a `defaults domains` failure aborts before any import — restore is **defaults-domain export/import, not a move of `$HOME/Library/Preferences` files**;
- back up the existing state into `$HOME/.workstation-setup-backups/$TIMESTAMP/<relative destination>` before import;
- run `defaults import "$domain" "$source"` and fail with `ws_die` if the import fails;
- print `MENU_BAR RESTORED <id>` after a successful import;
- never kill AltTab or Maccy — `defaults import` writes the database and the app reads curated preferences on its next launch (quit before apply for an immediate live effect).

Use this implementation shape so the source and destination remain distinct:

```bash
restore_menu_bar_settings() {
  [ "$OS" = macos ] || return 0
  # Apply requires a real `defaults`; dry-run may run where it is absent, in
  # which case we plan the restore without probing live domains/backups.
  if [ "$APPLY" -eq 1 ]; then
    ws_command_exists defaults || { ws_die 'defaults is required for menu-bar restore'; return 1; }
  fi
  for id in \
    'alt-tab|com.lwouis.alt-tab-macos|macos/menu-bar/alt-tab/preferences.plist|Library/Preferences/com.lwouis.alt-tab-macos.plist' \
    'maccy|org.p0deje.Maccy|macos/menu-bar/maccy/preferences.plist|Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist' \
    ; do
    IFS='|' read -r id domain source destination <<EOF
$id
EOF
    validate_source "$source" || { ws_die "unsafe menu-bar source $id"; return 1; }
    validate_menu_bar_plist "$id" "$source" || { ws_die "invalid menu-bar plist $id"; return 1; }
    validate_destination "$destination" || { ws_die "unsafe menu-bar destination $id"; return 1; }
    # A symlink destination is a defaults database masquerading as a link:
    # reject on apply (UNSAFE), emit PLAN REVIEW on dry-run, never follow it.
    # Then probe `defaults domains`; export a present domain (or copy a regular
    # file at the logical destination) into the timestamped backup dir, abort on
    # a `defaults domains` failure, and finally `defaults import` the template.
    # The full shipped function also handles the defaults-absent dry-run branch.
    …
    printf 'MENU_BAR RESTORED %s\n' "$id"
  done
}
```

- [ ] **Step 3: Wire the restore step into bootstrap**

Call `restore_menu_bar_settings || exit 1` immediately after the package-install `case` block and before `ensure_kickstart`. This makes dry-run output visible without side effects and ensures macOS packages are installed before their defaults domains are imported.

- [ ] **Step 4: Run the green bootstrap fixture**

Run:

```bash
bash 2-areas/workstation-setup/scripts/tests/test_bootstrap.sh
```

Expected result: `bootstrap fixture tests: PASS`, including package selection, dry-run plans, plist imports, and timestamped backups.

---

### Task 4: Update documentation and inventory expectations

**Files:**
- Modify: `2-areas/workstation-setup/README.md:82-87`
- Modify: `2-areas/workstation-setup/profiles/macos.md:30-65`
- Modify: `2-areas/workstation-setup/scripts/snapshot.sh:398-405`

- [ ] **Step 1: Add a dedicated inventory category**

Update `category_heading()` in `snapshot.sh` with:

```bash
menu-bar-utility) printf 'Menu-bar utilities' ;;
```

Append `'Menu-bar utilities'` to the heading-emission for-loop that writes `## <heading>` sections, so the new rows file is actually consumed and the section renders. Then make the section macOS-only: in `render_catalog_rows`, skip any catalog row whose `config_roots` is platform-prefixed (`macos=…`) but does not resolve on the current OS (so AltTab/Maccy, whose roots are `macos=`-prefixed, never render on Linux, while Hammerspoon's bare `.hammerspoon` root still does); and in the for-loop, skip emitting the `## Menu-bar utilities` heading when its `.rows` file is empty. Add `Menu-bar utilities` to the README inventory category list. Extend `test_snapshot.sh` to assert the generated macOS report contains `## Menu-bar utilities` and the AltTab/Maccy rows, and the Linux report contains neither the section nor the rows.
- [ ] **Step 2: Document selected menu-bar utilities**

Update the README's current mappings/package summary to name AltTab and Maccy as curated `base@macos` menu-bar utilities restored from `~/utils/macos/menu-bar/`. State that their preferences are imported rather than symlinked because macOS defaults databases contain dynamic state.

- [ ] **Step 3: Document manual handoffs and exclusions**

Add to `profiles/macos.md`:

- AltTab and Maccy are installed by the base macOS manifest.
- Accessibility/screen-recording permissions remain manual OS actions.
- Maccy clipboard history and all login/session state are intentionally not restored.
- Security agents and unselected menu-bar utilities remain outside the profile.

Add to `references/config-sources.md` a dedicated section explaining the two curated plist sources, their target defaults domains, timestamped backups, and the public-repository privacy boundary.

- [ ] **Step 4: Run documentation consistency checks**

Run:

```bash
git diff --check
bash 2-areas/workstation-setup/scripts/tests/test_snapshot.sh
```

Expected result: `snapshot fixture tests: PASS`; generated inventory rows include AltTab and Maccy without raw preference contents.

---

### Task 5: Run the complete verification suite

**Files:**
- Test: `2-areas/workstation-setup/scripts/tests/test_check.sh`
- Test: `2-areas/workstation-setup/scripts/tests/test_bootstrap.sh`
- Test: `2-areas/workstation-setup/scripts/tests/test_snapshot.sh`
- Sources: `/Users/amit/utils/macos/menu-bar/**/*.plist`

- [x] **Step 1: Run all focused fixtures**

Run:

```bash
bash 2-areas/workstation-setup/scripts/tests/test_check.sh
bash 2-areas/workstation-setup/scripts/tests/test_bootstrap.sh
bash 2-areas/workstation-setup/scripts/tests/test_snapshot.sh
```

Expected output:

```text
check fixture tests: PASS
bootstrap fixture tests: PASS
snapshot fixture tests: PASS
```

- [x] **Step 2: Run syntax and privacy checks**

Run:

```bash
bash -n 2-areas/workstation-setup/scripts/bootstrap.sh 2-areas/workstation-setup/scripts/tests/test_bootstrap.sh 2-areas/workstation-setup/scripts/tests/test_snapshot.sh
python3 -c 'import plistlib; [plistlib.load(open(p, "rb")) for p in ["/Users/amit/utils/macos/menu-bar/alt-tab/preferences.plist", "/Users/amit/utils/macos/menu-bar/maccy/preferences.plist"]]'
git diff --check
git -C /Users/amit/utils diff --check
```

Expected result: all commands exit zero and emit no syntax, plist, or whitespace errors.

- [x] **Step 3: Verify no raw preference artifacts are staged**

Run:

```bash
git -C /Users/amit/utils status --short
git status --short
```

Confirm only the two curated plist templates and the planned workstation setup files are changed. Do not stage `~/Library/Preferences`, clipboard databases, or generated fixture output.

- [x] **Step 4: Commit the two repositories separately**

Commit the source templates in `~/utils`:

```bash
cd /Users/amit/utils
git add macos/menu-bar/alt-tab/preferences.plist macos/menu-bar/maccy/preferences.plist
git commit -m "feat(menu-bar): add sanitized utility preferences" -m "Co-authored-by: oh-my-pi <https://omp.sh>"
```

Commit the setup control-plane changes in `private notes vault`:

```bash
cd /Users/amit/Projects/doordash/private notes vault
git add 2-areas/workstation-setup/manifests/macos/Brewfile \
  2-areas/workstation-setup/references/tool-catalog.tsv \
  2-areas/workstation-setup/scripts/bootstrap.sh \
  2-areas/workstation-setup/scripts/tests/test_bootstrap.sh \
  2-areas/workstation-setup/scripts/tests/test_snapshot.sh \
  2-areas/workstation-setup/README.md \
  2-areas/workstation-setup/profiles/macos.md \
  2-areas/workstation-setup/references/config-sources.md
git commit -m "feat(workstation): restore menu-bar utilities" -m "Co-authored-by: oh-my-pi <https://omp.sh>"
```

Do not push the public `~/utils` remote without verifying the intended GitHub owner and write identity; the tracked preferences are deliberately sanitized for public visibility but still represent user configuration.
