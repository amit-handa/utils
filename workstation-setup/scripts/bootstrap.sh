#!/usr/bin/env bash
set -u
export PYTHONDONTWRITEBYTECODE=1

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PACKAGE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

CONFIG_SOURCES="$PACKAGE_DIR/references/config-sources.tsv"
BREWFILE="$PACKAGE_DIR/manifests/macos/Brewfile"
APT_PACKAGES="$PACKAGE_DIR/manifests/linux/apt-packages.txt"
OS=''
PROFILE=''
UTILS_PATH=${HOME}/utils
APPLY=0
TIMESTAMP=''
TMP_ROOT=''

usage_error() {
  ws_die 'invalid bootstrap arguments'
  exit 2
}

unsafe_error() {
  printf 'UNSAFE configuration mapping rejected\n' >&2
  return 1
}

while [ "$#" -gt 0 ]; do
  case $1 in
    --os|--profile|--utils-path)
      [ "$#" -ge 2 ] || usage_error
      case $1 in
        --os) OS=$2 ;;
        --profile) PROFILE=$2 ;;
        --utils-path) UTILS_PATH=$2 ;;
      esac
      shift 2
      ;;
    --apply)
      [ "$APPLY" -eq 0 ] || usage_error
      APPLY=1
      shift
      ;;
    *) usage_error ;;
  esac
done

case $OS in macos|linux) ;; *) usage_error ;; esac
case $PROFILE in base|work|mobile) ;; *) usage_error ;; esac
ws_safe_tsv_field "${HOME:-}" && ws_safe_tsv_field "$UTILS_PATH" || usage_error
ws_command_exists python3 || {
  ws_die 'python3 is required for bootstrap safety'
  exit 1
}
[ -r "$CONFIG_SOURCES" ] || {
  ws_die 'bootstrap metadata is unavailable'
  exit 1
}
case $OS in
  macos) PACKAGE_MANIFEST=$BREWFILE ;;
  linux) PACKAGE_MANIFEST=$APT_PACKAGES ;;
esac
[ -r "$PACKAGE_MANIFEST" ] || {
  ws_die 'bootstrap metadata is unavailable'
  exit 1
}

canonicalize_path() {
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null
}

WS_HOME_CANONICAL=$(canonicalize_path "$HOME") || usage_error
UTILS_CANONICAL=$(canonicalize_path "$UTILS_PATH") || usage_error
[ -d "$WS_HOME_CANONICAL" ] && [ -d "$UTILS_CANONICAL" ] || {
  unsafe_error
  exit 1
}
case $WS_HOME_CANONICAL in
  "$UTILS_CANONICAL"|"$UTILS_CANONICAL"/*)
    unsafe_error
    exit 1
    ;;
esac

raw_timestamp=${BOOTSTRAP_TIMESTAMP:-}
if [ -n "$raw_timestamp" ]; then
  case $raw_timestamp in
    [!A-Za-z0-9]*|*[!A-Za-z0-9._-]*)
      ws_die 'invalid bootstrap timestamp'
      exit 2
      ;;
  esac
  TIMESTAMP=$raw_timestamp
else
  TIMESTAMP=$(date -u '+%Y%m%dT%H%M%SZ') || {
    ws_die 'cannot determine bootstrap timestamp'
    exit 1
  }
fi

path_is_within() {
  local path=$1 root=$2
  case $path in "$root"|"$root"/*) return 0 ;; *) return 1 ;; esac
}

safe_mapping_relative() {
  case $1 in .|./*|*/./*|*/.) return 1 ;; esac
  ws_safe_relative_path "$1"
}

valid_profile_tokens() {
  local tokens=$1 token profile platform old_ifs=$IFS
  [ -n "$tokens" ] || return 1
  IFS='|'
  for token in $tokens; do
    [ -n "$token" ] || { IFS=$old_ifs; return 1; }
    profile=${token%@*}
    platform=''
    case $token in *@*) platform=${token#*@} ;; esac
    case $profile in base|work|mobile) ;; *) IFS=$old_ifs; return 1 ;; esac
    case $platform in ''|macos|linux) ;; *) IFS=$old_ifs; return 1 ;; esac
    case $token in *@*@*) IFS=$old_ifs; return 1 ;; esac
  done
  IFS=$old_ifs
  return 0
}

destination_paths() {
  DESTINATION_PATH="$WS_HOME_CANONICAL/$1"
  DESTINATION_PARENT=${DESTINATION_PATH%/*}
  DESTINATION_PARENT_CANONICAL=$(canonicalize_path "$DESTINATION_PARENT") || return 1
  DESTINATION_CANONICAL="$DESTINATION_PARENT_CANONICAL/${DESTINATION_PATH##*/}"
}

validate_destination() {
  local destination=$1 canonical_relative
  safe_mapping_relative "$destination" || return 1
  destination_paths "$destination" || return 1
  path_is_within "$DESTINATION_PARENT_CANONICAL" "$WS_HOME_CANONICAL" || return 1
  path_is_within "$DESTINATION_CANONICAL" "$UTILS_CANONICAL" && return 1
  canonical_relative=${DESTINATION_CANONICAL#"$WS_HOME_CANONICAL"/}
  [ "$canonical_relative" != "$DESTINATION_CANONICAL" ] || return 1
  ws_forbidden_relative_path "$canonical_relative" && return 1
  return 0
}

validate_source() {
  local source=$1
  safe_mapping_relative "$source" || return 1
  SOURCE_PATH="$UTILS_CANONICAL/$source"
  [ -e "$SOURCE_PATH" ] || [ -L "$SOURCE_PATH" ] || return 1
  [ ! -L "$SOURCE_PATH" ] || return 1
  SOURCE_CANONICAL=$(canonicalize_path "$SOURCE_PATH") || return 1
  path_is_within "$SOURCE_CANONICAL" "$UTILS_CANONICAL" || return 1
  [ -f "$SOURCE_CANONICAL" ] || [ -d "$SOURCE_CANONICAL" ] || return 1
  return 0
}

validate_backup_target() {
  local destination=$1 backup_parent backup_parent_canonical backup_path backup_canonical
  backup_path="$WS_HOME_CANONICAL/.workstation-setup-backups/$TIMESTAMP/$destination"
  backup_parent=${backup_path%/*}
  backup_parent_canonical=$(canonicalize_path "$backup_parent") || return 1
  backup_canonical="$backup_parent_canonical/${backup_path##*/}"
  path_is_within "$backup_parent_canonical" "$WS_HOME_CANONICAL" || return 1
  path_is_within "$backup_canonical" "$UTILS_CANONICAL" && return 1
  [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || return 1
  return 0
}

git_config_is_safe() {
  python3 - "$1" <<'PY'
import re
import sys

path = sys.argv[1]
section = ""
try:
    source = open(path, encoding="utf-8", errors="replace")
except OSError:
    raise SystemExit(1)
with source:
    for raw_line in source:
        stripped = raw_line.strip()
        if not stripped or stripped.startswith(("#", ";")):
            continue
        if stripped.startswith("["):
            close = stripped.find("]")
            if close < 0:
                raise SystemExit(1)
            header = stripped[1:close].strip()
            match = re.match(r"([A-Za-z0-9.-]+)(?:\s+.*)?$", header)
            if not match:
                raise SystemExit(1)
            section = match.group(1).lower()
            if section == "credential":
                raise SystemExit(1)
            continue
        key_text = stripped.split("=", 1)[0].strip()
        key = key_text.split(None, 1)[0].lower() if key_text else ""
        if section == "user" and key in {"name", "email", "signingkey"}:
            raise SystemExit(1)
        if key == "credential.helper":
            raise SystemExit(1)
raise SystemExit(0)
PY
}
validate_agent_preference_source() {
  # Args: <id> <source_canonical>
  # Validates the curated Claude or OMP preference source against a strict
  # per-tool allowlist before any backup or write. Exits nonzero with
  # "invalid agent preference source <id>" on malformed or disallowed data.
  python3 - "$1" "$2" <<'PY' || return 1
import json
import os
import stat
import sys

pref_id = sys.argv[1]
source = sys.argv[2]


def fail():
    sys.stderr.write('invalid agent preference source %s\n' % pref_id)
    sys.exit(1)


CLAUDE_KEYS = {
    "model", "autoCompactEnabled", "autoCompactWindow",
    "tui", "voice", "voiceEnabled",
}
OMP_KEYS = {
    "defaultThinkingLevel", "theme.dark", "theme.light",
    "symbolPreset", "colorBlindMode",
    "statusLine.preset", "statusLine.separator",
    "statusLine.sessionAccent", "statusLine.compactThinkingLevel",
    "terminal.showProgress", "tui.renderMermaid", "tui.titleState",
    "display.smoothStreaming", "display.showTokenUsage",
}


def is_bytes(value):
    return isinstance(value, bytes)


def is_path_like(value):
    if not isinstance(value, str):
        return False
    return value.startswith("/") or value.startswith("~")


def is_shell_command(value):
    if not isinstance(value, str):
        return False
    return any(ch in value for ch in (";", "|", "`", "$", "&&", "(", ")"))


def is_credential_shaped(value):
    if isinstance(value, bytes):
        return True
    if isinstance(value, str):
        low = value.lower()
        if any(w in low for w in ("secret", "password", "token", "apikey",
                                   "api_key", "credential", "private_key",
                                   "bearer", "authorization")):
            return True
        if is_path_like(value) or is_shell_command(value):
            return True
    if isinstance(value, dict):
        return any(is_credential_shaped(v) for v in value.values())
    if isinstance(value, list):
        return any(is_credential_shaped(v) for v in value)
    return False



def validate_claude(data):
    if not isinstance(data, dict):
        fail()
    for key in data:
        if key not in CLAUDE_KEYS:
            fail()
    for key, value in data.items():
        if is_bytes(value) or is_credential_shaped(value):
            fail()
        if key == "model":
            if not isinstance(value, str):
                fail()
        elif key == "tui":
            if not isinstance(value, str):
                fail()
        elif key == "autoCompactEnabled":
            if not isinstance(value, bool):
                fail()
        elif key == "voiceEnabled":
            if not isinstance(value, bool):
                fail()
        elif key == "autoCompactWindow":
            if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                fail()
        elif key == "voice":
            if not isinstance(value, dict):
                fail()
            if set(value) - {"enabled", "mode"}:
                fail()
            if "enabled" in value and not isinstance(value["enabled"], bool):
                fail()
            if "mode" in value and not isinstance(value["mode"], str):
                fail()
            if is_credential_shaped(value):
                fail()


def validate_omp(data):
    if not isinstance(data, dict):
        fail()
    if set(data) != OMP_KEYS:
        fail()
    for key, value in data.items():
        if is_bytes(value) or is_credential_shaped(value):
            fail()
        if isinstance(value, bool) or isinstance(value, (int, float, str)):
            continue
        if isinstance(value, list):
            for item in value:
                if is_bytes(item) or is_credential_shaped(item):
                    fail()
                if not isinstance(item, (bool, int, float, str)):
                    fail()
            continue
        fail()
try:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    fd = os.open(source, flags)
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode):
            fail()
        chunks = []
        while True:
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        raw = b"".join(chunks)
    finally:
        os.close(fd)
    data = json.loads(raw.decode("utf-8"))
except Exception:
    fail()
if pref_id == "claude-preferences":
    validate_claude(data)
elif pref_id == "omp-preferences":
    validate_omp(data)
else:
    fail()
sys.exit(0)
PY
}
snapshot_validated_source() {
  # Args: <pref_id> <source_canonical>
  # Copies the validated source into an exclusive temp file using a
  # no-follow file-descriptor read (O_NOFOLLOW where available), verifying
  # the source is still a regular file within the utils root. Closes the
  # TOCTOU gap where the source path could be swapped to a symlink after
  # preflight. Sets SNAPSHOT_PATH on success.
  local pref_id=$1 source_canonical=$2
  SNAPSHOT_PATH=$(mktemp "${TMPDIR:-/tmp}/workstation-bootstrap-snapshot.XXXXXX") || return 1
  agent_config_register "$SNAPSHOT_PATH"
  if ! python3 - "$source_canonical" "$UTILS_CANONICAL" "$SNAPSHOT_PATH" <<'PY'; then
import os
import stat
import sys

source = sys.argv[1]
utils_root = sys.argv[2]
snapshot = sys.argv[3]

# Open with O_NOFOLLOW so a symlink swapped in after preflight is rejected.
flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
try:
    fd = os.open(source, flags)
except OSError:
    raise SystemExit(1)
try:
    st = os.fstat(fd)
    if not stat.S_ISREG(st.st_mode):
        raise SystemExit(1)
    chunks = []
    while True:
        chunk = os.read(fd, 65536)
        if not chunk:
            break
        chunks.append(chunk)
    data = b"".join(chunks)
finally:
    os.close(fd)
# Verify the canonical path is still within the utils root.
real = os.path.realpath(source)
if not (real == utils_root or real.startswith(utils_root + os.sep)):
    raise SystemExit(1)
wfd = os.open(snapshot, os.O_WRONLY | os.O_TRUNC | getattr(os, "O_NOFOLLOW", 0))
try:
    offset = 0
    while offset < len(data):
        written = os.write(wfd, data[offset:])
        if written <= 0:
            raise OSError("short write")
        offset += written
except OSError:
    os.close(wfd)
    raise SystemExit(1)
raise SystemExit(0)
PY
    rm -f "$SNAPSHOT_PATH"
    agent_config_unregister "$SNAPSHOT_PATH"
    return 1
  fi
  validate_agent_preference_source "$pref_id" "$SNAPSHOT_PATH" || {
    rm -f "$SNAPSHOT_PATH"
    agent_config_unregister "$SNAPSHOT_PATH"
    return 1
  }
}

safe_copy_file() {
  # Args: <source_path> <dest_path>
  # Exclusive no-follow copy: opens source with O_NOFOLLOW, verifies
  # regular file, creates destination exclusively with O_CREAT|O_EXCL
  # (no-follow where available), and copies data. Prevents leaf symlink
  # races on both source and backup paths.
  if ! python3 - "$1" "$2" <<'PY'; then
import os
import stat
import sys

src = sys.argv[1]
dst = sys.argv[2]

flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
try:
    sfd = os.open(src, flags)
except OSError:
    raise SystemExit(1)
try:
    st = os.fstat(sfd)
    if not stat.S_ISREG(st.st_mode):
        raise SystemExit(1)
    chunks = []
    while True:
        chunk = os.read(sfd, 65536)
        if not chunk:
            break
        chunks.append(chunk)
    data = b"".join(chunks)
finally:
    os.close(sfd)
dflags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
try:
    dfd = os.open(dst, dflags, 0o600)
except OSError:
    raise SystemExit(1)
try:
    offset = 0
    while offset < len(data):
        written = os.write(dfd, data[offset:])
        if written <= 0:
            raise OSError("short write")
        offset += written
except OSError:
    os.close(dfd)
    os.unlink(dst)
    raise SystemExit(1)
os.close(dfd)
raise SystemExit(0)
PY
    return 1
  fi
}

# Cleanup state for agent-config snapshot and OMP stage artifacts.
AGENT_CLEANUP_PATHS=()
agent_config_cleanup() {
  local p i=0 count=${#AGENT_CLEANUP_PATHS[@]}
  while [ "$i" -lt "$count" ]; do
    p=${AGENT_CLEANUP_PATHS[$i]}
    rm -rf "$p" 2>/dev/null || true
    i=$((i + 1))
  done
  AGENT_CLEANUP_PATHS=()
  [ -z "${TMP_ROOT:-}" ] || [ ! -e "$TMP_ROOT" ] || {
    rm -rf "$TMP_ROOT" 2>/dev/null || true
  }
}
agent_config_register() {
  AGENT_CLEANUP_PATHS+=("$1")
}
agent_config_unregister() {
  local p=$1 i=0 new=() entry count=${#AGENT_CLEANUP_PATHS[@]}
  while [ "$i" -lt "$count" ]; do
    entry=${AGENT_CLEANUP_PATHS[$i]}
    [ "$entry" != "$p" ] && new+=("$entry")
    i=$((i + 1))
  done
  if [ "${#new[@]}" -eq 0 ]; then
    AGENT_CLEANUP_PATHS=()
  else
    AGENT_CLEANUP_PATHS=("${new[@]}")
  fi
}
# EXIT: cleanup only (idempotent, runs on normal exit or after signal exit).
# HUP/INT/TERM: cleanup and terminate with conventional status (128+signal)
# so the script cannot continue mutating state after an interrupt.
agent_config_signal_exit() {
  agent_config_cleanup
  exit "$1"
}
trap agent_config_cleanup EXIT
trap 'agent_config_signal_exit 129' HUP
trap 'agent_config_signal_exit 130' INT
trap 'agent_config_signal_exit 143' TERM


preflight_mapping() {
  local id=$1 source=$2 destination=$3 mode=$4 profile=$5 destination_resolved
  ws_safe_token "$id" && valid_profile_tokens "$profile" || return 1
  ws_profile_matches "$profile" "$PROFILE" "$OS" || return 0
  validate_destination "$destination" || return 1
  case $mode in
    symlink)
      [ -n "$source" ] && validate_source "$source" || return 1
      if [ -e "$DESTINATION_PATH" ] || [ -L "$DESTINATION_PATH" ]; then
        if [ -L "$DESTINATION_PATH" ]; then
          destination_resolved=$(canonicalize_path "$DESTINATION_PATH") || return 1
          [ "$destination_resolved" = "$SOURCE_CANONICAL" ] && return 0
        fi
        validate_backup_target "$destination" || return 1
      fi
      ;;
    manual-review)
      [ -n "$source" ] && validate_source "$source" || return 1
      git_config_is_safe "$SOURCE_CANONICAL" || return 1
      ;;
    local)
      [ -z "$source" ] || return 1
      if [ -L "$DESTINATION_PATH" ]; then
        return 1
      elif [ -e "$DESTINATION_PATH" ]; then
        [ -f "$DESTINATION_PATH" ] || return 1
        destination_resolved=$(canonicalize_path "$DESTINATION_PATH") || return 1
        path_is_within "$destination_resolved" "$UTILS_CANONICAL" && return 1
      fi
      ;;
    json-merge)
      [ -n "$source" ] && validate_source "$source" || return 1
      validate_agent_preference_source "$id" "$SOURCE_CANONICAL" || return 1
      if [ -L "$DESTINATION_PATH" ]; then
        return 1
      elif [ -e "$DESTINATION_PATH" ]; then
        [ -f "$DESTINATION_PATH" ] || return 1
        python3 - "$DESTINATION_PATH" <<'PY' || return 1
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if isinstance(data, dict) else 1)
PY
        validate_backup_target "$destination" || return 1
      fi
      ;;
    omp-merge)
      [ -n "$source" ] && validate_source "$source" || return 1
      validate_agent_preference_source "$id" "$SOURCE_CANONICAL" || return 1
      if [ -L "$DESTINATION_PATH" ]; then
        return 1
      elif [ -e "$DESTINATION_PATH" ]; then
        [ -f "$DESTINATION_PATH" ] || return 1
        validate_backup_target "$destination" || return 1
      fi
      ;;
    *) return 1 ;;
  esac
  return 0
}

preflight_configs() {
  local line fields id source destination mode profile row=0
  while IFS= read -r line || [ -n "$line" ]; do
    row=$((row + 1))
    case $line in id$'\t'*) continue ;; esac
    [ -n "$line" ] || continue
    fields=$(ws_tsv_to_unit_separator "$line")
    IFS=$'\034' read -r id source destination mode profile <<EOF
$fields
EOF
    [ -n "$profile" ] || return 1
    preflight_mapping "$id" "$source" "$destination" "$mode" "$profile" || return 1
  done <"$CONFIG_SOURCES"
  [ "$row" -gt 1 ]
}

brew_line_profile() {
  local line=$1 token
  case $line in *' # profile:'*) ;; *) return 1 ;; esac
  token=${line##* # profile:}
  valid_profile_tokens "$token" || return 1
  printf '%s' "$token"
}

preflight_brew_manifest() {
  local line token entries=0
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in ''|'#'*) continue ;; esac
    token=$(brew_line_profile "$line") || return 1
    entries=$((entries + 1))
  done <"$BREWFILE"
  [ "$entries" -gt 0 ]
}

preflight_apt_manifest() {
  local line entries=0
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in ''|'#'*) continue ;; esac
    ws_safe_package_name "$line" || return 1
    entries=$((entries + 1))
  done <"$APT_PACKAGES"
  [ "$entries" -gt 0 ]
}

if ! preflight_configs; then
  unsafe_error
  exit 1
fi
validate_source 'nvim-custom/kickstart.patch' || {
  unsafe_error
  exit 1
}
KICKSTART_PATCH_CANONICAL=$SOURCE_CANONICAL
case $OS in
  macos) preflight_brew_manifest || { ws_die 'invalid package manifest'; exit 1; } ;;
  linux) preflight_apt_manifest || { ws_die 'invalid package manifest'; exit 1; } ;;
esac

print_packages() {
  local line token package_line
  case $OS in
    macos)
      while IFS= read -r line || [ -n "$line" ]; do
        case $line in ''|'#'*) continue ;; esac
        token=$(brew_line_profile "$line") || continue
        ws_profile_matches "$token" "$PROFILE" "$OS" || continue
        package_line=${line% # profile:*}
        printf 'PACKAGE %s\n' "$package_line"
      done <"$BREWFILE"
      ;;
    linux)
      while IFS= read -r line || [ -n "$line" ]; do
        case $line in ''|'#'*) continue ;; esac
        printf 'PACKAGE apt %s\n' "$line"
      done <"$APT_PACKAGES"
      ;;
  esac
}

install_macos_packages() {
  local filtered line token
  ws_command_exists brew || { ws_die 'brew is required for apply'; return 1; }
  TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/workstation-bootstrap.XXXXXX") || return 1
  agent_config_register "$TMP_ROOT"
  filtered="$TMP_ROOT/Brewfile"
  : >"$filtered" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in ''|'#'*) continue ;; esac
    token=$(brew_line_profile "$line") || return 1
    ws_profile_matches "$token" "$PROFILE" "$OS" || continue
    printf '%s\n' "$line" >>"$filtered" || return 1
  done <"$BREWFILE"
  brew bundle "--file=$filtered"
}

install_linux_packages() {
  local line
  ws_command_exists sudo && ws_command_exists apt-get || {
    ws_die 'sudo and apt-get are required for apply'
    return 1
  }
  set --
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in ''|'#'*) continue ;; esac
    set -- "$@" "$line"
  done <"$APT_PACKAGES"
  [ "$#" -eq 0 ] || sudo apt-get install -y "$@"
}

source_label() {
  printf '$UTILS/%s' "$1"
}

destination_label() {
  printf '$HOME/%s' "$1"
}

link_is_correct() {
  local destination_path=$1 source_canonical=$2 resolved
  [ -L "$destination_path" ] || return 1
  resolved=$(canonicalize_path "$destination_path") || return 1
  [ "$resolved" = "$source_canonical" ]
}
merge_claude_preferences() {
  # Args: <source_relative> <destination_relative>
  # Merges curated Claude preference keys into the destination JSON
  # atomically, preserving unknown local keys. Backs up the existing
  # destination first. Missing `claude` during apply prints a follow-up
  # and returns success without writing.
  local source=$1 destination=$2 stage backup_path snapshot
  validate_source "$source" || return 1
  local source_canonical=$SOURCE_CANONICAL
  validate_agent_preference_source 'claude-preferences' "$source_canonical" || return 1
  destination_paths "$destination" || return 1
  local dest_path=$DESTINATION_PATH dest_parent=$DESTINATION_PARENT
  if [ "$APPLY" -eq 0 ]; then
    printf 'PLAN AGENT_CONFIG claude-preferences -> %s\n' \
      "$(destination_label "$destination")"
    if [ -f "$dest_path" ] && [ ! -L "$dest_path" ]; then
      printf 'PLAN BACKUP %s\n' \
        "$WS_HOME_CANONICAL/.workstation-setup-backups/$TIMESTAMP/$destination"
    fi
    return 0
  fi
  ws_command_exists claude || {
    printf 'FOLLOW_UP Claude Code: install/authenticate Claude Code, then rerun bootstrap.\n'
    return 0
  }
  # Snapshot the validated source into an exclusive temp file and validate
  # the snapshot, closing the TOCTOU gap. Use only the snapshot after this.
  snapshot_validated_source 'claude-preferences' "$source_canonical" || return 1
  snapshot=$SNAPSHOT_PATH
  # Re-validate destination containment before any mkdir/mktemp/mv.
  validate_destination "$destination" || { rm -f "$snapshot"; return 1; }
  [ -L "$dest_path" ] && { rm -f "$snapshot"; return 1; }
  if [ -e "$dest_path" ]; then
    [ -f "$dest_path" ] || { rm -f "$snapshot"; return 1; }
    validate_backup_target "$destination" || { rm -f "$snapshot"; return 1; }
    backup_path="$WS_HOME_CANONICAL/.workstation-setup-backups/$TIMESTAMP/$destination"
    mkdir -p "${backup_path%/*}" || { rm -f "$snapshot"; return 1; }
    safe_copy_file "$dest_path" "$backup_path" || { rm -f "$snapshot"; return 1; }
  fi
  mkdir -p "$dest_parent" || { rm -f "$snapshot"; return 1; }
  # Use mktemp so the stage path is unpredictable and a preexisting or
  # raced symlink in the destination parent cannot be followed.
  stage=$(mktemp "${dest_parent}/.claude-settings.json.stage.XXXXXX") || {
    rm -f "$snapshot"; return 1; }
  agent_config_register "$stage"
  if ! python3 - "$snapshot" "$dest_path" "$stage" <<'PY'; then
import json
import os
import sys
src_path = sys.argv[1]
dst_path = sys.argv[2]
stage_path = sys.argv[3]
with open(src_path) as f:
    src = json.load(f)
obj = {}
try:
    with open(dst_path) as f:
        existing = json.load(f)
    if isinstance(existing, dict):
        obj = existing
except (FileNotFoundError, ValueError):
    pass
for key, value in src.items():
    obj[key] = value
stage_fd = os.open(stage_path, os.O_WRONLY | os.O_TRUNC | getattr(os, "O_NOFOLLOW", 0))
with os.fdopen(stage_fd, "w") as f:
    json.dump(obj, f, indent=2, sort_keys=True)
    f.write("\n")
PY
    rm -f "$stage" "$snapshot"
    return 1
  fi
  rm -f "$snapshot"
  agent_config_unregister "$snapshot"
  # Re-validate destination containment immediately before the atomic mv.
  validate_destination "$destination" || { rm -f "$stage"; return 1; }
  mv "$stage" "$dest_path" || { rm -f "$stage"; return 1; }
  agent_config_unregister "$stage"
  printf 'AGENT_CONFIG RESTORED claude-preferences\n'
}

merge_omp_preferences() {
  # Args: <source_relative> <destination_relative>
  # Stages curated OMP preference keys through `omp config set` against a
  # temporary PI_CODING_AGENT_DIR, then atomically installs the staged
  # config. Backs up the existing destination with a copy (not move) so a
  # failed final install leaves the live destination intact. Missing `omp`
  # during apply prints a follow-up and returns success without writing.
  local source=$1 destination=$2 stage_root backup_path staged_json snapshot
  validate_source "$source" || return 1
  local source_canonical=$SOURCE_CANONICAL
  validate_agent_preference_source 'omp-preferences' "$source_canonical" || return 1
  destination_paths "$destination" || return 1
  local dest_path=$DESTINATION_PATH dest_parent=$DESTINATION_PARENT
  if [ "$APPLY" -eq 0 ]; then
    printf 'PLAN AGENT_CONFIG omp-preferences -> %s\n' \
      "$(destination_label "$destination")"
    if [ -f "$dest_path" ] && [ ! -L "$dest_path" ]; then
      printf 'PLAN BACKUP %s\n' \
        "$WS_HOME_CANONICAL/.workstation-setup-backups/$TIMESTAMP/$destination"
    fi
    return 0
  fi
  ws_command_exists omp || {
    printf 'FOLLOW_UP OMP: install Oh My Pi, then rerun bootstrap.\n'
    return 0
  }
  # Snapshot the validated source into an exclusive temp file and validate
  # the snapshot, closing the TOCTOU gap. Use only the snapshot after this.
  snapshot_validated_source 'omp-preferences' "$source_canonical" || return 1
  snapshot=$SNAPSHOT_PATH
  # Re-validate destination containment before any mkdir/mktemp/mv.
  validate_destination "$destination" || { rm -f "$snapshot"; return 1; }
  [ -L "$dest_path" ] && { rm -f "$snapshot"; return 1; }
  mkdir -p "$dest_parent" || { rm -f "$snapshot"; return 1; }
  # Create a temporary OMP config root on the destination filesystem so
  # the atomic move stays within the same filesystem.
  stage_root=$(mktemp -d "${dest_parent}/.omp-config-stage.XXXXXX") || {
    rm -f "$snapshot"; return 1; }
  agent_config_register "$stage_root"
  if [ -f "$dest_path" ] && [ ! -L "$dest_path" ]; then
    safe_copy_file "$dest_path" "$stage_root/config.yml" || {
      rm -rf "$stage_root"; rm -f "$snapshot"; return 1; }
  fi
  # Serialize validated JSON dotted keys from the snapshot to a temp record
  # file, checking the Python exit status so a rejected control-char source
  # aborts before any omp config set call. Serialize arrays as JSON for
  # consistent round-tripping. Reject control chars/newlines in values.
  local record_file
  record_file=$(mktemp "${TMPDIR:-/tmp}/omp-keys.XXXXXX") || {
    rm -rf "$stage_root"; rm -f "$snapshot"; return 1; }
  agent_config_register "$record_file"
  if ! python3 - "$snapshot" >"$record_file" <<'PY'; then
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)
for key, value in data.items():
    if isinstance(value, bool):
        s = "true" if value else "false"
    elif isinstance(value, (int, float)):
        s = str(value)
    elif isinstance(value, str):
        if any(ord(c) < 0x20 or c == "\x7f" for c in value):
            raise SystemExit(1)
        s = value
    elif isinstance(value, list):
        s = json.dumps(value)
    else:
        s = str(value)
    if "\n" in s or "\r" in s or "\x00" in s:
        raise SystemExit(1)
    sys.stdout.write("%s\t%s\n" % (key, s))
PY
    rm -rf "$stage_root"; rm -f "$snapshot" "$record_file"
    ws_die 'cannot stage OMP preferences'
    return 1
  fi
  # Iterate the serialized record file and call omp config set against the
  # staged root, never the live home config.
  local key value_str
  while IFS=$'\t' read -r key value_str; do
    [ -n "$key" ] || continue
    PI_CODING_AGENT_DIR="$stage_root" omp config set "$key" "$value_str" || {
      rm -rf "$stage_root"; rm -f "$snapshot" "$record_file"
      ws_die 'cannot stage OMP preferences'
      return 1
    }
  done <"$record_file"
  rm -f "$record_file"
  agent_config_unregister "$record_file"
  [ -f "$stage_root/config.yml" ] && [ ! -L "$stage_root/config.yml" ] || {
    rm -rf "$stage_root"; rm -f "$snapshot"
    ws_die 'cannot stage OMP preferences'
    return 1
  }
  # Validate the staged result: query the staged config and confirm every
  # curated key/value is present and correct before replacing the live
  # destination. Normalizes both real descriptor shape
  # ({key: {value: ..., ...}}) and fixture direct shape ({key: value}).
  # Arrays are compared as decoded JSON, not string-comma-joined.
  staged_json=$(PI_CODING_AGENT_DIR="$stage_root" omp config list --json 2>/dev/null) || {
    rm -rf "$stage_root"; rm -f "$snapshot"
    ws_die 'cannot stage OMP preferences'
    return 1
  }
  printf '%s\0%s\0' "$staged_json" "$snapshot" | python3 -c '
import json
import sys

parts = sys.stdin.buffer.read().split(b"\0", 2)
if len(parts) < 2:
    raise SystemExit(1)
staged = json.loads(parts[0].decode())
with open(parts[1].decode()) as f:
    src = json.load(f)
for key, value in src.items():
    if isinstance(value, bool):
        want = value
    elif isinstance(value, list):
        want = value
    elif isinstance(value, (int, float)) and not isinstance(value, bool):
        want = value
    else:
        want = str(value)
    if key not in staged:
        raise SystemExit(1)
    got = staged[key]
    if isinstance(got, dict) and "value" in got:
        got = got["value"]
    if isinstance(want, bool):
        if isinstance(got, bool):
            if got != want:
                raise SystemExit(1)
            continue
        elif isinstance(got, str) and got in ("true", "false"):
            got = (got == "true")
            if got != want:
                raise SystemExit(1)
            continue
        else:
            raise SystemExit(1)
    elif isinstance(want, list):
        if isinstance(got, str):
            try:
                got = json.loads(got)
            except (ValueError, TypeError):
                raise SystemExit(1)
        if not isinstance(got, list) or got != want:
            raise SystemExit(1)
        continue
    elif isinstance(want, (int, float)) and not isinstance(want, bool):
        if isinstance(got, bool):
            raise SystemExit(1)
        elif isinstance(got, (int, float)) and not isinstance(got, bool):
            if got != want:
                raise SystemExit(1)
            continue
        elif isinstance(got, str):
            try:
                if float(got) != float(want):
                    raise SystemExit(1)
            except (ValueError, TypeError):
                raise SystemExit(1)
            continue
        else:
            raise SystemExit(1)
    if got != want:
        raise SystemExit(1)
' || {
    rm -rf "$stage_root"; rm -f "$snapshot"
    ws_die 'cannot stage OMP preferences'
    return 1
  }
  # Back up the existing destination with a safe copy so a failed final
  # move leaves the live destination intact.
  if [ -e "$dest_path" ] && [ ! -L "$dest_path" ]; then
    validate_backup_target "$destination" || {
      rm -rf "$stage_root"; rm -f "$snapshot"; return 1; }
    backup_path="$WS_HOME_CANONICAL/.workstation-setup-backups/$TIMESTAMP/$destination"
    mkdir -p "${backup_path%/*}" || {
      rm -rf "$stage_root"; rm -f "$snapshot"; return 1; }
    safe_copy_file "$dest_path" "$backup_path" || {
      rm -rf "$stage_root"; rm -f "$snapshot"; return 1; }
  fi
  mkdir -p "$dest_parent" || {
    rm -rf "$stage_root"; rm -f "$snapshot"; return 1; }
  # Re-validate destination containment immediately before the atomic mv.
  validate_destination "$destination" || {
    rm -rf "$stage_root"; rm -f "$snapshot"; return 1; }
  mv "$stage_root/config.yml" "$dest_path" || {
    rm -rf "$stage_root"; rm -f "$snapshot"; return 1; }
  rmdir "$stage_root" 2>/dev/null || true
  agent_config_unregister "$stage_root"
  rm -f "$snapshot"
  agent_config_unregister "$snapshot"
  printf 'AGENT_CONFIG RESTORED omp-preferences\n'
}


process_configs() {
  local line fields id source destination mode profile backup_path
  local source_canonical destination_path destination_parent
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in id$'\t'*) continue ;; esac
    [ -n "$line" ] || continue
    fields=$(ws_tsv_to_unit_separator "$line")
    IFS=$'\034' read -r id source destination mode profile <<EOF
$fields
EOF
    ws_profile_matches "$profile" "$PROFILE" "$OS" || continue
    destination_paths "$destination" || return 1
    destination_path=$DESTINATION_PATH
    destination_parent=$DESTINATION_PARENT
    case $mode in
      symlink)
        validate_source "$source" || return 1
        source_canonical=$SOURCE_CANONICAL
        if link_is_correct "$destination_path" "$source_canonical"; then
          printf 'UNCHANGED %s\n' "$(destination_label "$destination")"
          continue
        fi
        if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
          printf 'PLAN BACKUP %s\n' "$(destination_label "$destination")"
        fi
        printf 'PLAN LINK %s <- %s\n' \
          "$(destination_label "$destination")" "$(source_label "$source")"
        [ "$APPLY" -eq 1 ] || continue
        validate_destination "$destination" || return 1
        mkdir -p "$destination_parent" || return 1
        if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
          validate_backup_target "$destination" || return 1
          backup_path="$WS_HOME_CANONICAL/.workstation-setup-backups/$TIMESTAMP/$destination"
          mkdir -p "${backup_path%/*}" || return 1
          mv "$destination_path" "$backup_path" || return 1
        fi
        ln -s "$source_canonical" "$destination_path" || return 1
        ;;
      manual-review)
        printf 'MANUAL_REVIEW %s -> %s; inspect and link by hand\n' \
          "$(source_label "$source")" "$(destination_label "$destination")"
        ;;
      local)
        if [ -f "$destination_path" ] && [ ! -L "$destination_path" ]; then
          printf 'UNCHANGED %s\n' "$(destination_label "$destination")"
          continue
        fi
        printf 'PLAN LOCAL %s mode=0600\n' "$(destination_label "$destination")"
        [ "$APPLY" -eq 1 ] || continue
        validate_destination "$destination" || return 1
        [ ! -e "$destination_path" ] && [ ! -L "$destination_path" ] || return 1
        mkdir -p "$destination_parent" || return 1
        if ! (umask 077; set -C; : >"$destination_path") 2>/dev/null; then
          return 1
        fi
        chmod 600 "$destination_path" || return 1
        ;;
      json-merge) merge_claude_preferences "$source" "$destination" || return 1 ;;
      omp-merge) merge_omp_preferences "$source" "$destination" || return 1 ;;
    esac
  done <"$CONFIG_SOURCES"
}

ensure_kickstart() {
  local nvim_dir
  nvim_dir=$(canonicalize_path "$WS_HOME_CANONICAL/.config/nvim") || return 1
  if [ -d "$nvim_dir/.git" ] && [ -f "$nvim_dir/init.lua" ]; then
    return 0
  fi
  if [ -e "$nvim_dir" ] && [ ! -d "$nvim_dir" ]; then
    ws_die 'existing Neovim path is not a kickstart checkout'
    return 1
  fi
  if [ "$APPLY" -eq 0 ]; then
    printf 'PLAN PREREQ clone kickstart.nvim into $HOME/.config/nvim\n'
    return 0
  fi
  ws_command_exists git || { ws_die 'git is required to install kickstart.nvim'; return 1; }
  git clone https://github.com/nvim-lua/kickstart.nvim.git "$nvim_dir" || {
    ws_die 'cannot clone kickstart.nvim; inspect the existing Neovim directory'
    return 1
  }
  printf 'PREREQ installed kickstart.nvim at $HOME/.config/nvim\n'
}

apply_kickstart_patch() {
  local nvim_dir
  nvim_dir=$(canonicalize_path "$WS_HOME_CANONICAL/.config/nvim") || return 1
  if [ "$APPLY" -eq 0 ] && [ ! -d "$nvim_dir/.git" ]; then
    printf 'PLAN PREREQ apply tracked kickstart customizations\n'
    return 0
  fi
  ws_command_exists git || { ws_die 'git is required to apply kickstart customizations'; return 1; }
  if git -C "$nvim_dir" apply --reverse --check "$KICKSTART_PATCH_CANONICAL" >/dev/null 2>&1; then
    printf 'UNCHANGED tracked kickstart customizations active\n'
    return 0
  fi
  git -C "$nvim_dir" apply --check "$KICKSTART_PATCH_CANONICAL" >/dev/null 2>&1 || {
    ws_die 'tracked kickstart customizations do not apply cleanly'
    return 1
  }
  if [ "$APPLY" -eq 0 ]; then
    printf 'PLAN PREREQ apply tracked kickstart customizations\n'
    return 0
  fi
  git -C "$nvim_dir" apply "$KICKSTART_PATCH_CANONICAL" || return 1
  printf 'PREREQ applied tracked kickstart customizations\n'
}

ensure_ohmyzsh() {
  local zsh_root="$WS_HOME_CANONICAL/.oh-my-zsh"
  local plugin_root="$zsh_root/custom/plugins"
  local plugin url
  if [ ! -f "$zsh_root/oh-my-zsh.sh" ]; then
    if [ -e "$zsh_root" ] && [ ! -d "$zsh_root" ]; then
      ws_die 'existing oh-my-zsh path is not a directory'
      return 1
    fi
    if [ "$APPLY" -eq 0 ]; then
      printf 'PLAN PREREQ oh-my-zsh clone into $HOME/.oh-my-zsh\n'
    else
      ws_command_exists git || { ws_die 'git is required to install oh-my-zsh'; return 1; }
      git clone https://github.com/ohmyzsh/ohmyzsh.git "$zsh_root" || return 1
      printf 'PREREQ installed oh-my-zsh at $HOME/.oh-my-zsh\n'
    fi
  fi
  for plugin in zsh-autosuggestions zsh-completions; do
    case $plugin in
      zsh-autosuggestions) url=https://github.com/zsh-users/zsh-autosuggestions.git ;;
      zsh-completions) url=https://github.com/zsh-users/zsh-completions.git ;;
    esac
    if [ -d "$plugin_root/$plugin" ]; then
      continue
    fi
    if [ "$APPLY" -eq 0 ]; then
      printf 'PLAN PREREQ %s clone into $HOME/.oh-my-zsh/custom/plugins/%s\n' "$plugin" "$plugin"
    else
      ws_command_exists git || { ws_die 'git is required to install zsh plugins'; return 1; }
      mkdir -p "$plugin_root" || return 1
      git clone "$url" "$plugin_root/$plugin" || return 1
    fi
  done
}

ensure_vim() {
  local vundle="$WS_HOME_CANONICAL/.vim/bundle/Vundle.vim"
  if [ -d "$vundle" ]; then
    return 0
  fi
  if [ "$APPLY" -eq 0 ]; then
    printf 'PLAN PREREQ Vundle clone into $HOME/.vim/bundle/Vundle.vim\n'
    printf 'PLAN PREREQ Vim PluginInstall from $HOME/.vimrc\n'
    return 0
  fi
  ws_command_exists git || { ws_die 'git is required to install Vundle'; return 1; }
  mkdir -p "${vundle%/*}" || return 1
  git clone https://github.com/VundleVim/Vundle.vim.git "$vundle" || return 1
  if ws_command_exists vim; then
    vim -Nu "$UTILS_CANONICAL/.vimrc" -n -es +PluginInstall +qall >/dev/null 2>&1 || {
      ws_die 'Vim PluginInstall failed'
      return 1
    }
  fi
  printf 'PREREQ installed Vim plugins via Vundle\n'
}

validate_menu_bar_plist() {
  local id=$1 source=$2
  python3 - "$id" "$source" <<'PY' || return 1
import json
import plistlib
import re
import sys

util_id = sys.argv[1]
source = sys.argv[2]

ALLOWLISTS = {
    "alt-tab": {
        "appearanceSize", "appearanceStyle", "appsToShow", "appsToShow10",
        "appsToShow2", "crashPolicy", "exceptions", "nextWindowGesture",
        "previewFocusedWindow", "showFullscreenWindows",
        "showFullscreenWindows10", "showHiddenWindows",
        "showHiddenWindows10", "showMinimizedWindows",
        "showMinimizedWindows10", "spacesToShow", "spacesToShow10",
        "spacesToShow2", "updatePolicy", "windowOrder10",
    },
    "maccy": {
        "KeyboardShortcuts_delete", "KeyboardShortcuts_pin",
        "KeyboardShortcuts_popup", "KeyboardShortcuts_togglePreview",
        "NSStatusItem VisibleCC Item-1", "enabledPasteboardTypes",
        "pasteByDefault", "previewWidth", "removeFormattingByDefault",
        "showFooter", "showSearch", "showTitle",
    },
}
BUNDLE_IDENTIFIER_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9.-]*")
EXCEPTION_FLAG_RE = re.compile(r"[0-9]+")
MACCY_UTI_RE = re.compile(r"[A-Za-z0-9._-]+")



def bad_value(value):
    if isinstance(value, bytes):
        return True
    if isinstance(value, str):
        if value.startswith("/") or value.startswith("~"):
            return True
    if isinstance(value, dict):
        return any(bad_value(v) for v in value.values())
    if isinstance(value, list):
        return any(bad_value(v) for v in value)
    return False


def validate_alttab_exceptions(value):
    if not isinstance(value, str):
        return False
    try:
        parsed = json.loads(value)
    except (ValueError, TypeError):
        return False
    if not isinstance(parsed, list):
        return False
    for entry in parsed:
        if not isinstance(entry, dict):
            return False
        for key in entry:
            if key not in ("ignore", "hide", "bundleIdentifier"):
                return False
        for key in ("ignore", "hide"):
            if key in entry:
                value = entry[key]
                if isinstance(value, bool):
                    continue
                if isinstance(value, int):
                    continue
                if not isinstance(value, str) or EXCEPTION_FLAG_RE.fullmatch(value) is None:
                    return False
        bid = entry.get("bundleIdentifier")
        if bid is not None:
            if not isinstance(bid, str) or BUNDLE_IDENTIFIER_RE.fullmatch(bid) is None:
                return False
    return True


def validate_maccy_shortcut(value):
    if not isinstance(value, str):
        return False
    try:
        parsed = json.loads(value)
    except (ValueError, TypeError):
        return False
    if not isinstance(parsed, dict):
        return False
    if set(parsed) != {"carbonModifiers", "carbonKeyCode"}:
        return False
    for val in parsed.values():
        if not isinstance(val, int) or isinstance(val, bool):
            return False
    return True


def validate_maccy_pasteboard_types(value):
    if not isinstance(value, list):
        return False
    for item in value:
        if not isinstance(item, str) or MACCY_UTI_RE.fullmatch(item) is None:
            return False
    return True


def validate():
    allowlist = ALLOWLISTS.get(util_id)
    if allowlist is None:
        sys.exit(1)
    with open(source, "rb") as fh:
        data = plistlib.load(fh)
    if not isinstance(data, dict):
        sys.exit(1)
    for key in data:
        if key not in allowlist:
            sys.exit(1)
    for key, value in data.items():
        if bad_value(value):
            sys.exit(1)
        if util_id == "alt-tab" and key == "exceptions":
            if not validate_alttab_exceptions(value):
                sys.exit(1)
        if util_id == "maccy" and key.startswith("KeyboardShortcuts_"):
            if not validate_maccy_shortcut(value):
                sys.exit(1)
        if util_id == "maccy" and key == "enabledPasteboardTypes":
            if not validate_maccy_pasteboard_types(value):
                sys.exit(1)
    sys.exit(0)


try:
    validate()
except Exception:
    sys.exit(1)
PY
}

menu_bar_domain_status() {
  # Args: <domain> <domains>
  # Returns: 0 = allowlisted domain present, 1 = absent (skip backup).
  # Does not invoke `defaults`; the caller probes `defaults domains` once
  # before the restore loop and passes the captured, comma-normalized
  # output here so each domain is checked without re-running defaults.
  local domain=$1 domains=$2
  case ",$domains," in
    *",$domain,"*) return 0 ;;
    *) return 1 ;;
  esac
}

restore_menu_bar_settings() {
  local id domain source destination defaults_present domains_output _entry _id _destination
  local entry source_canonical destination_path backup_path status review record
  local -a mb_id=() mb_domain=() mb_source=() mb_destination=()
  local -a mb_dest_path=() mb_backup_path=() mb_status=() mb_review=()
  local i
  [ "$OS" = macos ] || return 0
  # Apply requires a real `defaults`; dry-run may run where it is absent, in
  # which case we plan the restore without probing live domains/backups.
  if [ "$APPLY" -eq 1 ]; then
    ws_command_exists defaults || { ws_die 'defaults is required for menu-bar restore'; return 1; }
    defaults_present=1
  elif ws_command_exists defaults; then
    defaults_present=1
  else
    defaults_present=0
  fi
  # Symlink pre-scan: in apply mode, reject any existing logical destination
  # symlink before probing `defaults domains` (i.e. before checking defaults
  # domain status), so a symlinked destination is preserved and aborted with
  # an unsafe error regardless of whether its domain is present. Dry-run does
  # not mutate, so symlinks are merely noted for PLAN REVIEW below.
  if [ "$APPLY" -eq 1 ]; then
    for _entry in \
      'alt-tab|Library/Preferences/com.lwouis.alt-tab-macos.plist' \
      'maccy|Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist' \
      ; do
      IFS='|' read -r _id _destination <<EOF
$_entry
EOF
      destination_paths "$_destination" || {
        ws_die "unsafe menu-bar destination $_id"
        return 1
      }
      if [ -L "$DESTINATION_PATH" ]; then
        unsafe_error
        ws_die "unsafe menu-bar destination symlink $_id"
        return 1
      fi
    done
  fi
  # Probe `defaults domains` exactly once, before the preflight loop, whenever
  # defaults is available. A single failure aborts before any export/import.
  domains_output=''
  if [ "$defaults_present" -eq 1 ]; then
    domains_output=$(defaults domains 2>/dev/null) || {
      ws_die 'defaults domains failed for menu-bar restore'
      return 1
    }
    domains_output=${domains_output//, /,}
  fi
  # Preflight loop: validate both fixed records and capture their statuses
  # before any backup/export/import. If any validation or status check fails,
  # return before mutating anything, so the restore is all-or-nothing rather
  # than a partial restore that mutated the first record before the second
  # failed.
  record=0
  for entry in \
    'alt-tab|com.lwouis.alt-tab-macos|macos/menu-bar/alt-tab/preferences.plist|Library/Preferences/com.lwouis.alt-tab-macos.plist' \
    'maccy|org.p0deje.Maccy|macos/menu-bar/maccy/preferences.plist|Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist' \
    ; do
    IFS='|' read -r id domain source destination <<EOF
$entry
EOF
    validate_source "$source" || {
      ws_die "unsafe menu-bar source $id"
      return 1
    }
    source_canonical=$SOURCE_CANONICAL
    validate_menu_bar_plist "$id" "$source_canonical" || {
      ws_die "invalid menu-bar plist $id"
      return 1
    }
    validate_destination "$destination" || {
      ws_die "unsafe menu-bar destination $id"
      return 1
    }
    destination_path=$DESTINATION_PATH
    backup_path="$WS_HOME_CANONICAL/.workstation-setup-backups/$TIMESTAMP/$destination"
    # Symlink destination: apply rejects as unsafe and fails preflight before
    # any export/import; dry-run marks the record for a PLAN REVIEW note and
    # skips backup/import in the action loop.
    review=0
    if [ -L "$destination_path" ]; then
      if [ "$APPLY" -eq 1 ]; then
        unsafe_error
        ws_die "unsafe menu-bar destination symlink $id"
        return 1
      fi
      review=1
    fi
    # Capture the domain status from the single pre-captured domains probe.
    status=1
    if [ "$defaults_present" -eq 1 ]; then
      menu_bar_domain_status "$domain" "$domains_output"
      status=$?
    fi
    # Apply only: validate the backup target for records that will back up, so
    # an unsafe or pre-existing backup path is caught before any export/import.
    if [ "$APPLY" -eq 1 ] && [ "$review" -eq 0 ]; then
      if [ "$status" -eq 0 ] || [ -f "$destination_path" ]; then
        validate_backup_target "$destination" || {
          ws_die "unsafe menu-bar backup target $id"
          return 1
        }
      fi
    fi
    mb_id[$record]=$id
    mb_domain[$record]=$domain
    mb_source[$record]=$source_canonical
    mb_destination[$record]=$destination
    mb_dest_path[$record]=$destination_path
    mb_backup_path[$record]=$backup_path
    mb_status[$record]=$status
    mb_review[$record]=$review
    record=$((record + 1))
  done
  # Action loop: dry-run output or apply backups/imports using the
  # prevalidated records and statuses. No defaults probing or
  # source/plist/destination validation runs here.
  i=0
  while [ "$i" -lt "$record" ]; do
    id=${mb_id[$i]}
    domain=${mb_domain[$i]}
    source=${mb_source[$i]}
    destination=${mb_destination[$i]}
    destination_path=${mb_dest_path[$i]}
    backup_path=${mb_backup_path[$i]}
    status=${mb_status[$i]}
    review=${mb_review[$i]}
    if [ "$APPLY" -eq 0 ]; then
      if [ "$review" -eq 1 ]; then
        printf 'PLAN REVIEW $HOME/%s is a symlink; resolve manually before apply\n' "$destination"
        printf 'PLAN MENU_BAR %s -> $HOME/%s\n' "$id" "$destination"
        i=$((i + 1))
        continue
      fi
      if [ "$defaults_present" -eq 1 ] && [ "$status" -eq 0 ]; then
        printf 'PLAN BACKUP $HOME/.workstation-setup-backups/%s/%s\n' "$TIMESTAMP" "$destination"
      elif [ "$defaults_present" -eq 1 ] && [ "$status" -ne 0 ] && [ -f "$destination_path" ]; then
        printf 'PLAN BACKUP $HOME/.workstation-setup-backups/%s/%s\n' "$TIMESTAMP" "$destination"
      fi
      printf 'PLAN MENU_BAR %s -> $HOME/%s\n' "$id" "$destination"
      i=$((i + 1))
      continue
    fi
    # Apply: back up the existing state before importing. A present domain is
    # exported from the live store; an absent domain with a regular file at
    # the logical destination is copied. Symlink destinations were rejected
    # during preflight, so only a regular file is backed up here.
    if [ "$status" -eq 0 ]; then
      mkdir -p "${backup_path%/*}" || return 1
      defaults export "$domain" "$backup_path" || {
        ws_die "cannot export menu-bar plist $id"
        return 1
      }
    elif [ -f "$destination_path" ]; then
      mkdir -p "${backup_path%/*}" || return 1
      cp "$destination_path" "$backup_path" || {
        ws_die "cannot back up menu-bar plist $id"
        return 1
      }
    fi
    defaults import "$domain" "$source" || {
      ws_die "cannot import menu-bar plist $id"
      return 1
    }
    printf 'MENU_BAR RESTORED %s\n' "$id"
    i=$((i + 1))
  done
}

restore_intellij_settings() {
  local jetbrains_root candidate candidate_canonical dir name source destination backup_path
  if [ "$OS" = macos ]; then
    jetbrains_root="$WS_HOME_CANONICAL/Library/Application Support/JetBrains"
  else
    jetbrains_root="$WS_HOME_CANONICAL/.config/JetBrains"
  fi
  candidate=''
  for dir in "$jetbrains_root"/IntelliJIdea*/ "$jetbrains_root"/IdeaIC*/; do
    [ -d "$dir/options" ] || continue
    candidate=${dir%/}
  done
  if [ -z "$candidate" ]; then
    printf 'FOLLOW_UP IntelliJ: install IntelliJ IDEA, then restore ide/intellij/options manually.\n'
    return 0
  fi
  candidate_canonical=$(canonicalize_path "$candidate") || return 1
  path_is_within "$candidate_canonical" "$WS_HOME_CANONICAL" || {
    ws_die 'IntelliJ options directory escapes HOME'
    return 1
  }

  for name in editor.xml ui.lnf.xml terminal.xml; do
    source="$UTILS_CANONICAL/ide/intellij/options/$name"
    destination="$candidate/options/$name"
    [ -f "$source" ] || continue
    validate_source "ide/intellij/options/$name" || {
      ws_die "unsafe IntelliJ source $name"
      return 1
    }
    source=$SOURCE_CANONICAL
    if [ -f "$destination" ] && cmp -s "$source" "$destination"; then
      printf 'UNCHANGED IntelliJ %s\n' "$name"
      continue
    fi
    if [ "$APPLY" -eq 0 ]; then
      printf 'PLAN IDE IntelliJ %s -> %s\n' "$name" "$destination"
      continue
    fi
    if [ -e "$destination" ] || [ -L "$destination" ]; then
      backup_path="$WS_HOME_CANONICAL/.workstation-setup-backups/$TIMESTAMP/$(basename "$jetbrains_root")/$(basename "$candidate")/options/$name"
      mkdir -p "${backup_path%/*}" || return 1
      mv "$destination" "$backup_path" || return 1
    fi
    cp "$source" "$destination" || return 1
    printf 'IDE RESTORED IntelliJ %s\n' "$name"
  done
}

install_ide_extensions() {
  local editor manifest_dir manifest extension
  for editor in code cursor; do
    case "$editor" in
      code) manifest_dir=vscode ;;
      cursor) manifest_dir=cursor ;;
    esac
    manifest="$UTILS_CANONICAL/ide/$manifest_dir/extensions.txt"
    [ -r "$manifest" ] || continue
    if ! ws_command_exists "$editor"; then
      printf 'FOLLOW_UP %s: install extensions from %s\n' "$editor" "$manifest"
      continue
    fi
    if [ "$APPLY" -eq 0 ]; then
      printf 'PLAN PREREQ %s extensions from %s\n' "$editor" "$manifest"
      continue
    fi
    while IFS= read -r extension || [ -n "$extension" ]; do
      [ -n "$extension" ] || continue
      "$editor" --install-extension "$extension" >/dev/null 2>&1 || {
        ws_die "cannot install $editor extension $extension"
        return 1
      }
    done <"$manifest"
    printf 'PREREQ installed %s extensions\n' "$editor"
  done
}

print_follow_ups() {
  printf 'FOLLOW_UP base: review local Git identity and sign in to developer tools manually.\n'
  case $PROFILE in
    work)
      printf 'FOLLOW_UP work: provision work access and Kubernetes configuration manually.\n'
      ;;
    mobile)
      printf 'FOLLOW_UP mobile: accept SDK licenses and configure signing manually.\n'
      ;;
  esac
}

if [ "$APPLY" -eq 0 ]; then
  printf 'DRY_RUN no changes will be made\n'
fi
print_packages
if [ "$APPLY" -eq 1 ]; then
  case $OS in
    macos) install_macos_packages || exit 1 ;;
    linux) install_linux_packages || exit 1 ;;
  esac
fi
restore_menu_bar_settings || exit 1
ensure_kickstart || exit 1
apply_kickstart_patch || {
  ws_die 'kickstart customization failed'
  exit 1
}
ensure_ohmyzsh || exit 1
ensure_vim || exit 1
restore_intellij_settings || exit 1
install_ide_extensions || exit 1
process_configs || {
  ws_die 'bootstrap apply failed'
  exit 1
}
print_follow_ups
