# Menu-Bar Utility Restore Design

## Goal

Make the intentionally selected third-party menu-bar utilities reproducible on a new macOS workstation. The first tracked set is:

- AltTab
- Maccy

Hammerspoon is already managed by the workstation setup kit and is unchanged by this design. Tailscale, OrbStack, Alfred, Apple status items, and enterprise/security agents are outside this scope.

## Existing state

The workstation inventory observes AltTab as a Homebrew cask and as an installed application. Maccy is running on the current machine and uses the `org.p0deje.Maccy` preferences domain. AltTab uses the `com.lwouis.alt-tab-macos` preferences domain.

Neither utility is currently part of the desired macOS package profile or the configuration restore layer. The current setup kit already provides:

- profile-filtered Homebrew package installation;
- dry-run and apply modes;
- destination backups under `~/.workstation-setup-backups/<UTC timestamp>/`;
- safe-source and safe-destination validation;
- fixture-based bootstrap and snapshot tests.

## Scope

### Included

1. Add AltTab and Maccy as intentional `base@macos` menu-bar utilities.
2. Add Homebrew cask entries for both applications.
3. Store sanitized, curated preference templates in `~/utils/macos/menu-bar/`:
   - `alt-tab/preferences.plist`
   - `maccy/preferences.plist`
4. Restore those preferences during macOS bootstrap.
5. Back up an existing defaults domain (via `defaults export`) or an existing preference file at the logical destination before replacing it.
6. Extend safety and bootstrap fixtures to cover dry-run, restore, and backup behavior.
7. Document the privacy boundary and restore behavior.

### Excluded

- Apple system menu extras and Control Center state.
- Enterprise/security-managed agents such as Cortex, Mosyle, and Santa.
- Tailscale, OrbStack, Alfred, or other utilities not selected for this change.
- Clipboard history, application login state, Keychain data, permissions, telemetry identifiers, crash history, window frames, caches, and machine-specific runtime state.
- A generic scanner that attempts to infer every visible menu-bar item.

## Architecture

### Source layout

`~/utils` remains the source of truth for portable user configuration. New files are grouped under `macos/menu-bar/` rather than mixed into IDE configuration:

```text
macos/menu-bar/
├── alt-tab/preferences.plist
└── maccy/preferences.plist
```

The templates contain only explicitly approved preference keys. Raw exports from `~/Library/Preferences` MUST NOT be committed because those files contain telemetry identifiers, device history, window geometry, update state, and other machine-specific data.

### Package profile

Add the two casks to the macOS package manifest with the `base@macos` selector. The catalog entries use a menu-bar utility category and identify the corresponding application/configuration footprint. Linux profiles do not receive these entries.

### Restore flow

Add a dedicated menu-bar restore step to `bootstrap.sh` after package installation and before normal configuration mapping:

1. Return without action on Linux.
2. Validate each source template is a regular file inside the configured utils root and parses as a property list with only per-app allowlisted keys.
3. Resolve the target defaults domain and its logical preference path under `$HOME`. AltTab's domain `com.lwouis.alt-tab-macos` lives at the conventional `~/Library/Preferences/com.lwouis.alt-tab-macos.plist`; Maccy is sandboxed, so its domain `org.p0deje.Maccy` lives at `~/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist`, not `~/Library/Preferences/`.
4. In dry-run mode, print the planned `PLAN MENU_BAR <id> -> $HOME/<destination>` restore and, when a live store exists, the planned timestamped backup path — without modifying files. If `defaults` is unavailable, dry-run still plans the restore without probing backups.
5. In apply mode, probe `defaults domains` for each domain. Back up a present domain with `defaults export <domain> <path>`; copy a regular file at the logical destination when the domain is absent; abort before any import if `defaults domains` itself fails. A symlink at the logical destination is rejected as `UNSAFE`. Restore is **defaults-domain export/import**, never a move of `$HOME/Library/Preferences` files.
6. Import the curated preference template into the app's defaults domain with `defaults import <domain> <template>` before the app is launched. The restore operation MUST not copy any app database or runtime directory, and MUST not kill the running app.
7. Report a clear failure if a source is malformed, an allowlist check fails, a backup target is unsafe, or a backup/import operation fails.

The implementation must preserve the existing bootstrap safety invariants (source inside `~/utils`, destination inside `$HOME`, validated backup targets) and must not write outside `$HOME` or the utils source tree.

## Data flow

```text
~/utils/macos/menu-bar/*.plist
        │
        ├── source validation and plist parsing
        │
        ├── bootstrap dry-run plan
        │
        └── bootstrap apply
              ├── backup existing preferences
              └── import curated preferences into AltTab/Maccy domains
```

The package manifest installs the applications; the curated templates restore user-facing behavior. Authentication, permissions, clipboard contents, and other external state remain manual follow-ups.

## Safety and privacy

The utils remote is public, so the tracked templates must be safe for public visibility. Before committing each template:

- parse it as a property list;
- allow only the intended preference keys;
- reject telemetry, device-history, window-frame, clipboard-history, credential, token, and absolute-path values;
- verify the source is a regular file within `~/utils`;
- verify restore destinations remain within `$HOME`.

The setup kit MUST continue to fail closed when a source cannot be classified safely. Existing destination backups remain the recovery path for local settings that are not represented by the curated templates.

## Verification

Add deterministic fixture coverage for:

- macOS profile selection includes both menu-bar casks;
- Linux profile selection excludes them;
- dry-run reports menu-bar restore actions without creating files;
- apply imports both templates;
- an existing preference file is backed up before replacement;
- malformed or unsafe source templates fail closed;
- existing check, bootstrap, and snapshot fixtures remain passing;
- all tracked templates pass property-list parsing and contain no forbidden data.

## Acceptance criteria

- A fresh macOS `base` bootstrap installs AltTab and Maccy.
- A fresh macOS `base` bootstrap restores the curated AltTab and Maccy preferences without copying history, credentials, or machine state.
- Existing preference files are backed up before replacement.
- Dry-run remains side-effect free.
- Linux behavior is unchanged.
- The implementation is covered by focused fixtures and documented in the workstation setup kit.
