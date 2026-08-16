#!/usr/bin/env bash
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PACKAGE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd -P)
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/server-sync-test.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT HUP INT TERM

HOME_DIR="$FIXTURE/home"
BIN_DIR="$FIXTURE/bin"
DEST_DIR="$FIXTURE/dest"
VARS_FILE="$FIXTURE/vars"
mkdir -p "$HOME_DIR" "$BIN_DIR" "$DEST_DIR"

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
    printf '%s\n' '[{"Name":"immich-app","Status":"running(4)"},{"Name":"ha2","Status":"running(1)"},{"Name":"mosquitto-docker","Status":"running(1)"},{"Name":"unexpected-app","Status":"running(1)"}]'
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

cat >"$VARS_FILE" <<'EOF'
APACHE_SITE_PATH=/etc/apache2/sites-available/server-sync-test.conf
APACHE_SERVER_NAME=example.invalid
APACHE_DOCUMENT_ROOT=/srv/server-sync-fixture/www
IMMICH_ROOT=/srv/server-sync-fixture/immich
HOMEASSISTANT_ROOT=/srv/server-sync-fixture/homeassistant
MOSQUITTO_ROOT=/srv/server-sync-fixture/mosquitto
EOF
chmod 600 "$VARS_FILE"

SYNC="$PACKAGE_DIR/scripts/server-sync.sh"
INVENTORY=$(WORKSTATION_PROFILE=server HOME="$HOME_DIR" PATH="$BIN_DIR:$PATH" \
  bash "$SYNC" --os linux --inventory 2>&1)
assert_contains "$INVENTORY" 'OK service apache2 active'
assert_contains "$INVENTORY" 'OK service syncthing active'
assert_contains "$INVENTORY" 'INACTIVE service photoview'
assert_contains "$INVENTORY" 'INACTIVE service vsftpd'
assert_contains "$INVENTORY" 'OK compose immich-app running'
assert_contains "$INVENTORY" 'OK compose ha2 running'
assert_contains "$INVENTORY" 'OK compose mosquitto-docker running'
assert_contains "$INVENTORY" 'UNEXPECTED compose project unexpected-app'

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
printf '%s\n' 'server sync fixture tests: PASS'
