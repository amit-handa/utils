#!/usr/bin/env bash
set -eu

export PYTHONDONTWRITEBYTECODE=1
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PACKAGE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

OS=''
SERVICE=''
UTILS_PATH=${HOME:-}/utils
UTILS_PATH_SET=0
VARS_FILE=''
APPLY=0
INVENTORY=0

SERVICES_TSV="$PACKAGE_DIR/server/services.tsv"
TEMPLATES_ROOT="$PACKAGE_DIR/server/templates"
TMP_ROOT=''
META_FILE=''
SEEN_IDS_FILE=''
STAGE_DIR=''

ROW_ID=''
ROW_MANAGER=''
ROW_PROBE=''
ROW_ARTIFACT=''
ROW_DESTINATION_KEY=''
ROW_POLICY=''
ROW_EXCLUDED_CLASSES=''

usage_error() {
  ws_die 'invalid server-sync arguments' >&2 || true
  exit 2
}

fail_error() {
  ws_die "$1" >&2 || true
  exit 1
}

valid_manager() {
  case $1 in systemd|systemd-user|docker-compose) return 0 ;; *) return 1 ;; esac
}

valid_policy() {
  case $1 in template|manual-review|inventory-only) return 0 ;; *) return 1 ;; esac
}

valid_destination_key() {
  case $1 in APACHE_SITE_PATH|IMMICH_ROOT|HOMEASSISTANT_ROOT|MOSQUITTO_ROOT|-) return 0 ;; *) return 1 ;; esac
}

valid_service_id() {
  case $1 in ''|*[!a-z0-9-]*) return 1 ;; *) return 0 ;; esac
}

cleanup() {
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf "$TMP_ROOT"
  fi
}
trap cleanup EXIT HUP INT TERM

require_server_profile() {
  [ "${WORKSTATION_PROFILE:-}" = server ] || fail_error 'WORKSTATION_PROFILE=server is required'
}

id_seen() {
  local wanted=$1 seen
  while IFS= read -r seen; do
    [ "$seen" = "$wanted" ] && return 0
  done < "$SEEN_IDS_FILE"
  return 1
}

validate_metadata() {
  local id manager probe artifact destination_key policy excluded_classes extra header_seen=0
  [ -f "$SERVICES_TSV" ] && [ ! -L "$SERVICES_TSV" ] || fail_error 'server service metadata is unavailable'
  [ -d "$TEMPLATES_ROOT" ] && [ ! -L "$TEMPLATES_ROOT" ] || fail_error 'server service templates are unavailable'

  TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/server-sync.XXXXXX")
  META_FILE="$TMP_ROOT/services.meta"
  SEEN_IDS_FILE="$TMP_ROOT/seen.ids"
  : >"$SEEN_IDS_FILE"
  tr '\t' '\034' <"$SERVICES_TSV" >"$META_FILE" || fail_error 'could not read server service metadata'

  while IFS="$(printf '\034')" read -r id manager probe artifact destination_key policy excluded_classes extra; do
    [ -n "$id" ] || continue
    if [ "$id" = id ]; then
      [ "$manager" = manager ] && [ "$probe" = probe ] && [ "$artifact" = artifact ] || fail_error 'invalid server service metadata header'
      header_seen=1
      continue
    fi
    [ -z "$extra" ] || fail_error 'server service metadata has too many fields'
    [ -n "$manager" ] && [ -n "$probe" ] && [ -n "$artifact" ] && [ -n "$destination_key" ] && [ -n "$policy" ] && [ -n "$excluded_classes" ] || fail_error 'server service metadata has missing fields'
    valid_service_id "$id" || fail_error 'invalid server service id'
    ws_safe_tsv_field "$id" && ws_safe_tsv_field "$manager" && ws_safe_tsv_field "$probe" && \
      ws_safe_tsv_field "$artifact" && ws_safe_tsv_field "$destination_key" && ws_safe_tsv_field "$policy" && \
      ws_safe_tsv_field "$excluded_classes" || fail_error 'unsafe server service metadata field'
    valid_manager "$manager" || fail_error 'invalid server service manager'
    valid_policy "$policy" || fail_error 'invalid server service policy'
    valid_destination_key "$destination_key" || fail_error 'invalid server service destination key'
    id_seen "$id" && fail_error 'duplicate server service id'
    printf '%s\n' "$id" >>"$SEEN_IDS_FILE"
    if [ "$policy" = template ]; then
      [ "$artifact" != - ] || fail_error 'template service has no artifact'
      ws_safe_relative_path "$artifact" || fail_error 'unsafe server service artifact path'
      [ -f "$PACKAGE_DIR/$artifact" ] && [ ! -L "$PACKAGE_DIR/$artifact" ] || fail_error 'server service template is unavailable'
      [ "$destination_key" != - ] || fail_error 'template service has no destination key'
    else
      [ "$artifact" = - ] || fail_error 'non-template service has an artifact'
      [ "$destination_key" = - ] || fail_error 'non-template service has a destination key'
    fi
  done <"$META_FILE"
  [ "$header_seen" -eq 1 ] || fail_error 'server service metadata header is missing'
}

select_service() {
  local wanted=$1 id manager probe artifact destination_key policy excluded_classes extra found=0
  ROW_ID=''
  while IFS="$(printf '\034')" read -r id manager probe artifact destination_key policy excluded_classes extra; do
    [ "$id" = id ] && continue
    if [ "$id" = "$wanted" ]; then
      ROW_ID=$id
      ROW_MANAGER=$manager
      ROW_PROBE=$probe
      ROW_ARTIFACT=$artifact
      ROW_DESTINATION_KEY=$destination_key
      ROW_POLICY=$policy
      ROW_EXCLUDED_CLASSES=$excluded_classes
      found=1
      break
    fi
  done <"$META_FILE"
  [ "$found" -eq 1 ] || fail_error 'unknown server service'
}

validate_vars_file() {
  [ -n "$VARS_FILE" ] || return 0
  [ -f "$VARS_FILE" ] && [ ! -L "$VARS_FILE" ] || fail_error 'vars file must be a regular non-symlink file'
  python3 - "$VARS_FILE" "$UTILS_PATH" <<'PY'
import os
import re
import stat
import sys
from pathlib import Path

path = Path(sys.argv[1])
utils = os.path.realpath(sys.argv[2])
if not path.is_file() or path.is_symlink():
    raise SystemExit('invalid vars file')
if stat.S_IMODE(path.stat().st_mode) & 0o077:
    raise SystemExit('vars file permissions are too broad')
real_path = os.path.realpath(str(path))
if real_path == utils or real_path.startswith(utils + os.sep):
    raise SystemExit('vars file is inside utils')

allowed = {
    'APACHE_SITE_PATH', 'APACHE_SERVER_NAME', 'APACHE_DOCUMENT_ROOT',
    'IMMICH_ROOT', 'HOMEASSISTANT_ROOT', 'MOSQUITTO_ROOT',
}
seen = set()

def fail(message):
    raise SystemExit(message)

def reject_path(value, allow_roots):
    parts = value.split('/')
    if not value.startswith('/') or '//' in value or any(part in ('.', '..', '') for part in parts[1:]):
        fail('unsafe path value')
    if not any(value == root or value.startswith(root + '/') for root in allow_roots):
        fail('path value outside allowed roots')
    for index in range(1, len(parts)):
        component = '/' + '/'.join(parts[1:index + 1])
        if os.path.lexists(component) and os.path.islink(component):
            fail('path value contains a symlink')

def reject_compose_root(value):
    reject_path(value, ('/srv', '/opt', '/mnt'))
    parts = value.split('/')[1:]
    if not parts:
        fail('compose root cannot be filesystem root')
    forbidden = re.compile(r'(^|[._-])(env|database|databases|media|log|logs|key|keys)([._-]|$)', re.I)
    if any(forbidden.search(part) for part in parts):
        fail('compose root contains excluded state name')

def reject_apache_site(value):
    if not re.fullmatch(r'/etc/apache2/sites-available/[A-Za-z0-9._-]+\.conf', value):
        fail('invalid Apache destination')
    if '..' in value.split('/'):
        fail('invalid Apache destination')
    parent = Path('/etc/apache2/sites-available')
    if parent.is_symlink():
        fail('Apache destination parent is a symlink')

def reject_document_root(value):
    reject_path(value, ('/srv', '/opt', '/mnt', '/var/www'))

for number, raw in enumerate(path.read_text().splitlines(), 1):
    line = raw.strip()
    if not line or line.startswith('#'):
        continue
    if line.count('=') != 1:
        fail(f'invalid vars line {number}')
    key, value = line.split('=', 1)
    if key not in allowed or key in seen or not re.fullmatch(r'[A-Z][A-Z0-9_]*', key):
        fail(f'invalid or duplicate vars key on line {number}')
    if not value or value.startswith('-') or value != value.strip() or any(ch in value for ch in '\t\r\n;&|`$()<>'):
        fail(f'unsafe vars value on line {number}')
    if '..' in value.split('/'):
        fail(f'traversal in vars value on line {number}')
    if key == 'APACHE_SERVER_NAME' and not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', value):
        fail(f'unsafe Apache server name on line {number}')
    if key == 'APACHE_SITE_PATH':
        reject_apache_site(value)
    elif key in ('IMMICH_ROOT', 'HOMEASSISTANT_ROOT', 'MOSQUITTO_ROOT'):
        reject_compose_root(value)
    elif key == 'APACHE_DOCUMENT_ROOT':
        reject_document_root(value)
    seen.add(key)
PY
}

get_var() {
  local wanted=$1 key value
  [ -n "$VARS_FILE" ] || return 1
  while IFS='=' read -r key value; do
    [ "$key" = "$wanted" ] || continue
    printf '%s' "$value"
    return 0
  done <"$VARS_FILE"
  return 1
}

validate_selected_destination() {
  local destination
  destination=$(get_var "$ROW_DESTINATION_KEY") || fail_error 'required destination variable is missing'
  if [ "$ROW_ID" = apache2 ]; then
    python3 - "$destination" <<'PY'
import sys
from pathlib import Path
path = sys.argv[1]
if not path.startswith('/etc/apache2/sites-available/') or not path.endswith('.conf'):
    raise SystemExit('invalid Apache destination')
if '..' in path.split('/') or '//' in path:
    raise SystemExit('invalid Apache destination')
parent = Path('/etc/apache2/sites-available')
if parent.is_symlink() or not parent.is_dir():
    raise SystemExit('Apache destination parent is unavailable')
target = Path(path)
if target.exists() and (target.is_symlink() or not target.is_file()):
    raise SystemExit('Apache destination is not a regular file')
PY
  else
    python3 - "$destination" <<'PY'
import os
import re
import sys
path = sys.argv[1]
if not path.startswith('/') or '//' in path or any(part in ('.', '..', '') for part in path.split('/')[1:]):
    raise SystemExit('invalid compose destination')
if not any(path == root or path.startswith(root + '/') for root in ('/srv', '/opt', '/mnt')):
    raise SystemExit('compose destination outside allowed roots')
parts = path.split('/')[1:]
if not parts:
    raise SystemExit('compose destination is filesystem root')
forbidden = re.compile(r'(^|[._-])(env|database|databases|media|log|logs|key|keys)([._-]|$)', re.I)
if any(forbidden.search(part) for part in parts):
    raise SystemExit('compose destination contains excluded state name')
for index in range(1, len(parts) + 1):
    component = '/' + '/'.join(parts[:index])
    if os.path.lexists(component) and os.path.islink(component):
        raise SystemExit('compose destination contains a symlink')
target = os.path.join(path, 'compose.yaml')
if os.path.lexists(target) and (os.path.islink(target) or not os.path.isfile(target)):
    raise SystemExit('compose destination is not a regular file')
PY
  fi
}

require_selected_vars() {
  [ -n "$VARS_FILE" ] || fail_error 'vars file is required for this operation'
  case $ROW_ID in
    apache2)
      get_var APACHE_SERVER_NAME >/dev/null || fail_error 'required Apache server name is missing'
      get_var APACHE_DOCUMENT_ROOT >/dev/null || fail_error 'required Apache document root is missing'
      ;;
  esac
  validate_selected_destination
}

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

prepare_staged() {
  local template destination
  [ -n "$STAGE_DIR" ] || STAGE_DIR="$TMP_ROOT/staged"
  mkdir -p "$STAGE_DIR" || return 1
  template="$PACKAGE_DIR/$ROW_ARTIFACT"
  if [ "$ROW_ID" = apache2 ]; then
    render_template "$template" "$STAGE_DIR/output" || return 1
  else
    cp "$template" "$STAGE_DIR/output" || return 1
  fi
  destination=$(get_var "$ROW_DESTINATION_KEY") || return 1
  printf '%s\n' "$destination" >"$STAGE_DIR/destination"
}

validate_staged() {
  local staged=$1 destination
  destination=$(get_var "$ROW_DESTINATION_KEY") || return 1
  if [ "$ROW_ID" = apache2 ]; then
    if ws_command_exists apachectl; then
      apachectl -t -f "$staged" >/dev/null 2>&1 || return 1
    elif [ "$APPLY" -eq 1 ]; then
      fail_error 'apachectl is required for apply'
    else
      printf 'WARN VALIDATION_TOOL apachectl unavailable\n'
    fi
  elif [ "$ROW_MANAGER" = docker-compose ]; then
    if ws_command_exists docker; then
      docker compose -f "$staged" --project-directory "$destination" config --quiet >/dev/null 2>&1 || return 1
    elif [ "$APPLY" -eq 1 ]; then
      fail_error 'docker is required for apply'
    else
      printf 'WARN VALIDATION_TOOL docker unavailable\n'
    fi
  fi
}

safe_destination_label() {
  printf '%s' "$ROW_DESTINATION_KEY"
}

print_plan_for_row() {
  printf 'PLAN SERVICE %s policy=%s\n' "$ROW_ID" "$ROW_POLICY"
  if [ "$ROW_POLICY" = inventory-only ]; then
    printf 'SKIP %s inventory-only policy\n' "$ROW_ID"
    return 0
  fi
  if [ "$ROW_POLICY" = manual-review ]; then
    printf 'MANUAL_REVIEW %s no portable artifact is applied\n' "$ROW_ID"
    return 0
  fi
  printf 'PLAN SOURCE %s\n' "$ROW_ARTIFACT"
  printf 'PLAN DESTINATION %s\n' "$(safe_destination_label)"
  printf 'PLAN VALIDATE %s\n' "$ROW_ID"
  if [ -n "$VARS_FILE" ]; then
    require_selected_vars
    prepare_staged || fail_error 'could not stage server service template'
    validate_staged "$STAGE_DIR/output" || fail_error 'staged server service validation failed'
  fi
}

probe_systemd_service() {
  local id=$1
  if ! ws_command_exists systemctl; then
    printf 'UNAVAILABLE service %s\n' "$id"
  elif systemctl is-active --quiet "$id" >/dev/null 2>&1; then
    printf 'OK service %s active\n' "$id"
  else
    printf 'INACTIVE service %s\n' "$id"
  fi
}

probe_syncthing() {
  if ! ws_command_exists systemctl; then
    printf 'UNAVAILABLE service syncthing\n'
  elif systemctl --user is-active --quiet syncthing >/dev/null 2>&1; then
    printf 'OK service syncthing active\n'
  else
    printf 'INACTIVE service syncthing\n'
  fi
}

run_dry_run() {
  local id manager probe artifact destination_key policy excluded_classes extra
  if [ -n "$SERVICE" ]; then
    select_service "$SERVICE"
    print_plan_for_row
    return 0
  fi
  while IFS="$(printf '\034')" read -r id manager probe artifact destination_key policy excluded_classes extra; do
    [ "$id" = id ] && continue
    [ "$policy" = template ] || [ "$policy" = manual-review ] || continue
    ROW_ID=$id
    ROW_MANAGER=$manager
    ROW_PROBE=$probe
    ROW_ARTIFACT=$artifact
    ROW_DESTINATION_KEY=$destination_key
    ROW_POLICY=$policy
    ROW_EXCLUDED_CLASSES=$excluded_classes
    print_plan_for_row
  done <"$META_FILE"
}


probe_compose_projects() {
  local output_file
  output_file="$TMP_ROOT/compose.json"
  if ! ws_command_exists docker || ! docker compose ls --all --format json >"$output_file" 2>/dev/null; then
    printf 'UNAVAILABLE compose inventory\n'
    return 0
  fi
  python3 - "$output_file" <<'PY'
import json
import re
import sys
from pathlib import Path
known = {'immich-app', 'ha2', 'mosquitto-docker'}
try:
    projects = json.loads(Path(sys.argv[1]).read_text())
except Exception:
    print('UNAVAILABLE compose inventory')
    raise SystemExit(0)
if not isinstance(projects, list):
    print('UNAVAILABLE compose inventory')
    raise SystemExit(0)
seen = set()
for project in projects:
    if not isinstance(project, dict):
        continue
    name = project.get('Name', '')
    status = project.get('Status', '')
    if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9_.-]+', name):
        continue
    if not isinstance(status, str):
        status = ''
    seen.add(name)
    state = 'running' if status.startswith('running') else 'inactive'
    if name in known:
        print(('OK' if state == 'running' else 'INACTIVE') + f' compose {name} {state}')
    else:
        print(f'UNEXPECTED compose project {name}')
for name in sorted(known - seen):
    print(f'INACTIVE compose {name} missing')
PY
}

run_inventory() {
  probe_systemd_service apache2
  probe_syncthing
  probe_systemd_service mariadb
  probe_systemd_service smbd
  probe_systemd_service x11vnc
  probe_systemd_service photoview
  probe_systemd_service vsftpd
  probe_compose_projects
}

apply_staged() {
  local destination target backup_root backup_dir
  destination=$(get_var "$ROW_DESTINATION_KEY") || fail_error 'required destination variable is missing'
  if [ "$ROW_ID" = apache2 ]; then
    target=$destination
    case $target in /etc/*) [ "$(id -u)" -eq 0 ] || fail_error 'root is required for Apache apply' ;; esac
    [ -d "${target%/*}" ] && [ ! -L "${target%/*}" ] || fail_error 'Apache destination parent is unavailable'
  else
    target="$destination/compose.yaml"
    mkdir -p "$destination" || fail_error 'could not create compose configuration directory'
  fi

  validate_selected_destination
  validate_staged "$STAGE_DIR/output" || fail_error 'staged server service validation failed'

  if [ -e "$target" ] || [ -L "$target" ]; then
    [ -f "$target" ] && [ ! -L "$target" ] || fail_error 'existing destination is not a regular file'
    backup_root=/var/backups/workstation-setup/server
    backup_dir="$backup_root/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$backup_dir" || fail_error 'could not create server configuration backup'
    chmod 700 "$backup_dir" || fail_error 'could not protect server configuration backup'
    cp -p "$target" "$backup_dir/$(basename "$target")" || fail_error 'could not back up existing server configuration'
  fi

  validate_selected_destination
  cp "$STAGE_DIR/output" "$target" || fail_error 'could not install server configuration'
  chmod 0644 "$target" || fail_error 'could not set server configuration mode'
  printf 'APPLIED %s %s\n' "$ROW_ID" "$(safe_destination_label)"
  printf 'FOLLOW_UP %s review the service-specific reload or restart procedure manually\n' "$ROW_ID"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case $1 in
      --os)
        [ "$#" -ge 2 ] && [ -z "$OS" ] || usage_error
        OS=$2
        shift 2
        ;;
      --service)
        [ "$#" -ge 2 ] && [ -z "$SERVICE" ] || usage_error
        SERVICE=$2
        shift 2
        ;;
      --utils-path)
        [ "$#" -ge 2 ] && [ "$UTILS_PATH_SET" -eq 0 ] || usage_error
        case $2 in /*) ;; *) usage_error ;; esac
        UTILS_PATH=$2
        UTILS_PATH_SET=1
        shift 2
        ;;
      --vars-file)
        [ "$#" -ge 2 ] && [ -z "$VARS_FILE" ] || usage_error
        VARS_FILE=$2
        shift 2
        ;;
      --apply)
        [ "$APPLY" -eq 0 ] || usage_error
        APPLY=1
        shift
        ;;
      --inventory)
        [ "$INVENTORY" -eq 0 ] || usage_error
        INVENTORY=1
        shift
        ;;
      *)
        usage_error
        ;;
    esac
  done
  [ "$OS" = linux ] || usage_error
  [ "$INVENTORY" -eq 0 ] || [ -z "$SERVICE" ] || usage_error
  [ "$INVENTORY" -eq 0 ] || [ "$APPLY" -eq 0 ] || usage_error
  [ "$APPLY" -eq 0 ] || [ -n "$SERVICE" ] || usage_error
}

main() {
  parse_args "$@"
  require_server_profile
  validate_metadata
  if [ -n "$VARS_FILE" ]; then
    validate_vars_file
  fi
  if [ "$INVENTORY" -eq 1 ]; then
    run_inventory
    return 0
  fi
  if [ "$APPLY" -eq 1 ]; then
    select_service "$SERVICE"
    [ "$ROW_POLICY" = template ] || fail_error 'only template services can be applied'
    require_selected_vars
    prepare_staged || fail_error 'could not stage server service template'
    apply_staged
    return 0
  fi
  run_dry_run
}

main "$@"
