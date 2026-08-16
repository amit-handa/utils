# Server Service Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a sanitized, dry-run-first service synchronization layer for the Linux `WORKSTATION_PROFILE=server` environment without copying secrets, identities, databases, media, or host-specific runtime state.

**Architecture:** Keep `references/config-sources.tsv` and `bootstrap.sh` unchanged. Add a separate `server/services.tsv` contract, reviewed service templates, and `scripts/server-sync.sh`. The command reads only fixed metadata and an optional local `0600` variables file, validates staged output, backs up only declared configuration files, and never restarts services or touches service data.

**Tech Stack:** Bash 3.2-compatible shell, existing `scripts/lib.sh` safety helpers, TSV metadata, Docker Compose CLI, Apache `apachectl`, systemd probes, fixture-driven Bash tests, Markdown documentation.

---

## File map

Create:

- `2-areas/workstation-setup/server/services.tsv` — service inventory and fixed synchronization policies.
- `2-areas/workstation-setup/server/templates/apache/virtual-host.conf.tmpl` — redacted Apache virtual-host template.
- `2-areas/workstation-setup/server/templates/compose/homeassistant/compose.yaml` — portable Home Assistant Compose definition.
- `2-areas/workstation-setup/server/templates/compose/immich/compose.yaml` — portable CPU-only Immich Compose definition.
- `2-areas/workstation-setup/server/templates/compose/mosquitto/compose.yaml` — portable Mosquitto Compose definition.
- `2-areas/workstation-setup/server/templates/examples/homeassistant-configuration.yaml` — minimal non-secret Home Assistant configuration example.
- `2-areas/workstation-setup/server/templates/examples/immich.env.example` — non-secret Immich variable names and local path examples.
- `2-areas/workstation-setup/server/templates/examples/mosquitto.conf` — reviewed broker configuration with anonymous access disabled.
- `2-areas/workstation-setup/scripts/server-sync.sh` — inventory, dry-run, staged validation, backup, and apply command.
- `2-areas/workstation-setup/scripts/tests/test_server_sync.sh` — rootless fixture tests and template privacy checks.
- `2-areas/workstation-setup/references/server-services.md` — user-facing service policy and operation reference.

Modify:

- `2-areas/workstation-setup/README.md` — link server synchronization from the server environment section and verification commands.
- `2-areas/workstation-setup/profiles/base.md` — document the server service inventory and manual follow-up boundary.

No existing home mapping, profile filtering, or live service data file is modified.

---

### Task 1: Add the failing server-sync fixture contract

**Files:**
- Create: `2-areas/workstation-setup/scripts/tests/test_server_sync.sh`

- [ ] **Step 1: Create the fixture test with explicit failure assertions**

Use the existing fixture conventions: `set -eu`, derive `PACKAGE_DIR` from `SCRIPT_DIR`, create a temporary `HOME_DIR`, `BIN_DIR`, `DEST_DIR`, and `VARS_FILE`, and remove the fixture with a trap. Define these helpers:

```bash
assert_contains() {
  case $1 in *"$2"*) ;; *) printf 'missing expected text: %s\n' "$2" >&2; exit 1 ;; esac
}
assert_not_contains() {
  case $1 in *"$2"*) printf 'found unexpected text: %s\n' "$2" >&2; exit 1 ;; *) ;; esac
}
assert_failed() {
  if "$@" >"$FIXTURE/command.out" 2>&1; then
    printf 'command unexpectedly passed: %s\n' "$*" >&2
    exit 1
  fi
}
```

Create fake command outputs without executing systemd or Docker:

```bash
cat >"$BIN_DIR/systemctl" <<'SH'
#!/bin/sh
case "$*" in
 *'is-active --quiet apache2'*) printf 'active\n'; exit 0 ;;
 *'--user is-active --quiet syncthing'*) printf 'active\n'; exit 0 ;;
 *'is-active --quiet photoview'*) printf 'failed\n'; exit 3 ;;
 *'is-active --quiet vsftpd'*) printf 'failed\n'; exit 3 ;;
  *) printf 'inactive\n'; exit 3 ;;
esac
SH
cat >"$BIN_DIR/docker" <<'SH'
#!/bin/sh
case "$*" in
  *'compose ls --all --format json'*)
    printf '%s\n' '[{"Name":"immich-app","Status":"running(4)"},{"Name":"ha2","Status":"running(1)"},{"Name":"mosquitto-docker","Status":"running(1)"},{"Name":"unexpected-app","Status":"running(1)}]'
    ;;
  *'compose config --quiet'*) exit 0 ;;
  *) exit 1 ;;
esac
SH
cat >"$BIN_DIR/apachectl" <<'SH'
#!/bin/sh
case "$*" in *'-t -f '*) printf 'Syntax OK\n'; exit 0 ;; *) exit 1 ;; esac
SH
chmod +x "$BIN_DIR/systemctl" "$BIN_DIR/docker" "$BIN_DIR/apachectl"
```

Create a `0600` variables file using paths that satisfy the production destination grammar but do not exist in the fixture:

```bash
cat >"$VARS_FILE" <<'EOF'
APACHE_SITE_PATH=/etc/apache2/sites-available/server-sync-test.conf
APACHE_SERVER_NAME=example.invalid
APACHE_DOCUMENT_ROOT=/srv/server-sync-fixture/www
IMMICH_ROOT=/srv/server-sync-fixture/immich
HOMEASSISTANT_ROOT=/srv/server-sync-fixture/homeassistant
MOSQUITTO_ROOT=/srv/server-sync-fixture/mosquitto
EOF
chmod 600 "$VARS_FILE"
```

Run the intended behavioral assertions once the command exists:

```bash
SYNC="$PACKAGE_DIR/scripts/server-sync.sh"
INVENTORY=$(WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --inventory 2>&1)
assert_contains "$INVENTORY" 'OK service apache2 active'
assert_contains "$INVENTORY" 'OK service syncthing active'
assert_contains "$INVENTORY" 'INACTIVE service photoview'
assert_contains "$INVENTORY" 'INACTIVE service vsftpd'
assert_contains "$INVENTORY" 'OK compose immich-app running'
assert_contains "$INVENTORY" 'UNEXPECTED compose project unexpected-app'
cat >"$BIN_DIR/docker" <<'SH'
#!/bin/sh
case "$*" in
  *'compose ls --all --format json'*)
    printf '%s\n' '[{"Name":"immich-app","Status":"running(4)"},{"Name":"unexpected-app","Status":"running(1)"}]'
    ;;
  *'compose config --quiet'*) exit 0 ;;
  *) exit 1 ;;
esac
SH
chmod +x "$BIN_DIR/docker"
MISSING_INVENTORY=$(WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --inventory 2>&1)
assert_contains "$MISSING_INVENTORY" 'INACTIVE compose ha2 missing'
assert_contains "$MISSING_INVENTORY" 'INACTIVE compose mosquitto-docker missing'

APACHE_PLAN=$(WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --service apache2 --vars-file "$VARS_FILE" 2>&1)
assert_contains "$APACHE_PLAN" 'PLAN SERVICE apache2'
assert_contains "$APACHE_PLAN" 'PLAN VALIDATE apache2'
assert_not_contains "$APACHE_PLAN" 'immich'
[ ! -e "$DEST_DIR/apache/site.conf" ] || exit 1

assert_failed env WORKSTATION_PROFILE=personal HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --service apache2 --vars-file "$VARS_FILE"
assert_failed env WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --service unknown
assert_failed env WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --service apache2 --apply

MISSING_VARS="$FIXTURE/missing-vars"
printf '%s\n' \
  'APACHE_SITE_PATH=/etc/apache2/sites-available/server-sync-test.conf' \
  'APACHE_SERVER_NAME=example.invalid' >"$MISSING_VARS"
chmod 600 "$MISSING_VARS"
assert_failed env WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --service apache2 --apply --vars-file "$MISSING_VARS"

BAD_DEST_VARS="$FIXTURE/bad-destination-vars"
cat >"$BAD_DEST_VARS" <<'EOF'
APACHE_SITE_PATH=/tmp/unsafe.conf
APACHE_SERVER_NAME=example.invalid
APACHE_DOCUMENT_ROOT=/srv/server-sync-fixture/www
EOF
chmod 600 "$BAD_DEST_VARS"
assert_failed env WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --service apache2 --apply --vars-file "$BAD_DEST_VARS"

UNRESOLVED_VARS="$FIXTURE/unresolved-vars"
cat >"$UNRESOLVED_VARS" <<'EOF'
APACHE_SITE_PATH=/etc/apache2/sites-available/server-sync-test.conf
APACHE_SERVER_NAME=__APACHE_DOCUMENT_ROOT__
APACHE_DOCUMENT_ROOT=/srv/server-sync-fixture/www
EOF
chmod 600 "$UNRESOLVED_VARS"
assert_failed env WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --service apache2 --vars-file "$UNRESOLVED_VARS"

DATA_ROOT_VARS="$FIXTURE/data-root-vars"
cat >"$DATA_ROOT_VARS" <<'EOF'
IMMICH_ROOT=/var/lib/immich
EOF
chmod 600 "$DATA_ROOT_VARS"
assert_failed env WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --service immich --apply --vars-file "$DATA_ROOT_VARS"
[ ! -e "$DEST_DIR/apache/site.conf" ] || exit 1
```

- [ ] **Step 2: Add the template privacy scan to the same test**

Use Python only as a file argument script, not a shell pipeline. Scan every file under `server/templates` and reject credential-shaped words or host-specific values, including commented lines:

```bash
python3 - "$PACKAGE_DIR/server/templates" <<'PY'
import re
import sys
from pathlib import Path
root = Path(sys.argv[1])
for path in root.rglob('*'):
    if not path.is_file():
        continue
    text = path.read_text()
    if re.search(r'(?i)(password|secret|token|private[_-]?key|credential|authorization|bearer)', text):
        raise SystemExit(f'credential-shaped content in {path}')
    if re.search(r'/home/amit/|/Users/|/mnt/media/nobackup/|192\.168\.|BEGIN .*PRIVATE KEY|dakshit', text):
        raise SystemExit(f'host-specific content in {path}')
print('template privacy: PASS')
PY
```

The example files must therefore avoid password keys and commented credentials; local credentials remain outside `utils`.

- [ ] **Step 3: Run the test before implementation**

Run from the worktree:

```bash
bash 2-areas/workstation-setup/scripts/tests/test_server_sync.sh
```

Expected: failure because `scripts/server-sync.sh` and `server/services.tsv` do not exist yet. Preserve the failing assertions; do not weaken them.

- [ ] **Step 4: Commit the red test contract**

```bash
git add 2-areas/workstation-setup/scripts/tests/test_server_sync.sh
git diff --cached --check
git commit -m "test(workstation): specify server service sync safety" \
  -m "Define rootless inventory, dry-run, failure, and template privacy behavior before implementation." \
  -m "Co-authored-by: oh-my-pi <https://omp.sh>"
```

---

### Task 2: Add service metadata and sanitized templates

**Files:**
- Create: `2-areas/workstation-setup/server/services.tsv`
- Create: `2-areas/workstation-setup/server/templates/apache/virtual-host.conf.tmpl`
- Create: `2-areas/workstation-setup/server/templates/compose/homeassistant/compose.yaml`
- Create: `2-areas/workstation-setup/server/templates/compose/immich/compose.yaml`
- Create: `2-areas/workstation-setup/server/templates/compose/mosquitto/compose.yaml`
- Create: `2-areas/workstation-setup/server/templates/examples/homeassistant-configuration.yaml`
- Create: `2-areas/workstation-setup/server/templates/examples/immich.env.example`
- Create: `2-areas/workstation-setup/server/templates/examples/mosquitto.conf`

- [ ] **Step 1: Create the seven-column service contract**

Write this exact TSV header and row set:

```text
id	manager	probe	artifact	destination_key	policy	excluded_classes
apache2	systemd	systemctl:is-active:apache2	server/templates/apache/virtual-host.conf.tmpl	APACHE_SITE_PATH	template	certificates|private-keys|logs|hostnames|document-roots
immich	docker-compose	docker:compose:immich-app	server/templates/compose/immich/compose.yaml	IMMICH_ROOT	template	env|uploads|media|postgresql|redis|model-cache
homeassistant	docker-compose	docker:compose:ha2	server/templates/compose/homeassistant/compose.yaml	HOMEASSISTANT_ROOT	template	env|storage|databases|logs|backups|device-ids|automations|credentials
mosquitto	docker-compose	docker:compose:mosquitto-docker	server/templates/compose/mosquitto/compose.yaml	MOSQUITTO_ROOT	template	password-files|data|logs|credentials|runtime-identity
syncthing	systemd-user	systemctl:user:is-active:syncthing	-	-	inventory-only	config|keys|device-ids|folders|indexes|database
mariadb	systemd	systemctl:is-active:mariadb	-	-	manual-review	data|users|grants|credentials|logs
samba	systemd	systemctl:is-active:smbd	-	-	manual-review	account-database|acls|shares|credentials
x11vnc	systemd	systemctl:is-active:x11vnc	-	-	manual-review	passwords|display-state|session-state|overrides
photoview	systemd	systemctl:is-active:photoview	-	-	manual-review	compose|env|media|database|logs
vsftpd	systemd	systemctl:is-active:vsftpd	-	-	manual-review	config|credentials|certificates|logs|user-data
```

The script will treat `probe` as a declarative label only; it will never execute a metadata field as shell code.

- [ ] **Step 2: Create the Apache template**

Write `virtual-host.conf.tmpl` with only fixed markers for host-local values:

```apache
<VirtualHost *:80>
    ServerName __APACHE_SERVER_NAME__
    DocumentRoot __APACHE_DOCUMENT_ROOT__

    <Directory __APACHE_DOCUMENT_ROOT__>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/server-sync-error.log
    CustomLog ${APACHE_LOG_DIR}/server-sync-access.log combined
</VirtualHost>
```

The template must not contain the live domain, document root, certificate path, private key, or personal server path. `server-sync.sh` replaces only the two double-underscore markers and validates the destination as `/etc/apache2/sites-available/*.conf`.

- [ ] **Step 3: Create portable Compose templates**

Use relative project roots and runtime environment variables, never the live host’s media paths.

`server/templates/compose/immich/compose.yaml`:

```yaml
name: immich-app
services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
    volumes:
      - ${UPLOAD_LOCATION:?Set UPLOAD_LOCATION in the local .env}:/usr/src/app/upload
      - ${PHOTOS_LOCATION:?Set PHOTOS_LOCATION in the local .env}:/mnt/media/pics
      - /etc/localtime:/etc/localtime:ro
    env_file: .env
    ports:
      - "2283:2283"
    depends_on:
      - redis
      - database
    restart: always
  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}
    volumes:
      - ./volumes/model-cache:/cache
    env_file: .env
    restart: always
  redis:
    image: redis:6.2-alpine
    restart: always
  database:
    image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0
    env_file: .env
    volumes:
      - ./volumes/pgdata:/var/lib/postgresql/data
    shm_size: 128mb
    restart: always
```

`server/templates/compose/homeassistant/compose.yaml`:

```yaml
name: ha2
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    volumes:
      - .:/config
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    network_mode: host
```

`server/templates/compose/mosquitto/compose.yaml`:

```yaml
name: mosquitto-docker
services:
  mosquitto:
    image: eclipse-mosquitto:2
    restart: unless-stopped
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log
```

- [ ] **Step 4: Create non-secret examples**

`homeassistant-configuration.yaml` contains only:

```yaml
default_config:
logger:
  default: info
automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
```

`immich.env.example` contains only non-secret variable names with relative or generic values:

```dotenv
IMMICH_VERSION=release
UPLOAD_LOCATION=./immich-data
PHOTOS_LOCATION=./photos
```

`mosquitto.conf` contains:

```text
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
listener 1883
allow_anonymous false
```

Do not add `DB_PASSWORD`, `password_file`, credentials, or commented credential examples. Authentication must be configured locally according to each service’s documentation.

- [ ] **Step 5: Run metadata and template privacy checks**

Run the new test’s privacy portion and a direct TSV shape check:

```bash
python3 - <<'PY'
import csv
from pathlib import Path
path = Path('2-areas/workstation-setup/server/services.tsv')
rows = list(csv.reader(path.open(newline=''), delimiter='\t'))
assert rows[0] == ['id', 'manager', 'probe', 'artifact', 'destination_key', 'policy', 'excluded_classes']
assert len(rows) == 11
assert all(len(row) == 7 for row in rows)
assert {row[5] for row in rows[1:]} == {'template', 'manual-review', 'inventory-only'}
print('service metadata: PASS')
PY
```

- [ ] **Step 6: Commit the sanitized source artifacts**

```bash
git add \
  2-areas/workstation-setup/server/services.tsv \
  2-areas/workstation-setup/server/templates
git diff --cached --check
git commit -m "feat(workstation): add sanitized server service templates" \
  -m "Record Linux service policies without copying credentials, identities, or runtime state." \
  -m "Co-authored-by: oh-my-pi <https://omp.sh>"
```

---

### Task 3: Implement the server-sync command

**Files:**
- Create: `2-areas/workstation-setup/scripts/server-sync.sh`

- [ ] **Step 1: Add fixed argument parsing and profile gates**

Source `scripts/lib.sh`, set `PYTHONDONTWRITEBYTECODE=1`, derive `PACKAGE_DIR`, and define:

```bash
OS=''
SERVICE=''
UTILS_PATH=${HOME}/utils
VARS_FILE=''
APPLY=0
INVENTORY=0

usage_error() {
  ws_die 'invalid server-sync arguments'
  exit 2
}
```

Accept only `--os`, `--service`, `--utils-path`, `--vars-file`, `--apply`, and `--inventory`. Reject duplicate mode flags and unknown arguments. Reject `--inventory` combined with `--service`. When neither is given, a dry-run selects all `template` and `manual-review` rows; `--inventory` selects probes only.

Validate `SERVICES_TSV` and template roots before any probe. The command must never use `eval`, `source` on the vars file, command substitution from metadata, or arbitrary metadata as a command.

- [ ] **Step 2: Add metadata validation and fixed service lookup**

Implement these functions:

```bash
valid_manager() {
  case $1 in systemd|systemd-user|docker-compose) return 0 ;; *) return 1 ;; esac
}
valid_policy() {
  case $1 in template|manual-review|inventory-only) return 0 ;; *) return 1 ;; esac
}
valid_destination_key() {
  case $1 in APACHE_SITE_PATH|IMMICH_ROOT|HOMEASSISTANT_ROOT|MOSQUITTO_ROOT|-) return 0 ;; *) return 1 ;; esac
}
```

Read `services.tsv` through `tr '\t' '\034'`, skip the header, require seven fields, validate IDs and all fields with `ws_safe_tsv_field`, validate managers/policies/destination keys, and reject duplicate IDs. Store the selected row in temporary files or scalar variables; do not use Bash associative arrays because the existing scripts remain Bash 3.2-compatible.

- [ ] **Step 3: Add safe vars-file parsing**

Implement `validate_vars_file` without sourcing it:

- require a regular file outside `UTILS_PATH` with mode `0600` or stricter;
- accept only `KEY=VALUE` lines and blank/comment lines;
- allow exactly `APACHE_SITE_PATH`, `APACHE_SERVER_NAME`, `APACHE_DOCUMENT_ROOT`, `IMMICH_ROOT`, `HOMEASSISTANT_ROOT`, and `MOSQUITTO_ROOT`;
- reject duplicate keys, unknown keys, tabs/newlines, `..` components, shell metacharacters in values, and values beginning with `-`;
- require `APACHE_SERVER_NAME` and `APACHE_DOCUMENT_ROOT` for Apache rendering, plus the selected service’s destination key;
- never print values.

Use this exact Python helper invoked as `python3 - "$VARS_FILE"` for duplicate detection and key/value validation:

```python
import sys
from pathlib import Path

allowed = {
    'APACHE_SITE_PATH', 'APACHE_SERVER_NAME', 'APACHE_DOCUMENT_ROOT',
    'IMMICH_ROOT', 'HOMEASSISTANT_ROOT', 'MOSQUITTO_ROOT',
}
seen = set()
for number, raw in enumerate(Path(sys.argv[1]).read_text().splitlines(), 1):
    line = raw.strip()
    if not line or line.startswith('#'):
        continue
    if line.count('=') != 1:
        raise SystemExit(f'invalid vars line {number}')
    key, value = line.split('=', 1)
    if key not in allowed or key in seen:
        raise SystemExit(f'invalid or duplicate vars key on line {number}')
    if not value or value.startswith('-') or any(ch in value for ch in '\t\r\n;&|`$()'):
        raise SystemExit(f'unsafe vars value on line {number}')
    if '..' in value.split('/'):
        raise SystemExit(f'traversal in vars value on line {number}')
    seen.add(key)
```

The shell command must additionally enforce the selected service’s required keys and destination grammar; do not use `eval`.

Implement `get_var KEY` by exact key comparison against the validated file. Missing keys return nonzero.

- [ ] **Step 4: Add destination safety checks**

Implement fixed destination validation:

- `APACHE_SITE_PATH` must be an absolute regular-file path whose parent is exactly `/etc/apache2/sites-available` and whose basename ends in `.conf` without `/` or `..`.
- Compose roots must be absolute directories or creatable descendants under `/srv`, `/opt`, or `/mnt`; reject `/`, `/etc`, `/var/lib`, `/var/log`, `/home`, symlinked destination components, `..`, and paths containing `.env`/database/media/log/key names.
- The installed Compose destination is `<ROOT>/compose.yaml`; the command never writes the root’s other files.
- Existing destination symlinks, directories where a regular file is expected, and paths outside these rules fail closed.

Use `python3` `os.path.abspath`/`os.path.realpath` checks where shell path handling would be ambiguous.

- [ ] **Step 5: Add literal template rendering**

Implement `render_template` with exact double-underscore markers:

```bash
render_template() {
  local template=$1 output=$2 text key marker value
  text=$(cat "$template") || return 1
  for key in APACHE_SERVER_NAME APACHE_DOCUMENT_ROOT; do
    marker="__${key}__"
    value=$(get_var "$key") || return 1
    text=${text//"$marker"/"$value"}
  done
  case $text in *__APACHE_*__) return 1 ;; esac
  printf '%s\n' "$text" >"$output"
}
```

For Compose templates, no server-sync markers are rendered; their runtime `${...}` variables remain for the service-local `.env`. The script must not read or create that `.env`.

- [ ] **Step 6: Add validation and dry-run planning**

Implement `validate_staged`:

- Apache invokes `apachectl -t -f "$staged"` when `apachectl` exists; missing validation tooling is an apply error and a dry-run warning.
- Compose invokes `docker compose -f "$staged" --project-directory "$destination_root" config --quiet`; missing Docker/Compose is an apply error and a dry-run warning.
- Manual-review and inventory-only rows print policy information and do not render or mutate.

Dry-run output must use stable records:

```text
PLAN SERVICE <id> policy=<policy>
PLAN SOURCE <template-relative-path>
PLAN DESTINATION <safe-label>
PLAN VALIDATE <id>
MANUAL_REVIEW <id> no portable artifact is applied
SKIP <id> inventory-only policy
```

With no vars file, dry-run prints the selected service plan and required variable names without rendering. With `--apply`, missing vars always fail before staging or backup.

- [ ] **Step 7: Add inventory probes**

Implement fixed probe functions:

- `systemctl is-active --quiet apache2`, `mariadb`, `smbd`, `x11vnc`, `photoview`, and `vsftpd`.
- `systemctl --user is-active --quiet syncthing`.
- `docker compose ls --all --format json`, parsed with Python to report project names and statuses only. Compare known projects `immich-app`, `ha2`, and `mosquitto-docker`; report other projects as `UNEXPECTED` and known projects absent from the output as `INACTIVE ... missing`, without failing.

Inventory output must never print environment variables, container logs, raw Compose file paths, or Docker inspect output. Missing tools produce `UNAVAILABLE`; inactive known services produce `MISSING`/`INACTIVE`; probes never start or modify services.

- [ ] **Step 8: Add staged backup/apply without restarts**

Implement `apply_staged`:

- require `--apply` and root only when the selected destination is under `/etc`;
- create `/var/backups/workstation-setup/server/<UTC timestamp>/` with mode `0700` when an existing regular destination is present;
- copy the existing file with `cp -p`, never move it before validation;
- install Apache files with mode `0644`; install Compose files with mode `0644`;
- re-check destination safety immediately before installation;
- print `APPLIED <id> <safe-label>` and a manual reload/follow-up message;
- never invoke `systemctl restart/reload`, `docker compose up`, `docker compose down`, or any data-directory command.

- [ ] **Step 9: Run the focused red-to-green test**

Run:

```bash
bash -n 2-areas/workstation-setup/scripts/server-sync.sh
bash 2-areas/workstation-setup/scripts/tests/test_server_sync.sh
```

Expected: syntax success and `server sync fixture tests: PASS` after all functions are implemented.

- [ ] **Step 10: Commit the command implementation**

```bash
git add 2-areas/workstation-setup/scripts/server-sync.sh
git diff --cached --check
git commit -m "feat(workstation): add safe server service sync" \
  -m "Provide inventory, dry-run, staged validation, and explicit config-only apply for server services." \
  -m "Co-authored-by: oh-my-pi <https://omp.sh>"
```

---

### Task 4: Add user-facing service documentation

**Files:**
- Create: `2-areas/workstation-setup/references/server-services.md`
- Modify: `2-areas/workstation-setup/README.md`
- Modify: `2-areas/workstation-setup/profiles/base.md`

- [ ] **Step 1: Write the service reference**

Document the metadata columns, all ten service rows, the three policy types, the exact exclusions, local vars-file rules, dry-run/apply commands, backup location, no-restart behavior, and the distinction between service configuration and service data. Include this command block:

```bash
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --os linux --inventory
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --os linux --service immich
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --os linux --service immich --apply \
  --vars-file "$HOME/.config/workstation-setup/server.env"
```

State that the vars file is local `0600`, never committed, and must not contain data that the command logs.

- [ ] **Step 2: Update README and base profile**

In the README server environment section, link `references/server-services.md` and state that `WORKSTATION_PROFILE=server` covers service configuration synchronization separately from home-file mappings. Add the inventory command to the verification list.

In `profiles/base.md`, add a `## Server services` section after configuration environments. Link the reference, list Apache2, Immich, Home Assistant, Mosquitto, Syncthing, MariaDB, Samba, x11vnc, Photoview, and vsftpd with their policies, and state that data/credentials/identities remain manual and local.

- [ ] **Step 3: Run documentation link checks**

Run this bounded Python audit from the package root:

```bash
python3 - <<'PY'
from pathlib import Path
import re
root = Path('.').resolve()
for path in root.rglob('*.md'):
    for target in re.findall(r'(?<!!)\[[^\]]+\]\(([^)]+)\)', path.read_text()):
        if target.startswith(('http://', 'https://', 'mailto:', '#')):
            continue
        target = target.split('#', 1)[0]
        if target and not (path.parent / target).resolve().exists():
            raise SystemExit(f'missing link: {path}: {target}')
print('documentation links: PASS')
PY
```

- [ ] **Step 4: Commit documentation**

```bash
git add \
  2-areas/workstation-setup/references/server-services.md \
  2-areas/workstation-setup/README.md \
  2-areas/workstation-setup/profiles/base.md
git diff --cached --check
git commit -m "docs(workstation): document server service sync" \
  -m "Explain service policies, local variables, exclusions, and manual follow-up for the server profile." \
  -m "Co-authored-by: oh-my-pi <https://omp.sh>"
```

---

### Task 5: Run full verification and preserve repository boundaries

**Files:**
- No source changes expected unless a concrete verification failure identifies a defect.

- [ ] **Step 1: Run the new focused suite and shell syntax checks**

```bash
bash -n \
  2-areas/workstation-setup/scripts/server-sync.sh \
  2-areas/workstation-setup/scripts/tests/test_server_sync.sh
bash 2-areas/workstation-setup/scripts/tests/test_server_sync.sh
```

Expected: `server sync fixture tests: PASS`.

- [ ] **Step 2: Run the complete existing workstation suite**

```bash
cd 2-areas/workstation-setup
bash -n scripts/bootstrap.sh scripts/check.sh scripts/lib.sh scripts/snapshot.sh \
  scripts/tests/test_environment_profile.sh scripts/tests/test_bootstrap.sh \
  scripts/tests/test_check.sh scripts/tests/test_snapshot.sh
python3 -m unittest scripts/tests/test_recent_usage.py
bash scripts/tests/test_environment_profile.sh
bash scripts/tests/test_check.sh
bash scripts/tests/test_bootstrap.sh
bash scripts/tests/test_snapshot.sh
```

Expected: all five Python tests pass, followed by PASS output from the environment, check, bootstrap, and snapshot fixtures.

- [ ] **Step 3: Smoke-test inventory on the target server**

Run read-only inventory from the target host’s worktree:

```bash
WORKSTATION_PROFILE=server \
  bash 2-areas/workstation-setup/scripts/server-sync.sh \
  --os linux --inventory
```

Confirm Apache2, Syncthing, Immich, Home Assistant, and Mosquitto are reported active; MariaDB, Samba, and x11vnc are reported according to their current state; Photoview and vsftpd are reported as failed/stale on the inspected host; no raw environment values, logs, data paths, or identity files are emitted.

- [ ] **Step 4: Verify metadata, privacy, and repository state**

Check every service row has seven fields and an allowlisted policy, run the template privacy scan, run `git diff --check`, then remove only `2-areas/workstation-setup/scripts/tests/__pycache__/` with `rm -rf`. Confirm the pre-existing untracked `abc` file is not staged and no live service data directory appears in the diff.

- [ ] **Step 5: Review and commit final state**

```bash
git status --short --branch
git diff --check
git log -4 --format='%h %s%n%b'
```

Confirm every implementation commit contains:

```text
Co-authored-by: oh-my-pi <https://omp.sh>
```

The final branch must contain only the design, service source artifacts, command, tests, and documentation described above.
